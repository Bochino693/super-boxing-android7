"""O projeto dos gabinetes do SUPER BOXING: desenho tecnico e lista de pecas.

    python tools/marketing/gerar_gabinetes.py

Saidas em marketing/gabinetes/:
  desenho_<modelo>.pdf / .png   frente e lado com as medidas (A3 deitado)
  texturas/saco.jpg             a estampa do saco (renders 3D)
As medidas vem de tools/marketing/medidas.py. Os renders 3D saem de
tools/marketing/gabinete3d (Godot) - ver marketing/LEIA-ME.md.

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

SAIDA = arte.RAIZ / "marketing" / "gabinetes"
F_TITULO = ImageFont.truetype(arte.BUNGEE, 64)
F_SUB = ImageFont.truetype(arte.SAIRA, 40)
F_COTA = ImageFont.truetype(arte.SAIRA, 30)
F_ROT = ImageFont.truetype(arte.SAIRA, 27)
F_LISTA = ImageFont.truetype(arte.SAIRA, 29)

TINTA = (25, 20, 45)
COTA = (200, 20, 120)
PECA = (60, 70, 200)
CINZA = (150, 150, 165)


# ------------------------------------------------------------- textura saco
def textura_saco() -> None:
    """Couro sintetico vermelho com o logo de frente (u = 0,25 e a frente)."""
    w, h = 2048, 1024
    rng = np.random.default_rng(4)
    base = np.zeros((h, w, 3), np.float32)
    base[:] = np.array((178, 14, 30), np.float32) / 255
    ruido = rng.normal(0, 1, (h // 4, w // 4)).astype(np.float32)
    ruido = np.array(Image.fromarray(((ruido * 18) + 128).clip(0, 255).astype(np.uint8)).resize((w, h), Image.BICUBIC),
                     np.float32) / 255 - 0.5
    base *= (1 + ruido[..., None] * 0.25)
    # costuras verticais
    for u in np.linspace(0, 1, 7)[:-1]:
        x = int(u * w)
        base[:, max(0, x - 2):x + 2] *= 0.55
    img = Image.fromarray((base.clip(0, 1) * 255).astype(np.uint8)).convert("RGBA")
    d = ImageDraw.Draw(img)
    # faixas brancas em cima e embaixo
    d.rectangle([0, int(h * 0.10), w, int(h * 0.14)], fill=(240, 240, 240, 255))
    d.rectangle([0, int(h * 0.86), w, int(h * 0.90)], fill=(240, 240, 240, 255))
    lg = arte.logo(1.2)
    arte.colar(img, lg, (int(w * 0.25), int(h * 0.5)), int(w * 0.24))
    arte.colar(img, lg, (int(w * 0.75), int(h * 0.5)), int(w * 0.24))
    (SAIDA / "texturas").mkdir(parents=True, exist_ok=True)
    img.convert("RGB").save(SAIDA / "texturas" / "saco.jpg", quality=90)
    print("  gabinetes/texturas/saco.jpg")


# ---------------------------------------------------------- desenho tecnico
class Folha:
    def __init__(self, w=4961, h=3508):   # A3 deitado em 300 dpi
        self.img = Image.new("RGB", (w, h), (255, 255, 255))
        self.d = ImageDraw.Draw(self.img)

    def texto(self, xy, t, f, cor=TINTA, ancora="la"):
        self.d.text(xy, t, font=f, fill=cor, anchor=ancora)


class Vista:
    """Uma vista: escala em px/cm, origem (chao, eixo) na folha."""

    def __init__(self, folha: Folha, ox: float, oy: float, escala: float):
        self.f, self.ox, self.oy, self.k = folha, ox, oy, escala

    def p(self, x, y):
        return (self.ox + x * self.k, self.oy - y * self.k)

    def poly(self, pts, fill=None, outline=TINTA, w=5):
        self.f.d.polygon([self.p(*q) for q in pts], fill=fill, outline=outline, width=w)

    def ret(self, x0, y0, x1, y1, fill=None, outline=TINTA, w=4):
        a, b = self.p(x0, y1), self.p(x1, y0)
        self.f.d.rectangle([a, b], fill=fill, outline=outline, width=w)

    def linha(self, a, b, cor=TINTA, w=3):
        self.f.d.line([self.p(*a), self.p(*b)], fill=cor, width=w)

    def elipse(self, cx, cy, rx, ry, fill=None, outline=TINTA, w=4):
        self.f.d.ellipse([self.p(cx - rx, cy + ry), self.p(cx + rx, cy - ry)], fill=fill, outline=outline, width=w)

    def cota_v(self, x, y0, y1, texto, lado=1):
        """Cota vertical em x (cm), de y0 a y1, texto ao lado."""
        a, b = self.p(x, y0), self.p(x, y1)
        d = self.f.d
        d.line([a, b], fill=COTA, width=3)
        for q in (a, b):
            d.line([(q[0] - 14, q[1]), (q[0] + 14, q[1])], fill=COTA, width=3)
        seta(d, a, b, COTA)
        seta(d, b, a, COTA)
        m = ((a[0] + b[0]) / 2 + 18 * lado, (a[1] + b[1]) / 2)
        self.f.texto(m, texto, F_COTA, COTA, "lm" if lado > 0 else "rm")

    def cota_h(self, y, x0, x1, texto, acima=True):
        a, b = self.p(x0, y), self.p(x1, y)
        d = self.f.d
        d.line([a, b], fill=COTA, width=3)
        for q in (a, b):
            d.line([(q[0], q[1] - 14), (q[0], q[1] + 14)], fill=COTA, width=3)
        seta(d, a, b, COTA)
        seta(d, b, a, COTA)
        m = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2 + (-16 if acima else 16))
        self.f.texto(m, texto, F_COTA, COTA, "md" if acima else "ma")

    def rotulo(self, alvo, texto, dx, dy, cor=PECA, x_abs=None):
        a = self.p(*alvo)
        b = (x_abs if x_abs is not None else a[0] + dx, a[1] + dy)
        dx = b[0] - a[0]
        self.f.d.line([a, b], fill=cor, width=2)
        self.f.d.ellipse([a[0] - 6, a[1] - 6, a[0] + 6, a[1] + 6], fill=cor)
        self.f.texto((b[0] + (8 if dx >= 0 else -8), b[1]), texto, F_ROT, cor, "lm" if dx >= 0 else "rm")


def seta(d, de, para, cor):
    ang = math.atan2(para[1] - de[1], para[0] - de[0])
    s = 16
    for da in (0.4, -0.4):
        d.line([para, (para[0] - math.cos(ang + da) * s, para[1] - math.sin(ang + da) * s)], fill=cor, width=3)


def desenho(modelo: str) -> None:
    m = medidas.MODELOS[modelo]
    f = Folha()
    W, H = m["W"], m["H"]
    k = 11.0 if modelo == "torre" else 12.0   # px por cm
    chao = 3150
    f.texto((120, 90), m["nome"], F_TITULO, (120, 20, 170))
    f.texto((120, 180), m["resumo"] + "  -  medidas em cm", F_SUB, TINTA)
    ch = m["chapa"]
    pe, co, tv, ca, ei, sc, le = m["pedestal"], m["comando"], m["tv"], m["capo"], m["eixo"], m["saco"], m["letreiro"]
    centro_saco = sc["topo"] - sc["altura"] / 2

    # ---------------- VISTA DE FRENTE
    fr = Vista(f, 700, chao, k)
    rx = 700 + (W + 12) * k + 230       # coluna dos rotulos da frente
    f.texto(fr.p(W / 2, H + 18), "FRENTE", F_SUB, TINTA, "md")
    fr.ret(0, 0, W, H, fill=(245, 243, 252))
    fr.ret(ch, 0, W - ch, pe["y1"], fill=(232, 228, 248))
    pc = m["porta_cofre"]
    fr.ret(W / 2 - pc["w"] / 2, pc["y0"], W / 2 + pc["w"] / 2, pc["y1"], outline=CINZA)
    so = m["som"]
    for s in (-1, 1):
        fr.elipse(W / 2 + s * so["dx"], so["y"], so["diam"] / 2, so["diam"] / 2, fill=(70, 70, 80))
    fr.ret(ch, co["y_frente"] - 1.5, W - ch, co["y_tras"], fill=(220, 214, 245))
    st = m["start"]
    fr.elipse(W / 2 + st["dx"], (co["y_frente"] + co["y_tras"]) / 2, st["diam"] / 2, 1.6, fill=(255, 200, 20))
    fr.ret(ch, co["y_tras"], W - ch, ca["y0"], fill=(235, 232, 250))
    tx0 = W / 2 - tv["ext_w"] / 2
    fr.ret(tx0, tv["y0"], tx0 + tv["ext_w"], tv["y0"] + tv["ext_h"], fill=(20, 20, 30))
    fr.ret(W / 2 - tv["vis_w"] / 2, tv["y0"] + (tv["ext_h"] - tv["vis_h"]) / 2, W / 2 + tv["vis_w"] / 2,
           tv["y0"] + (tv["ext_h"] + tv["vis_h"]) / 2, fill=(70, 40, 140), outline=(70, 40, 140))
    for s in (-1, 1):  # fitas de LED ao lado da TV
        x = W / 2 + s * (tv["vis_w"] / 2 + 5.0)
        fr.linha((x, tv["y0"] + 2), (x, tv["y0"] + tv["ext_h"] - 2), (255, 40, 170), 8)
    fr.ret(0, ca["y0"], W, H, fill=(60, 55, 80))
    fr.ret(ch, le["y0"], W - ch, le["y1"], fill=(255, 220, 60))
    fr.ret(W / 2 - 4.5, m["camera"]["y"] - 1.7, W / 2 + 4.5, m["camera"]["y"] + 1.7, fill=(30, 30, 40))
    fr.linha((W / 2, ca["y0"]), (W / 2, sc["topo"]), (150, 150, 160), 7)
    fr.elipse(W / 2, centro_saco, sc["diametro"] / 2, sc["altura"] / 2, fill=(210, 30, 50))
    # cotas
    fr.cota_h(H + 30, 0, W, f"{W:g}")
    fr.cota_h(-14, tx0, tx0 + tv["ext_w"], f"TV {tv['pol']}\" em pe: {tv['ext_w']:g} x {tv['ext_h']:g}", acima=False)
    fr.cota_v(-10, 0, H, f"{H:g}", -1)
    fr.cota_v(-26, 0, centro_saco, f"centro do saco {centro_saco:g}", -1)
    fr.cota_v(W + 10, 0, co["y_frente"], f"painel {co['y_frente']:g}")
    fr.cota_v(W + 10, co["y_frente"], tv["y0"], f"base da TV {tv['y0']:g}")
    fr.cota_v(W + 10, tv["y0"], tv["y0"] + tv["ext_h"], f"TV {tv['ext_h']:g}")
    fr.rotulo((W / 2, (le["y0"] + le["y1"]) / 2), "letreiro luminoso (frente do capo)", 0, -40, x_abs=rx)
    fr.rotulo((W / 2, m["camera"]["y"]), "camera USB (foto do ranking)", 0, -10, x_abs=rx)
    fr.rotulo((W / 2 + tv["vis_w"] / 2 + 5.0, tv["y0"] + tv["ext_h"] * 0.82), "fitas de LED WS2812B", 0, 0, x_abs=rx)
    fr.rotulo((W / 2, tv["y0"] + tv["ext_h"] * 0.92), f"TV {tv['pol']}\" + acrilico 4 mm na frente", 0, 0, x_abs=rx)
    fr.rotulo((W / 2 + sc["diametro"] / 2, centro_saco), "saco na frente da tela", 0, 0, x_abs=rx)
    fr.rotulo((W / 2 + st["dx"], (co["y_frente"] + co["y_tras"]) / 2), "painel: START e credito", 0, 20, x_abs=rx)
    fr.rotulo((W / 2 + so["dx"], so["y"]), "alto-falantes", 0, 0, x_abs=rx)
    fr.rotulo((W / 2 + pc["w"] / 2, (pc["y0"] + pc["y1"]) / 2), "porta do cofre / eletronica", 0, 20, x_abs=rx)

    # ---------------- VISTA DE LADO
    xmax = max(x for x, _ in medidas.perfil(modelo))
    la = Vista(f, rx + 560, chao, k)
    f.texto(la.p(xmax / 2, H + 18), "LADO (frente para a direita)", F_SUB, TINTA, "md")
    la.poly(medidas.perfil(modelo), fill=(240, 236, 252), w=6)
    la.ret(0.5, 0.5, pe["x1"] - 1, pe["y1"] - 0.5, outline=CINZA)
    la.ret(0, ca["y0"], ca["x1"], ca["y1"], fill=(70, 65, 95), outline=TINTA, w=3)
    la.ret(ca["x1"] - 1.5, le["y0"], ca["x1"], le["y1"], fill=(255, 220, 60), outline=None)
    tvx = tv["x"]
    la.ret(tvx - 9, tv["y0"], tvx, tv["y0"] + tv["ext_h"], fill=(20, 20, 30))
    la.ret(tvx, co["y_tras"], tvx + 0.6, ca["y0"], fill=(120, 190, 255), outline=None)
    la.elipse(ei["x"], ei["y"], 1.6, 1.6, fill=(255, 255, 255), w=3)
    la.linha((ei["x"], ei["y"]), (ei["x"], sc["topo"]), (90, 90, 100), 7)
    la.elipse(ei["x"], centro_saco, sc["diametro"] / 2, sc["altura"] / 2, fill=(210, 30, 50))
    # saco guardado (braco na horizontal, para a frente) em tracejado
    comp = ei["y"] - centro_saco
    gx = ei["x"] + comp
    a, b = la.p(gx - sc["altura"] / 2, ei["y"] + sc["diametro"] / 2), la.p(gx + sc["altura"] / 2, ei["y"] - sc["diametro"] / 2)
    for i in range(0, 360, 20):
        f.d.arc([a, b], i, i + 10, fill=(210, 30, 50), width=4)
    # o balanco do soco ate o batente: o saco para a 5 cm do acrilico
    folga = (ei["x"] - sc["diametro"] / 2) - (tv["x"] + 1.0) - 5.0
    ang = math.asin(max(0.0, min(1.0, folga / comp)))
    bx, by = ei["x"] - math.sin(ang) * comp, ei["y"] - math.cos(ang) * comp
    a2, b2 = la.p(bx - sc["diametro"] / 2, by + sc["altura"] / 2), la.p(bx + sc["diametro"] / 2, by - sc["altura"] / 2)
    for i in range(0, 360, 24):
        f.d.arc([a2, b2], i, i + 12, fill=(150, 150, 160), width=3)
    # motor e sensor dentro do capo
    mx = ca["x1"] * 0.35
    la.ret(mx - 7, ca["y0"] + 3, mx + 7, ca["y1"] - 3, fill=(170, 120, 255))
    la.linha((mx + 7, (ca["y0"] + ca["y1"]) / 2), (ei["x"], ei["y"]), (170, 120, 255), 3)
    la.ret(ei["x"] - 10, ei["y"] - 1, ei["x"] - 6, ei["y"] + 3, fill=(255, 200, 20))
    la.ret(ca["x1"] - 9, m["camera"]["y"] - 1.7, ca["x1"] - 2, m["camera"]["y"] + 1.7, fill=(30, 30, 40))
    # cotas
    la.cota_h(-14, 0, xmax, f"profundidade {xmax:g}", acima=False)
    la.cota_h(H + 30, 0, ca["x1"], f"capo {ca['x1']:g}")
    la.cota_h(pe["y1"] * 0.5, 0, pe["x1"], f"pedestal {pe['x1']:g}")
    la.cota_h(tv["y0"] - 5, tvx, ei["x"], f"{ei['x'] - tvx:g} da tela ao saco")
    la.cota_v(-10, 0, H, f"{H:g}", -1)
    la.cota_v(xmax + 8, sc["topo"] - sc["altura"], sc["topo"], f"saco {sc['diametro']:g} x {sc['altura']:g}")
    la.rotulo((ei["x"], ei["y"]), "eixo do braco", 40, -250)
    la.rotulo((mx, (ca["y0"] + ca["y1"]) / 2), "motor + corrente/correia", -20, -230)
    la.rotulo((ei["x"] - 8, ei["y"] + 1), "sensor de feixe + palheta", -160, -300)
    la.rotulo((gx, ei["y"]), "saco guardado (sobe para a frente)", 40, -40, (210, 30, 50))
    la.rotulo((bx, by - sc["altura"] / 2), f"batente: o saco volta no maximo {math.degrees(ang):.0f} graus", 30, 330, (120, 120, 140))
    la.rotulo((tvx, tv["y0"] + tv["ext_h"] * 0.4), "acrilico de protecao", -40, 0)
    la.rotulo((pe["x1"] / 2, 40), "TV Box, Arduino, ponte H, fontes", 40, 160)

    # ---------------- LISTA
    lx = 4120
    linhas = lista(modelo)
    y = 1300
    f.texto((lx, y), "PECAS E MATERIAIS", F_SUB, (120, 20, 170))
    y += 70
    for l in linhas:
        cor = (120, 20, 170) if l.isupper() else TINTA
        f.texto((lx, y), l, F_LISTA, cor)
        y += 44 if l.isupper() else 40
    f.texto((120, 3400), "Medidas de referencia (MDF): confira a TV e as pecas compradas antes de cortar. O capo avanca "
            "sobre o jogador: lastro no pedestal e fixacao na parede ou no piso.", F_ROT, (90, 90, 110))
    SAIDA.mkdir(parents=True, exist_ok=True)
    f.img.save(SAIDA / f"desenho_{modelo}.png", optimize=True)
    f.img.save(SAIDA / f"desenho_{modelo}.pdf", "PDF", resolution=300.0, quality=92)
    print(f"  gabinetes/desenho_{modelo}.pdf")


def lista(modelo: str) -> list[str]:
    m = medidas.MODELOS[modelo]
    tv = m["tv"]
    return [
        "ESTRUTURA",
        f"- laterais em MDF {m['chapa'] * 10:.0f} mm, perfil recortado (2)",
        "- frentes, tampos e fundo em MDF 15 mm",
        "- contorno das laterais: perfil de aluminio",
        "  com difusor + fita de LED RGB",
        "- acabamento PRETO BRILHO (adesivo laminado",
        "  ou pintura automotiva + verniz)",
        "- capo: MDF + cantoneiras de aco (leva o braco)",
        "- acrilico cristal 4 mm na frente da TV",
        "- lastro de 30 kg no pedestal",
        "- 4 pes niveladores + 2 cantoneiras p/ fixar",
        "MECANICA DO SACO (docs/MONTAGEM_3)",
        f"- saco de couro sintetico {m['saco']['diametro']:g} x {m['saco']['altura']:g} cm",
        "- braco de aco + eixo com 2 mancais",
        "- motor com reducao + corrente/correia",
        "- ponte H BTS7960 (IBT-2) + fonte do motor",
        "- sensor de feixe (fenda) + palheta de 20 mm",
        "- batente com borracha (limita o balanco)",
        "ELETRONICA (a do jogo)",
        f"- TV {tv['pol']}\" (em pe) + TV Box Mali-450 (TX9)",
        "- Arduino Nano/Uno com o firmware do jogo",
        "- botao START 60 mm iluminado",
        "- moedeiro/noteiro (credito) e botao CONFIG",
        "- webcam USB (foto do ranking, opcional)",
        "- 2 fitas WS2812B (lados da TV) + fonte 5 V",
        "- LED RGB: contorno, rodape, anel dos falantes",
        "- hub USB alimentado",
        "- 2 alto-falantes 4\" + amplificador",
        "- letreiro: acrilico leitoso + LED branco",
        "ADESIVOS (marketing/adesivos)",
        "- laterais E/D, frente, painel,",
        "  moldura da TV, letreiro",
        "- como jogar, aviso, piso, logos",
    ]


def main() -> None:
    textura_saco()
    for modelo in medidas.MODELOS:
        desenho(modelo)


if __name__ == "__main__":
    main()
