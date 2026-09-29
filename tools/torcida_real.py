"""A torcida do jogo feita da gravação real enviada pelo operador.

    python tools/torcida_real.py assets/audio/fontes/torcida_vitoria.mp3

A gravação (uma torcida de ginásio comemorando, ~16 s) substitui as torcidas
antigas, que tinham gritinhos agudos que ninguém gostou:

  torcida_festa      a vitória (a gravação inteira)
  torcida_recorde    entrada no ranking: recorde    (trecho, 6,0 s)
  torcida_podio      entrada no pódio               (trecho, 5,0 s)
  torcida_top10      entrada no top 10              (trecho, 4,1 s)
  torcida_top20      entrada no top 20              (trecho, 3,3 s)
  torcida_incentivo  a torcida empurrando no meio da luta (trecho, 4,2 s)
  arena_ambiente     NOVO: o ginásio cheio, em laço, por baixo da luta
                     inteira (a gravação + o público de fundo que já existia)

Requer: numpy, scipy, miniaudio (para ler o MP3).
"""
from pathlib import Path
import sys
import wave

import numpy as np
from scipy import signal

RAIZ = Path(__file__).resolve().parents[1]
AUDIO = RAIZ / "assets" / "audio" / "arcade"
SR = 44100


def ler_mp3(p):
    import miniaudio
    d = miniaudio.decode_file(str(p), output_format=miniaudio.SampleFormat.SIGNED16,
                              nchannels=2, sample_rate=SR)
    return np.frombuffer(d.samples, np.int16).reshape(-1, 2).astype(np.float64) / 32768.0


def ler_wav(p):
    with wave.open(str(p)) as w:
        x = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float64) / 32768.0
        x = x.reshape(-1, w.getnchannels())
    return np.repeat(x, 2, axis=1) if x.shape[1] == 1 else x


def gravar(nome, x, rms_db):
    x = x * (10 ** (rms_db / 20.0) / (np.sqrt((x ** 2).mean()) + 1e-12))
    pico = np.abs(x).max()
    if pico > 0.97:
        x *= 0.97 / pico
    with wave.open(str(AUDIO / nome), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).round().astype(np.int16).tobytes())
    print("ok %-22s %5.1f s  RMS %5.1f dBFS" % (nome, len(x) / SR, 20 * np.log10(np.sqrt((x ** 2).mean()))))


def trecho(x, inicio, dur, entra=0.08, sai=1.0):
    a = int(inicio * SR)
    y = x[a:a + int(dur * SR)].copy()
    n = len(y)
    e = np.ones(n)
    k = int(entra * SR)
    e[:k] = np.linspace(0, 1, k)
    s = int(min(sai, dur * 0.5) * SR)
    e[n - s:] *= np.linspace(1, 0, s) ** 1.5
    return y * e[:, None]


def laco(x, dur, cruza=1.5):
    """Um laço sem emenda: o fim cruza com o começo."""
    n, c = int(dur * SR), int(cruza * SR)
    y = x[:n + c].copy()
    r = np.linspace(0, 1, c)[:, None]
    cabeca = y[:c] * r + y[n:n + c] * (1 - r)
    return np.concatenate([cabeca, y[c:n]])


def main():
    fonte = Path(sys.argv[1]) if len(sys.argv) > 1 else RAIZ / "assets/audio/fontes/torcida_vitoria.mp3"
    x = ler_mp3(fonte)
    inicio = int(np.argmax(np.abs(x).mean(1) > 0.05) / SR * 10) / 10.0  # onde a torcida explode
    gravar("torcida_festa.wav", trecho(x, 0.0, len(x) / SR - 0.05, 0.02, 1.5), -16.0)
    gravar("torcida_recorde.wav", trecho(x, inicio + 0.3, 6.0), -17.0)
    gravar("torcida_podio.wav", trecho(x, inicio + 1.5, 5.0), -18.0)
    gravar("torcida_top10.wav", trecho(x, inicio + 3.0, 4.1), -19.0)
    gravar("torcida_top20.wav", trecho(x, inicio + 4.5, 3.3), -20.0)
    gravar("torcida_incentivo.wav", trecho(x, inicio + 6.0, 4.2, 0.25, 1.2), -19.0)
    # O GINÁSIO: o miolo constante da gravação, mais escuro (é o fundo, não o
    # grito), somado ao público que já existia, em laço de 10 s.
    miolo = x[int((inicio + 1.0) * SR):int((inicio + 12.5) * SR)]
    sos = signal.butter(2, 3500, "lowpass", fs=SR, output="sos")
    miolo = np.stack([signal.sosfiltfilt(sos, miolo[:, c]) for c in range(2)], 1)
    # a gravação vai baixando: iguala o volume ao longo do trecho
    env = np.sqrt(signal.sosfiltfilt(signal.butter(1, 0.5, "lowpass", fs=SR, output="sos"),
                                     (miolo ** 2).mean(1)) + 1e-6)
    miolo = miolo / env[:, None] * env.mean()
    publico = ler_wav(AUDIO / "arena_publico.wav")
    publico = np.tile(publico, (int(np.ceil(len(miolo) / len(publico))) + 1, 1))[:len(miolo)]
    cama = miolo + publico * (np.sqrt((miolo ** 2).mean()) / (np.sqrt((publico ** 2).mean()) + 1e-9)) * 0.5
    gravar("arena_ambiente.wav", laco(cama, 10.0), -20.0)


if __name__ == "__main__":
    main()
