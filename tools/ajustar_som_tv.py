"""Deixa os sons do jogo audíveis no alto-falante da TV.

    python tools/ajustar_som_tv.py

POR QUE: alto-falante de TV quase não toca abaixo de ~150-200 Hz. A música
de abertura tinha 92% da energia abaixo de 250 Hz, o START 56%, o soco 97%:
no fone de ouvido tudo soava; na TV Box ligada na TV, a abertura ficava
muda, o START sem som e o soco sem corpo — só a torcida (que é toda médio)
aparecia.

COMO: o grave de cada som é copiado e "saturado" (gera os harmônicos 2º,
3º, 4º... que caem na faixa que a TV toca — o ouvido reconstrói o grave a
partir deles, como em celular e notebook), e a presença (2-4 kHz) ganha um
pouco de brilho. O grave original continua lá para quem tiver caixa de som.
O volume final (RMS) fica igual ou um pouco acima do original, sem estourar.

Cada arquivo é tratado UMA vez: o resultado fica registrado em
`tools/som_tv_feito.json` (nome -> sha1 do arquivo tratado); rodar de novo
não trata duas vezes.

Requer: numpy, scipy.
"""
from pathlib import Path
import hashlib
import json
import wave

import numpy as np
from scipy import signal

RAIZ = Path(__file__).resolve().parents[1]
AUDIO = RAIZ / "assets" / "audio" / "arcade"
REGISTRO = Path(__file__).resolve().parent / "som_tv_feito.json"
SR = 44100
## Quanto da energia tem de ficar acima de 250 Hz depois do tratamento.
PRESENCA_ALVO = 0.45
## Sons que ficam de fora: o subgrave é a camada de grave de propósito.
FORA = {"subgrave.wav"}


def ler(p):
    with wave.open(str(p)) as w:
        assert w.getsampwidth() == 2
        x = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float64) / 32768.0
        return x.reshape(-1, w.getnchannels()), w.getframerate()


def gravar(p, x, sr):
    x = np.clip(x, -1.0, 1.0)
    with wave.open(str(p), "wb") as w:
        w.setnchannels(x.shape[1])
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((x * 32767.0).round().astype(np.int16).tobytes())


def presenca(x, sr):
    m = x.mean(axis=1)
    X = np.abs(np.fft.rfft(m)) ** 2
    f = np.fft.rfftfreq(len(m), 1.0 / sr)
    return float(X[f >= 250].sum() / max(X.sum(), 1e-12))


def rms(x):
    return float(np.sqrt((x ** 2).mean()) + 1e-12)


def harmonicos(x, sr):
    """Os harmônicos do grave, só na faixa que a TV toca."""
    sos_grave = signal.butter(4, 220, "lowpass", fs=sr, output="sos")
    sos_faixa = signal.butter(4, [300, 3000], "bandpass", fs=sr, output="sos")
    saida = np.zeros_like(x)
    for c in range(x.shape[1]):
        grave = signal.sosfiltfilt(sos_grave, x[:, c])
        pico = np.abs(grave).max() + 1e-9
        g = grave / pico
        # ímpares (tanh) + pares (retificação): o timbre de "grave de TV"
        h = np.tanh(3.0 * g) + 0.6 * (np.abs(g) - np.abs(g).mean())
        h = signal.sosfiltfilt(sos_faixa, h)
        h *= rms(grave) / (rms(h) + 1e-12)
        saida[:, c] = h
    return saida


def brilho(x, sr, db=3.0):
    """Um sino largo em 3 kHz: a presença de voz e de ataque."""
    b, a = signal.iirpeak(3000.0, 0.7, fs=sr)
    extra = np.stack([signal.filtfilt(b, a, x[:, c]) for c in range(x.shape[1])], 1)
    return x + extra * (10 ** (db / 20.0) - 1.0)


def tratar(x, sr):
    alvo_rms = rms(x) * 10 ** (1.5 / 20.0)
    h = harmonicos(x, sr)
    y = brilho(x, sr)
    for ganho in np.linspace(0.3, 6.0, 58):
        y = brilho(x + h * ganho, sr)
        if presenca(y, sr) >= PRESENCA_ALVO:
            break
    # volume: RMS do original (+1,5 dB), com limitador macio no pico
    y *= alvo_rms / rms(y)
    pico = np.abs(y).max()
    if pico > 0.97:
        y = np.tanh(y * 1.2) / np.tanh(1.2)
        y *= alvo_rms / rms(y)
        y /= max(1.0, np.abs(y).max() / 0.97)
    return y


def main():
    feito = json.loads(REGISTRO.read_text()) if REGISTRO.exists() else {}
    for p in sorted(AUDIO.glob("*.wav")):
        if p.name in FORA:
            continue
        sha = hashlib.sha1(p.read_bytes()).hexdigest()
        if feito.get(p.name) == sha:
            continue
        x, sr = ler(p)
        antes = presenca(x, sr)
        if antes >= PRESENCA_ALVO:
            continue
        y = tratar(x, sr)
        gravar(p, y, sr)
        feito[p.name] = hashlib.sha1(p.read_bytes()).hexdigest()
        print("%-24s presença %4.1f%% -> %4.1f%%   RMS %5.1f -> %5.1f dBFS" % (
            p.name, 100 * antes, 100 * presenca(y, sr),
            20 * np.log10(rms(x)), 20 * np.log10(rms(y))))
    REGISTRO.write_text(json.dumps(feito, indent=1, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
