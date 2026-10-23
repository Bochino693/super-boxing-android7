"""A definicao dos musculos do lutador, pintada na pele: o tanquinho e o resto.

    python tools/definir_musculos_boxeador.py

Le as texturas ORIGINAIS da pele (tools/lutador3d_fontes/) e grava as que o
jogo usa (assets/lutador3d/boxeador_pele.jpg e boxeador_relevo.png). Pode
rodar quantas vezes quiser: parte sempre das originais. Rode DEPOIS do
tools/ajustar_corpo_boxeador.py (a anatomia segue a forma final do corpo).

POR QUE. O corpo da TV Box tem 5 mil vertices: a simplificacao guardou a
forma grande (peito, ombros, braco), mas o desenho miudo do abdomen - os
gomos, os sulcos entre eles - nao cabe nessa malha, e a luz sozinha nao
tinha o que desenhar: a barriga saia lisa. Os jogos de console fazem
isso na textura: a anatomia vira sombra pintada na cor da pele (o sulco
mais escuro, o gomo levemente mais claro) e relevo no mapa de normais (a
luz pega a borda de cada gomo). Na placa de video nao custa NADA a mais:
e a mesma textura, o mesmo desenho, so com outro conteudo.

A ANATOMIA (em metros, no espaco do corpo: x para os lados, y para cima,
z para a frente) e posta em cima da malha pela posicao 3D de cada ponto da
textura - por isso cai no lugar certo do corpo, e as costuras do UV nao
aparecem:
  * o reto abdominal: tres pares de gomos acima do cinto (o quarto fica
    atras dele), a linha do meio (linea alba), os sulcos entre os gomos
    (levemente curvos) e a borda de fora (linea semilunaris);
  * os obliquos dos lados da barriga e os "dedos" do serratil nas costelas;
  * a borda de baixo do peitoral e o sulco do esterno.

Requer: numpy e pillow.
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from ajustar_corpo_boxeador import GLB  # noqa: E402

MODELO = RAIZ / "assets" / "lutador3d" / "boxeador_tvbox.glb"
FONTES = RAIZ / "tools" / "lutador3d_fontes"
PELE_FONTE = FONTES / "boxeador_2.jpg"
RELEVO_FONTE = FONTES / "boxeador_3.png"
PELE_SAIDA = RAIZ / "assets" / "lutador3d" / "boxeador_pele.jpg"
RELEVO_SAIDA = RAIZ / "assets" / "lutador3d" / "boxeador_relevo.png"

## Profundidades (m) e forca das sombras pintadas.
GOMO = 0.0016          # quanto cada gomo do abdomen estufa
SULCO = 0.0015         # quanto os sulcos afundam
SOMBRA = 0.30          # o sulco mais fundo escurece a pele nisto
LUZ_DO_GOMO = 0.06     # e o alto do gomo clareia nisto
## Se o relevo sair ao contrario na TV (gomo afundado), troque o sinal:
SINAL_DO_RELEVO = 1.0

## O reto abdominal: de onde ate onde (y), a meia largura em baixo e em
## cima, e as linhas entre os gomos.
## As linhas entre os gomos seguem as que a pintura original ja tinha (feitas
## na malha cheia, de 43 mil vertices: 0,975 e 1,034; a de 0,912 fica atras
## do cinturao). A borda do peitoral fica uns 2,5 cm abaixo do mamilo
## (y 1,148).
RETO_DE, RETO_ATE = 0.950, 1.118
RETO_MEIA_LARGURA = (0.055, 0.068)
LINHAS_DOS_GOMOS = [0.975, 1.034, 1.080]


def _sino(d, largura):
    return np.exp(-(d / largura) ** 2)


def _faixa(v, de, ate, suave):
    """1 dentro de [de, ate], descendo suave fora."""
    return np.clip((v - de) / suave + 0.5, 0, 1) * np.clip((ate - v) / suave + 0.5, 0, 1)


def anatomia(P, N):
    """Altura do relevo (m), o quanto e sulco (0..1) e o quanto e alto de
    gomo (0..1), para pontos `P` de normal `N`."""
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    ax = np.abs(x)
    frente = np.clip((N[:, 2] - 0.15) / 0.35, 0, 1)
    lado = np.clip((np.abs(N[:, 0]) - 0.2) / 0.4, 0, 1) * np.clip((N[:, 2] + 0.4) / 0.4, 0, 1)
    altura = np.zeros(len(P))
    sulco = np.zeros(len(P))
    gomo = np.zeros(len(P))

    # ---- o reto abdominal
    t = np.clip((y - RETO_DE) / (RETO_ATE - RETO_DE), 0, 1)
    w = RETO_MEIA_LARGURA[0] + (RETO_MEIA_LARGURA[1] - RETO_MEIA_LARGURA[0]) * t
    no_reto = _faixa(y, RETO_DE, RETO_ATE, 0.008) * np.clip((w + 0.006 - ax) / 0.006, 0, 1) * frente
    bordas = [RETO_DE - 0.03] + LINHAS_DOS_GOMOS + [RETO_ATE]
    for j in range(len(bordas) - 1):
        y0, y1 = bordas[j], bordas[j + 1]
        u = (ax - w * 0.5) / (w * 0.5)
        v = (y - 0.5 * (y0 + y1)) / (0.5 * (y1 - y0))
        almofada = np.clip(1 - u ** 2, 0, 1) ** 0.7 * np.clip(1 - v ** 2, 0, 1) ** 0.7
        gomo = np.maximum(gomo, almofada * no_reto)
    alba = _sino(x, 0.0045) * _faixa(y, RETO_DE, RETO_ATE + 0.004, 0.01)
    entre = np.zeros(len(P))
    for yb in LINHAS_DOS_GOMOS:
        # os sulcos sobem um pouco para fora (como no corpo de verdade)
        curva = yb + 0.007 * (ax / w) ** 2 - 0.002
        entre = np.maximum(entre, _sino(y - curva, 0.0042) * np.clip((w - ax) / 0.008, 0, 1))
    semilunar = _sino(ax - w, 0.0060) * _faixa(y, RETO_DE, RETO_ATE - 0.01, 0.015)
    s_reto = np.maximum.reduce([alba, entre, semilunar]) * frente
    sulco = np.maximum(sulco, s_reto)

    # ---- os obliquos (dos lados da barriga) e o serratil (nas costelas)
    obliquo = _faixa(ax, RETO_MEIA_LARGURA[0] + 0.012, 0.135, 0.02) * _faixa(y, 0.955, 1.075, 0.03)
    obliquo *= np.maximum(frente, lado) * np.clip((ax - w) / 0.01, 0, 1)
    gomo = np.maximum(gomo, 0.6 * obliquo)
    s_ = (y - 1.07) - 0.55 * (ax - 0.095)
    fase = (s_ / 0.027) % 1.0
    dedos = _sino((fase - 0.5) * 0.027, 0.0040)
    serratil = dedos * _faixa(ax, 0.105, 0.145, 0.012) * _faixa(y, 1.07, 1.16, 0.02) * lado
    sulco = np.maximum(sulco, 0.45 * serratil)
    # a costela de baixo: o sulco que separa obliquo e serratil
    costela = _sino(y - (1.078 + 0.30 * (ax - 0.07)), 0.0045) * _faixa(ax, 0.075, 0.14, 0.015) * np.maximum(lado, frente)
    sulco = np.maximum(sulco, 0.7 * costela)

    # ---- o peitoral: a borda de baixo e o esterno
    y_peito = 1.118 + 0.9 * ax ** 2
    borda_peito = _sino(y - y_peito, 0.0055) * _faixa(ax, -0.01, 0.15, 0.025) * frente
    esterno = _sino(x, 0.0055) * _faixa(y, 1.12, 1.22, 0.02) * frente * 0.5
    sulco = np.maximum.reduce([sulco, borda_peito, esterno])

    altura = GOMO * gomo - SULCO * sulco
    return altura, np.clip(sulco, 0, 1), np.clip(gomo, 0, 1)


def _gradiente(P, N, eps=0.0008):
    """O gradiente da altura sobre a superficie (derivada numerica)."""
    g = np.zeros_like(P)
    for k in range(3):
        d = np.zeros(3)
        d[k] = eps
        g[:, k] = (anatomia(P + d, N)[0] - anatomia(P - d, N)[0]) / (2 * eps)
    return g - N * (g * N).sum(1, keepdims=True)


def main():
    g = GLB(MODELO)
    p = g.malha("Pele")
    a = p["attributes"]
    P = g.ler(a["POSITION"])
    N = g.ler(a["NORMAL"])
    T = g.ler(a["TANGENT"])
    UV = g.ler(a["TEXCOORD_0"])
    tri = g.ler(p["indices"]).reshape(-1, 3)

    pele = np.asarray(Image.open(PELE_FONTE).convert("RGB"), dtype=np.float64)
    relevo = np.asarray(Image.open(RELEVO_FONTE).convert("RGB"), dtype=np.float64)
    H, W = pele.shape[:2]
    Hr, Wr = relevo.shape[:2]
    escala_r = Wr / W

    # so os triangulos do tronco (frente e lados)
    perto = ((P[:, 1] > 0.92) & (P[:, 1] < 1.27) & (np.abs(P[:, 0]) < 0.18) & (N[:, 2] > -0.45))
    sel = tri[perto[tri].any(1)]
    print("triangulos do tronco:", len(sel))

    sombra = np.ones((H, W))
    luz = np.zeros((H, W))
    feito = np.zeros((H, W), bool)
    n_relevo = {}
    for i0, i1, i2 in sel:
        uv = UV[[i0, i1, i2]] * [W, H]
        x0, y0 = np.floor(uv.min(0)).astype(int)
        x1, y1 = np.ceil(uv.max(0)).astype(int)
        x0, y0 = max(x0, 0), max(y0, 0)
        x1, y1 = min(x1, W - 1), min(y1, H - 1)
        if x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        (ax_, ay_), (bx, by), (cx, cy) = uv
        den = (by - cy) * (ax_ - cx) + (cx - bx) * (ay_ - cy)
        if abs(den) < 1e-12:
            continue
        w0 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / den
        w1 = ((cy - ay_) * (gx - cx) + (ax_ - cx) * (gy - cy)) / den
        w2 = 1 - w0 - w1
        m = (w0 >= -0.02) & (w1 >= -0.02) & (w2 >= -0.02)
        if not m.any():
            continue
        b = np.stack([w0[m], w1[m], w2[m]], 1)
        Pt = b @ P[[i0, i1, i2]]
        Nt = b @ N[[i0, i1, i2]]
        Nt /= np.linalg.norm(Nt, axis=1, keepdims=True)
        Tt = b @ T[[i0, i1, i2], :3]
        Tt -= Nt * (Tt * Nt).sum(1, keepdims=True)
        Tt /= np.linalg.norm(Tt, axis=1, keepdims=True) + 1e-12
        wt = np.sign(T[i0, 3]) if T[i0, 3] != 0 else 1.0
        Bt = np.cross(Nt, Tt) * wt
        _, s, gm = anatomia(Pt, Nt)
        py = (gy[m] - 0.5).astype(int)
        px = (gx[m] - 0.5).astype(int)
        sombra[py, px] = 1.0 - SOMBRA * s
        luz[py, px] = LUZ_DO_GOMO * gm
        feito[py, px] = True
        # o relevo: a normal inclinada pelo gradiente, no espaco da tangente
        gr = _gradiente(Pt, Nt) * SINAL_DO_RELEVO
        nn = Nt - gr
        nn /= np.linalg.norm(nn, axis=1, keepdims=True)
        nts = np.stack([(nn * Tt).sum(1), (nn * Bt).sum(1), (nn * Nt).sum(1)], 1)
        for (yy, xx), v in zip(zip((py * escala_r).astype(int), (px * escala_r).astype(int)), nts):
            n_relevo[(yy, xx)] = v

    # a pele: o sulco escurece puxando para o tom quente da sombra; o alto
    # do gomo clareia um pouco
    tom_da_sombra = np.array([0.80, 0.66, 0.60])
    s3 = sombra[:, :, None]
    saida = pele * s3 * (1.0 + luz[:, :, None]) * (1.0 - (1.0 - s3) * (1.0 - tom_da_sombra) * 0.5)
    Image.fromarray(np.clip(saida, 0, 255).astype(np.uint8)).save(PELE_SAIDA, quality=93)
    print("ok:", PELE_SAIDA)

    # o relevo: soma a inclinacao dos musculos ao relevo de poros que ja
    # existia (mistura "whiteout": as inclinacoes se somam)
    n0 = relevo / 255.0 * 2.0 - 1.0
    for (yy, xx), v in n_relevo.items():
        if 0 <= yy < Hr and 0 <= xx < Wr:
            o = n0[yy, xx]
            c = np.array([o[0] + v[0], o[1] + v[1], o[2] * v[2]])
            n0[yy, xx] = c / (np.linalg.norm(c) + 1e-12)
    Image.fromarray(np.clip((n0 * 0.5 + 0.5) * 255.0 + 0.5, 0, 255).astype(np.uint8)).save(RELEVO_SAIDA)
    print("ok:", RELEVO_SAIDA, "(%d pontos com relevo)" % len(n_relevo))


if __name__ == "__main__":
    main()
