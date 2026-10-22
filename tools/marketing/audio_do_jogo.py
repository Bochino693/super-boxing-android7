"""Remonta o SOM DO JOGO de uma captura, em sincronia com os quadros.

A captura (tools/marketing/captura) grava, junto com os quadros, cada chamada
ao banco de sons do jogo (scripts/audio_bank.gd): play, stop, music, duck,
attract, silence e o tom do loop do placar. Aqui essas chamadas sao tocadas
de novo com os MESMOS arquivos de assets/audio/arcade/, as mesmas mesas
(Impact +1,5 dB), o mesmo abafamento da musica e o mesmo sino e loop do
placar sintetizados do audio_bank.gd. Resultado: o audio que a maquina
tocaria, quadro a quadro.

    from audio_do_jogo import mixar
    som = mixar(captura_json, fps=30)   # float32 [amostras, 2] a 44100 Hz
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly

RAIZ = Path(__file__).resolve().parents[2]
SONS = RAIZ / "assets" / "audio" / "arcade"
TAXA = 44100
LOOPS = {"music", "charge", "score_loop", "arena_ambiente"}
ARQUIVO = {"error": "aviso"}
IMPACT = {"hit", "subgrave", "couro", "nivel_leve", "nivel_bom", "nivel_forte", "nivel_explosivo", "nivel_nocaute",
          "nivel_peso", "nivel_lendario", "nivel_perfeito", "arena_corpo", "arena_queda", "not_supress"}
MUSICA_REFORCO_DB = 6.0

_CACHE: dict = {}


def db(v: float) -> float:
    return 10.0 ** (v / 20.0)


def carregar(nome: str) -> np.ndarray | None:
    if nome in _CACHE:
        return _CACHE[nome]
    if nome == "round_bell":
        _CACHE[nome] = sino()
        return _CACHE[nome]
    if nome == "score_loop":
        _CACHE[nome] = None
        return None
    f = SONS / (ARQUIVO.get(nome, nome) + ".wav")
    if not f.exists():
        _CACHE[nome] = None
        return None
    taxa, d = wavfile.read(f)
    if d.dtype == np.int16:
        d = d.astype(np.float32) / 32768.0
    elif d.dtype == np.int32:
        d = d.astype(np.float32) / 2147483648.0
    elif d.dtype == np.uint8:
        d = (d.astype(np.float32) - 128.0) / 128.0
    d = d.astype(np.float32)
    if d.ndim == 1:
        d = np.stack([d, d], 1)
    if taxa != TAXA:
        g = math.gcd(taxa, TAXA)
        d = resample_poly(d, TAXA // g, taxa // g, axis=0).astype(np.float32)
    _CACHE[nome] = d
    return d


def sino() -> np.ndarray:
    """O sino de round do audio_bank.gd (_criar_sino_de_round)."""
    t = np.arange(int(TAXA * 1.2)) / TAXA
    env = np.exp(-t * 3.1)
    ataque = np.exp(-t * 70.0) * np.sin(math.tau * 3100.0 * t) * 0.24
    metal = (np.sin(math.tau * 620.0 * t) * 0.55 + np.sin(math.tau * 947.0 * t) * 0.34
             + np.sin(math.tau * 1315.0 * t) * 0.20) * env
    s = np.clip((metal + ataque) * 0.78, -1, 1).astype(np.float32)
    return np.stack([s, s], 1)


def mixar(captura: Path, fps: float = 30.0) -> np.ndarray:
    dados = json.loads(Path(captura).read_text())
    quadros = dados["quadros"]
    eventos = dados["sons"]
    idle0 = quadros[0][1]
    n_q = len(quadros)
    dur = n_q / fps
    N = int(dur * TAXA) + TAXA
    saida = np.zeros((N, 2), np.float32)

    def t_de(idle):
        return (idle - idle0) / fps

    # ---- efeitos: cada som tem UM tocador (tocar de novo reinicia)
    tocando: dict = {}       # nome -> [inicio_s, volume_db]
    trechos = []             # (nome, inicio, fim, vol)
    pitch = []               # (t, progresso) do loop do placar

    def encerrar(nome, t):
        if nome in tocando:
            ini, vol = tocando.pop(nome)
            trechos.append((nome, ini, t, vol))

    # ---- musica: alvo, rampa de 45 dB/s, abafamento (duck)
    musica = []              # (t, tipo, valor)
    for ev in eventos:
        t = t_de(ev[0])
        tipo = ev[1]
        if tipo == "play":
            nome, vol = ev[2], float(ev[3])
            encerrar(nome, t)
            tocando[nome] = [t, vol]
            if nome == "score_loop":
                pitch.append((t, 0.0))
        elif tipo == "stop":
            encerrar(ev[2], t)
        elif tipo == "silence":
            for nome in list(tocando):
                encerrar(nome, t)
            musica.append((t, "parar", 0.0))
        elif tipo == "attract":
            for nome in list(tocando):
                encerrar(nome, t)
            musica.append((t, "nivel", float(ev[2])))
        elif tipo == "music":
            musica.append((t, "nivel", float(ev[2])))
        elif tipo == "duck":
            musica.append((t, "duck", (float(ev[2]), float(ev[3]))))
        elif tipo == "pitch":
            pitch.append((t, float(ev[2])))
    for nome in list(tocando):
        encerrar(nome, dur + 1.0)

    for nome, ini, fim, vol in trechos:
        if fim <= 0.0 and nome not in LOOPS:
            continue
        g = db(vol) * (db(1.5) if nome in IMPACT else 1.0)
        a = int(max(0.0, ini) * TAXA)
        b = min(N, int(fim * TAXA))
        if b <= a:
            continue
        if nome == "score_loop":
            saida[a:b] += loop_do_placar(ini, a, b, pitch) * g
            continue
        s = carregar(nome)
        if s is None:
            continue
        desloc = int((max(0.0, ini) - ini) * TAXA)   # comecou antes da captura
        n = b - a
        if nome in LOOPS:
            idx = (np.arange(n) + desloc) % len(s)
            saida[a:b] += s[idx] * g
        else:
            if desloc >= len(s):
                continue
            pedaco = s[desloc:desloc + n]
            saida[a:a + len(pedaco)] += pedaco * g

    saida += trilha(musica, N, fps)
    # limitador suave e -1 dBFS de pico
    pico = np.max(np.abs(saida)) + 1e-9
    saida = np.tanh(saida / max(pico, 1.0) * 1.2) / np.tanh(1.2)
    saida *= db(-1.0) / (np.max(np.abs(saida)) + 1e-9)
    return saida[: int(dur * TAXA)]


def loop_do_placar(ini, a, b, pitch) -> np.ndarray:
    n = b - a
    t = (np.arange(n) + a) / TAXA
    prog = np.zeros(n, np.float32)
    for tp, p in sorted(pitch):
        prog[t >= tp] = p
    escala = 0.85 + (1.8 - 0.85) * np.clip(prog, 0, 1)
    fase = np.cumsum(escala) / TAXA
    tt = fase % 1.0
    env = 0.65 + 0.35 * np.cos(math.tau * 8.0 * tt)
    s = (np.sin(math.tau * 220.0 * fase) + 0.25 * np.sin(math.tau * 440.0 * fase)) * env * 0.22
    s = s.astype(np.float32)
    return np.stack([s, s], 1)


def trilha(musica, N, fps) -> np.ndarray:
    s = carregar("music")
    if s is None:
        return np.zeros((N, 2), np.float32)
    passo = 1.0 / fps
    total = int(N / TAXA * fps) + 2
    vol = -80.0
    alvo = -80.0
    tocando = False
    inicio = 0.0
    duck = 0.0
    duck_alvo = 0.0
    duck_ate = -1.0
    ganhos = np.zeros(total, np.float32)
    inicios = []
    eventos = sorted(musica, key=lambda e: e[0])
    k = 0
    for q in range(total):
        t = q * passo
        while k < len(eventos) and eventos[k][0] <= t:
            _, tipo, v = eventos[k]
            if tipo == "parar":
                alvo = -80.0
                tocando = False
                vol = -80.0
            elif tipo == "nivel":
                nivel = v
                if nivel > -79.0:
                    nivel = min(nivel + MUSICA_REFORCO_DB, 0.0)
                alvo = nivel
                if nivel > -79.0 and not tocando:
                    tocando = True
                    vol = -45.0
                    inicio = t
                    inicios.append(t)
            elif tipo == "duck":
                d, seg = v
                duck_alvo = min(duck_alvo, -abs(d))
                duck_ate = max(duck_ate, t + seg)
            k += 1
        if duck_ate > 0 and t > duck_ate:
            duck_alvo = 0.0
            duck_ate = -1.0
        duck += np.clip(duck_alvo - duck, -60.0 * passo, 14.0 * passo)
        if tocando:
            vol += np.clip(alvo - vol, -45.0 * passo, 45.0 * passo)
            if alvo <= -79.0 and vol <= -79.0:
                tocando = False
        ganhos[q] = db(vol + duck) if tocando else 0.0
    # a musica toca em laco desde o ultimo "play" (o tocador reinicia)
    out = np.zeros((N, 2), np.float32)
    g = np.interp(np.arange(N) / TAXA * fps, np.arange(total), ganhos).astype(np.float32)
    inicio_amostra = np.zeros(N, np.int64)
    marcas = [int(t * TAXA) for t in inicios] or [0]
    for i, m in enumerate(marcas):
        fim = marcas[i + 1] if i + 1 < len(marcas) else N
        inicio_amostra[max(0, m):fim] = m
    idx = (np.arange(N) - inicio_amostra) % len(s)
    out[:] = s[idx] * g[:, None]
    return out
