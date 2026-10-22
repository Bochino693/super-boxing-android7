"""Adesivos do gabinete do SUPER BOXING, prontos para a grafica.

    python tools/marketing/gerar_adesivos.py [torre|compacto|comuns ...]

Cada peca sai em TAMANHO REAL, com sangria, em marketing/adesivos/:
  <modelo>/<peca>.pdf          arquivo de impressao (RGB, 100 a 300 dpi)
  <modelo>/previas/<peca>.jpg  previa com a linha de corte (magenta), a
                               area segura (ciano tracejado), os furos e
                               as medidas
As medidas dos gabinetes vem de tools/marketing/medidas.py; o lutador, de
marketing/renders/ (renders do proprio jogo); o logo e as letras, de
tools/marketing/arte.py (as mesmas do jogo, em alta). O estilo e o das
maquinas chinesas: preto brilhante, uma lamina de cor, logo e lutador, e
nenhuma frase no movel (ver "o estilo", mais abaixo).

Requer: numpy, scipy, pillow.
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import arte  # noqa: E402
import medidas  # noqa: E402
from arte import (AMARELO, BRANCO, BUNGEE, CIANO, CONTORNO, MAGENTA, ROXO, SAIRA)  # noqa: E402

RAIZ = arte.RAIZ
SAIDA = RAIZ / "marketing" / "adesivos"
RENDERS = RAIZ / "marketing" / "renders"
Image.MAX_IMAGE_PIXELS = None


# ===================================================================== peca
class Peca:
    """Uma folha de adesivo em tamanho real. Coordenadas em cm a partir do
    canto de cima e da esquerda da area de CORTE (a sangria fica em volta)."""

    def __init__(self, nome: str, titulo: str, w: float, h: float, dpi: int, sangria: float,
                 material: str, pasta: Path):
        self.nome, self.titulo = nome, titulo
        self.w, self.h, self.dpi, self.b = w, h, dpi, sangria
        self.material = material
        self.pasta = pasta
        self.img = Image.new("RGBA", (self.s(w + 2 * sangria), self.s(h + 2 * sangria)), (0, 0, 0, 0))
        self.contorno: list[tuple[float, float]] | None = None   # recorte especial (cm)
        self.furos: list[tuple] = []     # ("circulo", cx, cy, d) | ("retangulo", x0, y0, x1, y1)
        self.linhas_guia: list[tuple] = []   # emendas (porta), so na previa
        self.notas: list[str] = []

    def s(self, cm: float) -> int:
        return int(round(cm / 2.54 * self.dpi))

    def p(self, x: float, y: float) -> tuple[int, int]:
        return (self.s(x + self.b), self.s(y + self.b))

    # ------------------------------------------------------------ desenho
    def colar(self, peca: Image.Image, cx: float, cy: float, largura: float | None = None,
              altura: float | None = None, halo=None) -> None:
        h = (halo[0], self.s(halo[1]), halo[2]) if halo else None
        arte.colar(self.img, peca, self.p(cx, cy), self.s(largura) if largura else None,
                   self.s(altura) if altura else None, h)

    def texto(self, texto: str, cx: float, cy: float, altura: float, cor=BRANCO, fonte=SAIRA,
              borda=CONTORNO, borda_rel=0.12, largura_max=None, ancora="centro") -> None:
        tam = max(16, int(self.s(altura) * 1.25))
        t = arte.texto_simples(texto, fonte, tam, cor, borda, int(tam * borda_rel) if borda else 0)
        k = self.s(altura) / t.height
        if largura_max is not None and t.width * k > self.s(largura_max):
            k = self.s(largura_max) / t.width
        t = t.resize((max(1, int(t.width * k)), max(1, int(t.height * k))), Image.LANCZOS)
        x, y = self.p(cx, cy)
        if ancora == "esquerda":
            x += t.width // 2
        arte._colar_seguro(self.img, t, x - t.width // 2, y - t.height // 2)

    def retangulo(self, x0, y0, x1, y1, cor, raio=0.0) -> None:
        d = ImageDraw.Draw(self.img)
        d.rounded_rectangle([self.p(x0, y0), self.p(x1, y1)], radius=self.s(raio), fill=cor)

    def zebra_ret(self, x0, y0, x1, y1, passo=3.0, borda=0.4) -> None:
        a, b = self.p(x0, y0), self.p(x1, y1)
        z = arte.zebra(b[0] - a[0], b[1] - a[1], self.s(passo))
        self.img.paste(z.convert("RGBA"), a)
        if borda:
            d = ImageDraw.Draw(self.img)
            d.rectangle([a, b], outline=CONTORNO + (255,), width=self.s(borda))

    # ------------------------------------------------------------- saidas
    def mascara_da_forma(self, folga: float) -> Image.Image:
        """A forma do recorte engordada `folga` cm (a area impressa)."""
        m = Image.new("L", self.img.size, 0)
        if self.contorno is None:
            ImageDraw.Draw(m).rectangle([self.p(-folga, -folga), self.p(self.w + folga, self.h + folga)], fill=255)
            return m
        ImageDraw.Draw(m).polygon([self.p(x, y) for x, y in self.contorno], fill=255)
        return arte.dilatar(m, self.s(folga)) if folga > 0 else m

    def salvar(self) -> None:
        self.pasta.mkdir(parents=True, exist_ok=True)
        (self.pasta / "previas").mkdir(exist_ok=True)
        branco = Image.new("RGBA", self.img.size, (255, 255, 255, 255))
        arte_ok = self.img.copy()
        arte_ok.putalpha(Image.fromarray(np.minimum(np.asarray(self.img.split()[3]),
                                                    np.asarray(self.mascara_da_forma(self.b)))))
        branco.alpha_composite(arte_ok)
        rgb = branco.convert("RGB")
        # furos e janelas saem BRANCOS no arquivo (a grafica recorta)
        d = ImageDraw.Draw(rgb)
        for f in self.furos:
            if f[0] == "circulo":
                _, cx, cy, dd = f
                d.ellipse([self.p(cx - dd / 2, cy - dd / 2), self.p(cx + dd / 2, cy + dd / 2)], fill=(255, 255, 255))
            else:
                _, x0, y0, x1, y1 = f
                d.rectangle([self.p(x0, y0), self.p(x1, y1)], fill=(255, 255, 255))
        pdf = self.pasta / f"{self.nome}.pdf"
        rgb.save(pdf, "PDF", resolution=float(self.dpi), quality=90)
        self._previa(rgb)
        # a peca recortada, menor: a textura dos renders 3D (tools/marketing/gabinete3d)
        corte = rgb.crop((self.s(self.b), self.s(self.b), self.s(self.b + self.w), self.s(self.b + self.h)))
        k = min(1.0, 2048 / max(corte.size))
        (self.pasta / "texturas").mkdir(exist_ok=True)
        corte.resize((max(1, int(corte.width * k)), max(1, int(corte.height * k))), Image.LANCZOS).save(
            self.pasta / "texturas" / f"{self.nome}.jpg", quality=90)
        mb = pdf.stat().st_size / 1e6
        print(f"  {self.pasta.name}/{self.nome}.pdf  {self.w:.1f} x {self.h:.1f} cm  {self.dpi} dpi  {mb:.1f} MB")

    def _previa(self, rgb: Image.Image) -> None:
        k = min(1.0, 1500 / max(rgb.size))
        prev = rgb.resize((int(rgb.width * k), int(rgb.height * k)), Image.LANCZOS)
        d = ImageDraw.Draw(prev)

        def q(x, y):
            a, b = self.p(x, y)
            return (a * k, b * k)
        corte = self.contorno or [(0, 0), (self.w, 0), (self.w, self.h), (0, self.h)]
        d.line([q(x, y) for x, y in pts_fechar(corte, True)], fill=(255, 0, 200), width=3)
        if self.contorno is None:
            m = 2.0
            pts = [(m, m), (self.w - m, m), (self.w - m, self.h - m), (m, self.h - m), (m, m)]
            for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
                tracejar(d, q(x0, y0), q(x1, y1), (0, 200, 255), 2, 10)
        for f in self.furos:
            if f[0] == "circulo":
                _, cx, cy, dd = f
                d.ellipse([q(cx - dd / 2, cy - dd / 2), q(cx + dd / 2, cy + dd / 2)], outline=(255, 0, 200), width=3)
            else:
                _, x0, y0, x1, y1 = f
                d.rectangle([q(x0, y0), q(x1, y1)], outline=(255, 0, 200), width=3)
        for (x0, y0), (x1, y1) in self.linhas_guia:
            tracejar(d, q(x0, y0), q(x1, y1), (255, 0, 200), 2, 8)
        # faixa de legenda
        f1 = ImageFont.truetype(SAIRA, 30)
        f2 = ImageFont.truetype(SAIRA, 22)
        notas = [f"{self.w:.1f} x {self.h:.1f} cm (corte) + sangria {self.b:g} cm  |  {self.dpi} dpi  |  {self.material}"]
        notas += self.notas
        alt = 50 + 30 * len(notas)
        final = Image.new("RGB", (max(prev.width, 900), prev.height + alt), (20, 12, 40))
        final.paste(prev, ((final.width - prev.width) // 2, 0))
        dd = ImageDraw.Draw(final)
        dd.text((14, prev.height + 8), self.titulo, font=f1, fill=(255, 220, 60))
        for i, n in enumerate(notas):
            dd.text((14, prev.height + 46 + 30 * i), n, font=f2, fill=(230, 230, 255))
        final.save(self.pasta / "previas" / f"{self.nome}.jpg", quality=88)


def pts_fechar(pts, fechado):
    pts = list(pts)
    return pts + [pts[0]] if fechado and pts else pts


def tracejar(d, a, b, cor, w, passo):
    dist = math.hypot(b[0] - a[0], b[1] - a[1])
    n = max(1, int(dist / passo))
    for i in range(0, n, 2):
        t0, t1 = i / n, min(1.0, (i + 1) / n)
        d.line([(a[0] + (b[0] - a[0]) * t0, a[1] + (b[1] - a[1]) * t0),
                (a[0] + (b[0] - a[0]) * t1, a[1] + (b[1] - a[1]) * t1)], fill=cor, width=w)


# ================================================================ recursos
_CACHE: dict = {}


def lutador(nome: str) -> Image.Image:
    if nome not in _CACHE:
        _CACHE[nome] = Image.open(RENDERS / f"lutador_{nome}.png").convert("RGBA")
    return _CACHE[nome]


def logo_hd() -> Image.Image:
    if "logo" not in _CACHE:
        _CACHE["logo"] = arte.logo(4.0)
    return _CACHE["logo"]


def lazer(largura_px: int) -> Image.Image:
    return arte.logo_lazer(largura_px)


# ================================================================== o estilo
## O ESTILO DAS MAQUINAS CHINESAS. Corpo PRETO brilhante; UMA lamina de cor
## (ciano em cima, roxo, rosa embaixo: as cores do jogo) acompanhando a
## frente do gabinete; o logo e o lutador. Nada de frase, selo ou faixa
## zebrada no movel: quem chama a atencao sao os LEDs de verdade (bordas das
## laterais, moldura da TV, alto-falantes, letreiro) e a tela.
PRETO_CIMA = (18, 13, 30)
PRETO_BAIXO = (7, 5, 13)
PRATA = (190, 196, 214)
LAMINA = ((0.0, CIANO), (0.45, ROXO), (1.0, MAGENTA))   # 0 = alto do gabinete


def fundo_preto(p: Peca, reflexo: float = 1.0) -> None:
    """Preto brilhante: degrade suave e reflexos diagonais bem leves (o
    brilho do verniz). Feito pequeno e ampliado: liso e sem custo."""
    w, h = p.img.size
    sw, sh = max(4, w // 10), max(4, h // 10)
    y = np.linspace(0.0, 1.0, sh, dtype=np.float32)[:, None, None]
    base = np.array(PRETO_CIMA, np.float32) * (1.0 - y) + np.array(PRETO_BAIXO, np.float32) * y
    base = np.repeat(base, sw, axis=1)
    if reflexo > 0:
        xx = np.linspace(0.0, 1.0, sw, dtype=np.float32)[None, :]
        yy = np.linspace(0.0, 1.0, sh, dtype=np.float32)[:, None] * (h / w)
        d = (xx * 0.8 + yy * 0.6) / (0.8 + 0.6 * h / w)
        tom = np.array([1.0, 0.9, 1.15], np.float32)
        for c, larg, forca in ((0.30, 0.07, 8.0), (0.37, 0.012, 6.0), (0.70, 0.12, 5.0)):
            base += (np.exp(-((d - c) / larg) ** 2) * forca * reflexo)[..., None] * tom
    img = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    p.img.paste(img.convert("RGBA"), (0, 0))


def cor_da_lamina(t: np.ndarray) -> np.ndarray:
    """Cores da lamina para t de 0 (alto) a 1 (chao)."""
    t = np.clip(t, 0.0, 1.0)
    cor = np.zeros(t.shape + (3,), np.float32)
    for (t0, c0), (t1, c1) in zip(LAMINA, LAMINA[1:]):
        k = np.clip((t - t0) / (t1 - t0), 0.0, 1.0)[..., None]
        dentro = ((t >= t0) & (t <= t1))[..., None]
        cor = np.where(dentro, np.array(c0, np.float32) * (1 - k) + np.array(c1, np.float32) * k, cor)
    return cor


def tinta_por_altura(p: Peca, altura_do_topo: float, altura_total: float) -> Image.Image:
    """O degrade da lamina pela ALTURA NO GABINETE: a mesma cor na lateral,
    na frente e no letreiro. `altura_do_topo` = altura (cm do chao) da borda
    de cima da folha; `altura_total` = altura em que a lamina e ciano."""
    w, h = p.img.size
    y_folha = (np.arange(h, dtype=np.float32) / (p.dpi / 2.54)) - p.b
    altura = altura_do_topo - y_folha
    col = cor_da_lamina(1.0 - altura / altura_total)
    return Image.fromarray(col.astype(np.uint8)[:, None, :]).resize((w, h), Image.NEAREST)


def aura(p: Peca, cx: float, cy: float, rx: float, ry: float, cor, forca: float = 0.5) -> None:
    """Brilho redondo e macio atras de uma peca (feito pequeno e ampliado)."""
    w, h = p.s(rx * 2), p.s(ry * 2)
    n = 128
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32) / (n - 1) * 2 - 1
    a = np.clip(1.0 - np.sqrt(xx ** 2 + yy ** 2), 0, 1) ** 2.2 * forca
    g = np.zeros((n, n, 4), np.float32)
    g[..., :3] = cor
    g[..., 3] = a * 255
    img = Image.fromarray(g.astype(np.uint8), "RGBA").resize((w, h), Image.BICUBIC)
    x, y = p.p(cx, cy)
    arte._colar_seguro(p.img, img, x - w // 2, y - h // 2)


def anel_prata(p: Peca, cx: float, cy: float, d: float, largura: float = 0.35) -> None:
    dd = ImageDraw.Draw(p.img)
    r = d / 2 + largura
    dd.ellipse([p.p(cx - r, cy - r), p.p(cx + r, cy + r)], outline=PRATA + (255,), width=max(1, p.s(largura)))


# ================================================================ laterais
def _frente_da_lateral(perfil, y_max):
    """O contorno da FRENTE da lateral como x(y), do chao ate `y_max`."""
    pts = {}
    for x, y in perfil:
        if x > 1.0 and -0.01 <= y <= y_max:
            pts[round(y, 3)] = max(pts.get(round(y, 3), 0.0), x)
    ys = sorted(pts)
    xs = [pts[y] for y in ys]
    return lambda y: float(np.interp(y, ys, xs))


def lateral(modelo: str, lado: str) -> None:
    m = medidas.MODELOS[modelo]
    perfil = medidas.perfil(modelo)
    xmax = max(x for x, _ in perfil)
    H = m["H"]
    espelho = lado == "direita"

    def cm(x, y):  # coordenada do gabinete -> coordenada da folha
        return ((xmax - x) if espelho else x, H - y)

    pasta = SAIDA / modelo
    p = Peca(f"lateral_{lado}", f"{m['nome']} - LATERAL {lado.upper()} (recorte no contorno)",
             xmax, H, 100, 1.0, "vinil adesivo BRILHO + laminacao, recorte eletronico no contorno", pasta)
    p.contorno = [cm(x, y) for x, y in perfil]
    fundo_preto(p)
    forma = p.mascara_da_forma(p.b)
    pe, tv, ca = m["pedestal"], m["tv"], m["capo"]

    # A LAMINA: acompanha a frente, larga embaixo e fina em cima (onde o
    # fio de LED da borda continua o desenho ate o capo).
    y_topo = ca["y0"] - 6.0
    frente = _frente_da_lateral(perfil, y_topo + 1.0)
    larga, fina = pe["x1"] * 0.36, 1.2

    def largura(y):
        s = np.clip(y / y_topo, 0.0, 1.0)
        return larga * (1.0 - s) ** 1.35 + fina * s

    ys = np.linspace(-2.0, y_topo, 160)
    fora = [(frente(max(0.0, y)) - 1.6, y) for y in ys]
    dentro = [(frente(max(0.0, y)) - 1.6 - largura(y), y) for y in ys[::-1]]
    mascara = Image.new("L", p.img.size, 0)
    ImageDraw.Draw(mascara).polygon([p.p(*cm(x, y)) for x, y in fora + dentro], fill=255)
    # o FIO: uma segunda lamina fina por dentro, que some no alto
    ys2 = np.linspace(-2.0, y_topo * 0.62, 100)
    fio_f = [(frente(max(0.0, y)) - 1.6 - largura(y) - 2.2, y) for y in ys2]
    fio_d = [(frente(max(0.0, y)) - 1.6 - largura(y) - 2.2 - 1.3 * (1.0 - y / (y_topo * 0.62)), y) for y in ys2[::-1]]
    ImageDraw.Draw(mascara).polygon([p.p(*cm(x, y)) for x, y in fio_f + fio_d], fill=255)
    mascara = Image.fromarray(np.minimum(np.asarray(mascara), np.asarray(forma)))
    p.img = arte.pintar(mascara, tinta_por_altura(p, H, y_topo), p.img)
    # o friso de luz na borda de dentro da lamina larga
    friso = Image.new("L", p.img.size, 0)
    ImageDraw.Draw(friso).line([p.p(*cm(x, y)) for x, y in dentro[::-1]], fill=255, width=max(1, p.s(0.25)))
    p.img = arte.pintar(friso, (255, 255, 255), p.img)

    # O LUTADOR na coluna ao lado da TV, com uma aura atras
    alt_lut = (ca["y0"] - tv["y0"]) * 0.92
    larg_col = frente(tv["y0"] + 40.0) - 1.6 - largura(tv["y0"] + 40.0)
    x_lut = larg_col * 0.5
    y_lut = tv["y0"] + alt_lut / 2 - 1.0
    lx, ly = cm(x_lut, y_lut)
    aura(p, lx, ly - alt_lut * 0.08, larg_col * 0.62, alt_lut * 0.42, ROXO, 0.55)
    alt_ok = min(alt_lut, larg_col * 0.92 * lutador("guarda").height / lutador("guarda").width)
    p.colar(lutador("guarda"), lx, ly, altura=alt_ok)

    # O LOGO no pedestal, no espaco livre antes da lamina
    y_logo = pe["y1"] * 0.52
    livre = frente(y_logo) - 1.6 - largura(y_logo)
    gx, gy = cm(livre * 0.5, y_logo)
    larg_logo = min(livre * 0.86, pe["y1"] * 0.62 * logo_hd().width / logo_hd().height)
    aura(p, gx, gy, larg_logo * 0.62, larg_logo * 0.45, MAGENTA, 0.35)
    p.colar(logo_hd(), gx, gy, largura=larg_logo)

    p.notas.append("esquerda: a frente do gabinete fica a DIREITA da folha" if not espelho else
                   "direita: a frente do gabinete fica a ESQUERDA da folha")
    p.notas.append("contorno em magenta = recorte (a sangria de 1 cm passa por fora); a borda leva fita de LED")
    p.salvar()


# ================================================================ frontal
def frontal(modelo: str) -> None:
    m = medidas.MODELOS[modelo]
    W = m["W"] - 2 * m["chapa"]
    H = m["pedestal"]["y1"]
    p = Peca("frontal", f"{m['nome']} - FRENTE DO PEDESTAL", W, H, 100, 1.0,
             "vinil adesivo BRILHO + laminacao; recortar furos dos alto-falantes e a emenda da porta", SAIDA / modelo)
    fundo_preto(p, 0.7)
    y_topo = m["capo"]["y0"] - 6.0
    # a lamina dobra a quina: nas duas bordas, larga no chao e sumindo no alto
    mascara = Image.new("L", p.img.size, 0)
    d = ImageDraw.Draw(mascara)
    base = W * 0.16
    for pts in ([(-1.0, H + 1.0), (-1.0 + base, H + 1.0), (0.4, H * 0.12), (-1.0, H * 0.12)],
                [(W + 1.0, H + 1.0), (W + 1.0 - base, H + 1.0), (W - 0.4, H * 0.12), (W + 1.0, H * 0.12)]):
        d.polygon([p.p(x, y) for x, y in pts], fill=255)
    p.img = arte.pintar(mascara, tinta_por_altura(p, H, y_topo), p.img)
    so = m["som"]
    cx = W / 2
    y_som = H - so["y"]
    for s in (-1, 1):
        x = cx + s * so["dx"]
        anel_prata(p, x, y_som, so["diam"] + 1.6, 0.3)
        p.furos.append(("circulo", x, y_som, so["diam"]))
    pc = m["porta_cofre"]
    y0, y1 = H - pc["y1"], H - pc["y0"]
    # a marca da casa entre os alto-falantes e a porta
    ls = lazer(p.s(min(W * 0.36, 26.0)))
    p.colar(ls, cx, (y_som + so["diam"] / 2 + y0) / 2)
    p.linhas_guia += [((cx - pc["w"] / 2, y0), (cx + pc["w"] / 2, y0)), ((cx + pc["w"] / 2, y0), (cx + pc["w"] / 2, y1)),
                      ((cx - pc["w"] / 2, y1), (cx + pc["w"] / 2, y1)), ((cx - pc["w"] / 2, y0), (cx - pc["w"] / 2, y1))]
    p.notas.append("tracejado = emenda da porta do cofre (cortar o adesivo nela); circulos = alto-falantes (anel de LED por tras)")
    p.salvar()


# ================================================================ letreiro
def letreiro(modelo: str) -> None:
    m = medidas.MODELOS[modelo]
    W = m["W"] - 2 * m["chapa"]
    H = m["letreiro"]["y1"] - m["letreiro"]["y0"]
    p = Peca("letreiro", f"{m['nome']} - LETREIRO LUMINOSO (frente do capo)", W, H, 150, 0.5,
             "vinil TRANSLUCIDO (backlight) sobre acrilico leitoso, luz por tras", SAIDA / modelo)
    fundo_preto(p, 0.0)
    lg = logo_hd()
    alt = H * 0.96
    larg = alt * lg.width / lg.height
    aura(p, W / 2, H / 2, larg * 0.75, H * 0.75, ROXO, 0.6)
    # riscos de luz saindo do logo para os lados (rosa a esquerda, ciano a direita)
    for s, cor in ((-1, MAGENTA), (1, CIANO)):
        for dy, comp, esp in ((-0.22, 0.85, 0.30), (0.0, 1.0, 0.45), (0.22, 0.7, 0.30)):
            x_ini = W / 2 + s * (larg * 0.5 + 1.0)
            x_fim = x_ini + s * (W / 2 - larg * 0.5 - 2.5) * comp
            y = H / 2 + dy * H
            n = 40
            for i in range(n):
                a = x_ini + (x_fim - x_ini) * i / n
                b = x_ini + (x_fim - x_ini) * (i + 1) / n
                k = 1.0 - i / n
                c = tuple(int(v * (0.35 + 0.65 * k)) for v in cor) + (int(255 * (0.25 + 0.75 * k)),)
                ImageDraw.Draw(p.img).line([p.p(a, y), p.p(b, y)], fill=c, width=max(1, p.s(esp)))
    p.colar(lg, W / 2, H / 2, altura=alt)
    p.notas.append("a luz de tras clareia: imprimir com tinta carregada (perfil backlight)")
    p.salvar()


# ================================================================ comando
def comando(modelo: str) -> None:
    m = medidas.MODELOS[modelo]
    c = m["comando"]
    W = m["W"] - 2 * m["chapa"]
    L = math.hypot(c["x_frente"] - c["x_tras"], c["y_tras"] - c["y_frente"])
    p = Peca("painel_comando", f"{m['nome']} - PAINEL DE COMANDO (START e credito)", W, L, 200, 0.5,
             "vinil adesivo + laminacao FOSCA resistente; furo do botao e do moedeiro", SAIDA / modelo)
    fundo_preto(p, 0.4)
    # o friso de luz na borda da frente (a de baixo da folha)
    mascara = Image.new("L", p.img.size, 0)
    ImageDraw.Draw(mascara).rectangle([p.p(-0.5, L - 0.9), p.p(W + 0.5, L - 0.5)], fill=255)
    tinta = Image.new("RGB", p.img.size)
    tinta.paste(arte.degrade((p.img.width, p.img.height), MAGENTA, CIANO, horizontal=True))
    p.img = arte.pintar(mascara, tinta, p.img)
    cx = W / 2
    yb = L * 0.45
    st, mo = m["start"], m["moedeiro"]
    xs = cx + st["dx"]
    xm = cx + mo["dx"]
    anel_prata(p, xs, yb, st["diam"] + 0.6, 0.35)
    p.furos.append(("circulo", xs, yb, st["diam"]))
    p.texto("START", xs, yb + st["diam"] / 2 + 2.2, 1.6, cor=BRANCO, fonte=BUNGEE, borda=None)
    p.furos.append(("retangulo", xm - mo["w"] / 2, yb - mo["h"] / 2, xm + mo["w"] / 2, yb + mo["h"] / 2))
    dd = ImageDraw.Draw(p.img)
    dd.rounded_rectangle([p.p(xm - mo["w"] / 2 - 0.6, yb - mo["h"] / 2 - 0.6), p.p(xm + mo["w"] / 2 + 0.6, yb + mo["h"] / 2 + 0.6)],
                         radius=p.s(0.6), outline=PRATA + (255,), width=max(1, p.s(0.3)))
    p.texto("CRÉDITO", xm, yb + mo["h"] / 2 + 2.2, 1.6, cor=BRANCO, fonte=BUNGEE, borda=None)
    p.notas.append("o furo do moedeiro/noteiro e uma sugestao: recorte conforme a sua peca")
    p.salvar()


# ============================================================ moldura da TV
def moldura(modelo: str) -> None:
    m = medidas.MODELOS[modelo]
    tv = m["tv"]
    W = m["W"] - 2 * m["chapa"]
    y_cima = m["capo"]["y0"]
    y_baixo = m["comando"]["y_tras"]
    H = y_cima - y_baixo
    jx0 = (W - tv["vis_w"]) / 2
    jy0 = y_cima - (tv["y0"] + (tv["ext_h"] + tv["vis_h"]) / 2)
    jx1, jy1 = jx0 + tv["vis_w"], jy0 + tv["vis_h"]
    p = Peca("moldura_da_tela", f"{m['nome']} - MOLDURA DA TV {tv['pol']}\" (janela recortada)", W, H, 120, 1.0,
             "vinil adesivo BRILHO + laminacao; janela da TV recortada; por cima, acrilico 4 mm", SAIDA / modelo)
    fundo_preto(p, 0.6)
    # um friso fino em degrade em volta da janela (ciano em cima, rosa embaixo)
    folga, esp = 1.4, 0.35
    fora = Image.new("L", p.img.size, 0)
    dentro = Image.new("L", p.img.size, 0)
    ImageDraw.Draw(fora).rounded_rectangle([p.p(jx0 - folga - esp, jy0 - folga - esp), p.p(jx1 + folga + esp, jy1 + folga + esp)],
                                           radius=p.s(2.0), fill=255)
    ImageDraw.Draw(dentro).rounded_rectangle([p.p(jx0 - folga, jy0 - folga), p.p(jx1 + folga, jy1 + folga)],
                                             radius=p.s(1.7), fill=255)
    anel = Image.fromarray(np.clip(np.asarray(fora, np.int16) - np.asarray(dentro, np.int16), 0, 255).astype(np.uint8))
    p.img = arte.pintar(anel, tinta_por_altura(p, y_cima, m["capo"]["y0"] - 6.0), p.img)
    # canaletas das fitas de LED (WS2812B, esquerda e direita): so na previa
    for s in (-1, 1):
        x = (jx0 - folga - 3.0) if s < 0 else (jx1 + folga + 3.0)
        p.linhas_guia.append(((x - 0.8, jy0 + 2), (x - 0.8, jy1 - 2)))
        p.linhas_guia.append(((x + 0.8, jy0 + 2), (x + 0.8, jy1 - 2)))
    p.furos.append(("retangulo", jx0, jy0, jx1, jy1))
    p.notas.append(f"janela = area visivel da TV {tv['pol']}\" em pe ({tv['vis_w']} x {tv['vis_h']} cm); tracejado = canaletas do LED")
    p.salvar()


# ================================================================== comuns
def como_jogar() -> None:
    """Tres passos, grandes, e mais nada."""
    W, H = 29.7, 42.0
    p = Peca("como_jogar", "COMO JOGAR (A3)", W, H, 200, 0.3, "vinil adesivo + laminacao fosca (ou placa PS)",
             SAIDA / "comuns")
    fundo_preto(p, 0.6)
    p.colar(logo_hd(), W / 2, 6.8, largura=19.0)
    passos = ["APERTE START", "ESPERE O SACO DESCER", "SOQUE!"]
    y = 17.5
    for i, titulo in enumerate(passos):
        cor = tuple(int(v) for v in cor_da_lamina(np.array(i / 2.0)))
        d = ImageDraw.Draw(p.img)
        d.ellipse([p.p(3.0, y - 2.2), p.p(7.4, y + 2.2)], outline=cor + (255,), width=p.s(0.35))
        p.texto(str(i + 1), 5.2, y, 2.4, cor=BRANCO, fonte=BUNGEE, borda=None)
        p.texto(titulo, 9.0, y, 1.3, cor=BRANCO, fonte=BUNGEE, largura_max=W - 12, ancora="esquerda", borda=None)
        y += 7.6
    p.colar(lazer(p.s(8.0)), W / 2, H - 5.2)
    p.salvar()


def aviso() -> None:
    W, H = 20.0, 14.0
    p = Peca("aviso_de_seguranca", "AVISO DE SEGURANCA", W, H, 300, 0.3, "vinil adesivo + laminacao fosca", SAIDA / "comuns")
    p.retangulo(-0.3, -0.3, W + 0.3, H + 0.3, (255, 255, 255, 255))
    p.zebra_ret(-0.3, -0.3, W + 0.3, 2.6, 1.4)
    p.retangulo(5.0, 0.45, 15.0, 2.05, CONTORNO + (255,), 0.3)
    p.texto("ATENÇÃO", W / 2, 1.25, 1.1, cor=AMARELO, fonte=BUNGEE, borda=None)
    linhas = [
        "Soque somente o saco, com a mão fechada.",
        "Tire anéis, relógios e pulseiras antes de jogar.",
        "Espere o saco parar EMBAIXO para socar.",
        "Mantenha distância de quem está jogando.",
        "Não se pendure no saco nem no gabinete.",
        "Crianças só com um adulto por perto.",
    ]
    for i, l in enumerate(linhas):
        p.texto("•  " + l, 1.2, 4.0 + i * 1.6, 0.85, cor=CONTORNO, borda=None, ancora="esquerda", largura_max=W - 2)
    p.salvar()


def piso() -> None:
    """Onde ficar: as duas pegadas e um arco de luz do lado da maquina."""
    W, H = 60.0, 60.0
    p = Peca("piso_posicao", "ADESIVO DE PISO - POSICAO DO JOGADOR", W, H, 100, 0.5,
             "vinil de PISO antiderrapante (laminacao para chao)", SAIDA / "comuns")
    fundo_preto(p, 0.5)
    mascara = Image.new("L", p.img.size, 0)
    ImageDraw.Draw(mascara).arc([p.p(4.0, 3.0), p.p(W - 4.0, H * 1.6)], 200, 340, fill=255, width=p.s(0.9))
    tinta = arte.degrade(p.img.size, MAGENTA, CIANO, horizontal=True)
    p.img = arte.pintar(mascara, tinta, p.img)
    for s_ in (-1, 1):
        pe = pegada(p.s(11), p.s(26), s_ < 0, BRANCO)
        p.colar(pe, W / 2 + s_ * 9.0, 34.0)
    p.notas.append("o arco fica do lado da maquina")
    p.salvar()


def pegada(w: int, h: int, esquerda: bool, cor=AMARELO) -> Image.Image:
    s = 4
    img = Image.new("RGBA", (w * s, h * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    W, H = w * s, h * s
    d.ellipse([W * 0.12, H * 0.2, W * 0.95, H * 0.72], fill=cor + (255,))
    d.ellipse([W * 0.2, H * 0.62, W * 0.85, H * 0.98], fill=cor + (255,))
    for i, (x, y, r) in enumerate([(0.78, 0.1, 0.13), (0.55, 0.06, 0.11), (0.36, 0.07, 0.10), (0.2, 0.11, 0.09), (0.08, 0.18, 0.08)]):
        d.ellipse([W * (x - r), H * (y - r * 0.6), W * (x + r), H * (y + r * 0.6)], fill=cor + (255,))
    if esquerda:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    return img.resize((w, h), Image.LANCZOS)


def logo_recortado() -> None:
    for largura, nome in ((40.0, "logo_recortado_40cm"), (15.0, "logo_recortado_15cm")):
        lg = logo_hd()
        h = largura * lg.height / lg.width
        p = Peca(nome, f"LOGO SUPER BOXING RECORTADO ({largura:g} cm)", largura + 2.0, h + 2.0, 150, 0.3,
                 "vinil adesivo brilho, recorte eletronico no contorno branco", SAIDA / "comuns")
        folga = 60
        a = Image.new("L", (lg.width + folga * 2, lg.height + folga * 2), 0)
        a.paste(lg.split()[3], (folga, folga))
        base = arte.pintar(arte.dilatar(a, 40), (255, 255, 255))
        base.alpha_composite(lg, (folga, folga))
        p.colar(base, p.w / 2, p.h / 2, largura=largura + 1.6)
        p.notas.append("a borda branca e a linha de recorte do contorno")
        p.salvar()


PECAS_DO_MODELO = [lateral, frontal, letreiro, comando, moldura]


def main() -> None:
    alvos = sys.argv[1:] or ["torre", "compacto", "comuns"]
    for a in alvos:
        if a == "comuns":
            print("comuns:")
            como_jogar(); aviso(); piso(); logo_recortado()
            continue
        print(f"{a}:")
        for f in PECAS_DO_MODELO:
            if f is lateral:
                lateral(a, "esquerda"); lateral(a, "direita")
            else:
                f(a)


if __name__ == "__main__":
    main()
