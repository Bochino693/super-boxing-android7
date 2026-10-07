# MONTAGEM_0: a ligação completa do motor do saco (firmware V9)
W, H = 2200, 2420
s = []; a = s.append
VERM, PRETO, ROXO, LILAS, AZUL, ROSA = "#d1242f", "#24292f", "#a333c8", "#8250df", "#0969da", "#bf3989"
def esc(x): return x.replace("&", "&amp;").replace("<", "&lt;")
def t(x, y, txt, tam=17, cor="#1f2328", peso="normal", anc="start"):
    a(f'<text x="{x}" y="{y}" font-size="{tam}" fill="{cor}" font-weight="{peso}" text-anchor="{anc}">{esc(txt)}</text>')
def fio(pts, cor, larg=5, trac=False):
    d = "M" + " L".join(f"{p[0]},{p[1]}" for p in pts)
    tr = ' stroke-dasharray="14 8"' if trac else ''
    a(f'<path d="{d}" fill="none" stroke="{cor}" stroke-width="{larg}" stroke-linejoin="round" stroke-linecap="round"{tr}/>')
def caixa(x, y, w, h, fundo="#f6f8fa", borda="#8c959f", r=12, larg=3):
    a(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fundo}" stroke="{borda}" stroke-width="{larg}"/>')
def bandeira(x, y, txt, cor, lado=-1):
    """Etiqueta de ligação (5V/GND): fio curto + plaquinha. lado=-1 para a esquerda."""
    w = 26 + len(txt) * 10.2
    x2 = x + lado * 34
    fio([(x, y), (x2, y)], cor, 4)
    if lado < 0:
        pts = f"{x2},{y} {x2-14},{y-16} {x2-14-w},{y-16} {x2-14-w},{y+16} {x2-14},{y+16}"
        tx = x2 - 14 - w / 2
    else:
        pts = f"{x2},{y} {x2+14},{y-16} {x2+14+w},{y-16} {x2+14+w},{y+16} {x2+14},{y+16}"
        tx = x2 + 14 + w / 2
    a(f'<polygon points="{pts}" fill="{cor}"/>')
    t(tx, y + 6, txt, 15, "#fff", "bold", "middle")
def etq(x, y, txt, cor, tam=15):
    w = 20 + len(txt) * tam * 0.6
    a(f'<rect x="{x-w/2}" y="{y-15}" width="{w}" height="30" rx="15" fill="#fff" stroke="{cor}" stroke-width="3"/>')
    t(x, y + 6, txt, tam, cor, "bold", "middle")

a(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="DejaVu Sans, Arial">')
a(f'<rect width="{W}" height="{H}" fill="#fff"/>')
t(60, 70, "LIGAÇÃO COMPLETA DO MOTOR DO SACO — ARDUINO NANO + PONTE H BT_2 (firmware V9)", 34, "#111", "bold")
t(60, 108, "Fora da partida o saco fica ENROLADO em cima. Só desce no START, depois da foto, e sobe no fim da rodada. Ao ligar, a placa recolhe o saco sozinha.", 19, "#555")
t(60, 140, "Cada peça está na mesma altura do pino do Nano em que ela liga. Plaquinha vermelha = vai no 5V do Nano; plaquinha preta = vai no GND do Nano.", 17, "#555")

# ---------------- ARDUINO NANO
NX, NY, NW, PAS = 1240, 250, 320, 72
esq = ["TX1", "RX0", "RST", "GND", "D2", "D3", "D4", "D5", "D6", "D7", "D8", "D9", "D10", "D11", "D12"]
dir_ = ["VIN", "GND", "RST", "5V", "A7", "A6", "A5", "A4", "A3", "A2", "A1", "A0", "REF", "3V3", "D13"]
NH = 70 + 15 * PAS + 20
caixa(NX, NY, NW, NH, "#0b5cad", "#06386b", 18, 4)
P = {}
usados = {"D2", "D3", "D7", "D8", "D9", "D10", "D11", "D12"}
for i, n in enumerate(esq):
    y = NY + 70 + i * PAS; P[n] = (NX + 26, y)
    a(f'<circle cx="{NX+26}" cy="{y}" r="12" fill="{"#ffcf33" if n in usados else "#e8eef7"}" stroke="#06386b" stroke-width="2"/>')
    t(NX + 50, y + 7, n, 20, "#fff", "bold")
for i, n in enumerate(dir_):
    y = NY + 70 + i * PAS; P["R" + n] = (NX + NW - 26, y)
    a(f'<circle cx="{NX+NW-26}" cy="{y}" r="12" fill="{"#ffcf33" if i in (1, 3) else "#e8eef7"}" stroke="#06386b" stroke-width="2"/>')
    t(NX + NW - 50, y + 7, n, 20, "#fff", "bold", "end")
t(NX + NW / 2, NY + 42, "ARDUINO NANO", 23, "#fff", "bold", "middle")
def Y(n): return P[n][1]
# 5V e GND do Nano: as plaquinhas de origem
bandeira(P["R5V"][0], Y("R5V"), "5V  (todas as plaquinhas 5V aqui)", VERM, +1)
bandeira(P["RGND"][0], Y("RGND"), "GND  (todas as plaquinhas GND aqui)", PRETO, +1)
# USB -> TV box
caixa(NX + 105, NY + NH - 6, 110, 50, "#d0d7de", "#57606a", 6)
t(NX + 160, NY + NH + 26, "USB", 18, "#333", "bold", "middle")
fio([(NX + 160, NY + NH + 44), (NX + 160, NY + NH + 110)], "#57606a", 9)
caixa(NX + 40, NY + NH + 110, 240, 74, "#eef1f4", "#57606a", 10)
t(NX + 160, NY + NH + 142, "TV BOX", 21, "#111", "bold", "middle")
t(NX + 160, NY + NH + 166, "(cabo USB de dados)", 14, "#555", "normal", "middle")
t(NX + NW + 30, Y("RA7") + 6, "A0 = sensor do soco (feixe, já ligado)", 15, "#57606a")

# ---------------- BOTÕES START (D2) e CRÉDITO (D3): caixinhas na altura do pino
def botao(pino, nome, obs, x0=700, w=400):
    y = Y(pino)
    caixa(x0, y - 26, w, 52, "#fff8c5", "#9a6700", 10, 2)
    a(f'<circle cx="{x0+28}" cy="{y}" r="15" fill="#cf222e" stroke="#82071e" stroke-width="3"/>')
    t(x0 + 54, y + (0 if obs else 6), nome, 16, "#111", "bold")
    if obs: t(x0 + 54, y + 19, obs, 13, "#9a6700", "bold")
    fio([(x0 + w, y), P[pino]], ROSA, 4)
    bandeira(x0, y, "GND", PRETO, -1)
botao("D2", "BOTÃO START", "segurado ao ligar = AUTOTESTE")
botao("D3", "BOTÃO CRÉDITO", "")
for pino, txt in (("D4", "D4 = sensor do soco (feixe D0)"), ("D5", "D5 = fita de LED esquerda"), ("D6", "D6 = fita de LED direita")):
    t(P[pino][0] - 30, Y(pino) + 6, txt + "  (já ligado — ver MONTAGEM_2)", 15, "#8c959f", "normal", "end")

# ---------------- PONTE H: placa + conector 2x4 ampliado (RPWM na linha do D9, LPWM na do D10)
HX0 = 520                     # coluna VCC/GND do conector ampliado
cols = {"VCC": HX0, "R_IS": HX0 + 120, "R_EN": HX0 + 240, "RPWM": HX0 + 360,
        "GND": HX0, "L_IS": HX0 + 120, "L_EN": HX0 + 240, "LPWM": HX0 + 360}
yR, yL = Y("D9"), Y("D10")
caixa(HX0 - 120, yR - 150, 560, 330, "#f6f8fa", "#57606a", 12, 2)
t(HX0 + 160, yR - 118, "CONECTOR 2×4 DA BT_2 (ampliado)", 17, "#111", "bold", "middle")
t(HX0 + 160, yR - 96, "confira os nomes na tabelinha impressa ao lado dele", 13, "#57606a", "normal", "middle")
for n, x in cols.items():
    topo = n in ("VCC", "R_IS", "R_EN", "RPWM")
    y = yR if topo else yL
    cor = "#e5534b" if "IS" in n else "#d4a72c"
    a(f'<rect x="{x-14}" y="{y-14}" width="28" height="28" rx="4" fill="{cor}" stroke="#57606a" stroke-width="2"/>')
    t(x, y - 24 if topo else y + 36, n, 15, "#111", "bold", "middle")
t(cols["R_IS"], yL + 70, "R_IS e L_IS: NÃO LIGAR", 14, "#cf222e", "bold", "middle")
t(HX0 + 160, yL + 100, "VCC + R_EN + L_EN no 5V (sem isso a ponte não anda)", 14, VERM, "bold", "middle")
# sinais
fio([(cols["RPWM"] + 14, yR), P["D9"]], ROXO, 6)
fio([(cols["LPWM"] + 14, yL), P["D10"]], LILAS, 6)
t(1080, yR - 12, "RPWM → D9 = DESCE", 15, ROXO, "bold", "middle")
t(1080, yL + 28, "LPWM → D10 = SOBE", 15, LILAS, "bold", "middle")
# D7/D8: a ligação antiga também serve
for pino, txt, cor in (("D7", "ou RPWM aqui (ligação antiga)", ROXO), ("D8", "ou LPWM aqui (ligação antiga)", LILAS)):
    x0, y0 = P[pino]
    fio([(x0, y0), (x0 - 70, y0)], cor, 4, True)
    t(x0 - 80, y0 + 6, txt, 15, cor, "bold", "end")
# VCC, R_EN, L_EN -> 5V  |  GND -> GND  (plaquinhas)
yb5 = yR - 56
fio([(cols["VCC"], yR - 14), (cols["VCC"], yb5), (cols["R_EN"] + 60, yb5), (cols["R_EN"] + 60, yL), (cols["L_EN"] + 14, yL)], VERM, 4)
fio([(cols["R_EN"], yR - 38), (cols["R_EN"], yb5)], VERM, 4)
fio([(cols["R_EN"], yR - 14), (cols["R_EN"], yR - 18)], VERM, 4)
a(f'<circle cx="{cols["R_EN"]}" cy="{yb5}" r="6" fill="{VERM}"/>')
a(f'<circle cx="{cols["VCC"]}" cy="{yb5}" r="6" fill="{VERM}"/>')
bandeira(cols["VCC"] - 14, yR, "5V", VERM, -1)
bandeira(cols["GND"] - 14, yL, "GND", PRETO, -1)

# placa BT_2 (desenho) acima/à esquerda do conector
BX, BY, BW, BH = 40, 560, 360, 420
caixa(BX, BY, BW, BH, "#1565c0", "#0d3c7a", 18, 4)
t(BX + BW / 2, BY + 44, "PONTE H  BT_2", 21, "#fff", "bold", "middle")
t(BX + BW / 2, BY + 68, "(IBT-2 / BTS7960)", 15, "#c9d8ee", "normal", "middle")
for i in range(2):
    xx = BX + 90 + i * 115
    a(f'<rect x="{xx}" y="{BY+100}" width="88" height="88" rx="4" fill="#1f2328"/>')
    t(xx + 44, BY + 150, "BTS7960", 13, "#c9ced6", "bold", "middle")
a(f'<rect x="{BX+130}" y="{BY+215}" width="120" height="42" rx="3" fill="#1f2328"/>')
t(BX + 190, BY + 242, "74HC244", 13, "#c9ced6", "bold", "middle")
a(f'<rect x="{BX+300}" y="{BY+215}" width="56" height="34" rx="3" fill="#1f2328"/>')
for k in range(4):
    for r_ in range(2):
        a(f'<circle cx="{BX+309+k*13}" cy="{BY+225+r_*14}" r="4" fill="#d4a72c"/>')
a(f'<line x1="{BX+356}" y1="{BY+232}" x2="{HX0-120}" y2="{yR-150}" stroke="#8c959f" stroke-dasharray="6 6" stroke-width="2"/>')
bor = {"B+": BX + 55, "B−": BX + 135, "M+": BX + 225, "M−": BX + 305}
a(f'<rect x="{BX+25}" y="{BY+BH-80}" width="330" height="60" rx="6" fill="#3fb950" stroke="#1a7f37" stroke-width="3"/>')
for n, x in bor.items():
    a(f'<circle cx="{x}" cy="{BY+BH-50}" r="16" fill="#d0d7de" stroke="#57606a" stroke-width="3"/>')
    t(x, BY + BH - 92, n, 20, "#fff", "bold", "middle")
yb = BY + BH - 50

# ---------------- FONTE (embaixo de B+/B−) e MOTOR (embaixo de M+/M−)
FY = 1450
caixa(BX, FY, 190, 160, "#eef1f4", "#6b7280", 10)
t(BX + 95, FY + 64, "FONTE DO", 18, "#111", "bold", "middle")
t(BX + 95, FY + 88, "MOTOR", 18, "#111", "bold", "middle")
t(BX + 95, FY + 116, "12 V ou 24 V", 15, "#555", "normal", "middle")
a(f'<circle cx="{bor["B+"]}" cy="{FY}" r="9" fill="{VERM}"/>'); t(bor["B+"] - 14, FY + 26, "V+", 15, VERM, "bold", "middle")
a(f'<circle cx="{bor["B−"]}" cy="{FY}" r="9" fill="{PRETO}"/>'); t(bor["B−"] + 14, FY + 26, "V−", 15, PRETO, "bold", "middle")
fio([(bor["B+"], yb), (bor["B+"], FY)], VERM, 8)
a(f'<rect x="{bor["B+"]-13}" y="{1200}" width="26" height="70" rx="12" fill="#fff3bf" stroke="#b08800" stroke-width="3"/>')
t(bor["B+"] + 20, 1242, "fusível", 14, "#9a6700", "bold")
fio([(bor["B−"], yb), (bor["B−"], FY)], PRETO, 8)
MXc, MYc = (bor["M+"] + bor["M−"]) // 2, 1560
fio([(bor["M+"], yb), (bor["M+"], MYc - 40)], "#6e40c9", 8)
fio([(bor["M−"], yb), (bor["M−"], MYc - 40)], "#6e40c9", 8)
a(f'<circle cx="{MXc}" cy="{MYc}" r="58" fill="#9aa1ab" stroke="#4b5563" stroke-width="6"/>')
a(f'<circle cx="{MXc}" cy="{MYc}" r="26" fill="#4b5563"/>')
t(MXc, MYc + 92, "MOTOR DO SACO", 18, "#111", "bold", "middle")
t(BX, 1700, "A força do motor vem da FONTE (B+/B−).", 15, "#57606a")
t(BX, 1722, "A USB do Nano NÃO move o motor.", 15, "#57606a")
t(BX, 1744, "Saco desce quando manda subir:", 15, "#57606a")
t(BX, 1766, "troque M+ com M−.", 15, "#57606a")

# ---------------- SENSOR DE CIMA (D11) + 100k  e  BOTÃO CONFIG (D12)
y11, y12 = Y("D11"), Y("D12")
SX, SY = 560, y11 + 60
caixa(SX, SY, 250, 160, "#0a3069", "#0550ae", 12)
t(SX + 125, SY + 34, "SENSOR DE CIMA", 17, "#fff", "bold", "middle")
t(SX + 125, SY + 56, "infravermelho FC-51", 14, "#c9d1d9", "normal", "middle")
t(SX + 125, SY + 78, "(LED acende quando vê o saco)", 12, "#c9d1d9", "normal", "middle")
pins_s = {"VCC": SY + 110, "GND": SY + 138}
for n, y in pins_s.items():
    a(f'<rect x="{SX-12}" y="{y-9}" width="22" height="18" fill="#d4a72c" stroke="#57606a" stroke-width="2"/>')
    t(SX + 18, y + 5, n, 13, "#fff", "bold")
bandeira(SX - 12, pins_s["VCC"], "5V", VERM, -1)
bandeira(SX - 12, pins_s["GND"], "GND", PRETO, -1)
yo_ = SY + 124
a(f'<rect x="{SX+250-11}" y="{yo_-9}" width="22" height="18" fill="#d4a72c" stroke="#57606a" stroke-width="2"/>')
t(SX + 232, yo_ + 5, "OUT", 13, "#fff", "bold", "end")
xo = SX + 270
fio([(SX + 261, yo_), (xo, yo_), (xo, y11), P["D11"]], AZUL, 5)
t(1080, y11 - 12, "OUT → D11", 15, AZUL, "bold", "middle")
# resistor 100k do D11 ao GND
RX = xo + 40
a(f'<circle cx="{RX}" cy="{y11}" r="6" fill="{AZUL}"/>')
fio([(RX, y11), (RX, y11 + 120)], AZUL, 4)
a(f'<rect x="{RX-12}" y="{y11+120}" width="24" height="64" rx="6" fill="#f0d9b5" stroke="#9a6700" stroke-width="3"/>')
t(RX + 22, y11 + 160, "100k", 15, "#9a6700", "bold")
fio([(RX, y11 + 184), (RX, y11 + 220)], PRETO, 4)
bandeira(RX, y11 + 220, "GND", PRETO, +1)
# CONFIG
botao("D12", "BOTÃO CONFIG", "", x0=RX + 150, w=230)

# ---------------- TABELA
TY = 1820
caixa(60, TY, W - 120, 560, "#f6f8fa", "#d0d7de", 14, 2)
t(90, TY + 44, "FIO POR FIO (firmware V9)", 23, "#111", "bold")
cx = [90, 470, 980]
t(cx[0], TY + 84, "De", 16, "#57606a", "bold"); t(cx[1], TY + 84, "Para", 16, "#57606a", "bold"); t(cx[2], TY + 84, "Para que serve / atenção", 16, "#57606a", "bold")
linhas = [
    ("BT_2 RPWM", "Nano D9   (ou D7)", "DESCE o saco. D9 = com velocidade; D7 = velocidade cheia (ligação antiga)."),
    ("BT_2 LPWM", "Nano D10  (ou D8)", "SOBE o saco. D10 = com velocidade; D8 = velocidade cheia (ligação antiga)."),
    ("BT_2 VCC, R_EN e L_EN", "Nano 5V", "os TRÊS no 5V. Sem o 5V no R_EN e no L_EN a ponte NÃO anda."),
    ("BT_2 GND", "Nano GND", "terra comum entre o Nano e a ponte (obrigatório)."),
    ("BT_2 R_IS e L_IS", "nada", "medição de corrente: não usar."),
    ("BT_2 B+ / B−", "fonte V+ (com fusível) / fonte V−", "a força do motor. Fonte desligada = motor parado, mesmo com tudo certo."),
    ("BT_2 M+ / M−", "os 2 fios do motor", "se o saco DESCER no SUBIR: troque M+ com M−."),
    ("Sensor FC-51 VCC / GND / OUT", "5V / GND / D11", "e um resistor de 100k do D11 ao GND. Vê o saco quando ele chega em cima."),
    ("Botão START", "D2 e GND", "segure START e ligue o Arduino (2 s) = AUTOTESTE do motor."),
    ("Botão CRÉDITO / CONFIG", "D3 e GND / D12 e GND", "botões do gabinete."),
    ("Nano USB", "TV Box", "cabo USB de DADOS (cabo só de carga não conversa)."),
]
for i, (c1, c2, c3) in enumerate(linhas):
    y = TY + 122 + i * 38
    if i % 2 == 0: a(f'<rect x="76" y="{y-26}" width="{W-152}" height="38" fill="#eaeef2"/>')
    t(cx[0], y, c1, 16, "#1f2328", "bold"); t(cx[1], y, c2, 16, "#1f2328", "bold"); t(cx[2], y, c3, 16)
a('</svg>')
open('montagem_0.svg', 'w').write('\n'.join(s))
print("ok")
