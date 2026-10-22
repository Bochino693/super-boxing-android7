"""As imagens da interface que o jogo desenha por TEXTURA (assets/ui/).

    python tools/gerar_icones.py

Na TV Box, montar uma forma no script (pontos, triângulos, borda lisa) a
cada quadro custa dezenas de microssegundos por peça; uma textura — e as
placas em "nove pedaços", que esticam o meio e guardam os cantos — custa
um ou dois, e a placa de vídeo junta tudo no mesmo desenho. Ver
`scripts/formas.gd`. Tudo é branco: o jogo tinge com a cor pedida.

LUVA

A forma é a mesma de `Icones._massa_da_luva` (scripts/icones.gd): a união de
dois círculos e duas caixas redondas, com o contorno saindo das mesmas
formas dilatadas. Desenhada 8x maior e reduzida, para a borda sair lisa.

  luva_corpo.png   branco no corpo, cinza 55% no contorno: o jogo tinge
                   com a cor pedida (o contorno fica a cor escurecida 45%)
  luva_brilho.png  os dois riscos brancos, desenhados por cima sem tinta
"""
from pathlib import Path

from PIL import Image, ImageDraw

RAIZ = Path(__file__).resolve().parent.parent
LADO = 128          # pixels da imagem final; o raio da luva é LADO / 2
SUPER = 8


def massa(d, r, folga, cor, c):
    def pt(x, y):
        return (c + x * r, c + y * r)

    for (x, y), raio in (((0.10, -0.26), 0.64), ((-0.58, 0.02), 0.30)):
        cx, cy = pt(x, y)
        rr = raio * r + folga
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=cor)
    for (x, y), (w, h) in (((-0.54, -0.30), (1.12, 0.56)), ((-0.30, 0.24), (0.80, 0.60))):
        x0, y0 = pt(x, y)
        d.rounded_rectangle([x0 - folga, y0 - folga, x0 + w * r + folga, y0 + h * r + folga],
                            radius=0.16 * r, fill=cor)


def traco(d, r, c, a, b, largura):
    (ax, ay), (bx, by) = a, b
    d.line([(c + ax * r, c + ay * r), (c + bx * r, c + by * r)], fill=255, width=int(round(largura * r)))


def _reduzir(img, lado):
    return img.resize(lado, Image.BOX)


def placa(raio, largura=None):
    """Retângulo de cantos redondos (raio em px) para nove pedaços: os cantos
    ocupam `raio` px e o meio tem 2 px. Com `largura`, só a moldura."""
    lado = 2 * raio + 2
    n = lado * SUPER
    a = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(a)
    d.rounded_rectangle([0, 0, n - 1, n - 1], radius=raio * SUPER, fill=255)
    if largura is not None:
        w = int(round(largura * SUPER))
        d.rounded_rectangle([w, w, n - 1 - w, n - 1 - w], radius=max(0, (raio - largura) * SUPER), fill=0)
    a = _reduzir(a, (lado, lado))
    branco = Image.new("L", (lado, lado), 255)
    return Image.merge("RGBA", (branco, branco, branco, a))


def disco(raio, largura=None, abertura=None):
    """Disco (ou anel de `largura`, ou arco de `abertura` radianos a partir
    do ângulo 0, no sentido horário da tela) de `raio` px, com 2 px de folga."""
    import math
    fora = raio + (largura / 2.0 if abertura is not None else 0.0)
    lado = int(math.ceil(fora)) * 2 + 4
    n = lado * SUPER
    c = n / 2.0
    a = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(a)
    r = raio * SUPER
    if abertura is None:
        d.ellipse([c - r, c - r, c + r, c + r], fill=255)
        if largura is not None:
            ri = (raio - largura) * SUPER
            d.ellipse([c - ri, c - ri, c + ri, c + ri], fill=0)
    else:
        meia = largura * SUPER / 2.0
        ro, ri = r + meia, r - meia
        d.pieslice([c - ro, c - ro, c + ro, c + ro], 0, math.degrees(abertura), fill=255)
        d.ellipse([c - ri, c - ri, c + ri, c + ri], fill=0)
        # pontas retas, como o arco do lote
    a = _reduzir(a, (lado, lado))
    branco = Image.new("L", (lado, lado), 255)
    return Image.merge("RGBA", (branco, branco, branco, a))


def avatar(parte):
    """O boneco de quem não tem foto (`main._draw_avatar`), para a medida da
    linha do TOP 20 (140 px), desenhado em 256 px: `traco` é a cabeça e os
    ombros; `cantos`, as cantoneiras de visor (4 px na medida de 140)."""
    import math
    lado = 256
    n = lado * SUPER
    u = float(n)
    c = n / 2.0
    a = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(a)
    if parte == "traco":
        e = 0.035 * u
        cx, cy, r = c, c - 0.10 * u, 0.13 * u
        d.ellipse([cx - r - e / 2, cy - r - e / 2, cx + r + e / 2, cy + r + e / 2], fill=255)
        d.ellipse([cx - r + e / 2, cy - r + e / 2, cx + r - e / 2, cy + r - e / 2], fill=0)
        cx, cy, r = c, c + 0.30 * u, 0.25 * u
        ro, ri = r + e / 2, r - e / 2
        d.pieslice([cx - ro, cy - ro, cx + ro, cy + ro], 180 * 1.08, 180 * 1.92, fill=255)
        d.ellipse([cx - ri, cy - ri, cx + ri, cy + ri], fill=0)
    else:
        w = 4.0 / 140.0 * u
        m, b = 0.10 * u, 0.14 * u
        for sx in (-1, 1):
            for sy in (-1, 1):
                x = c + sx * (u / 2 - m)
                y = c + sy * (u / 2 - m)
                d.rectangle(sorted([x - sx * b, x])[:1] + [y - w / 2] + sorted([x - sx * b, x])[1:] + [y + w / 2], fill=255)
                d.rectangle([x - w / 2] + sorted([y - sy * b, y])[:1] + [x + w / 2] + sorted([y - sy * b, y])[1:], fill=255)
    a = _reduzir(a, (lado, lado))
    branco = Image.new("L", (lado, lado), 255)
    return Image.merge("RGBA", (branco, branco, branco, a))


FORMAS = {
    "avatar_traco": (avatar, ("traco",)),
    "avatar_cantos": (avatar, ("cantos",)),
    # placas (`Formas.placa`): os raios que a tela usa
    **{"placa_r%d" % r: (placa, (r,)) for r in (10, 12, 16, 17, 19, 22)},
    # o cartão do soco: a pílula (raio 84), o brilho em volta (94) e a borda
    "pilula_r84": (placa, (84,)),
    "pilula_r94": (placa, (94,)),
    "pilula_borda_r84_w4": (placa, (84, 4.0)),
    "pilula_borda_r84_w2": (placa, (84, 2.5)),
    # o anel do cartão: o halo (raio 70), o trilho (62, 9 px) e o arco que
    # gira chamando o soco (62, 8 px, 2,2 rad)
    "cartao_halo": (disco, (70.0,)),
    "cartao_trilho": (disco, (66.5, 9.0)),
    "cartao_giro": (disco, (62.0, 8.0, 2.2)),
    # o medidor redondo do impacto: os dois arcos que giram lendo o sensor
    # (raios 160 e 118) e o aro do vidro (170, 3 px)
    "medidor_giro_fora": (disco, (160.0, 5.0, 1.4)),
    "medidor_giro_dentro": (disco, (118.0, 4.0, 0.9)),
    "medidor_aro": (disco, (171.5, 3.0)),
    # um disco liso para qualquer raio (512 px, potência de 2, com mipmaps:
    # serve das faíscas de 2 px aos círculos de 300)
    "disco": (disco, (254.0,)),
}


def main():
    pasta = RAIZ / "assets" / "ui"
    pasta.mkdir(parents=True, exist_ok=True)
    for nome, (f, args) in FORMAS.items():
        f(*args).save(pasta / (nome + ".png"), optimize=True)
    n = LADO * SUPER
    r = n / 2.0 * 0.98
    c = n / 2.0
    # corpo: alfa = união das formas dilatadas; cor = 55% no contorno, 100% no corpo
    alfa = Image.new("L", (n, n), 0)
    massa(ImageDraw.Draw(alfa), r, r * 0.10, 255, c)
    tom = Image.new("L", (n, n), 140)
    massa(ImageDraw.Draw(tom), r, 0.0, 255, c)
    corpo = Image.merge("RGBA", (tom, tom, tom, alfa)).resize((LADO, LADO), Image.LANCZOS)
    brilho_a = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(brilho_a)
    traco(d, r, c, (-0.24, -0.22), (0.58, -0.26), 0.11)
    traco(d, r, c, (-0.20, 0.42), (0.38, 0.42), 0.12)
    brilho_a = brilho_a.point(lambda v: int(v * 0.92))
    branco = Image.new("L", (n, n), 255)
    brilho = Image.merge("RGBA", (branco, branco, branco, brilho_a)).resize((LADO, LADO), Image.LANCZOS)
    pasta = RAIZ / "assets" / "ui"
    pasta.mkdir(parents=True, exist_ok=True)
    corpo.save(pasta / "luva_corpo.png", optimize=True)
    brilho.save(pasta / "luva_brilho.png", optimize=True)
    print("ok", pasta)


if __name__ == "__main__":
    main()
