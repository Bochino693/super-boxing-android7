"""Gera a torcida da arena: sons longos e a plateia pintada (gente de verdade).

    python tools/gerar_torcida.py

Saídas:
  assets/audio/arcade/torcida_vaia.wav   vaia longa ("uuuuh") + apitos, sintetizada
  assets/audio/arcade/torcida_festa.wav  festa longa, emendando as gravações CC0
                                          que já estão no projeto
  assets/audio/arcade/torcida_incentivo.wav  a torcida EMPURRANDO no meio da luta:
                                          palmas ritmadas, "VAI! VAI!" em coro e
                                          a plateia gravada por baixo
  assets/arena/torcida_baixo.png         plateia de braços baixos
  assets/arena/torcida_cima.png          a MESMA plateia, braços para o alto

Requer: numpy, scipy, pillow.
"""
from pathlib import Path
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage as nd
from scipy import signal

RAIZ = Path(__file__).resolve().parents[1]
AUDIO = RAIZ / "assets" / "audio" / "arcade"
ARENA = RAIZ / "assets" / "arena"
FONTE_PLACA = str(RAIZ / "assets" / "fonts" / "Bungee-Regular.ttf")
SR = 44100
rng = np.random.default_rng(20260924)


def ler(nome):
    with wave.open(str(AUDIO / nome)) as w:
        dados = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float32) / 32768
        return dados.reshape(-1, w.getnchannels())


def gravar(nome, x):
    x = x / max(1e-6, np.abs(x).max()) * 0.84
    with wave.open(str(AUDIO / nome), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    print("ok", nome, round(len(x) / SR, 2), "s")


def reverb(x, segundos=1.3, mistura=0.28):
    n = int(SR * segundos)
    t = np.arange(n) / SR
    ir = rng.standard_normal((n, 2)) * np.exp(-t * 5.0)[:, None]
    ir[0] = 1.0
    out = np.stack([signal.fftconvolve(x[:, c], ir[:, c])[: len(x)] for c in range(2)], 1)
    out /= np.abs(out).max() + 1e-9
    return x * (1 - mistura) + out * mistura * np.abs(x).max()


def formante(x, f, largura):
    b, a = signal.iirpeak(f, f / largura, SR)
    return signal.lfilter(b, a, x)


def vaia(duracao=8.0):
    n = int(SR * duracao)
    t = np.arange(n) / SR
    mix = np.zeros((n, 2))
    for _ in range(70):
        f0 = rng.uniform(92, 175) if rng.random() < 0.8 else rng.uniform(170, 260)
        vib = 1 + 0.012 * np.sin(2 * np.pi * rng.uniform(4, 6.5) * t + rng.uniform(0, 6))
        queda = 1 - 0.10 * np.clip((t - rng.uniform(1, 5)) / 3, 0, 1)
        fase = np.cumsum(f0 * vib * queda) / SR
        voz = 2 * (fase % 1) - 1  # dente de serra: a glote
        voz = formante(voz, rng.uniform(300, 360), 5) * 1.0 + formante(voz, rng.uniform(760, 880), 7) * 0.45 \
            + formante(voz, 2300, 10) * 0.06
        inicio = rng.uniform(0.0, 1.2)
        env = np.clip((t - inicio) / rng.uniform(0.25, 0.7), 0, 1)
        # respiração: a vaia vem em ondas ("uuuh... uuuuh")
        periodo = rng.uniform(1.6, 3.2)
        onda = 0.55 + 0.45 * np.clip(np.sin(2 * np.pi * (t - inicio) / periodo + rng.uniform(0, 1)) * 1.6, -1, 1)
        fim = np.clip((duracao - t) / 1.4, 0, 1)
        voz = voz * env * onda * fim * rng.uniform(0.4, 1.0)
        pan = rng.uniform(0.15, 0.85)
        mix[:, 0] += voz * (1 - pan)
        mix[:, 1] += voz * pan
    # apitos de torcida, poucos
    for _ in range(5):
        ini = rng.uniform(0.8, duracao - 2)
        dur = rng.uniform(0.35, 0.9)
        tt = np.clip(t - ini, 0, None)
        f = rng.uniform(2300, 3300) * (1 - 0.08 * tt / dur)
        ap = np.sin(2 * np.pi * np.cumsum(f) / SR) * ((t > ini) & (t < ini + dur)) * np.exp(-tt * 1.5)
        pan = rng.uniform(0.2, 0.8)
        mix[:, 0] += ap * 0.05 * (1 - pan)
        mix[:, 1] += ap * 0.05 * pan
    # cama de gente falando (ruído grave)
    cama = signal.lfilter(*signal.butter(2, [120, 900], "bandpass", fs=SR), rng.standard_normal((n, 2)), axis=0)
    mix += cama * 0.25 * np.clip(t / 0.6, 0, 1)[:, None] * np.clip((duracao - t) / 1.4, 0, 1)[:, None]
    return reverb(mix)


def festa():
    partes = [ler("torcida_recorde.wav"), ler("torcida_podio.wav"), ler("arena_publico.wav")]
    cruza = int(SR * 0.9)
    out = partes[0]
    for p in partes[1:]:
        rampa = np.linspace(0, 1, cruza)[:, None]
        meio = out[-cruza:] * (1 - rampa) + p[:cruza] * rampa
        out = np.concatenate([out[:-cruza], meio, p[cruza:]])
    n = len(out)
    t = np.arange(n) / SR
    # palmas ritmadas por baixo (a torcida "pegando fogo")
    palmas = np.zeros(n)
    batida = 60 / 128
    k = 0.6
    while k < t[-1] - 0.5:
        i = int(k * SR)
        m = min(n - i, int(0.06 * SR))
        palmas[i:i + m] += rng.standard_normal(m) * np.exp(-np.arange(m) / (0.012 * SR))
        k += batida
    palmas = signal.lfilter(*signal.butter(2, [900, 5000], "bandpass", fs=SR), palmas)
    out = out + np.stack([palmas, palmas], 1) * 0.18
    fim = np.clip((t[-1] - t) / 1.2, 0, 1)[:, None]
    return out * fim


def incentivo(duracao=4.2):
    """O coro que empurra quem está batendo: "VAI! VAI! VAI!" com palmas.

    Nada de vaia aqui — vaia é só do fim, de quem perdeu. No meio da luta
    a torcida está do lado do jogador."""
    n = int(SR * duracao)
    t = np.arange(n) / SR
    mix = np.zeros((n, 2))
    batida = 60 / 150
    inicios = np.arange(0.18, duracao - 0.6, batida * 2)
    for _ in range(46):
        f0 = rng.uniform(130, 230) if rng.random() < 0.7 else rng.uniform(210, 330)
        atraso = rng.normal(0, 0.025)
        voz = np.zeros(n)
        for k, ini in enumerate(inicios):
            ini += atraso
            dur = batida * rng.uniform(0.62, 0.8)
            m = (t >= ini) & (t < ini + dur)
            tt = np.clip(t - ini, 0, None)
            # "vai": do /a/ para o /i/, com o tom subindo no fim do grito
            fase = np.cumsum(f0 * (1 + 0.10 * np.clip(tt / dur, 0, 1))) / SR
            glote = 2 * (fase % 1) - 1
            env = np.clip(tt / 0.035, 0, 1) * np.clip((ini + dur - t) / 0.08, 0, 1) * m
            voz += glote * env
        # formantes: /a/ (730, 1090) indo para /i/ (300, 2300) — mistura fixa
        # das duas bocas; o ouvido lê o ditongo na média de 46 vozes
        voz = formante(voz, rng.uniform(640, 760), 5) + formante(voz, rng.uniform(1050, 1250), 7) * 0.5 \
            + formante(voz, rng.uniform(2100, 2500), 10) * 0.18
        pan = rng.uniform(0.1, 0.9)
        g = rng.uniform(0.4, 1.0)
        mix[:, 0] += voz * g * (1 - pan)
        mix[:, 1] += voz * g * pan
    # palmas no contratempo do coro
    palmas = np.zeros((n, 2))
    k = 0.18 + batida
    while k < duracao - 0.4:
        for _ in range(18):
            i = int((k + rng.normal(0, 0.012)) * SR)
            m = min(n - i, int(0.05 * SR))
            if m <= 0:
                continue
            pan = rng.uniform(0, 1)
            c = rng.standard_normal(m) * np.exp(-np.arange(m) / (0.009 * SR)) * rng.uniform(0.5, 1)
            palmas[i:i + m, 0] += c * (1 - pan)
            palmas[i:i + m, 1] += c * pan
        k += batida
    palmas = signal.lfilter(*signal.butter(2, [800, 6000], "bandpass", fs=SR), palmas, axis=0)
    mix = mix / (np.abs(mix).max() + 1e-9) + palmas / (np.abs(palmas).max() + 1e-9) * 0.55
    publico = ler("arena_publico.wav")
    cama = np.zeros((n, 2))
    m = min(n, len(publico))
    cama[:m] = publico[:m]
    mix = mix + cama * 0.5
    fim = np.clip((duracao - t) / 0.7, 0, 1)[:, None] * np.clip(t / 0.08, 0, 1)[:, None]
    return reverb(mix * fim, 1.1, 0.24)


# ------------------------------------------------------------ plateia
## AS FILEIRAS DA PLATEIA: (colunas, faixa em pixels, quanto a névoa come).
## CADA PESSOA MORA INTEIRA DENTRO DA SUA COLUNA, e cada fileira numa
## faixa própria da imagem. O shader da arena faz cada coluna pular no seu
## ritmo — com gente espalhada ao acaso, a coluna cortava a pessoa ao
## meio e metade do corpo pulava separada da outra. A coluna É a pessoa.
FILEIRAS = [
    (52, (0, 150), 0.52),     # fundo: pequena, mais apagada pela névoa
    (40, (150, 320), 0.74),   # meio
    (30, (320, 512), 0.92),   # frente: grande e nítida
]
## GENTE DE VERDADE, e não silhueta: pele, cabelo, camisa e o que cada um
## traz na mão variam pessoa a pessoa (sorteio fixo: a imagem sai igual
## toda vez que o script roda).
PELES = [(255, 214, 170), (238, 190, 140), (222, 168, 112), (196, 136, 88),
         (160, 102, 62), (120, 76, 46), (88, 56, 36), (232, 184, 158)]
CABELOS = [(18, 14, 12), (34, 22, 14), (58, 36, 20), (96, 62, 30),
           (170, 128, 70), (120, 48, 22), (130, 130, 136), (12, 10, 10)]
CAMISAS = [(214, 30, 48), (30, 76, 200), (250, 200, 30), (238, 238, 242),
           (26, 26, 30), (20, 150, 80), (240, 110, 20), (130, 50, 190),
           (0, 170, 200), (200, 40, 140), (90, 96, 110), (150, 20, 30)]
CAMISAS[3] = (196, 196, 204)  # branco de ginásio, não branco de estúdio
PLACAS = ["KO!", "VAI!", "10", "UAU", "POW", "#1"]
## O ENCOSTO DA ARQUIBANCADA: da fração ASSENTO da faixa até o pé dela, uma
## faixa opaca na frente de cada fileira. O shader da arena deixa esse
## trecho PARADO (as pessoas pulam atrás dele) — tem de ser o mesmo número
## de `ASSENTO_DA_TORCIDA` em `scripts/arena/arena3d.gd`. Sem ele cada
## pessoa era uma barra que terminava num corte reto no pé da fileira.
ASSENTO = 0.80
ENCOSTO = (40, 28, 62)
ESCALA = 2  # desenha no dobro e reduz: bordas lisas, sem serrilhado


def _cor(c, f=1.0, a=255):
    return tuple(int(max(0, min(255, v * f))) for v in c[:3]) + (a,)


def _pessoa(dbx, dcx, x, y0, y1, ww, cw):
    """Uma pessoa nas duas versões (braços baixos em `dbx`, erguidos em
    `dcx`), com os MESMOS traços: o shader troca uma pela outra."""
    pele = PELES[rng.integers(len(PELES))]
    cabelo = CABELOS[rng.integers(len(CABELOS))]
    camisa = CAMISAS[rng.integers(len(CAMISAS))]
    estilo = rng.choice(["curto", "curto", "longo", "careca", "bone", "black", "gorro", "rabo"])
    mao_baixa = rng.choice(["nada", "nada", "celular", "palmas", "copo"])
    mao_alta = rng.choice(["punhos", "punhos", "abertas", "celular", "placa", "cachecol"])
    barba = rng.random() < 0.22
    listra = rng.random() < 0.35
    ombro = y0 + max(1.22 * ww, (y1 - y0) * 0.50) + rng.uniform(-0.05, 0.05) * ww
    cab_r = ww * rng.uniform(0.21, 0.24)
    cab_y = ombro - ww * 0.46
    boca_aberta = rng.random() < 0.55
    cor_bone = CAMISAS[rng.integers(len(CAMISAS))]
    texto = PLACAS[rng.integers(len(PLACAS))]
    cor_placa = [(250, 250, 240), (255, 214, 40), (255, 90, 170)][rng.integers(3)]
    for d, alto in ((dbx, False), (dcx, True)):
        # cabelo de trás (longo, black power, rabo de cavalo)
        if estilo == "longo":
            d.rounded_rectangle([x - cab_r * 1.15, cab_y - cab_r * 1.05, x + cab_r * 1.15, cab_y + cab_r * 1.9],
                                radius=cab_r, fill=_cor(cabelo))
        elif estilo == "black":
            d.ellipse([x - cab_r * 1.55, cab_y - cab_r * 1.6, x + cab_r * 1.55, cab_y + cab_r * 0.9], fill=_cor(cabelo))
        elif estilo == "rabo":
            d.ellipse([x + cab_r * 0.6, cab_y - cab_r * 0.2, x + cab_r * 1.4, cab_y + cab_r * 1.3], fill=_cor(cabelo))
        # tronco: ombros largos, afina na cintura; camisa com sombra embaixo
        d.polygon([(x - ww * 0.52, ombro - ww * 0.05), (x + ww * 0.52, ombro - ww * 0.05),
                   (x + ww * 0.49, y1 - 1), (x - ww * 0.49, y1 - 1)], fill=_cor(camisa))
        d.ellipse([x - ww * 0.56, ombro - ww * 0.14, x - ww * 0.20, ombro + ww * 0.22], fill=_cor(camisa))
        d.ellipse([x + ww * 0.20, ombro - ww * 0.14, x + ww * 0.56, ombro + ww * 0.22], fill=_cor(camisa))
        if listra:
            d.rectangle([x - ww * 0.46, ombro + ww * 0.30, x + ww * 0.46, ombro + ww * 0.42], fill=_cor(camisa, 0.45))
        # gola
        d.ellipse([x - ww * 0.15, ombro - ww * 0.12, x + ww * 0.15, ombro + ww * 0.08], fill=_cor(camisa, 0.55))
        # braços
        mangas = _cor(camisa, 0.82)
        grosso = max(3, int(ww * 0.24))
        if not alto:
            for lado in (-1, 1):
                ox = x + lado * ww * 0.43
                if mao_baixa in ("celular", "palmas", "copo"):
                    mx, my = x + lado * ww * 0.10, ombro + ww * 0.55
                else:
                    mx, my = x + lado * ww * 0.47, ombro + ww * 0.95
                cx_, cy_ = ox + lado * ww * 0.10, ombro + ww * 0.45
                d.line([ox, ombro + ww * 0.05, cx_, cy_], fill=mangas, width=grosso)
                d.line([cx_, cy_, mx, my], fill=_cor(pele, 0.85), width=int(grosso * 0.85))
                d.ellipse([mx - ww * 0.09, my - ww * 0.09, mx + ww * 0.09, my + ww * 0.09], fill=_cor(pele, 0.9))
            if mao_baixa == "celular":
                d.rectangle([x - ww * 0.09, ombro + ww * 0.36, x + ww * 0.09, ombro + ww * 0.58], fill=(200, 230, 255, 255))
            elif mao_baixa == "copo":
                d.rectangle([x + ww * 0.02, ombro + ww * 0.34, x + ww * 0.20, ombro + ww * 0.60], fill=(250, 210, 60, 255))
        else:
            abre = rng.uniform(0.05, 0.20)
            for lado in (-1, 1):
                ox, oy = x + lado * ww * 0.44, ombro + ww * 0.02
                if mao_alta in ("placa", "cachecol"):
                    mx, my = x + lado * ww * 0.40, ombro - ww * 1.05
                elif mao_alta == "celular" and lado > 0:
                    mx, my = x + ww * 0.30, ombro - ww * 0.95
                elif mao_alta == "celular":
                    mx, my = x - ww * 0.50, ombro + ww * 0.85
                else:
                    mx, my = ox + lado * ww * abre, ombro - ww * 1.05
                cx_, cy_ = (ox + mx) * 0.5 + lado * ww * 0.10, (oy + my) * 0.5
                d.line([ox, oy, cx_, cy_], fill=mangas, width=grosso)
                d.line([cx_, cy_, mx, my], fill=_cor(pele, 0.9), width=int(grosso * 0.85))
                r = ww * (0.10 if mao_alta == "punhos" else 0.09)
                d.ellipse([mx - r, my - r, mx + r, my + r], fill=_cor(pele))
            topo = ombro - ww * 1.05
            if mao_alta == "celular":
                d.rectangle([x + ww * 0.20, topo - ww * 0.26, x + ww * 0.40, topo + ww * 0.02], fill=(215, 240, 255, 255))
            elif mao_alta == "placa":
                d.rectangle([x - ww * 0.50, topo - ww * 0.42, x + ww * 0.50, topo + ww * 0.08], fill=_cor(cor_placa))
                try:
                    fonte = ImageFont.truetype(FONTE_PLACA, max(8, int(ww * 0.34)))
                    d.text((x, topo - ww * 0.17), texto, font=fonte, fill=(30, 12, 40, 255), anchor="mm")
                except OSError:
                    pass
            elif mao_alta == "cachecol":
                for k in range(6):
                    xa = x - ww * 0.40 + k * ww * 0.8 / 6
                    d.rectangle([xa, topo - ww * 0.12, xa + ww * 0.8 / 6, topo + ww * 0.06],
                                fill=_cor(camisa if k % 2 == 0 else (240, 240, 240)))
        # pescoço e cabeça
        d.rectangle([x - ww * 0.09, cab_y + cab_r * 0.6, x + ww * 0.09, ombro], fill=_cor(pele, 0.78))
        d.ellipse([x - cab_r, cab_y - cab_r * 1.12, x + cab_r, cab_y + cab_r * 1.08], fill=_cor(pele))
        d.ellipse([x - cab_r * 1.12, cab_y - cab_r * 0.1, x - cab_r * 0.78, cab_y + cab_r * 0.35], fill=_cor(pele, 0.9))
        d.ellipse([x + cab_r * 0.78, cab_y - cab_r * 0.1, x + cab_r * 1.12, cab_y + cab_r * 0.35], fill=_cor(pele, 0.9))
        # cabelo da frente / bonés
        if estilo in ("curto", "longo", "rabo"):
            d.chord([x - cab_r * 1.04, cab_y - cab_r * 1.2, x + cab_r * 1.04, cab_y + cab_r * 0.5], 180, 360, fill=_cor(cabelo))
        elif estilo == "black":
            d.chord([x - cab_r * 1.2, cab_y - cab_r * 1.45, x + cab_r * 1.2, cab_y + cab_r * 0.3], 180, 360, fill=_cor(cabelo))
        elif estilo == "bone":
            d.chord([x - cab_r * 1.05, cab_y - cab_r * 1.25, x + cab_r * 1.05, cab_y + cab_r * 0.3], 180, 360, fill=_cor(cor_bone))
            d.rectangle([x - cab_r * 1.0, cab_y - cab_r * 0.5, x + cab_r * 1.35, cab_y - cab_r * 0.3], fill=_cor(cor_bone, 0.7))
        elif estilo == "gorro":
            d.chord([x - cab_r * 1.08, cab_y - cab_r * 1.35, x + cab_r * 1.08, cab_y + cab_r * 0.2], 180, 360, fill=_cor(cor_bone))
            d.rectangle([x - cab_r * 1.08, cab_y - cab_r * 0.55, x + cab_r * 1.08, cab_y - cab_r * 0.30], fill=_cor(cor_bone, 0.7))
        if barba:
            d.chord([x - cab_r * 0.9, cab_y - cab_r * 0.3, x + cab_r * 0.9, cab_y + cab_r * 1.1], 0, 180, fill=_cor(cabelo, 0.9))
        # rosto: sobrancelhas, olhos, nariz e a boca (gritando ou sorrindo)
        olho_y = cab_y - cab_r * 0.05
        for lado in (-1, 1):
            ex = x + lado * cab_r * 0.38
            d.line([ex - cab_r * 0.18, olho_y - cab_r * 0.28, ex + cab_r * 0.18, olho_y - cab_r * 0.30], fill=_cor(cabelo, 0.8),
                   width=max(1, int(cab_r * 0.12)))
            d.ellipse([ex - cab_r * 0.11, olho_y - cab_r * 0.08, ex + cab_r * 0.11, olho_y + cab_r * 0.10], fill=(24, 16, 14, 255))
        d.line([x, olho_y + cab_r * 0.05, x - cab_r * 0.08, olho_y + cab_r * 0.40], fill=_cor(pele, 0.72), width=max(1, int(cab_r * 0.1)))
        by = cab_y + cab_r * 0.62
        if boca_aberta or alto:
            d.ellipse([x - cab_r * 0.26, by - cab_r * 0.14, x + cab_r * 0.26, by + cab_r * 0.26], fill=(70, 18, 24, 255))
        else:
            d.arc([x - cab_r * 0.3, by - cab_r * 0.3, x + cab_r * 0.3, by + cab_r * 0.12], 20, 160, fill=(80, 30, 30, 255),
                  width=max(1, int(cab_r * 0.1)))


def plateia():
    L, A = 2048 * ESCALA, 512 * ESCALA
    baixo = Image.new("RGBA", (L, A), (0, 0, 0, 0))
    cima = Image.new("RGBA", (L, A), (0, 0, 0, 0))
    db, dc = ImageDraw.Draw(baixo), ImageDraw.Draw(cima)
    for colunas, (y0, y1), _ in FILEIRAS:
        cw = L / colunas
        for c in range(colunas):
            x = (c + 0.5) * cw + rng.uniform(-0.04, 0.04) * cw
            ww = cw * rng.uniform(0.84, 0.90)
            _pessoa(db, dc, x, y0 * ESCALA, y1 * ESCALA, ww, cw)
        # o encosto na frente da fileira, igual nas duas versões
        ya = (y0 + (y1 - y0) * ASSENTO) * ESCALA
        yb = y1 * ESCALA
        for d in (db, dc):
            d.rectangle([0, ya, L, yb], fill=_cor(ENCOSTO))
            for c in range(colunas):
                xa, xb = c * cw + cw * 0.06, (c + 1) * cw - cw * 0.06
                d.rounded_rectangle([xa, ya + ESCALA * 2, xb, yb], radius=cw * 0.10, fill=_cor(ENCOSTO, 1.35))
            # o friso de cima pega a luz do ringue
            d.rectangle([0, ya, L, ya + ESCALA * 2], fill=_cor(ENCOSTO, 2.4))
    saidas = []
    for img in (baixo, cima):
        a = np.asarray(img).astype(np.float32) / 255.0
        alfa = a[..., 3]
        cor = a[..., :3]
        yy = np.arange(A)[:, None] / A
        xx = np.arange(L)[None, :] / L
        # VOLUME: o miolo de cada forma mais claro que a borda (ombros,
        # cabeça e braços deixam de ser recortes chapados).
        d = nd.distance_transform_edt(alfa > 0.5).astype(np.float32)
        volume = np.clip(d / (8.0 * ESCALA), 0.0, 1.0) ** 0.6
        # A LUZ DO RINGUE: poças de refletor que varrem a plateia e um
        # brilho que vem de baixo (o ringue aceso na frente dela).
        pocas = 0.55 + 0.45 * np.clip(np.sin(xx * 9.0 + 0.6) * 0.5 + 0.5, 0, 1) ** 2
        luz = np.zeros_like(alfa)
        for colunas, (y0, y1), nevoa in FILEIRAS:
            faixa = (np.arange(A) >= y0 * ESCALA) & (np.arange(A) < y1 * ESCALA)
            dentro = (yy[faixa] - y0 / 512) / ((y1 - y0) / 512)
            # o corpo mergulha na sombra da fileira da frente
            luz[faixa] = nevoa * np.where(dentro >= ASSENTO, 0.62,
                                          0.22 + 0.78 * np.clip(1.15 - dentro * 1.15, 0.0, 1.0) ** 1.3)
        brilho = luz * pocas * (0.62 + 0.38 * volume)
        cor = cor * brilho[..., None]
        # névoa do ginásio: as fileiras do fundo puxam para o roxo
        roxo = np.array([0.16, 0.10, 0.30], np.float32)
        for colunas, (y0, y1), nevoa in FILEIRAS:
            s = slice(y0 * ESCALA, y1 * ESCALA)
            cor[s] = cor[s] * (0.55 + 0.45 * nevoa) + roxo * (1.0 - nevoa) * 0.5
        # contorno de luz: magenta da esquerda, ciano da direita, e o alto
        # das cabeças pegando o branco dos refletores
        passo = 2 * ESCALA
        borda_e = np.clip(alfa - np.roll(alfa, passo, axis=1), 0, 1)
        borda_d = np.clip(alfa - np.roll(alfa, -passo, axis=1), 0, 1)
        borda_c = np.clip(alfa - np.roll(alfa, passo, axis=0), 0, 1)
        cor += borda_e[..., None] * np.array([0.75, 0.10, 0.55]) * 0.30
        cor += borda_d[..., None] * np.array([0.10, 0.65, 0.85]) * 0.30
        cor += borda_c[..., None] * np.array([0.9, 0.85, 1.0]) * 0.22
        # telas de celular e placas continuam acesas (não pegam a névoa)
        tela = (a[..., 2] > 0.85) & (a[..., 1] > 0.80) & (a[..., 0] > 0.70) & (alfa > 0.5)
        cor[tela] = np.maximum(cor[tela], a[..., :3][tela] * 0.85)
        out = np.dstack([np.clip(cor, 0, 1), alfa])
        im = Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA")
        im = im.resize((L // ESCALA, A // ESCALA), Image.LANCZOS)
        saidas.append(im)
    saidas[0].save(ARENA / "torcida_baixo.png", optimize=True)
    saidas[1].save(ARENA / "torcida_cima.png", optimize=True)
    print("ok plateia", L // ESCALA, "x", A // ESCALA)


def so_plateia():
    plateia()


if __name__ == "__main__":
    import sys
    if "--so-plateia" in sys.argv:
        plateia()
        raise SystemExit
    gravar("torcida_vaia.wav", vaia())
    gravar("torcida_festa.wav", festa())
    gravar("torcida_incentivo.wav", incentivo())
    plateia()
