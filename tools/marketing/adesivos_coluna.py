"""Adesivos do gabinete COLUNA do SUPER BOXING (o modelo classico chines).

    python tools/marketing/adesivos_coluna.py

O gabinete: uma COLUNA com a TV em pe na frente, o CAPO em cima avancando
sobre o jogador (a bola de soco pendura embaixo dele) e a BASE de piso na
frente, onde o jogador pisa. O visual e o da foto de referencia: estilhacos
roxos e azuis com raios de luz, a moldura amarela e preta em volta da tela,
o logo com contorno branco, FIGHT! e NEVER GIVE UP!, e a base em chapa
xadrez vermelha.

Cada peca sai em TAMANHO REAL, com sangria, em marketing/adesivos/coluna/
(PDF para a grafica + previa com a linha de corte, os furos e as medidas) e
um MAPA DE APLICACAO (montagem.jpg) com a frente e o lado do gabinete ja
vestidos. As medidas sao uma proposta: confira o gabinete e a TV e ajuste
em MEDIDAS, logo abaixo; tudo sai de la.

Requer: numpy, scipy, pillow.
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import arte  # noqa: E402
import gerar_adesivos as base  # noqa: E402
from arte import BRANCO, BUNGEE, CONTORNO, SAIRA  # noqa: E402
from gerar_adesivos import Peca, anel_prata, lazer, lutador  # noqa: E402

PASTA = base.SAIDA / "coluna"

# ============================================================== as medidas
## Em centimetros. Largura = de lado a lado; profundidade = de tras para a
## frente; altura = de baixo para cima.
MEDIDAS = {
    # a coluna (fica em pe sobre a parte de tras da base)
    "coluna": {"largura": 62.0, "profundidade": 48.0, "altura": 175.0},
    # o capo em cima da coluna, avancando para a frente sobre o jogador
    "capo": {"largura": 72.0, "profundidade": 115.0, "altura": 38.0},
    # a base de piso (a coluna ocupa o fundo dela; o resto e o piso)
    "base": {"largura": 85.0, "profundidade": 130.0, "altura": 12.0},
    # TV 32" em pe (area visivel), centrada na janela da moldura
    "tv": {"pol": 32, "vis_w": 39.9, "vis_h": 70.9},
    # a frente da coluna, de cima para baixo: faixa com o nome, moldura da
    # TV e o painel de baixo (com START e credito no alto dele)
    "faixa_topo": 15.0,
    "moldura": 85.0,
    "comando": 12.0,
    "start": {"diam": 6.0},
    "moedeiro": {"w": 4.0, "h": 9.0},
    # o suporte da bola embaixo do capo: furo e distancia da borda da frente
    "suporte_bola": {"diam": 12.0, "da_frente": 30.0},
}

# a paleta da referencia: roxo, violeta, azul eletrico e rosa
ROXO_FUNDO_CIMA = (26, 8, 60)
ROXO_FUNDO_BAIXO = (9, 4, 30)
CORES_ESTILHACO = [(92, 38, 210), (128, 48, 236), (66, 92, 255), (176, 42, 214), (44, 30, 132), (40, 140, 255)]
NEON_ROSA = (255, 60, 200)
NEON_CIANO = (80, 210, 255)
AMARELO_FIGHT = (255, 236, 70)
LARANJA_FIGHT = (255, 120, 20)
VERMELHO_FIGHT = (226, 24, 40)


# ======================================================= a arte de fundo
def estilhacos(p: Peca, seed: int, angulo: float = -62.0, quantidade: float = 1.0,
               calmos: list[tuple[float, float, float, float]] = ()) -> None:
    """Fundo de ESTILHACOS: roxo escuro, laminas facetadas em diagonal com
    filete de luz, riscos de neon, raios e brilhos. `calmos` = elipses
    (cx, cy, rx, ry em cm da folha) escurecidas, onde vai o logo ou o texto."""
    rng = np.random.default_rng(seed)
    W, H = p.img.size
    curto = min(W, H)
    diag = math.hypot(W, H)
    # o fundo: degrade roxo
    sw, sh = max(4, W // 8), max(4, H // 8)
    y = np.linspace(0, 1, sh, dtype=np.float32)[:, None, None]
    g = np.array(ROXO_FUNDO_CIMA, np.float32) * (1 - y) + np.array(ROXO_FUNDO_BAIXO, np.float32) * y
    g = np.repeat(g, sw, axis=1)
    img = Image.fromarray(g.astype(np.uint8)).resize((W, H), Image.BICUBIC).convert("RGBA")

    camada = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(camada)
    # as LAMINAS: cunhas longas, cada uma com uma face escura e uma clara
    n = int(46 * quantidade * max(1.0, max(W, H) / curto * 0.6))
    for _ in range(n):
        a = math.radians(angulo + rng.uniform(-16, 16))
        ux, uy = math.cos(a), math.sin(a)
        nx, ny = -uy, ux
        cx, cy = rng.uniform(-0.15, 1.15) * W, rng.uniform(-0.15, 1.15) * H
        comp = rng.uniform(0.25, 0.9) * diag
        larg = rng.uniform(0.04, 0.22) * curto
        cor = CORES_ESTILHACO[rng.integers(len(CORES_ESTILHACO))]
        alfa = int(rng.uniform(70, 190))
        base_l = (cx - ux * comp / 2, cy - uy * comp / 2)
        ponta = (cx + ux * comp / 2, cy + uy * comp / 2)
        e = (base_l[0] + nx * larg / 2, base_l[1] + ny * larg / 2)
        dd = (base_l[0] - nx * larg / 2, base_l[1] - ny * larg / 2)
        meio = base_l
        escura = tuple(int(c * 0.55) for c in cor)
        d.polygon([e, ponta, meio], fill=cor + (alfa,))
        d.polygon([meio, ponta, dd], fill=escura + (alfa,))
        if rng.random() < 0.45:
            filete = (255, 255, 255) if rng.random() < 0.5 else (NEON_CIANO if rng.random() < 0.5 else NEON_ROSA)
            d.line([e, ponta], fill=filete + (int(rng.uniform(120, 230)),), width=max(1, p.s(0.12)))
    img.alpha_composite(camada)

    # A LUZ (riscos de neon, raios e brilhos), desenhada pequena e borrada
    k = 4
    lw, lh = W // k, H // k
    luzes = {"rosa": Image.new("L", (lw, lh), 0), "ciano": Image.new("L", (lw, lh), 0),
             "branco": Image.new("L", (lw, lh), 0)}
    nucleo = Image.new("L", (W, H), 0)
    dn = ImageDraw.Draw(nucleo)
    for _ in range(int(9 * quantidade)):  # riscos longos
        a = math.radians(angulo + rng.uniform(-8, 8))
        cx, cy = rng.uniform(0, W), rng.uniform(0, H)
        comp = rng.uniform(0.3, 0.8) * diag
        p0 = (cx - math.cos(a) * comp / 2, cy - math.sin(a) * comp / 2)
        p1 = (cx + math.cos(a) * comp / 2, cy + math.sin(a) * comp / 2)
        qual = "rosa" if rng.random() < 0.5 else "ciano"
        ImageDraw.Draw(luzes[qual]).line([(p0[0] / k, p0[1] / k), (p1[0] / k, p1[1] / k)], fill=255,
                                         width=max(1, int(p.s(0.5) / k)))
        dn.line([p0, p1], fill=200, width=max(1, p.s(0.08)))
    for _ in range(max(1, int(3 * quantidade))):  # raios
        x, yy = rng.uniform(0.1, 0.9) * W, -0.05 * H
        pts = [(x, yy)]
        passo = curto * 0.12
        a0 = math.radians(90 + rng.uniform(-25, 25))
        while yy < H * 1.05 and len(pts) < 60:
            a = a0 + rng.uniform(-0.9, 0.9)
            x += math.cos(a) * passo
            yy += abs(math.sin(a)) * passo
            pts.append((x, yy))
            if rng.random() < 0.18:  # galho
                gx, gy = x, yy
                galho = [(gx, gy)]
                for _ in range(rng.integers(2, 5)):
                    ag = a0 + rng.uniform(-1.4, 1.4)
                    gx += math.cos(ag) * passo * 0.7
                    gy += abs(math.sin(ag)) * passo * 0.7
                    galho.append((gx, gy))
                ImageDraw.Draw(luzes["rosa"]).line([(u / k, v / k) for u, v in galho], fill=200, width=max(1, int(p.s(0.4) / k)))
                dn.line(galho, fill=230, width=max(1, p.s(0.06)))
        qual = "ciano" if rng.random() < 0.5 else "rosa"
        ImageDraw.Draw(luzes[qual]).line([(u / k, v / k) for u, v in pts], fill=255, width=max(1, int(p.s(0.7) / k)))
        dn.line(pts, fill=255, width=max(1, p.s(0.1)))
    for _ in range(int(40 * quantidade)):  # brilhos (estrelinhas de 4 pontas)
        x, yy = rng.uniform(0, W), rng.uniform(0, H)
        r = rng.uniform(0.25, 0.9) * p.s(1.0)
        dl = ImageDraw.Draw(luzes["branco"])
        dl.ellipse([(x - r * 0.6) / k, (yy - r * 0.6) / k, (x + r * 0.6) / k, (yy + r * 0.6) / k], fill=170)
        dn.line([(x - r * 1.6, yy), (x + r * 1.6, yy)], fill=230, width=max(1, p.s(0.05)))
        dn.line([(x, yy - r * 1.6), (x, yy + r * 1.6)], fill=230, width=max(1, p.s(0.05)))
    rgb = np.zeros((lh, lw, 3), np.float32)
    for qual, cor, raio in (("rosa", NEON_ROSA, 2.4), ("ciano", NEON_CIANO, 2.4), ("branco", (230, 220, 255), 1.6)):
        m = np.asarray(luzes[qual].filter(ImageFilter.GaussianBlur(p.s(raio) / k)), np.float32) / 255.0
        rgb += m[..., None] * np.array(cor, np.float32) * 1.4
    brilho = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)
    rgb_img = ImageChops.screen(img.convert("RGB"), brilho)
    rgb_img = ImageChops.screen(rgb_img, Image.merge("RGB", (nucleo, nucleo, nucleo)))

    # as AREAS CALMAS (atras do logo e do texto): mais escuras e lisas
    if calmos:
        mk = 8
        sombra = Image.new("L", (W // mk, H // mk), 0)
        ds = ImageDraw.Draw(sombra)
        for cx, cy, rx, ry in calmos:
            x0, y0 = p.p(cx - rx, cy - ry)
            x1, y1 = p.p(cx + rx, cy + ry)
            ds.ellipse([x0 / mk, y0 / mk, x1 / mk, y1 / mk], fill=150)
        sombra = sombra.filter(ImageFilter.GaussianBlur(p.s(6.0) / mk)).resize((W, H), Image.BICUBIC)
        escuro = Image.new("RGB", (W, H), (14, 6, 36))
        rgb_img = Image.composite(escuro, rgb_img, sombra)
    p.img = rgb_img.convert("RGBA")


# ======================================================== as pecas soltas
def logo_contornado(largura_px: int) -> Image.Image:
    """O logo do jogo com o contorno BRANCO grosso (como adesivo recortado),
    que faz ele saltar em cima dos estilhacos."""
    lg = base.logo_hd()
    k = largura_px / lg.width
    lg = lg.resize((largura_px, max(1, int(lg.height * k))), Image.LANCZOS)
    folga = max(4, int(largura_px * 0.05))
    a = Image.new("L", (lg.width + folga * 2, lg.height + folga * 2), 0)
    a.paste(lg.split()[3], (folga, folga))
    borda = arte.dilatar(a, folga * 0.55)
    escuro = arte.dilatar(a, folga * 0.85)
    out = arte.pintar(escuro, CONTORNO)
    out = arte.pintar(borda, (255, 255, 255), out)
    out.alpha_composite(lg, (folga, folga))
    return out


def texto_fight(altura_px: int) -> Image.Image:
    """FIGHT! em amarelo, laranja e vermelho, inclinado, com contorno escuro
    e borda branca por fora."""
    t = arte.letreiro("FIGHT!", BUNGEE, altura_px, AMARELO_FIGHT, VERMELHO_FIGHT, CONTORNO,
                      altura_px * 0.10, altura_px * 0.07, -0.22)
    return _borda_branca(t, altura_px * 0.05)


def texto_never(altura_px: int) -> Image.Image:
    """NEVER GIVE UP! em branco, condensado e inclinado, com contorno."""
    t = arte.letreiro("NEVER GIVE UP!", SAIRA, altura_px, (255, 255, 255), (200, 214, 255), CONTORNO,
                      altura_px * 0.09, altura_px * 0.06, -0.22)
    return t


def _borda_branca(img: Image.Image, raio: float) -> Image.Image:
    folga = int(raio * 2) + 2
    a = Image.new("L", (img.width + folga * 2, img.height + folga * 2), 0)
    a.paste(img.split()[3], (folga, folga))
    out = arte.pintar(arte.dilatar(a, raio), (255, 255, 255))
    out.alpha_composite(img, (folga, folga))
    return out


def colar_px(p: Peca, img: Image.Image, cx: float, cy: float, largura: float | None = None,
             altura: float | None = None, halo=None) -> None:
    p.colar(img, cx, cy, largura=largura, altura=altura, halo=halo)


def faixa_zebra_chanfrada(p: Peca, x0, y0, x1, y1, largura: float, chanfro: float, passo: float = 3.0) -> None:
    """A moldura amarela e preta em volta da tela, com os cantos chanfrados
    (como a da foto) e um filete escuro por dentro."""
    def octo(a0, b0, a1, b1, c):
        return [p.p(a0 + c, b0), p.p(a1 - c, b0), p.p(a1, b0 + c), p.p(a1, b1 - c), p.p(a1 - c, b1),
                p.p(a0 + c, b1), p.p(a0, b1 - c), p.p(a0, b0 + c)]
    fora = Image.new("L", p.img.size, 0)
    dentro = Image.new("L", p.img.size, 0)
    ImageDraw.Draw(fora).polygon(octo(x0 - largura, y0 - largura, x1 + largura, y1 + largura, chanfro + largura * 0.6), fill=255)
    ImageDraw.Draw(dentro).polygon(octo(x0, y0, x1, y1, chanfro * 0.5), fill=255)
    anel = Image.fromarray(np.clip(np.asarray(fora, np.int16) - np.asarray(dentro, np.int16), 0, 255).astype(np.uint8))
    z = arte.zebra(p.img.width, p.img.height, p.s(passo))
    p.img = arte.pintar(anel, z, p.img)
    d = ImageDraw.Draw(p.img)
    d.polygon(octo(x0 - largura, y0 - largura, x1 + largura, y1 + largura, chanfro + largura * 0.6),
              outline=CONTORNO + (255,), width=p.s(0.45))
    # o filete escuro por dentro (o "chanfro" da moldura) e um fio de luz
    d.polygon(octo(x0 - 0.9, y0 - 0.9, x1 + 0.9, y1 + 0.9, chanfro * 0.5 + 0.6), outline=(12, 8, 24, 255), width=p.s(0.9))
    d.polygon(octo(x0 - largura - 0.6, y0 - largura - 0.6, x1 + largura + 0.6, y1 + largura + 0.6, chanfro + largura * 0.6 + 0.4),
              outline=NEON_CIANO + (255,), width=p.s(0.18))


# ================================================================ o capo
def capo_lateral(lado: str) -> None:
    c = MEDIDAS["capo"]
    W, H = c["profundidade"], c["altura"]
    espelho = lado == "direita"
    p = Peca(f"capo_lateral_{lado}", f"COLUNA - CAPO, LATERAL {lado.upper()}", W, H, 120, 1.0,
             "vinil adesivo brilho + laminacao", PASTA)
    # a frente do capo fica a direita na lateral esquerda (como o jogador ve)
    def x(frac):
        return W * (1.0 - frac) if espelho else W * frac
    estilhacos(p, seed=101 if not espelho else 102, angulo=-24, quantidade=0.8,
               calmos=[(x(0.50), H / 2, W * 0.17, H * 0.55), (x(0.82), H * 0.5, W * 0.13, H * 0.45),
                       (x(0.18), H * 0.5, W * 0.14, H * 0.45)])
    colar_px(p, logo_contornado(p.s(H * 1.35)), x(0.50), H / 2, altura=H * 0.86)
    colar_px(p, texto_fight(p.s(H * 0.42)), x(0.84), H * 0.46, largura=W * 0.25)
    colar_px(p, texto_never(p.s(H * 0.30)), x(0.155), H * 0.52, largura=W * 0.235)
    p.notas.append("a FRENTE do capo (lado do jogador) fica a " + ("ESQUERDA" if espelho else "DIREITA") + " da folha")
    p.salvar()


def capo_frente() -> None:
    c = MEDIDAS["capo"]
    W, H = c["largura"], c["altura"]
    p = Peca("capo_frente", "COLUNA - CAPO, FRENTE (o lado do jogador)", W, H, 150, 1.0,
             "vinil adesivo brilho + laminacao", PASTA)
    estilhacos(p, seed=103, angulo=-30, quantidade=0.7, calmos=[(W / 2, H / 2, W * 0.32, H * 0.6)])
    colar_px(p, logo_contornado(p.s(H * 1.4)), W / 2, H / 2, altura=H * 0.88)
    p.salvar()


def capo_baixo() -> None:
    c = MEDIDAS["capo"]
    sb = MEDIDAS["suporte_bola"]
    W, H = c["largura"], c["profundidade"]
    p = Peca("capo_baixo", "COLUNA - CAPO, EMBAIXO (onde pendura a bola)", W, H, 100, 1.0,
             "vinil adesivo brilho + laminacao; furo do suporte da bola", PASTA)
    estilhacos(p, seed=104, angulo=-90, quantidade=0.5)
    # a frente do capo e a borda de BAIXO da folha (olhando de baixo, de frente)
    cx, cy = W / 2, H - sb["da_frente"]
    d = ImageDraw.Draw(p.img)
    for i, (r, cor) in enumerate(((sb["diam"] / 2 + 3.0, NEON_CIANO), (sb["diam"] / 2 + 6.0, NEON_ROSA),
                                  (sb["diam"] / 2 + 9.5, (128, 48, 236)))):
        d.ellipse([p.p(cx - r, cy - r), p.p(cx + r, cy + r)], outline=cor + (255,), width=p.s(0.5 - i * 0.1))
    anel_prata(p, cx, cy, sb["diam"] + 0.8, 0.4)
    p.furos.append(("circulo", cx, cy, sb["diam"]))
    p.notas.append(f"a FRENTE do capo e a borda de baixo da folha; furo do suporte a {sb['da_frente']:g} cm dela")
    p.salvar()


# =============================================================== a coluna
def coluna_frente_alto() -> None:
    """A faixa com o nome e a moldura amarela e preta da TV (janela recortada)."""
    co, tv = MEDIDAS["coluna"], MEDIDAS["tv"]
    W = co["largura"]
    ft, mo = MEDIDAS["faixa_topo"], MEDIDAS["moldura"]
    H = ft + mo
    p = Peca("coluna_frente_alto", f"COLUNA - FRENTE DE CIMA (nome + moldura da TV {tv['pol']}\")", W, H, 120, 1.0,
             "vinil adesivo brilho + laminacao; janela da TV recortada; por cima, acrilico 4 mm", PASTA)
    jx0 = (W - tv["vis_w"]) / 2
    jy0 = ft + (mo - tv["vis_h"]) / 2
    jx1, jy1 = jx0 + tv["vis_w"], jy0 + tv["vis_h"]
    estilhacos(p, seed=105, angulo=-62, quantidade=0.7, calmos=[(W / 2, ft / 2, W * 0.45, ft * 0.7)])
    # SUPER BOXING na faixa de cima (letras brancas, como na foto)
    t = arte.letreiro("SUPER BOXING", BUNGEE, 300, (255, 255, 255), (200, 210, 255), CONTORNO, 26, 18, -0.08)
    colar_px(p, t, W / 2, ft * 0.52, largura=min(W * 0.78, ft * 0.62 * t.width / t.height))
    faixa_zebra_chanfrada(p, jx0, jy0, jx1, jy1, largura=min(jx0 - 1.2, 5.5), chanfro=3.5)
    p.furos.append(("retangulo", jx0, jy0, jx1, jy1))
    p.notas.append(f"janela = area visivel da TV {tv['pol']}\" em pe ({tv['vis_w']} x {tv['vis_h']} cm)")
    p.salvar()


def coluna_frente_baixo() -> None:
    """O painel de baixo: START e credito no alto, o logo, o lutador e FIGHT!."""
    co = MEDIDAS["coluna"]
    W = co["largura"]
    H = co["altura"] - MEDIDAS["faixa_topo"] - MEDIDAS["moldura"]
    cm_ = MEDIDAS["comando"]
    p = Peca("coluna_frente_baixo", "COLUNA - FRENTE DE BAIXO (START, credito e arte)", W, H, 120, 1.0,
             "vinil adesivo brilho + laminacao; furo do START e do moedeiro", PASTA)
    estilhacos(p, seed=106, angulo=-62, quantidade=0.9,
               calmos=[(W / 2, cm_ + 12.0, W * 0.42, 12.0), (W * 0.30, H * 0.62, W * 0.26, 10.0)])
    # a faixa de comando: preta, com START e credito
    d = ImageDraw.Draw(p.img)
    d.rectangle([p.p(-1.0, -1.0), p.p(W + 1.0, cm_)], fill=(10, 6, 22, 255))
    d.line([p.p(-1.0, cm_), p.p(W + 1.0, cm_)], fill=NEON_CIANO + (255,), width=p.s(0.25))
    st, mo = MEDIDAS["start"], MEDIDAS["moedeiro"]
    xs, xm, yb = W * 0.32, W * 0.70, cm_ * 0.42
    anel_prata(p, xs, yb, st["diam"] + 0.6, 0.35)
    p.furos.append(("circulo", xs, yb, st["diam"]))
    p.texto("START", xs, cm_ - 1.6, 1.4, cor=BRANCO, fonte=BUNGEE, borda=None)
    p.furos.append(("retangulo", xm - mo["w"] / 2, yb - mo["h"] / 2 + 0.6, xm + mo["w"] / 2, yb + mo["h"] / 2 - 0.6))
    p.texto("CRÉDITO", xm + mo["w"] / 2 + 6.0, yb, 1.4, cor=BRANCO, fonte=BUNGEE, borda=None)
    # o logo, o lutador socando e o FIGHT!
    colar_px(p, logo_contornado(p.s(W * 0.9)), W * 0.5, cm_ + 12.5, largura=W * 0.70)
    lut = lutador("soco")
    alt_lut = H - cm_ - 22.0
    ex = arte.explosao(p.s(alt_lut * 0.95), p.s(alt_lut * 0.85), 18, seed=12)
    ex.putalpha(ex.split()[3].point(lambda v: int(v * 0.85)))
    colar_px(p, ex, W * 0.66, H - alt_lut * 0.48)
    colar_px(p, lut, W * 0.64, H - alt_lut / 2 + 1.0, altura=alt_lut)
    colar_px(p, texto_fight(p.s(9.0)), W * 0.27, H * 0.62, largura=W * 0.42)
    colar_px(p, lazer(p.s(13.0)), W * 0.20, H - 5.0)
    p.notas.append("a faixa preta de cima leva o botao START (60 mm) e o moedeiro (furo sugerido)")
    p.salvar()


def coluna_lateral(lado: str) -> None:
    co = MEDIDAS["coluna"]
    W, H = co["profundidade"], co["altura"]
    espelho = lado == "direita"
    p = Peca(f"coluna_lateral_{lado}", f"COLUNA - LATERAL {lado.upper()}", W, H, 100, 1.0,
             "vinil adesivo brilho + laminacao", PASTA)
    estilhacos(p, seed=107 if not espelho else 108, angulo=-62 if not espelho else -118, quantidade=1.2,
               calmos=[(W / 2, H * 0.22, W * 0.55, 16.0)])
    lg = logo_contornado(p.s(W * 0.95))
    colar_px(p, lg, W / 2, H * 0.22, largura=W * 0.86)
    p.notas.append("a FRENTE da coluna fica a " + ("ESQUERDA" if espelho else "DIREITA") + " da folha")
    p.salvar()


def coluna_traseira() -> None:
    co = MEDIDAS["coluna"]
    W, H = co["largura"], co["altura"]
    p = Peca("coluna_traseira", "COLUNA - TRASEIRA (opcional: se a maquina ficar de costas para o salao)", W, H, 100, 1.0,
             "vinil adesivo brilho + laminacao", PASTA)
    estilhacos(p, seed=109, angulo=-62, quantidade=0.8, calmos=[(W / 2, H * 0.40, W * 0.55, 18.0)])
    colar_px(p, logo_contornado(p.s(W * 0.9)), W / 2, H * 0.40, largura=W * 0.80)
    colar_px(p, texto_never(p.s(6.0)), W / 2, H * 0.60, largura=W * 0.70)
    p.salvar()


# ================================================================ a base
def chapa_xadrez(p: Peca, seed: int = 7) -> None:
    """Chapa xadrez (antiderrapante) vermelha: gomos em losango alongado numa
    grade diagonal, vizinhos sempre cruzados (o desenho classico da chapa),
    com luz de cima e sombra embaixo."""
    W, H = p.img.size
    rng = np.random.default_rng(seed)
    h = p.s(1.6)                       # meio passo da grade
    sw, sh = max(4, W // 8), max(4, H // 8)
    yy, xx = np.mgrid[0:sh, 0:sw].astype(np.float32)
    t = (xx / sw * 0.6 + yy / sh * 0.4)
    luz = (np.exp(-((t - 0.45) / 0.22) ** 2) * 34).astype(np.float32)
    base_rgb = np.stack([150 + luz, 12 + luz * 0.25, 22 + luz * 0.3], -1)
    img = Image.fromarray(np.clip(base_rgb, 0, 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)
    d = ImageDraw.Draw(img)
    comp, larg = p.s(2.0), p.s(0.5)
    for j in range(-1, int(H / h) + 2):
        for i in range(-1, int(W / h) + 2):
            if (i + j) % 2:
                continue
            x, y = i * h, j * h
            a = math.radians(45 if i % 2 == 0 else -45)
            ux, uy = math.cos(a) * comp / 2, math.sin(a) * comp / 2
            nx, ny = -math.sin(a) * larg / 2, math.cos(a) * larg / 2
            pts = [(x - ux, y - uy), (x + nx, y + ny), (x + ux, y + uy), (x - nx, y - ny)]
            d.polygon([(px_ + larg * 0.25, py_ + larg * 0.35) for px_, py_ in pts], fill=(80, 4, 12))
            d.polygon(pts, fill=(206, 34, 44))
            d.line([pts[3], pts[0], pts[1]], fill=(255, 130, 130), width=max(1, int(larg * 0.16)))
    # riscos finos de uso
    for _ in range(60):
        x0, y0 = rng.uniform(0, W), rng.uniform(0, H)
        a = rng.uniform(0, math.tau)
        c = rng.uniform(0.02, 0.10) * W
        d.line([(x0, y0), (x0 + math.cos(a) * c, y0 + math.sin(a) * c)], fill=(190, 60, 66), width=1)
    p.img = img.convert("RGBA")


def base_piso() -> None:
    b, co = MEDIDAS["base"], MEDIDAS["coluna"]
    W, H = b["largura"], b["profundidade"] - co["profundidade"]
    p = Peca("base_piso", "COLUNA - PISO DA BASE (chapa xadrez vermelha)", W, H, 100, 1.0,
             "vinil de PISO antiderrapante com laminacao para chao (ou chapa xadrez de aluminio pintada)", PASTA)
    chapa_xadrez(p)
    p.notas.append("a borda de cima da folha encosta na coluna; a de baixo e a frente da base (fita de LED na borda)")
    p.salvar()


# ============================================================ a montagem
def montagem() -> None:
    """O mapa de aplicacao: a frente e o lado do gabinete ja vestidos (com as
    previas das pecas, na escala), para conferir antes de mandar imprimir."""
    k = 7.0  # px por cm
    co, ca, b = MEDIDAS["coluna"], MEDIDAS["capo"], MEDIDAS["base"]
    tex = PASTA / "texturas"

    def peca(nome, w, h):
        im = Image.open(tex / f"{nome}.jpg").convert("RGB")
        return im.resize((int(w * k), int(h * k)), Image.LANCZOS)

    alt_total = b["altura"] + co["altura"] + ca["altura"]
    larg_frente = max(ca["largura"], b["largura"])
    larg_lado = max(ca["profundidade"], b["profundidade"])
    margem = 60
    Wimg = int((larg_frente + larg_lado) * k + margem * 3)
    Himg = int(alt_total * k + margem * 2 + 80)
    img = Image.new("RGB", (Wimg, Himg), (24, 22, 30))
    d = ImageDraw.Draw(img)
    chao = margem + 80 + alt_total * k
    f1 = ImageFont.truetype(SAIRA, 34)
    f2 = ImageFont.truetype(SAIRA, 24)

    # ---- FRENTE
    x0 = margem
    cxf = x0 + larg_frente * k / 2
    d.text((x0, 20), "FRENTE", font=f1, fill=(255, 220, 60))
    # base (vista de frente: so a borda)
    d.rectangle([cxf - b["largura"] * k / 2, chao - b["altura"] * k, cxf + b["largura"] * k / 2, chao], fill=(16, 12, 20))
    d.line([cxf - b["largura"] * k / 2, chao - 3, cxf + b["largura"] * k / 2, chao - 3], fill=(70, 140, 255), width=5)
    ytopo_col = chao - (b["altura"] + co["altura"]) * k
    alto = peca("coluna_frente_alto", co["largura"], MEDIDAS["faixa_topo"] + MEDIDAS["moldura"])
    baixo = peca("coluna_frente_baixo", co["largura"], co["altura"] - MEDIDAS["faixa_topo"] - MEDIDAS["moldura"])
    img.paste(alto, (int(cxf - co["largura"] * k / 2), int(ytopo_col)))
    img.paste(baixo, (int(cxf - co["largura"] * k / 2), int(ytopo_col + alto.height)))
    capo = peca("capo_frente", ca["largura"], ca["altura"])
    img.paste(capo, (int(cxf - ca["largura"] * k / 2), int(ytopo_col - capo.height)))
    # a tela (no lugar da janela branca)
    tv = MEDIDAS["tv"]
    jx0 = cxf - tv["vis_w"] * k / 2
    jy0 = ytopo_col + (MEDIDAS["faixa_topo"] + (MEDIDAS["moldura"] - tv["vis_h"]) / 2) * k
    d.rectangle([jx0, jy0, jx0 + tv["vis_w"] * k, jy0 + tv["vis_h"] * k], fill=(18, 16, 40))
    d.text((jx0 + 12, jy0 + 12), f"TV {tv['pol']}\"", font=f2, fill=(160, 170, 220))
    # a bola pendurada, na frente da tela
    by = ytopo_col + 18 * k
    d.line([cxf, ytopo_col, cxf, by], fill=(150, 150, 160), width=4)
    d.ellipse([cxf - 13 * k, by, cxf + 13 * k, by + 34 * k], fill=(190, 20, 30), outline=(20, 10, 10), width=3)

    # ---- LADO (frente para a direita)
    x1 = margem * 2 + larg_frente * k
    d.text((x1, 20), "LADO ESQUERDO (frente para a direita)", font=f1, fill=(255, 220, 60))
    d.rectangle([x1, chao - b["altura"] * k, x1 + b["profundidade"] * k, chao], fill=(16, 12, 20))
    d.rectangle([x1 + co["profundidade"] * k, chao - b["altura"] * k - 6, x1 + b["profundidade"] * k, chao - b["altura"] * k],
                fill=(176, 18, 30))
    d.line([x1, chao - 3, x1 + b["profundidade"] * k, chao - 3], fill=(70, 140, 255), width=5)
    lado_col = peca("coluna_lateral_esquerda", co["profundidade"], co["altura"])
    img.paste(lado_col, (int(x1), int(ytopo_col)))
    lado_capo = peca("capo_lateral_esquerda", ca["profundidade"], ca["altura"])
    img.paste(lado_capo, (int(x1), int(ytopo_col - lado_capo.height)))
    bx = x1 + (ca["profundidade"] - MEDIDAS["suporte_bola"]["da_frente"]) * k
    d.line([bx, ytopo_col, bx, by], fill=(150, 150, 160), width=4)
    d.ellipse([bx - 13 * k, by, bx + 13 * k, by + 34 * k], fill=(190, 20, 30), outline=(20, 10, 10), width=3)
    # as medidas
    d.text((margem, Himg - 46), f"medidas (cm): coluna {co['largura']:g} x {co['profundidade']:g} x {co['altura']:g}  •  "
           f"capo {ca['largura']:g} x {ca['profundidade']:g} x {ca['altura']:g}  •  base {b['largura']:g} x {b['profundidade']:g} x "
           f"{b['altura']:g}  •  altura total {alt_total:g}", font=f2, fill=(220, 220, 235))
    img.save(PASTA / "montagem.jpg", quality=90)
    print("  coluna/montagem.jpg")


def exportar_medidas() -> None:
    """As medidas para o modelo 3D (tools/marketing/coluna3d)."""
    import json
    destino = Path(__file__).resolve().parent / "coluna3d" / "medidas.json"
    destino.parent.mkdir(parents=True, exist_ok=True)
    destino.write_text(json.dumps(MEDIDAS, indent=1), encoding="utf-8")


def main() -> None:
    exportar_medidas()
    print("coluna:")
    capo_frente()
    capo_lateral("esquerda")
    capo_lateral("direita")
    capo_baixo()
    coluna_frente_alto()
    coluna_frente_baixo()
    coluna_lateral("esquerda")
    coluna_lateral("direita")
    coluna_traseira()
    base_piso()
    montagem()


if __name__ == "__main__":
    main()
