"""Pecas de arte da divulgacao do SUPER BOXING, em qualquer resolucao.

O mesmo desenho de tools/gerar_tema.py (logo, fundo do gabinete, letreiros
em Bungee com contorno e sombra), mas com tamanho livre: as pecas de grafica
saem em 100 a 300 dpi no tamanho real, sem ampliar imagem pequena.

Requer: numpy, scipy, pillow.
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage as nd

RAIZ = Path(__file__).resolve().parents[2]
BUNGEE = str(RAIZ / "assets" / "fonts" / "Bungee-Regular.ttf")
SAIRA = str(RAIZ / "assets" / "fonts" / "SairaCondensed-ExtraBold.ttf")
LOGO_LAZER = RAIZ / "assets" / "logo_lazersport.png"

# as cores do jogo (scripts/paleta.gd e tools/gerar_tema.py)
NOITE = (11, 6, 32)
NOITE2 = (34, 10, 70)
ROXO = (122, 46, 255)
MAGENTA = (255, 38, 168)
AZUL = (40, 110, 255)
CIANO = (70, 220, 255)
AMARELO = (255, 208, 20)
LARANJA = (255, 120, 20)
VERMELHO = (232, 16, 42)
BRANCO = (255, 255, 255)
CONTORNO = (14, 8, 40)
SOMBRA = (8, 3, 22)
CREME = (246, 251, 255)
VERDE = (50, 242, 160)


def px(cm: float, dpi: float) -> int:
    return int(round(cm / 2.54 * dpi))


# ----------------------------------------------------------------- mascaras
def mascara_texto(texto: str, fonte: str, tamanho: int, inclina: float = 0.0) -> Image.Image:
    f = ImageFont.truetype(fonte, int(tamanho))
    caixa = f.getbbox(texto)
    w = caixa[2] - caixa[0] + int(tamanho)
    h = caixa[3] - caixa[1] + int(tamanho)
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).text((tamanho / 2 - caixa[0], tamanho / 2 - caixa[1]), texto, font=f, fill=255)
    if inclina:
        m = m.transform(m.size, Image.AFFINE, (1, inclina, -inclina * h * 0.5, 0, 1, 0), Image.BICUBIC)
    return m


def dilatar(m: Image.Image, raio: float) -> Image.Image:
    """Engorda a mascara `raio` pixels (borda lisa). Pela distancia, e nao
    por MaxFilter: com contorno de 80 px o filtro levava minutos."""
    if raio <= 0:
        return m
    a = np.asarray(m, np.float32) / 255.0
    fora = a < 0.5
    dist = nd.distance_transform_edt(fora)
    # meio pixel de borda vem da propria mascara (antisserrilhado)
    v = np.clip(raio + 0.5 - dist, 0.0, 1.0)
    v = np.maximum(v, a)
    return Image.fromarray((v * 255).astype(np.uint8))


def degrade(tam, cima, baixo, horizontal: bool = False) -> Image.Image:
    w, h = tam
    if horizontal:
        t = np.linspace(0, 1, w)[None, :, None]
    else:
        t = np.linspace(0, 1, h)[:, None, None]
    a = np.array(cima, np.float32)[None, None, :3]
    b = np.array(baixo, np.float32)[None, None, :3]
    g = a * (1 - t) + b * t
    return Image.fromarray(np.broadcast_to(g, (h, w, 3)).astype(np.uint8))


def pintar(m: Image.Image, tinta, base: Image.Image | None = None) -> Image.Image:
    out = base if base is not None else Image.new("RGBA", m.size, (0, 0, 0, 0))
    if isinstance(tinta, tuple):
        tinta = Image.new("RGB", m.size, tinta[:3])
    camada = tinta.convert("RGBA")
    camada.putalpha(m)
    out.alpha_composite(camada)
    return out


def recortar(img: Image.Image) -> Image.Image:
    return img.crop(img.getbbox())


# --------------------------------------------------------------- letreiros
def letreiro(texto, fonte, tamanho, cima, baixo, borda=CONTORNO, borda_px=16, sombra_px=10,
             inclina=-0.12, brilho=True, sombra_cor=SOMBRA) -> Image.Image:
    """Texto do jogo: preenchimento em degrade, contorno escuro, sombra
    deslocada (o "volume") e o fio de luz na metade de cima."""
    m = mascara_texto(texto, fonte, tamanho, inclina)
    pad = int(borda_px * 2 + sombra_px + 20)
    big = Image.new("L", (m.width + pad * 2, m.height + pad * 2), 0)
    big.paste(m, (pad, pad))
    m = big
    img = Image.new("RGBA", m.size, (0, 0, 0, 0))
    borda_m = dilatar(m, borda_px)
    if sombra_px:
        s = borda_m.transform(m.size, Image.AFFINE, (1, 0, -sombra_px * 0.6, 0, 1, -sombra_px), Image.BILINEAR)
        img = pintar(s, sombra_cor, img)
    img = pintar(borda_m, borda[:3], img)
    img = pintar(m, degrade(m.size, cima, baixo), img)
    if brilho:
        topo = np.asarray(m, np.float32) / 255
        desl = np.roll(topo, max(1, int(tamanho * 0.06)), axis=0)
        fio = np.clip(topo - desl, 0, 1) * 0.55
        img = pintar(Image.fromarray((fio * 255).astype(np.uint8)), BRANCO, img)
    return recortar(img)


def texto_simples(texto, fonte, tamanho, cor=BRANCO, borda=None, borda_px=0) -> Image.Image:
    m = mascara_texto(texto, fonte, tamanho)
    pad = int(borda_px + 4)
    big = Image.new("L", (m.width + pad * 2, m.height + pad * 2), 0)
    big.paste(m, (pad, pad))
    img = Image.new("RGBA", big.size, (0, 0, 0, 0))
    if borda is not None and borda_px:
        img = pintar(dilatar(big, borda_px), borda, img)
    img = pintar(big, cor, img)
    return recortar(img)


# ------------------------------------------------------------------- logo
def estrela_pts(w, h, pontas=16, fundo=0.62, seed=3, cx=None, cy=None):
    r = np.random.default_rng(seed)
    cx = w / 2 if cx is None else cx
    cy = h / 2 if cy is None else cy
    pts = []
    for i in range(pontas * 2):
        a = i / (pontas * 2) * math.tau - math.pi / 2
        k = 1.0 if i % 2 == 0 else fundo
        k *= r.uniform(0.86, 1.08)
        pts.append((cx + math.cos(a) * w / 2 * k, cy + math.sin(a) * h / 2 * k))
    return pts


def luva(tam: int) -> Image.Image:
    """Luva vermelha de frente (o O de BOXING), desenhada em 4x e reduzida."""
    s = tam * 4
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([s * 0.08, s * 0.04, s * 0.92, s * 0.86], fill=(70, 4, 14, 255))
    d.ellipse([s * 0.12, s * 0.07, s * 0.88, s * 0.81], fill=VERMELHO + (255,))
    d.ellipse([s * 0.02, s * 0.38, s * 0.34, s * 0.72], fill=(70, 4, 14, 255))
    d.ellipse([s * 0.05, s * 0.41, s * 0.31, s * 0.69], fill=(205, 14, 36, 255))
    d.rounded_rectangle([s * 0.26, s * 0.74, s * 0.74, s * 0.98], radius=s * 0.06, fill=(245, 245, 245, 255))
    d.rectangle([s * 0.26, s * 0.83, s * 0.74, s * 0.87], fill=VERMELHO + (255,))
    d.ellipse([s * 0.30, s * 0.14, s * 0.56, s * 0.34], fill=(255, 140, 150, 170))
    return img.resize((tam, tam), Image.LANCZOS)


def logo(k: float = 1.0, seed: int = 7) -> Image.Image:
    """O logo SUPER BOXING de tools/gerar_tema.py em escala `k` (k=1: 1400 px)."""
    rng = np.random.default_rng(seed)
    W, H = int(1400 * k), int(900 * k)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for escala, c in ((1.00, (12, 6, 30)), (0.965, BRANCO), (0.925, None)):
        pts = estrela_pts(W * 0.98 * escala, H * 0.96 * escala)
        pts = [(x + W * (1 - 0.98 * escala) / 2, y + H * (1 - 0.96 * escala) / 2) for x, y in pts]
        m = Image.new("L", (W * 2, H * 2), 0)
        ImageDraw.Draw(m).polygon([(x * 2, y * 2) for x, y in pts], fill=255)
        m = m.resize((W, H), Image.LANCZOS)
        if c is not None:
            img = pintar(m, c, img)
        else:
            miolo = degrade((W, H), (60, 120, 255), (86, 20, 170)).convert("RGBA")
            riscos = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            dm = ImageDraw.Draw(riscos)
            for _ in range(60):
                a = rng.uniform(0, math.tau)
                r0, r1 = rng.uniform(60, 250) * k, rng.uniform(300, 700) * k
                dm.line([(W / 2 + math.cos(a) * r0, H / 2 + math.sin(a) * r0 * 0.65),
                         (W / 2 + math.cos(a) * r1, H / 2 + math.sin(a) * r1 * 0.65)],
                        fill=(180, 220, 255, 90), width=max(1, int(rng.integers(2, 6) * k)))
            miolo.alpha_composite(riscos)
            img = pintar(m, miolo.convert("RGB"), img)
    su = letreiro("SUPE", BUNGEE, 230 * k, (255, 255, 255), (170, 200, 255), CONTORNO, 16 * k, 10 * k, -0.12)
    rr = letreiro("R", BUNGEE, 260 * k, (255, 90, 100), (190, 10, 30), CONTORNO, 16 * k, 10 * k, -0.12)
    y0 = 150 * k
    x0 = (W - (su.width + rr.width - 30 * k)) / 2
    img.alpha_composite(su, (int(x0), int(y0 + 20 * k)))
    img.alpha_composite(rr, (int(x0 + su.width - 30 * k), int(y0 - 10 * k)))
    b = letreiro("B", BUNGEE, 210 * k, (255, 255, 255), (170, 200, 255), CONTORNO, 15 * k, 10 * k, -0.12)
    xi = letreiro("XING", BUNGEE, 210 * k, (255, 255, 255), (170, 200, 255), CONTORNO, 15 * k, 10 * k, -0.12)
    lv = luva(int(200 * k))
    folga = int(15 * k)
    lv_borda = Image.new("RGBA", (lv.width + folga * 2, lv.height + folga * 2), (0, 0, 0, 0))
    a = Image.new("L", lv_borda.size, 0)
    a.paste(lv.split()[3], (folga, folga))
    lv_borda = pintar(dilatar(a, 14 * k), CONTORNO, lv_borda)
    lv_borda.alpha_composite(lv, (folga, folga))
    total = b.width + lv_borda.width + xi.width - 40 * k
    x1 = (W - total) / 2
    y1 = 455 * k
    img.alpha_composite(b, (int(x1), int(y1)))
    img.alpha_composite(lv_borda, (int(x1 + b.width - 20 * k), int(y1 + 5 * k)))
    img.alpha_composite(xi, (int(x1 + b.width + lv_borda.width - 40 * k), int(y1)))
    return recortar(img)


def logo_lazer(largura: int) -> Image.Image:
    im = Image.open(LOGO_LAZER).convert("RGBA")
    h = int(im.height * largura / im.width)
    return im.resize((largura, h), Image.LANCZOS)


# ------------------------------------------------------------------ fundos
def fundo_limpo(w: int, h: int, seed: int = 1) -> Image.Image:
    """O fundo do estilo novo (o do gabinete): preto arroxeado com dois
    brilhos macios, rosa embaixo e ciano em cima, e um roxo no meio. Feito
    pequeno e ampliado: liso e sem custo."""
    sw, sh = max(4, w // 4), max(4, h // 4)
    yy, xx = np.mgrid[0:sh, 0:sw].astype(np.float32)
    y = yy / sh
    img = np.array([16, 10, 30], np.float32) * (1 - y[..., None]) + np.array([5, 3, 11], np.float32) * y[..., None]
    rng = np.random.default_rng(seed)
    for cx, cy, r, cor, forca in ((0.12, 0.92, 0.75, MAGENTA, 0.30), (0.92, 0.10, 0.65, CIANO, 0.20),
                                  (0.55, 0.55, 0.55, ROXO, 0.16)):
        d = np.sqrt(((xx / sw - cx) * w / max(w, h)) ** 2 + ((yy / sh - cy) * h / max(w, h)) ** 2) / r
        img += (np.clip(1 - d, 0, 1) ** 2 * forca)[..., None] * np.array(cor, np.float32)
    img += rng.normal(0, 1.2, img.shape).astype(np.float32)
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)


def zebra(w: int, h: int, passo: int, angulo: float = 45.0, amarelo=AMARELO, preto=(16, 12, 18)) -> Image.Image:
    """Faixa amarela e preta de alerta (listras diagonais com borda lisa)."""
    y, x = np.mgrid[:h, :w].astype(np.float32)
    a = math.radians(angulo)
    u = (x * math.cos(a) + y * math.sin(a)) / passo
    f = np.abs((u % 2.0) - 1.0)  # 0..1 triangular
    lim = np.clip((f - 0.5) * passo * 0.7 + 0.5, 0, 1)[..., None]
    rgb = np.array(amarelo, np.float32) * lim + np.array(preto, np.float32) * (1 - lim)
    return Image.fromarray(rgb.astype(np.uint8))


def brilho(base: Image.Image, mascara: Image.Image, cor, raio: float, forca: float = 1.0) -> Image.Image:
    """Halo de neon: a mascara borrada, somada (aditivo) na cor."""
    a = np.asarray(mascara.filter(ImageFilter.GaussianBlur(raio)), np.float32) / 255 * forca
    b = np.asarray(base.convert("RGBA"), np.float32)
    b[..., :3] += a[..., None] * np.array(cor, np.float32)
    b[..., 3] = np.maximum(b[..., 3], np.clip(a * 255, 0, 255))
    return Image.fromarray(np.clip(b, 0, 255).astype(np.uint8), "RGBA")


def colar(base: Image.Image, peca: Image.Image, centro, largura=None, altura=None, halo=None):
    """Cola `peca` centrada em `centro` com largura (ou altura) pedida; `halo`
    = (cor, raio, forca) desenha um brilho em volta antes."""
    if largura is not None:
        k = largura / peca.width
    elif altura is not None:
        k = altura / peca.height
    else:
        k = 1.0
    if abs(k - 1.0) > 1e-3:
        peca = peca.resize((max(1, int(peca.width * k)), max(1, int(peca.height * k))), Image.LANCZOS)
    x = int(centro[0] - peca.width / 2)
    y = int(centro[1] - peca.height / 2)
    if halo is not None:
        cor, raio, forca = halo
        pad = int(raio * 3)
        m = Image.new("L", (peca.width + pad * 2, peca.height + pad * 2), 0)
        m.paste(peca.split()[3], (pad, pad))
        g = Image.new("RGBA", m.size, (0, 0, 0, 0))
        g = brilho(g, m, cor, raio, forca)
        base.alpha_composite(g, (x - pad, y - pad)) if x - pad >= 0 and y - pad >= 0 else _colar_seguro(base, g, x - pad, y - pad)
    _colar_seguro(base, peca, x, y)
    return (x, y, peca.width, peca.height)


def _colar_seguro(base: Image.Image, peca: Image.Image, x: int, y: int) -> None:
    """alpha_composite aceitando posicao negativa ou peca maior que a base."""
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(base.width, x + peca.width), min(base.height, y + peca.height)
    if x1 <= x0 or y1 <= y0:
        return
    base.alpha_composite(peca.crop((x0 - x, y0 - y, x1 - x, y1 - y)), (x0, y0))


def explosao(w: int, h: int, pontas=18, cores=((255, 238, 60), (255, 96, 20)), seed=5) -> Image.Image:
    """Estrela de impacto (estilo historia em quadrinhos) com contorno."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for escala, cor in ((1.0, CONTORNO), (0.94, None)):
        pts = estrela_pts(w * escala, h * escala, pontas, 0.68, seed)
        pts = [(x + w * (1 - escala) / 2, y + h * (1 - escala) / 2) for x, y in pts]
        m = Image.new("L", (w, h), 0)
        ImageDraw.Draw(m).polygon(pts, fill=255)
        img = pintar(m, cor if cor else degrade((w, h), cores[0], cores[1]), img)
    return img
