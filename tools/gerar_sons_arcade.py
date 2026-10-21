"""Os sons de torcida e as vinhetas do jogo, no estilo de fliperama de luta.

    python tools/gerar_sons_arcade.py

POR QUE. As torcidas antigas eram gravacoes de ginasio de verdade, e nelas
havia gritos agudos de mulheres - por baixo da luta inteira (o ambiente em
laco), a cada soco e em toda comemoracao. Num fliperama de luta o som e
outro: pancada, plateia grave reagindo ("OOOH!"), batida de pe e palma
puxando o ritmo e fanfarra de vitoria. Aqui tudo e sintetizado (nada de
gravacao): a plateia so tem vozes graves e passa por um filtro que corta o
agudo acima de ~2 kHz, entao nenhum grito fino sobra.

Gera em assets/audio/arcade/:
  arena_ambiente     o ginasio por baixo da luta (laco de 10 s): ronco grave
                     e murmurio de gente, sem grito
  arena_publico      a plateia reagindo ao soco: "OOOH!" grave
  torcida_incentivo  pe, pe, palma e "HEY!" puxando o ritmo no meio da luta
  torcida_festa      a vitoria: rugido "AAAH" com batida e fanfarra
  good_player        os dois socos bons: subida, golpe de metais e plateia
  torcida_top20      vinheta curta de entrada no TOP 20
  torcida_top10      vinheta do TOP 10
  torcida_podio      rufar e fanfarra do podio
  torcida_recorde    rufar, fanfarra heroica e prato do recorde

Requer: numpy e scipy.
"""
from pathlib import Path
import wave

import numpy as np
from scipy import signal

RAIZ = Path(__file__).resolve().parents[1]
AUDIO = RAIZ / "assets" / "audio" / "arcade"
SR = 44100
rng = np.random.default_rng(116)


# ------------------------------------------------------------ utilidades
def tempo(segundos):
    return np.arange(int(SR * segundos)) / SR


def passa_baixa(x, fc, ordem=4):
    return signal.sosfilt(signal.butter(ordem, fc, "low", fs=SR, output="sos"), x, axis=0)


def passa_alta(x, fc, ordem=2):
    return signal.sosfilt(signal.butter(ordem, fc, "high", fs=SR, output="sos"), x, axis=0)


def passa_faixa(x, f1, f2, ordem=2):
    return signal.sosfilt(signal.butter(ordem, [f1, f2], "bandpass", fs=SR, output="sos"), x, axis=0)


def formante(x, f, q):
    b, a = signal.iirpeak(f, q, SR)
    return signal.lfilter(b, a, x)


def estereo(m, pan=0.5):
    return np.stack([m * (1.0 - pan) * 2.0, m * pan * 2.0], 1) * 0.5


def colocar(destino, som, inicio):
    i = int(inicio * SR)
    if i >= len(destino):
        return
    n = min(len(som), len(destino) - i)
    destino[i:i + n] += som[:n]


def reverb(x, segundos=1.2, mistura=0.22, brilho=3200.0):
    n = int(SR * segundos)
    t = np.arange(n) / SR
    ir = passa_baixa(rng.standard_normal((n, 2)), brilho, 2) * np.exp(-t * 4.5)[:, None]
    ir[0] = 0.0
    molhado = np.stack([signal.fftconvolve(x[:, c], ir[:, c])[: len(x)] for c in range(2)], 1)
    molhado *= np.abs(x).max() / (np.abs(molhado).max() + 1e-9)
    return x * (1.0 - mistura) + molhado * mistura


def gravar(nome, x, rms_alvo, pico=0.89):
    x = np.asarray(x, dtype=np.float64)
    x = x - x.mean(axis=0)
    rms = np.sqrt(np.mean(x * x)) + 1e-12
    x = x * (rms_alvo / rms)
    topo = np.abs(x).max()
    if topo > pico:
        # limitador suave: o pico cai sem achatar o som inteiro
        x = np.tanh(x / pico * 1.1) * pico / np.tanh(1.1)
    with wave.open(str(AUDIO / (nome + ".wav")), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1.0, 1.0) * 32767.0).astype(np.int16).tobytes())
    print("ok %-18s %5.2f s  rms %.3f" % (nome, len(x) / SR, np.sqrt(np.mean(x * x))))


# --------------------------------------------------------------- a plateia
## Vogais de voz MASCULINA (formantes em Hz, nitidez, ganho).
VOGAIS = {
    "o": [(450, 6, 1.0), (800, 8, 0.50), (2450, 12, 0.04)],
    "a": [(700, 6, 1.0), (1150, 8, 0.55), (2500, 12, 0.05)],
    "u": [(320, 5, 1.0), (780, 7, 0.32), (2300, 10, 0.03)],
    "e": [(460, 6, 1.0), (1750, 9, 0.40), (2550, 12, 0.06)],
}


def voz(t, f0, vogal, envelope, subida=0.0):
    """Uma pessoa: glote (dente de serra suavizado) passando pelas formantes."""
    vib = 1.0 + 0.010 * np.sin(2 * np.pi * rng.uniform(4.0, 6.0) * t + rng.uniform(0, 6))
    jitter = 1.0 + 0.006 * passa_baixa(rng.standard_normal(len(t)), 30, 2)
    inflexao = 1.0 + subida * np.exp(-t * 3.0)
    fase = np.cumsum(f0 * vib * jitter * inflexao) / SR
    glote = passa_baixa(2.0 * (fase % 1.0) - 1.0, 2600, 2)
    saida = np.zeros_like(t)
    for f, q, g in VOGAIS[vogal]:
        saida += formante(glote, f * rng.uniform(0.95, 1.05), q) * g
    return saida * envelope


def plateia(duracao, vozes, vogal, envelope_de, subida=0.0, f0=(92.0, 165.0), respiro=0.25):
    """Muita gente junta, so vozes graves, e o agudo cortado no fim."""
    t = tempo(duracao)
    mistura = np.zeros((len(t), 2))
    for _ in range(vozes):
        env = envelope_de(t)
        uma = voz(t, rng.uniform(*f0), vogal, env, subida * rng.uniform(0.5, 1.5)) * rng.uniform(0.5, 1.0)
        mistura += estereo(uma, rng.uniform(0.15, 0.85))
    # o ar de muita gente gritando junto (ruido grave, sem chiado)
    ar = passa_faixa(rng.standard_normal((len(t), 2)), 180, 1400) * envelope_de(t)[:, None]
    mistura += ar * respiro * np.abs(mistura).max() / (np.abs(ar).max() + 1e-9)
    return passa_baixa(mistura, 2200, 6)


def envelope(ataque, sustenta, cai, atraso=0.0, espalha=0.0):
    def env(t):
        a = atraso + rng.uniform(0.0, espalha)
        sobe = np.clip((t - a) / max(ataque * rng.uniform(0.7, 1.4), 1e-3), 0.0, 1.0)
        fim = a + ataque + sustenta * rng.uniform(0.8, 1.2)
        desce = np.exp(-np.clip(t - fim, 0.0, None) / cai)
        return sobe * desce
    return env


# ------------------------------------------------------------- percussao
def pisada(forca=1.0):
    t = tempo(0.45)
    f = 44.0 + 70.0 * np.exp(-t * 28.0)
    corpo = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 8.5)
    estalo = passa_baixa(rng.standard_normal(len(t)), 900) * np.exp(-t * 70.0) * 0.35
    return estereo((corpo + estalo) * forca, 0.5)


def palma(forca=1.0):
    t = tempo(0.32)
    x = np.zeros(len(t))
    for k, atraso in enumerate([0.0, 0.009, 0.018, 0.026]):
        m = (t >= atraso).astype(float) * np.exp(-np.clip(t - atraso, 0, None) / (0.006 if k < 3 else 0.06))
        x += rng.standard_normal(len(t)) * m * (0.8 if k < 3 else 1.0)
    x = passa_faixa(x, 850, 2600)
    return estereo(x * forca, rng.uniform(0.4, 0.6))


def caixa(forca=1.0):
    t = tempo(0.22)
    tom = np.sin(2 * np.pi * 190.0 * t) * np.exp(-t * 30.0)
    esteira = passa_faixa(rng.standard_normal(len(t)), 1200, 5200) * np.exp(-t * 22.0)
    return estereo((tom * 0.6 + esteira) * forca, 0.5)


def rufar(duracao, de=0.15, ate=1.0):
    saida = np.zeros((int(SR * (duracao + 0.3)), 2))
    k = 0.0
    passo = 1.0 / 22.0
    while k < duracao:
        colocar(saida, caixa(de + (ate - de) * (k / duracao) ** 1.6), k)
        k += passo
    return saida


def prato(duracao=2.2, forca=1.0):
    t = tempo(duracao)
    chiado = passa_alta(rng.standard_normal((len(t), 2)), 4500, 2)
    metal = np.zeros(len(t))
    for f in [3150, 4320, 5270, 6380, 7710]:
        metal += np.sin(2 * np.pi * f * t + rng.uniform(0, 6))
    x = (chiado + metal[:, None] * 0.05) * np.exp(-t * (2.6 / duracao * 2.0))[:, None]
    return passa_baixa(x, 9000) * forca * 0.5


def baque(forca=1.0):
    """O subgrave do golpe de metais (o 'pa!' que se sente no peito)."""
    t = tempo(0.6)
    f = 38.0 + 55.0 * np.exp(-t * 18.0)
    return estereo(np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 5.0) * forca, 0.5)


# ----------------------------------------------------- metais de fliperama
def nota(n):
    """Numero MIDI -> Hz."""
    return 440.0 * 2.0 ** ((n - 69) / 12.0)


def metal(freq, duracao, forca=1.0, brilho=1.0):
    """Metais de sintetizador: tres serras desafinadas, ataque brilhante que
    escurece, e uma camada de onda quadrada (o 8 bits do fliperama)."""
    t = tempo(duracao + 0.35)
    serras = np.zeros(len(t))
    for cents in (-7.0, 0.0, 7.0):
        f = freq * 2.0 ** (cents / 1200.0)
        serras += 2.0 * ((f * t + rng.uniform(0, 1)) % 1.0) - 1.0
    corpo = passa_baixa(serras, 1500)
    ataque = passa_baixa(serras, 4200) * np.exp(-t * 7.0) * brilho
    quadrada = np.sign(np.sin(2 * np.pi * freq * 2.0 * t)) * 0.12
    env = np.clip(t / 0.018, 0, 1) * np.where(t < duracao, 1.0, np.exp(-(t - duracao) / 0.12))
    env *= 0.85 + 0.15 * np.exp(-t * 3.0)
    return (corpo + ataque * 0.6 + quadrada) * env * forca / 3.0


def acorde(notas, duracao, forca=1.0, brilho=1.0):
    x = sum(metal(nota(n), duracao, forca, brilho) for n in notas)
    return estereo(x, 0.5)


def frase(passos, forca=1.0):
    """[(inicio, [notas], duracao), ...] -> metais."""
    fim = max(i + d for i, _, d in passos) + 0.5
    saida = np.zeros((int(SR * fim), 2))
    for inicio, notas, duracao in passos:
        colocar(saida, acorde(notas, duracao, forca), inicio)
    return saida


# --------------------------------------------------------------- os sons
def arena_ambiente():
    """10 s em laco: ronco grave do ginasio + murmurio de gente. Sem grito."""
    dur = 11.0
    t = tempo(dur)
    ronco = np.cumsum(rng.standard_normal((len(t), 2)), axis=0)
    ronco = passa_baixa(passa_alta(ronco, 30, 2), 320, 4)
    ronco /= np.abs(ronco).max()
    onda = 0.82 + 0.18 * np.sin(2 * np.pi * t / 4.3)[:, None]
    murmurio = np.zeros((len(t), 2))
    for _ in range(26):
        # cada pessoa fala em frases curtas, com pausas
        liga = np.zeros(len(t))
        k = rng.uniform(0, 1.5)
        while k < dur:
            d = rng.uniform(0.4, 1.4)
            sel = (t >= k) & (t < k + d)
            liga[sel] = 1.0
            k += d + rng.uniform(0.3, 1.6)
        liga = passa_baixa(liga, 8, 2)
        murmurio += estereo(voz(t, rng.uniform(95, 150), rng.choice(["a", "o", "e", "u"]), liga), rng.uniform(0.1, 0.9))
    murmurio = passa_baixa(murmurio, 1200, 6)
    murmurio *= 0.6 / (np.abs(murmurio).max() + 1e-9)
    x = ronco * onda * 0.7 + murmurio
    x = reverb(x, 1.6, 0.35, 1800)
    # o laco sem emenda: o ultimo segundo se mistura ao primeiro
    n = int(SR * 10.0)
    cruza = len(t) - n
    rampa = np.linspace(0, 1, cruza)[:, None]
    laco = x[:n].copy()
    laco[:cruza] = x[n:] * (1 - rampa) + x[:cruza] * rampa
    gravar("arena_ambiente", laco, 0.055)


def arena_publico():
    """A plateia reagindo ao soco: "OOOH!" grave, curto."""
    voz_ = plateia(2.2, 46, "o", envelope(0.10, 0.25, 0.55, 0.02, 0.12), subida=0.10)
    x = voz_
    colocar(x, baque(0.6), 0.0)
    gravar("arena_publico", reverb(x, 1.3, 0.25), 0.075)


def torcida_incentivo():
    """Pe, pe, palma + "HEY!" (duas vezes): a plateia puxando o ritmo."""
    x = np.zeros((int(SR * 4.2), 2))
    batida = 0.5
    hey = plateia(0.6, 34, "e", envelope(0.03, 0.10, 0.10, 0.0, 0.04), subida=0.18, f0=(110.0, 185.0), respiro=0.35)
    for ciclo in range(2):
        b = 0.05 + ciclo * batida * 4
        colocar(x, pisada(1.0), b)
        colocar(x, pisada(1.0), b + batida)
        colocar(x, palma(0.9), b + batida * 2)
        colocar(x, hey * 0.9, b + batida * 2)
    gravar("torcida_incentivo", reverb(x, 1.0, 0.2), 0.085)


def torcida_festa():
    """A vitoria: rugido "AAAH" que cresce, batida e o golpe de metais."""
    dur = 7.0
    rugido = plateia(dur, 60, "a", envelope(0.45, 4.6, 0.9, 0.0, 0.3), subida=0.06)
    x = rugido * 0.9
    batida = 60.0 / 128.0
    k = 0.6
    i = 0
    while k < dur - 1.0:
        colocar(x, pisada(0.8) if i % 4 in (0, 1) else palma(0.7), k)
        k += batida
        i += 1
    colocar(x, frase([(0.0, [60, 64, 67, 72], 0.35), (0.42, [60, 64, 67, 72], 0.9)], 0.9), 0.0)
    colocar(x, baque(0.9), 0.0)
    colocar(x, prato(2.4, 0.8), 0.42)
    fim = np.clip((dur - tempo(dur)) / 1.2, 0, 1)[:, None]
    gravar("torcida_festa", reverb(x * fim, 1.4, 0.24), 0.12)


def good_player():
    """Os dois socos bons: subida, golpe de metais e plateia "OOOH-AAH"."""
    dur = 4.2
    x = np.zeros((int(SR * dur), 2))
    # a subida (chiado filtrado subindo e uma serra que sobe junto)
    ts = tempo(0.7)
    f = 120.0 * 2.0 ** (ts / 0.7 * 2.5)
    serra = 2.0 * ((np.cumsum(f) / SR) % 1.0) - 1.0
    chiado = passa_faixa(rng.standard_normal(len(ts)), 300, 2400)
    sobe = (passa_baixa(serra, 2200) * 0.5 + chiado * 0.3) * (ts / 0.7) ** 2
    colocar(x, estereo(sobe, 0.5), 0.0)
    # o golpe: acorde de potencia (do, sol, do) com baque e prato
    colocar(x, frase([(0.0, [48, 55, 60, 67, 72], 0.25), (0.32, [48, 55, 60, 64, 67, 72], 1.1)], 1.0), 0.7)
    colocar(x, baque(1.0), 0.7)
    colocar(x, prato(2.6, 0.9), 0.7)
    # a plateia: "OOOH" que abre em "AAAH"
    oh = plateia(3.2, 40, "o", envelope(0.12, 0.5, 0.6, 0.0, 0.1), subida=0.08)
    ah = plateia(3.0, 40, "a", envelope(0.25, 1.0, 0.8, 0.45, 0.2), subida=0.04)
    colocar(x, oh * 0.8, 0.8)
    colocar(x, ah * 0.8, 0.9)
    gravar("good_player", reverb(x, 1.4, 0.24), 0.11)


def vinheta(nome, rufo, passos, prato_em, plateia_forca, duracao, rms):
    x = np.zeros((int(SR * duracao), 2))
    inicio = 0.0
    if rufo > 0.0:
        colocar(x, rufar(rufo), 0.0)
        inicio = rufo
    colocar(x, frase(passos, 1.0), inicio)
    colocar(x, baque(0.8), inicio)
    if prato_em is not None:
        colocar(x, prato(2.2, 0.8), inicio + prato_em)
        colocar(x, baque(0.9), inicio + prato_em)
    if plateia_forca > 0.0:
        resto = duracao - inicio
        roar = plateia(resto, 40, "a", envelope(0.35, resto - 1.4, 0.7, 0.1, 0.25), subida=0.05)
        colocar(x, roar * plateia_forca, inicio)
    fim = np.clip((duracao - tempo(duracao)) / 0.6, 0, 1)[:, None]
    gravar(nome, reverb(x * fim, 1.3, 0.22), rms)


def vinhetas():
    # TOP 20: arpejo curto e a nota longa
    vinheta("torcida_top20", 0.0, [
        (0.0, [72], 0.11), (0.12, [76], 0.11), (0.24, [79], 0.11),
        (0.36, [72, 76, 79, 84], 1.3),
    ], None, 0.0, 3.3, 0.085)
    # TOP 10: arpejo de quatro notas, acorde e prato
    vinheta("torcida_top10", 0.0, [
        (0.0, [67], 0.11), (0.12, [72], 0.11), (0.24, [76], 0.11), (0.36, [79], 0.11),
        (0.48, [72, 76, 79, 84], 1.8),
    ], 0.48, 0.35, 4.1, 0.095)
    # PODIO: rufar, "ta-ta-TAAA", e do maior com o quarto grau no meio
    vinheta("torcida_podio", 0.9, [
        (0.0, [67], 0.14), (0.18, [67], 0.14), (0.36, [60, 64, 67, 72], 0.5),
        (0.9, [65, 69, 72, 77], 0.3), (1.25, [60, 64, 67, 72, 76], 1.9),
    ], 1.25, 0.55, 5.0, 0.105)
    # RECORDE: rufar longo, "ta-ta-ta-TAAA" e a cadencia heroica
    # (la bemol - si bemol - do), com prato no do final
    vinheta("torcida_recorde", 1.4, [
        (0.0, [67], 0.13), (0.16, [67], 0.13), (0.32, [67], 0.13), (0.48, [60, 64, 67, 72], 0.55),
        (1.1, [56, 60, 63, 68], 0.32), (1.45, [58, 62, 65, 70], 0.32),
        (1.8, [60, 64, 67, 72, 76, 84], 2.2),
    ], 1.8, 0.7, 6.0, 0.12)


if __name__ == "__main__":
    arena_ambiente()
    arena_publico()
    torcida_incentivo()
    torcida_festa()
    good_player()
    vinhetas()
