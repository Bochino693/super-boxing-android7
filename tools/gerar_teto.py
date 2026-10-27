"""O teto da derrota em imagens prontas (build 128).

    python3 tools/gerar_teto.py

Gera assets/arena/teto.png (o teto com as fileiras de lâmpadas) e
assets/arena/telao.png (o telão de LED com a logo do jogo).

POR QUE. Até a build 127 os dois eram desenhados por shaders próprios
(`SHADER_TETO` e `SHADER_TELAO` em arena3d.gd), que só apareciam na
derrota: a Mali-450 compilava os dois NA HORA DO NOCAUTE, nenhum quadro
do aquecimento os tinha desenhado — e era depois de perder que o jogo
fechava. Agora são texturas comuns, desenhadas pelo mesmo material sem
luz do resto do ginásio (nada novo para compilar). As contas são as dos
shaders, com o relógio parado.

Requer: numpy e pillow.
"""
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parents[1]
SAIDA = RAIZ / "assets" / "arena"
LOGO = RAIZ / "assets" / "logos" / "superboxing_h256.png"


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def uv(largura, altura):
    u = (np.arange(largura) + 0.5) / largura
    v = (np.arange(altura) + 0.5) / altura
    return np.meshgrid(u, v)


def salvar(rgb, nome):
    img = Image.fromarray((np.clip(rgb, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8), "RGB")
    img.save(SAIDA / nome, optimize=True)
    print("ok:", SAIDA / nome, img.size)


def teto():
    """26 x 6 lâmpadas (com halo) sobre o fundo escuro, mais escuro nas pontas."""
    U, V = uv(1024, 256)
    gx, gy = U * 26.0, V * 6.0
    fx, fy = gx - np.floor(gx) - 0.5, gy - np.floor(gy) - 0.5
    d = np.sqrt(fx ** 2 + (fy * 1.6) ** 2)
    ident = np.floor(gx) * 1.7 + np.floor(gy) * 13.1
    pisca = 0.72 + 0.28 * np.sin(ident)
    lampada = (1.0 - smoothstep(0.10, 0.20, d)) * pisca
    halo = (1.0 - smoothstep(0.0, 0.5, d)) * 0.22 * pisca
    viga = (1.0 - smoothstep(0.0, 0.06, np.abs(fy - 0.5))) * 0.06
    meio = 1.0 - 0.55 * np.abs(U - 0.5) * 2.0
    cor_lampada = np.array([1.0, 0.84, 0.62])
    cor_fundo = np.array([0.045, 0.028, 0.085])
    rgb = (cor_fundo + cor_lampada * (lampada + halo)[..., None] + viga[..., None]) * meio[..., None]
    salvar(rgb, "teto.png")


def telao():
    """A logo no meio de uma grade de LEDs (150 x 84 pontos)."""
    U, V = uv(1024, 512)
    logo = np.asarray(Image.open(LOGO).convert("RGBA"), np.float64) / 255.0
    qx = (U - 0.5) * 1.18 + 0.5
    qy = (V - 0.5) * 1.32 + 0.5
    dentro = ((qx >= 0.0) & (qx <= 1.0) & (qy >= 0.0) & (qy <= 1.0)).astype(float)
    lh, lw = logo.shape[:2]
    px = np.clip((np.clip(qx, 0.0, 1.0) * lw).astype(int), 0, lw - 1)
    py = np.clip((np.clip(qy, 0.0, 1.0) * lh).astype(int), 0, lh - 1)
    c = logo[py, px] * dentro[..., None]
    gx = U * 150.0
    gy = V * 84.0
    g = np.sqrt((gx - np.floor(gx) - 0.5) ** 2 + (gy - np.floor(gy) - 0.5) ** 2)
    led = 1.0 - smoothstep(0.22, 0.5, g)
    fundo = np.array([0.03, 0.0, 0.08]) + np.array([0.10, 0.02, 0.16]) * (0.5 + 0.5 * np.sin(V * 7.0))[..., None]
    a = c[..., 3:4]
    rgb = (fundo * (1.0 - a) + c[..., :3] * 1.15 * a) * (0.62 + 0.55 * led)[..., None]
    salvar(rgb, "telao.png")


if __name__ == "__main__":
    teto()
    telao()
