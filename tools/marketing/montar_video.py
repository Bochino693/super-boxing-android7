"""O video promocional do SUPER BOXING (vertical 1080x1920 e horizontal 1920x1080).

    python tools/marketing/montar_video.py --captura PASTA --giro PASTA --fila IMG [--saida marketing/video]

  --captura  quadros do jogo (q00000.jpg...) + captura.json (tools/marketing/captura)
  --giro     o gabinete girando (giro_0000.png...) de tools/marketing/gabinete3d
  --fila     a foto dos dois gabinetes lado a lado (linha_heroi.png)

O som e o do proprio jogo, remontado quadro a quadro (audio_do_jogo.py).
Requer: numpy, scipy, pillow e o ffmpeg no PATH.
"""
from __future__ import annotations

import argparse
import json
import math
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import arte  # noqa: E402
import audio_do_jogo  # noqa: E402
from arte import AMARELO, BUNGEE, CONTORNO, MAGENTA, SAIRA  # noqa: E402

FPS = 30
TAXA = audio_do_jogo.TAXA
V = (1080, 1920)
H = (1920, 1080)


def ease_out(t):
    t = min(max(t, 0.0), 1.0)
    return 1 - (1 - t) ** 3


def ease_back(t):
    t = min(max(t, 0.0), 1.0)
    c = 1.70158
    return 1 + (c + 1) * (t - 1) ** 3 + c * (t - 1) ** 2


# ================================================================ recursos
class Recursos:
    def __init__(self):
        self.logo = arte.logo(1.6)
        self.fundo_v = arte.fundo_limpo(V[0] + 120, V[1] + 200, seed=3)
        self.fundo_h = arte.fundo_limpo(H[0] + 200, H[1] + 120, seed=4)
        self.lazer = arte.logo_lazer(520)
        self._txt = {}

    def texto(self, t, tam, cima=(255, 238, 60), baixo=(255, 120, 20)):
        k = (t, tam, cima, baixo)
        if k not in self._txt:
            self._txt[k] = arte.letreiro(t, BUNGEE, tam, cima, baixo, CONTORNO, tam * 0.11, tam * 0.08, -0.12)
        return self._txt[k]

    def simples(self, t, tam, cor=(255, 255, 255)):
        k = ("s", t, tam, cor)
        if k not in self._txt:
            self._txt[k] = arte.texto_simples(t, SAIRA, tam, cor, CONTORNO, max(2, tam // 9))
        return self._txt[k]


def colar(base, peca, cx, cy, escala=1.0, alpha=1.0):
    if escala != 1.0:
        peca = peca.resize((max(1, int(peca.width * escala)), max(1, int(peca.height * escala))), Image.BICUBIC)
    if alpha < 1.0:
        peca = peca.copy()
        peca.putalpha(peca.split()[3].point(lambda v: int(v * alpha)))
    arte._colar_seguro(base, peca, int(cx - peca.width / 2), int(cy - peca.height / 2))


def fundo(R, tam, t, total):
    f = R.fundo_v if tam == V else R.fundo_h
    k = t / max(total, 1e-3)
    dx = int(20 + 60 * k)
    dy = int(40 + 80 * k)
    return f.crop((dx, dy, dx + tam[0], dy + tam[1])).convert("RGBA")


# ================================================================ segmentos
class Seg:
    """Um trecho do video: N quadros e o audio correspondente."""

    def __init__(self, n, quadro, audio=None, nome=""):
        self.n, self.quadro, self.audio, self.nome = n, quadro, audio, nome


def seg_abertura(R, tam, sons):
    n = int(2.6 * FPS)

    def q(i):
        t = i / FPS
        img = fundo(R, tam, t, n / FPS)
        vert = tam == V
        cy_logo = tam[1] * (0.40 if vert else 0.42)
        larg = tam[0] * (0.86 if vert else 0.52)
        base = larg / R.logo.width
        s = base * (2.4 - 1.4 * ease_back(t / 0.35))
        tremor = max(0.0, 1 - (t - 0.35) / 0.4) if t > 0.35 else 0.0
        ox = math.sin(t * 90) * 22 * tremor
        oy = math.cos(t * 77) * 16 * tremor
        colar(img, R.logo, tam[0] / 2 + ox, cy_logo + oy, s, min(1.0, t / 0.2))
        if t > 0.75:
            k = ease_out((t - 0.75) / 0.35)
            l1 = R.texto("QUAL A FORÇA", 150 if vert else 110)
            colar(img, l1, tam[0] / 2 - (1 - k) * tam[0], tam[1] * (0.70 if vert else 0.80), (tam[0] * 0.86) / l1.width if vert else 1.0)
        if t > 1.0:
            k = ease_out((t - 1.0) / 0.35)
            l2 = R.texto("DO SEU SOCO?", 150 if vert else 110)
            colar(img, l2, tam[0] / 2 + (1 - k) * tam[0], tam[1] * (0.78 if vert else 0.92), (tam[0] * 0.86) / l2.width if vert else 1.0)
        rgb = img.convert("RGB")
        if 0.33 < t < 0.63:
            flash = 0.6 * (1 - (t - 0.33) / 0.30)
            rgb = Image.blend(rgb, Image.new("RGB", tam, (255, 255, 255)), flash)
        return rgb
    audio = vazio(n)
    misturar(audio, sons["subgrave"], 0.33, -2)
    misturar(audio, sons["hit"], 0.33, -3)
    misturar(audio, sons["couro"], 0.34, -4)
    misturar(audio, sons["go"], 1.0, -6)
    misturar(audio, sons["music"], 0.0, -14, n / FPS)
    return Seg(n, q, audio, "abertura")


def seg_jogo(R, tam, cap, a, b, legenda=None, aceleracao=1.0):
    """Quadros [a, b) da captura (em velocidade `aceleracao`), com o som do jogo."""
    idx = [int(a + i * aceleracao) for i in range(int((b - a) / aceleracao))]
    n = len(idx)

    def q(i):
        jogo = Image.open(cap.pasta / f"q{idx[i]:05d}.jpg").convert("RGB")
        if tam == V:
            img = jogo.resize(V, Image.LANCZOS) if jogo.size != V else jogo
            img = img.convert("RGBA")
            if legenda:
                legenda_v(R, img, legenda, i / FPS)
            return img.convert("RGB")
        return quadro_h(R, jogo, i / FPS, n / FPS, legenda)
    if aceleracao == 1.0:
        audio = cap.audio[int(a / FPS * TAXA): int(a / FPS * TAXA) + int(n / FPS * TAXA)].copy()
    else:
        audio = cap.audio[int(a / FPS * TAXA): int(b / FPS * TAXA)]
        audio = audio[np.linspace(0, len(audio) - 1, int(n / FPS * TAXA)).astype(int)]
    audio = ajustar(audio, n)
    rampa(audio)
    return Seg(n, q, audio, f"jogo {a}-{b}")


def legenda_v(R, img, legenda, t):
    """Faixa de chamada no alto do video vertical (desliza e assenta)."""
    titulo, sub = legenda
    # entra deslizando, fica ~2 s e sai: nao cobre o placar do jogo o tempo todo
    k = ease_out(t / 0.3) * (1.0 - ease_out((t - 2.2) / 0.3) if t > 2.2 else 1.0)
    if k <= 0.001:
        return
    y = -260 + 260 * k
    faixa = Image.new("RGBA", (V[0], 250), (12, 6, 30, 225))
    d = ImageDraw.Draw(faixa)
    d.rectangle([0, 238, V[0], 250], fill=MAGENTA + (255,))
    img.alpha_composite(faixa, (0, int(y)))
    tt = R.texto(titulo, 104)
    colar(img, tt, V[0] / 2, y + 95, min(1.0, V[0] * 0.92 / tt.width))
    if sub:
        ss = R.simples(sub, 50)
        colar(img, ss, V[0] / 2, y + 195, min(1.0, V[0] * 0.92 / ss.width))


def quadro_h(R, vertical, t, total, legenda):
    """Video horizontal: o jogo de pe no meio, fundo do gabinete e as
    chamadas dos lados."""
    img = fundo(R, H, t, total)
    jogo = vertical.resize((int(H[1] * 1080 / 1920), H[1]), Image.LANCZOS)
    x0 = (H[0] - jogo.width) // 2
    sombra = Image.new("RGBA", (jogo.width + 60, H[1]), (0, 0, 0, 0))
    ImageDraw.Draw(sombra).rectangle([0, 0, jogo.width + 60, H[1]], fill=(0, 0, 0, 150))
    sombra = sombra.filter(ImageFilter.GaussianBlur(18))
    img.alpha_composite(sombra, (x0 - 30, 0))
    img.paste(jogo, (x0, 0))
    d = ImageDraw.Draw(img)
    for x in (x0 - 4, x0 + jogo.width):
        d.rectangle([x, 0, x + 4, H[1]], fill=MAGENTA + (255,))
    lado = x0
    colar(img, R.logo, lado / 2, H[1] * 0.30, (lado * 0.80) / R.logo.width)
    colar(img, R.lazer, H[0] - lado / 2, H[1] * 0.86, (lado * 0.62) / R.lazer.width)
    if legenda:
        titulo, sub = legenda
        k = ease_out(t / 0.35)
        tt = R.texto(titulo, 80)
        e = min(1.0, (lado * 0.86) / tt.width)
        colar(img, tt, H[0] - lado / 2 + (1 - k) * lado, H[1] * 0.36, e)
        if sub:
            for j, linha in enumerate(quebrar(sub, 22)):
                ss = R.simples(linha, 44)
                colar(img, ss, H[0] - lado / 2 + (1 - k) * lado, H[1] * 0.50 + j * 58, min(1.0, lado * 0.86 / ss.width))
    return img.convert("RGB")


def quebrar(texto, n):
    linhas, atual = [], ""
    for p in texto.split():
        if len(atual) + len(p) + 1 > n and atual:
            linhas.append(atual)
            atual = p
        else:
            atual = (atual + " " + p).strip()
    if atual:
        linhas.append(atual)
    return linhas


def seg_giro(R, tam, pasta_giro, sons, legenda):
    fs = sorted(Path(pasta_giro).glob("giro_*.png"))
    n = len(fs)

    def q(i):
        g = Image.open(fs[i]).convert("RGB")
        img = fundo(R, V, i / FPS, n / FPS)
        k = V[0] / g.width
        g2 = g.resize((V[0], int(g.height * k)), Image.LANCZOS)
        img.paste(g2, (0, (V[1] - g2.height) // 2 + 60))
        if tam == V:
            legenda_v(R, img, legenda, i / FPS)
            return img.convert("RGB")
        return quadro_h(R, img.convert("RGB"), i / FPS, n / FPS, legenda)
    audio = vazio(n)
    misturar(audio, sons["music"], 0.0, -9, n / FPS)
    rampa(audio)
    return Seg(n, q, audio, "giro")


def seg_final(R, tam, fila_png, sons):
    n = int(4.2 * FPS)
    fila = Image.open(fila_png).convert("RGBA")

    def q(i):
        t = i / FPS
        img = fundo(R, tam, t, n / FPS)
        vert = tam == V
        k = ease_out(t / 0.5)
        if vert:
            fl = fila.resize((V[0], int(fila.height * V[0] / fila.width)), Image.LANCZOS)
            img.alpha_composite(fl, (0, int(V[1] * 0.40 - fl.height / 2 + (1 - k) * 200)))
            colar(img, R.logo, V[0] / 2, V[1] * 0.12, V[0] * 0.70 / R.logo.width * (1 + 0.02 * math.sin(t * 3)))
            colar(img, R.texto("LEVE PARA O", 96), V[0] / 2, V[1] * 0.70, 1.0, min(1, t / 0.4))
            colar(img, R.texto("SEU ESPAÇO!", 120), V[0] / 2, V[1] * 0.77, 1.0, min(1, max(0, t - 0.2) / 0.4))
            colar(img, R.simples("2 modelos: TORRE (TV 40\") e COMPACTO (TV 32\")", 40), V[0] / 2, V[1] * 0.835)
            colar(img, R.lazer, V[0] / 2, V[1] * 0.92, 0.9)
        else:
            fl = fila.resize((int(fila.width * H[1] * 0.92 / fila.height), int(H[1] * 0.92)), Image.LANCZOS)
            img.alpha_composite(fl, (int(H[0] * 0.70 - fl.width / 2), int(H[1] * 0.06 + (1 - k) * 120)))
            colar(img, R.logo, H[0] * 0.27, H[1] * 0.27, H[0] * 0.40 / R.logo.width * (1 + 0.02 * math.sin(t * 3)))
            colar(img, R.texto("LEVE PARA O SEU ESPAÇO!", 70), H[0] * 0.27, H[1] * 0.58, 1.0, min(1, t / 0.4))
            colar(img, R.simples("TORRE (TV 40\")  •  COMPACTO (TV 32\")", 38), H[0] * 0.27, H[1] * 0.67)
            colar(img, R.lazer, H[0] * 0.27, H[1] * 0.84, 0.8)
        return img.convert("RGB")
    audio = vazio(n)
    misturar(audio, sons["torcida_recorde"], 0.1, -4)
    misturar(audio, sons["music"], 0.0, -10, n / FPS)
    rampa(audio, fim=1.2)
    return Seg(n, q, audio, "final")


# ================================================================== audio
def vazio(n):
    return np.zeros((int(n / FPS * TAXA), 2), np.float32)


def ajustar(a, n):
    alvo = int(n / FPS * TAXA)
    if len(a) >= alvo:
        return a[:alvo].copy()
    return np.concatenate([a, np.zeros((alvo - len(a), 2), np.float32)])


def misturar(dest, som, t, db, dur=None):
    if som is None:
        return
    i = int(t * TAXA)
    n = len(dest) - i
    if dur is not None:
        n = min(n, int(dur * TAXA))
    if n <= 0:
        return
    if len(som) < n:
        reps = int(math.ceil(n / len(som)))
        som = np.concatenate([som] * reps)
    dest[i:i + n] += som[:n] * audio_do_jogo.db(db)


def rampa(a, ini=0.02, fim=0.02):
    ni, nf = int(ini * TAXA), int(fim * TAXA)
    if ni:
        a[:ni] *= np.linspace(0, 1, ni)[:, None]
    if nf:
        a[-nf:] *= np.linspace(1, 0, nf)[:, None]


# ================================================================= captura
class Captura:
    def __init__(self, pasta: Path):
        self.pasta = Path(pasta)
        self.dados = json.loads((self.pasta / "captura.json").read_text())
        self.estados = [q[2] for q in self.dados["quadros"]]
        print("mixando o som do jogo...")
        self.audio = audio_do_jogo.mixar(self.pasta / "captura.json", FPS)

    def trechos(self):
        """Os quadros onde cada estado comeca (para montar o roteiro)."""
        out = []
        ant = None
        for i, e in enumerate(self.estados):
            if e != ant:
                out.append((i, e))
                ant = e
        return out


# ================================================================== saida
def limitar(a, joelho=0.8, teto=0.89):
    """Limitador suave: ate `joelho` o som passa igual; acima, o pico e
    arredondado ate 1 (o soco nao estoura nem chia nas caixas). No fim tudo
    desce para `teto` (-1 dB): folga para o AAC, que passa um pouco do pico."""
    m = np.abs(a)
    acima = m > joelho
    resto = 1.0 - joelho
    out = a.copy()
    out[acima] = np.sign(a[acima]) * (joelho + resto * np.tanh((m[acima] - joelho) / resto))
    return np.clip(out, -1.0, 1.0) * teto


def gravar(segs, tam, saida: Path):
    saida.parent.mkdir(parents=True, exist_ok=True)
    audio = np.concatenate([s.audio for s in segs]).astype(np.float32)
    wav = saida.with_suffix(".wav")
    from scipy.io import wavfile
    wavfile.write(wav, TAXA, (limitar(audio) * 32767).astype(np.int16))
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{tam[0]}x{tam[1]}",
           "-r", str(FPS), "-i", "-", "-i", str(wav), "-c:v", "libx264", "-preset", "slow", "-crf", "21",
           "-pix_fmt", "yuv420p", "-profile:v", "high", "-movflags", "+faststart", "-c:a", "aac", "-b:a", "192k",
           "-shortest", str(saida)]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    total = sum(s.n for s in segs)
    feito = 0
    for s in segs:
        for i in range(s.n):
            img = s.quadro(i)
            if img.size != tam:
                img = img.resize(tam, Image.LANCZOS)
            p.stdin.write(img.tobytes())
            feito += 1
            if feito % 150 == 0:
                print(f"  {saida.name}: {feito}/{total} quadros", flush=True)
    p.stdin.close()
    p.wait()
    wav.unlink()
    print(f"  gravado {saida} ({saida.stat().st_size / 1e6:.1f} MB, {total / FPS:.1f} s)")


def roteiro(R, tam, cap, args, sons):
    """A ordem do video. Os cortes saem dos estados gravados na captura."""
    tr = cap.trechos()
    print("estados:", tr)
    ini = {}
    for i, e in tr:
        ini.setdefault(e, []).append(i)
    fim_intro = ini["IDLE"][0]
    start = json.loads(args.cortes) if args.cortes else {}
    segs = [seg_abertura(R, tam, sons)]
    # a abertura do jogo (sem o "apresenta", que a abertura do video ja fez)
    segs.append(seg_jogo(R, tam, cap, start.get("intro", 40), fim_intro))
    a = start.get("idle", fim_intro + 20)
    b = start.get("luta", ini["ARMED"][0] + 10)
    segs.append(seg_jogo(R, tam, cap, a, b, ("APERTE START", "e o saco desce para o soco")))
    for parte in start.get("partes", []):
        segs.append(seg_jogo(R, tam, cap, parte[0], parte[1], tuple(parte[2]) if len(parte) > 2 and parte[2] else None,
                             parte[3] if len(parte) > 3 else 1.0))
    segs.append(seg_giro(R, tam, args.giro, sons, ("SUPER BOXING TORRE", "TV 40\" em pé • saco motorizado • LED")))
    segs.append(seg_final(R, tam, args.fila, sons))
    return segs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--captura", required=True)
    ap.add_argument("--giro", required=True)
    ap.add_argument("--fila", required=True)
    ap.add_argument("--saida", default=str(arte.RAIZ / "marketing" / "video"))
    ap.add_argument("--cortes", default="")
    ap.add_argument("--formatos", default="vertical,horizontal")
    args = ap.parse_args()
    cap = Captura(Path(args.captura))
    sons = {k: audio_do_jogo.carregar(k) for k in ["subgrave", "hit", "couro", "go", "music", "torcida_recorde"]}
    R = Recursos()
    saida = Path(args.saida)
    if "vertical" in args.formatos:
        gravar(roteiro(R, V, cap, args, sons), V, saida / "super_boxing_promo_vertical_1080x1920.mp4")
    if "horizontal" in args.formatos:
        gravar(roteiro(R, H, cap, args, sons), H, saida / "super_boxing_promo_horizontal_1920x1080.mp4")


if __name__ == "__main__":
    main()
