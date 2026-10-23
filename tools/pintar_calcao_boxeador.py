"""A listra do calcao do lutador: uma so, continua, dos dois lados.

    python tools/pintar_calcao_boxeador.py

Le a textura ORIGINAL do calcao (tools/lutador3d_fontes/boxeador_4.jpg) e
grava a que o jogo usa (assets/lutador3d/boxeador_calcao.jpg). Pode rodar
quantas vezes quiser. Rode DEPOIS do tools/ajustar_corpo_boxeador.py (a
listra segue a forma final do calcao).

POR QUE. A listra vinha pintada em tres pedacos soltos no mapa da textura:
um de cada lado do quadril e um so nas pernas - e as duas pernas dividem o
mesmo pedaco da textura, espelhadas. A listra do quadril ficava a ~70 graus
da frente (em volta do corpo) e a da perna a ~60 graus (em volta da coxa):
na passagem do quadril para a perna ela pulava uns 5 cm para o lado, e de
lado as duas nao se acompanhavam.

O QUE MUDA. As listras pintadas sao apagadas (o tecido em volta preenche o
lugar) e a listra e pintada de novo pela posicao 3D de cada ponto da
textura: o centro dela e a LINHA DO LADO do calcao - em cada altura, o
ponto mais de fora - do cos ate a barra, dos dois lados, com o mesmo
desenho da original (branco, dourado, vermelho largo, dourado, branco).

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
FONTE = RAIZ / "tools" / "lutador3d_fontes" / "boxeador_4.jpg"
SAIDA = RAIZ / "assets" / "lutador3d" / "boxeador_calcao.jpg"

## O desenho da listra, do centro para fora (m): vermelho, dourado, branco.
VERMELHO, DOURADO, BRANCO = 0.0145, 0.0185, 0.0240
COR_VERMELHO = np.array([196, 16, 41], float)
COR_DOURADO = np.array([219, 160, 66], float)
COR_BRANCO = np.array([242, 240, 240], float)
## O centro da listra fica este tanto a frente da linha do lado (m).
A_FRENTE = 0.006


def apagar_listras(img):
    """Tira as listras pintadas: cada ponto dela recebe o tecido de cada
    lado da mesma linha, interpolado."""
    marca = img.max(axis=2) > 45
    # alarga 2 px (a borda escura da listra)
    m = marca.copy()
    for d in (1, 2):
        m[:, d:] |= marca[:, :-d]
        m[:, :-d] |= marca[:, d:]
    saida = img.copy()
    largura = img.shape[1]
    for y in range(img.shape[0]):
        linha = m[y]
        if not linha.any():
            continue
        livres = np.nonzero(~linha)[0]
        if len(livres) < 2:
            continue
        for c in range(3):
            saida[y, linha, c] = np.interp(np.nonzero(linha)[0], livres, img[y, livres, c])
    return saida


def linha_do_lado(C):
    """Em cada altura (de cm em cm), o ponto mais de fora do calcao do lado
    esquerdo (x > 0), alisado."""
    ys = np.arange(C[:, 1].min(), C[:, 1].max() + 0.01, 0.01)
    xs, zs = [], []
    for y in ys:
        m = (np.abs(C[:, 1] - y) < 0.012) & (C[:, 0] > 0.0)
        if not m.any():
            xs.append(np.nan)
            zs.append(np.nan)
            continue
        k = np.argmax(C[m, 0])
        xs.append(C[m][k, 0])
        zs.append(C[m][k, 2])
    xs, zs = np.array(xs), np.array(zs)
    ok = ~np.isnan(xs)
    # uma curva suave (grau 3 na altura): a listra desce reta, sem os
    # degraus da malha onde o quadril vira perna
    xs = np.polyval(np.polyfit(ys[ok], xs[ok], 3), ys)
    zs = np.polyval(np.polyfit(ys[ok], zs[ok], 3), ys)
    return ys, xs, zs


def cor_da_listra(d):
    """Cor e cobertura (0..1) a uma distancia `d` (m) do centro."""
    a = np.abs(d)
    cor = np.where(a[:, None] < VERMELHO, COR_VERMELHO,
                   np.where(a[:, None] < DOURADO, COR_DOURADO, COR_BRANCO))
    cobre = np.clip((BRANCO - a) / 0.0012 + 0.5, 0.0, 1.0)
    return cor, cobre


def main():
    g = GLB(MODELO)
    p = g.malha("Calcao")
    a = p["attributes"]
    P = g.ler(a["POSITION"])
    UV = g.ler(a["TEXCOORD_0"])
    tri = g.ler(p["indices"]).reshape(-1, 3)
    img = np.asarray(Image.open(FONTE).convert("RGB"), dtype=np.float64)
    H, W = img.shape[:2]
    saida = apagar_listras(img)
    ys, xs, zs = linha_do_lado(P)

    for i0, i1, i2 in tri:
        idx = [i0, i1, i2]
        v_meio = UV[idx, 1].mean()
        x_meio = P[idx, 0].mean()
        # as pernas dividem o mesmo pedaco da textura (espelhadas): pinta
        # pela perna esquerda, e a direita sai igual
        if v_meio > 0.5 and x_meio < 0.0:
            continue
        uv = UV[idx] * [W, H]
        x0, y0 = np.floor(uv.min(0)).astype(int)
        x1, y1 = np.ceil(uv.max(0)).astype(int)
        x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, W - 1), min(y1, H - 1)
        if x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        (ax, ay), (bx, by), (cx, cy) = uv
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-12:
            continue
        w0 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / den
        w1 = ((cy - ay) * (gx - cx) + (ax - cx) * (gy - cy)) / den
        w2 = 1 - w0 - w1
        m = (w0 >= -0.03) & (w1 >= -0.03) & (w2 >= -0.03)
        if not m.any():
            continue
        Pt = np.stack([w0[m], w1[m], w2[m]], 1) @ P[idx]
        xl = np.interp(Pt[:, 1], ys, xs)
        zl = np.interp(Pt[:, 1], ys, zs) + A_FRENTE
        # distancia na secao horizontal ate o centro da listra, com sinal
        # (para a frente positivo)
        dx = np.abs(Pt[:, 0]) - xl
        dz = Pt[:, 2] - zl
        d = np.sign(dz) * np.hypot(dx, dz)
        cor, cobre = cor_da_listra(d)
        so_do_lado = (np.abs(Pt[:, 0]) > 0.04).astype(float)
        cobre *= so_do_lado
        if not (cobre > 0).any():
            continue
        py = (gy[m] - 0.5).astype(int)
        px = (gx[m] - 0.5).astype(int)
        saida[py, px] = saida[py, px] * (1 - cobre[:, None]) + cor * cobre[:, None]

    Image.fromarray(np.clip(saida, 0, 255).astype(np.uint8)).save(SAIDA, quality=93)
    print("ok:", SAIDA)


if __name__ == "__main__":
    main()
