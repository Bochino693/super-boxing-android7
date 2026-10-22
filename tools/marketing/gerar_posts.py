"""Pecas de divulgacao para redes sociais e catalogo do SUPER BOXING.

    python tools/marketing/gerar_posts.py

Saidas em marketing/posts/:
  poster_vertical_1080x1920.png   Stories, Status, Reels (capa), cartaz
  post_quadrado_1080x1080.png     feed do Instagram/Facebook
  banner_horizontal_1920x1080.png YouTube, Facebook, site, apresentacao
  catalogo_gabinetes_1920x1080.png os dois gabinetes com as medidas
Usa o logo e as letras do jogo (arte.py), os renders do lutador
(marketing/renders) e os renders 3D dos gabinetes (marketing/gabinetes/renders).
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import arte  # noqa: E402
import medidas  # noqa: E402
from arte import AMARELO, BUNGEE, CIANO, CONTORNO, MAGENTA, SAIRA  # noqa: E402

MK = arte.RAIZ / "marketing"
SAIDA = MK / "posts"


def lutador(nome):
    return Image.open(MK / "renders" / f"lutador_{nome}.png").convert("RGBA")


def letreiro(t, tam, cima=(255, 238, 60), baixo=(255, 120, 20)):
    return arte.letreiro(t, BUNGEE, tam, cima, baixo, CONTORNO, tam * 0.11, tam * 0.08, -0.12)


def simples(t, tam, cor=(255, 255, 255)):
    return arte.texto_simples(t, SAIRA, tam, cor, CONTORNO, max(2, tam // 9))


def pilula(img, cx, cy, texto, tam=40, cor=MAGENTA):
    t = simples(texto, tam)
    w, h = t.width + tam, t.height + tam * 0.45
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2], radius=h / 2, fill=(20, 8, 46, 235),
                        outline=cor + (255,), width=4)
    arte.colar(img, t, (cx, cy))


def base(w, h, seed):
    return arte.fundo_limpo(w, h, seed).convert("RGBA")


def poster_vertical(logo):
    W, H = 1080, 1920
    img = base(W, H, 101)
    ex = arte.explosao(1000, 900, 18, seed=9)
    ex.putalpha(ex.split()[3].point(lambda v: int(v * 0.85)))
    arte.colar(img, ex, (W / 2, 1010))
    arte.colar(img, lutador("soco"), (W / 2, 1010), largura=1000, halo=(CIANO, 18, 0.8))
    arte.colar(img, logo, (W / 2, 290), largura=860, halo=(MAGENTA, 20, 0.8))
    arte.colar(img, letreiro("QUAL A FORÇA", 130), (W / 2, 1495), largura=960)
    arte.colar(img, letreiro("DO SEU SOCO?", 130), (W / 2, 1620), largura=960)
    pilula(img, W / 2, 1728, "LUTADOR 3D  •  SACO QUE SOBE E DESCE  •  TOP 20 COM FOTO", 34)
    arte.colar(img, arte.logo_lazer(220), (W / 2, 1838))
    salvar(img, "poster_vertical_1080x1920.png")


def post_quadrado(logo):
    W = H = 1080
    img = base(W, H, 102)
    ex = arte.explosao(760, 700, 16, seed=12)
    ex.putalpha(ex.split()[3].point(lambda v: int(v * 0.85)))
    arte.colar(img, ex, (W * 0.68, 600))
    arte.colar(img, lutador("campeao"), (W * 0.70, 600), altura=960, halo=(CIANO, 14, 0.8))
    arte.colar(img, logo, (W * 0.30, 230), largura=560, halo=(MAGENTA, 16, 0.8))
    for i, t in enumerate(["TESTE", "SUA", "FORÇA!"]):
        arte.colar(img, letreiro(t, 120), (W * 0.27, 520 + i * 135), largura=470)
    pilula(img, W * 0.27, 880, "ENTRE NO TOP 20", 38, AMARELO)
    arte.colar(img, arte.logo_lazer(210), (W * 0.27, 990))
    salvar(img, "post_quadrado_1080x1080.png")


def banner(logo):
    W, H = 1920, 1080
    img = base(W, H, 103)
    ex = arte.explosao(1000, 900, 18, seed=14)
    ex.putalpha(ex.split()[3].point(lambda v: int(v * 0.85)))
    arte.colar(img, ex, (W * 0.70, 560))
    arte.colar(img, lutador("soco"), (W * 0.71, 560), altura=1040, halo=(CIANO, 18, 0.8))
    arte.colar(img, logo, (W * 0.26, 260), largura=760, halo=(MAGENTA, 20, 0.8))
    arte.colar(img, letreiro("QUAL A FORÇA DO SEU SOCO?", 90), (W * 0.26, 590), largura=820)
    itens = ["Lutador 3D que reage a cada soco", "Saco que desce para jogar e sobe para guardar",
             "Pontuação de 0 a 9999 e nocaute na tela", "TOP 20 com a foto de quem bateu"]
    for i, t in enumerate(itens):
        tt = simples("•  " + t, 44)
        img.alpha_composite(tt, (int(W * 0.26 - 400), int(650 + i * 58)))
    arte.colar(img, arte.logo_lazer(200), (W * 0.26, 995))
    salvar(img, "banner_horizontal_1920x1080.png")


def catalogo(logo):
    fila = MK / "gabinetes" / "renders" / "linha_heroi_recorte.png"
    if not fila.exists():
        print("  (sem o render dos gabinetes recortados: rode o gabinete3d com --fila --recorte)")
        return
    W, H = 1920, 1080
    img = base(W, H, 104)
    g = Image.open(fila).convert("RGBA")
    g = g.crop(g.getbbox())
    arte.colar(img, g, (W * 0.64, 560), altura=1000)
    arte.colar(img, logo, (W * 0.20, 180), largura=560, halo=(MAGENTA, 16, 0.8))
    arte.colar(img, letreiro("2 MODELOS", 96), (W * 0.20, 400), largura=520)
    y = 500
    for chave in ("torre", "compacto"):
        m = medidas.MODELOS[chave]
        prof = max(x for x, _ in medidas.perfil(chave))
        arte.colar(img, letreiro(m["nome"].replace("SUPER BOXING ", ""), 64, (255, 255, 255), (170, 200, 255)),
                   (W * 0.20, y), largura=420)
        for j, t in enumerate([f"{m['W']:g} x {prof:g} x {m['H']:g} cm (L x P x A)",
                               f"TV {m['tv']['pol']}\" em pé  •  saco a {(m['saco']['topo'] - m['saco']['altura'] / 2) / 100 + 1e-6:.2f} m".replace(".", ","),
                               m["resumo"].split("(")[-1].rstrip(")") if "(" in m["resumo"] else ""]):
            if t:
                tt = simples(t, 34)
                arte.colar(img, tt, (W * 0.20, y + 70 + j * 46))
        y += 250
    arte.colar(img, arte.logo_lazer(240), (W * 0.20, 1010))
    salvar(img, "catalogo_gabinetes_1920x1080.png")


def salvar(img, nome):
    SAIDA.mkdir(parents=True, exist_ok=True)
    img.convert("RGB").save(SAIDA / nome, optimize=True)
    print("  posts/" + nome)


def main():
    logo = arte.logo(1.6)
    poster_vertical(logo)
    post_quadrado(logo)
    banner(logo)
    catalogo(logo)


if __name__ == "__main__":
    main()
