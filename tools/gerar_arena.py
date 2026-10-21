"""Gera as texturas da arena 3D (assets/arena/*.png).

Tudo e procedural e reproduzivel: rode de novo para regenerar.
    python3 tools/gerar_arena.py

Requer: pillow, numpy, scipy.
As texturas saem prontas (luz ja "assada"), porque na TV Box a arena usa
materiais sem iluminacao: um desenho por superficie, custo quase zero.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage as nd

RAIZ = Path(__file__).resolve().parents[1]
SAIDA = RAIZ / "assets" / "arena"
FONTE = str(RAIZ / "assets" / "fonts" / "Bungee-Regular.ttf")
FONTE_TEXTO = str(RAIZ / "assets" / "fonts" / "SairaCondensed-ExtraBold.ttf")
rng = np.random.default_rng(20260923)


def hexcor(h: str) -> np.ndarray:
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


def salvar(arr: np.ndarray, nome: str) -> None:
    arr = np.clip(arr, 0.0, 1.0)
    modo = "RGBA" if arr.shape[2] == 4 else "RGB"
    Image.fromarray((arr * 255.0 + 0.5).astype(np.uint8), modo).save(SAIDA / nome, optimize=True)
    print("ok", nome, arr.shape[1], "x", arr.shape[0])


def blur(arr: np.ndarray, sigma: float) -> np.ndarray:
    if arr.ndim == 2:
        return nd.gaussian_filter(arr, sigma)
    return np.stack([nd.gaussian_filter(arr[..., c], sigma) for c in range(arr.shape[2])], -1)


def disco_macio(h, w, cy, cx, r, dureza=2.0):
    y, x = np.ogrid[:h, :w]
    d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / max(r, 1e-3)
    return np.clip(1.0 - d, 0.0, 1.0) ** dureza


# --------------------------------------------------------------- o fundo
def fundo() -> None:
    """Arquibancada no escuro: plateia desfocada, luzes e telao de LED."""
    W, H = 1024, 768
    y = np.linspace(0.0, 1.0, H)[:, None]
    img = np.zeros((H, W, 3), np.float32)
    topo, base = hexcor("06051a"), hexcor("1c0a3a")
    img[:] = topo * (1 - y[..., None]) + base * y[..., None]

    # Neblina colorida: magenta a esquerda, ciano a direita (as luzes de contorno).
    img += disco_macio(H, W, H * 0.62, W * 0.12, W * 0.55, 1.6)[..., None] * hexcor("5a0b5a") * 0.55
    img += disco_macio(H, W, H * 0.58, W * 0.90, W * 0.50, 1.6)[..., None] * hexcor("0b3a52") * 0.55

    # A ARQUIBANCADA ALTA: gente de verdade, pequena e fora de foco —
    # camisas coloridas, rostos e braços, e não manchas escuras. As
    # fileiras de trás são menores, mais desfocadas e mais apagadas pela
    # névoa do ginásio; cada fileira tem o degrau de concreto embaixo.
    camisas = [hexcor(c) for c in ("d61e30", "1e4cc8", "fac81e", "c4c4cc", "1a1a1e", "14965a",
                                   "f06e14", "8232be", "00aac8", "c8288c", "5a606e")]
    peles = [hexcor(c) for c in ("ffd6aa", "eebe8c", "dea870", "c48858", "a0663e", "784c2e", "58382a")]
    # (pequenas de propósito: estão atrás da torcida pintada da arena, e
    # gente maior no fundo do que na frente quebrava a perspectiva)
    # Os degraus ficam colados (a cabeça de uma fileira encosta no peito
    # da de cima), como numa arquibancada cheia.
    fileiras = []
    y0, tam = 0.31, 4.2
    while y0 < 0.68:
        k = (y0 - 0.31) / 0.37
        fileiras.append((y0, tam, 1.2 - 0.4 * k, 0.09 + 0.10 * k))
        y0 += tam * 2.05 / H
        tam *= 1.07
    for fila, (y0, tam, sig, luz) in enumerate(fileiras):
        cam = Image.new("RGB", (W, H), (0, 0, 0))
        msk = Image.new("L", (W, H), 0)
        dc, dm = ImageDraw.Draw(cam), ImageDraw.Draw(msk)
        x = -tam
        while x < W + tam:
            cx = x + rng.uniform(-tam * 0.2, tam * 0.2)
            cy = H * y0 + rng.uniform(-tam * 0.25, tam * 0.25)
            camisa = tuple(int(v * 255) for v in camisas[rng.integers(len(camisas))])
            pele = tuple(int(v * 255) for v in peles[rng.integers(len(peles))])
            if rng.random() < 0.35:  # braço para o alto
                lado = rng.choice([-1, 1])
                dc.line([cx + lado * tam * 0.7, cy, cx + lado * tam * 0.9, cy - tam * 1.9], fill=pele, width=max(2, int(tam * 0.45)))
                dm.line([cx + lado * tam * 0.7, cy, cx + lado * tam * 0.9, cy - tam * 1.9], fill=255, width=max(2, int(tam * 0.45)))
            for d, cor in ((dc, camisa), (dm, 255)):
                d.rounded_rectangle([cx - tam * 0.95, cy - tam * 0.35, cx + tam * 0.95, cy + tam * 2.6], radius=tam * 0.6, fill=cor)
            for d, cor in ((dc, pele), (dm, 255)):
                d.ellipse([cx - tam * 0.42, cy - tam * 1.05, cx + tam * 0.42, cy - tam * 0.2], fill=cor)
            x += tam * rng.uniform(1.75, 2.05)
        m = blur(np.asarray(msk, np.float32) / 255.0, sig)
        c = blur(np.asarray(cam, np.float32) / 255.0, sig)
        # degrau de concreto da fileira
        degrau = np.zeros((H, W), np.float32)
        ya = int(H * y0 + tam * 2.2)
        degrau[ya:ya + 2] = 1.0
        contorno = np.clip(m - np.roll(m, 3, axis=0), 0, 1)
        tom = hexcor("100a20")
        cor = c * luz + tom * (1.0 - luz)
        img = img * (1 - m[..., None] * 0.95) + cor * m[..., None] * 0.95
        img += degrau[..., None] * hexcor("2a2040") * 0.4
        img += contorno[..., None] * (hexcor("ff3ab4") * 0.5 + hexcor("45d8ff") * 0.5) * luz * 0.5

    # Luzes de palco desfocadas (bokeh): celulares, placas, refletores.
    paleta = [hexcor(c) for c in ("ffd35a", "ff3bb0", "46dcff", "ffffff", "9a5cff")]
    camada = np.zeros_like(img)
    for _ in range(170):
        cx, cy = rng.uniform(0, W), rng.uniform(H * 0.12, H * 0.80)
        r = rng.uniform(2.0, 9.0) * (0.6 + cy / H)
        cor = paleta[rng.integers(len(paleta))]
        forca = rng.uniform(0.15, 0.55)
        x0, x1 = int(max(cx - r - 2, 0)), int(min(cx + r + 3, W))
        y0, y1 = int(max(cy - r - 2, 0)), int(min(cy + r + 3, H))
        if x1 <= x0 or y1 <= y0:
            continue
        sub = disco_macio(y1 - y0, x1 - x0, cy - y0, cx - x0, r, 0.6)
        camada[y0:y1, x0:x1] += sub[..., None] * cor * forca
    img += blur(camada, 1.2)

    # Fachos de luz vindos do teto, bem sutis (os fachos animados sao outra malha).
    fachos = np.zeros((H, W), np.float32)
    yy, xx = np.mgrid[:H, :W].astype(np.float32)
    for ox, ang in ((0.18, 0.20), (0.40, 0.06), (0.62, -0.08), (0.84, -0.22)):
        dx = xx - (W * ox + (yy * np.tan(ang)))
        largura = 18 + yy * 0.10
        fachos += np.exp(-(dx / largura) ** 2) * (1 - yy / H) ** 1.5
    img += fachos[..., None] * hexcor("9fb8ff") * 0.07

    # O telao de LED sobre a plateia: faixa escura com letreiro vermelho/ouro.
    faixa_y0, faixa_y1 = int(H * 0.18), int(H * 0.27)
    img[faixa_y0:faixa_y1] = img[faixa_y0:faixa_y1] * 0.25 + hexcor("07041a") * 0.75
    texto = Image.new("L", (W, faixa_y1 - faixa_y0), 0)
    dt = ImageDraw.Draw(texto)
    fonte = ImageFont.truetype(FONTE, int((faixa_y1 - faixa_y0) * 0.62))
    frase = "SUPER BOXING  •  FIGHT!  •  NEVER GIVE UP!  •  SUPER BOXING  •  LAZER SPORT  •  "
    dt.text((-40, (faixa_y1 - faixa_y0) * 0.14), frase, font=fonte, fill=255)
    t = np.asarray(texto, np.float32) / 255.0
    # Pontos de LED: a letra acesa em grade, com brilho em volta.
    grade = ((np.arange(t.shape[0])[:, None] % 3) < 2) & ((np.arange(t.shape[1])[None, :] % 3) < 2)
    led = t * grade
    brilho = blur(t, 3.0)
    cor_led = np.where((np.arange(W)[None, :] // 260) % 2 == 0, 1.0, 0.0)[..., None]
    cor = hexcor("ff2ab0") * cor_led + hexcor("ffd014") * (1 - cor_led)
    img[faixa_y0:faixa_y1] += led[..., None] * cor * 0.95 + brilho[..., None] * cor * 0.35
    img[faixa_y0:faixa_y0 + 2] += hexcor("ff2ab0") * 0.35
    img[faixa_y1 - 2:faixa_y1] += hexcor("ff2ab0") * 0.35

    # Vinheta: segura o olho no centro, onde o lutador fica.
    v = disco_macio(H, W, H * 0.55, W * 0.5, W * 0.95, 0.9)
    img *= (0.45 + 0.55 * v)[..., None]
    # Grao leve: sem ele o degrade vira faixas no video da TV.
    img += rng.normal(0, 0.006, img.shape).astype(np.float32)
    salvar(img, "fundo.png")


# ---------------------------------------------------------------- a lona
def lona() -> None:
    """Lona do ringue vista de cima, com o emblema no centro e a luz do refletor."""
    N = 1024
    img = np.zeros((N, N, 3), np.float32)
    img[:] = hexcor("24155a")
    # Trama do tecido: ruido fino direcional.
    trama = rng.normal(0, 1, (N, N)).astype(np.float32)
    trama = nd.gaussian_filter(trama, (0.6, 2.2)) * 0.5 + nd.gaussian_filter(trama, (2.2, 0.6)) * 0.5
    img += trama[..., None] * 0.018
    # Manchas de uso: leves, grandes.
    uso = nd.gaussian_filter(rng.normal(0, 1, (N, N)).astype(np.float32), 40)
    img *= (1 + uso * 1.8)[..., None]

    # Faixa das cordas (borda) mais escura, com fio vermelho e fio ouro.
    b = int(N * 0.045)
    img[:b] *= 0.55
    img[-b:] *= 0.55
    img[:, :b] *= 0.55
    img[:, -b:] *= 0.55
    for off, cor in ((b, "ff2ab0"), (b + 10, "ffd014")):
        img[off:off + 4, off:N - off] = hexcor(cor)
        img[N - off - 4:N - off, off:N - off] = hexcor(cor)
        img[off:N - off, off:off + 4] = hexcor(cor)
        img[off:N - off, N - off - 4:N - off] = hexcor(cor)

    # Cantos: triangulos vermelho e azul (canto do desafiante e do campeao).
    yy, xx = np.mgrid[:N, :N].astype(np.float32)
    for (cx, cy, cor) in ((0, N, "b3122a"), (N, N, "1d4fb8"), (0, 0, "1d4fb8"), (N, 0, "b3122a")):
        d = np.abs(xx - cx) + np.abs(yy - cy)
        m = np.clip((N * 0.2 - d) / 3.0, 0, 1)
        img = img * (1 - m[..., None] * 0.8) + hexcor(cor) * m[..., None] * 0.8

    # Emblema central: anel duplo e o LOGO SUPER BOXING (o mesmo do
    # gabinete, de tools/gerar_tema.py), já no plano do chão.
    em = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(em)
    c = N / 2
    for r, w, cor in ((350, 16, (255, 42, 176, 235)), (322, 5, (255, 208, 20, 230))):
        d.ellipse([c - r, c - r, c + r, c + r], outline=cor, width=w)
    # O LOGO FICA ATRÁS DOS PÉS e esticado na profundidade. A câmera vê
    # a lona quase de lado: no centro exato ele ficava debaixo das botas
    # e achatado pela perspectiva. Esticado 1,5x no sentido da câmera
    # (como as marcas pintadas em campo de futebol) e recuado, ele se lê
    # inteiro atrás do lutador, entre as pernas e as cordas.
    logo = Image.open(RAIZ / "assets" / "tema" / "logo.png").convert("RGBA")
    lw = 700
    lh = int(logo.height * lw / logo.width * 1.35)
    logo = logo.resize((lw, lh), Image.LANCZOS)
    # NO MEIO DO RINGUE, como nas lonas de verdade: o lutador luta em cima
    # da marca.
    em.alpha_composite(logo, (int(c - lw / 2), int(c - lh / 2)))
    ema = np.asarray(em, np.float32) / 255.0
    # Tinta sobre tecido: um pouco gasta, nunca adesivo chapado.
    gasto = np.clip(1.0 - np.abs(nd.gaussian_filter(rng.normal(0, 1, (N, N)), 3)) * 0.6, 0.55, 1.0)
    a = ema[..., 3:4] * gasto[..., None]
    img = img * (1 - a) + ema[..., :3] * a

    # O refletor: poca de luz em cima do centro, queda suave para as bordas.
    luz = disco_macio(N, N, N * 0.5, N * 0.5, N * 0.62, 1.4)
    img *= (0.55 + 0.75 * luz)[..., None]
    img += rng.normal(0, 0.005, img.shape).astype(np.float32)
    salvar(img, "lona.png")


# ------------------------------------------------------ a saia do ringue
def saia() -> None:
    """A SAIA DO RINGUE: o painel de LED na frente do tablado.

    Sem ela, quando a câmera desce (nocaute, jogador no chão) aparecia
    embaixo do quadro a lateral lisa do tablado — uma faixa cinza sem
    desenho. Agora é um letreiro de LED que rola (o shader anda o `u`).
    """
    W, H = 2048, 192
    img = np.zeros((H, W, 3), np.float32)
    img[:] = hexcor("0a0616")
    texto = Image.new("L", (W, H), 0)
    dt = ImageDraw.Draw(texto)
    fonte = ImageFont.truetype(FONTE, int(H * 0.46))
    frase = "SUPER BOXING  •  PUNCH CHALLENGE  •  LAZER SPORT  •  "
    x = 0
    while x < W:
        dt.text((x, H * 0.24), frase, font=fonte, fill=255)
        x += int(dt.textlength(frase, font=fonte))
    t = np.asarray(texto, np.float32) / 255.0
    grade = ((np.arange(H)[:, None] % 4) < 3) & ((np.arange(W)[None, :] % 4) < 3)
    led = t * grade
    brilho = blur(t, 4.0)
    faixa = np.where((np.arange(W)[None, :] // 512) % 2 == 0, 1.0, 0.0)[..., None]
    cor = hexcor("ff2ab0") * faixa + hexcor("ffd014") * (1 - faixa)
    img += led[..., None] * cor * 0.95 + brilho[..., None] * cor * 0.30
    # frisos de cima e de baixo, e a quina acesa do tablado
    img[:6] = hexcor("ff2ab0") * 0.9
    img[6:10] = hexcor("ffd014") * 0.7
    img[-5:] = hexcor("46dcff") * 0.5
    img += rng.normal(0, 0.006, img.shape).astype(np.float32)
    salvar(img, "saia.png")


# ---------------------------------------------------------- sprites de luz
def brilho() -> None:
    """Estrela de flash: nucleo, halo e quatro raios. Aditivo, fundo preto."""
    N = 128
    yy, xx = np.mgrid[:N, :N].astype(np.float32)
    dx, dy = (xx - N / 2 + 0.5) / (N / 2), (yy - N / 2 + 0.5) / (N / 2)
    r = np.sqrt(dx * dx + dy * dy)
    nucleo = np.exp(-(r / 0.10) ** 2)
    halo = np.exp(-(r / 0.38) ** 2) * 0.35
    raios = (np.exp(-(dy / 0.025) ** 2) * np.clip(1 - np.abs(dx), 0, 1) ** 3
             + np.exp(-(dx / 0.025) ** 2) * np.clip(1 - np.abs(dy), 0, 1) ** 3) * 0.7
    a = np.clip(nucleo + halo + raios, 0, 1)
    img = np.dstack([a, a, a, a])
    salvar(img, "brilho.png")


def facho() -> None:
    """Facho de luz vertical (cone visto de frente), aditivo."""
    W, H = 128, 512
    yy, xx = np.mgrid[:H, :W].astype(np.float32)
    v = yy / H
    largura = 0.10 + v * 0.40
    dx = (xx - W / 2 + 0.5) / (W / 2)
    a = np.exp(-(dx / largura) ** 2) * (1 - v) ** 0.8 * np.clip(v * 8, 0, 1)
    a *= 0.9 + 0.1 * np.sin(yy * 0.05)
    img = np.dstack([a, a, a, a])
    salvar(img, "facho.png")


if __name__ == "__main__":
    SAIDA.mkdir(parents=True, exist_ok=True)
    fundo()
    lona()
    saia()
    brilho()
    facho()
