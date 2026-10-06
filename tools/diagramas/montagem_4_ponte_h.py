W, H = 1800, 1510
s=[]; a=s.append
C = {"v5":"#d1242f","gnd":"#24292f","mot":"#a333c8","sobe":"#8250df","pot":"#cf222e","potn":"#1f2328"}
def t(x, y, txt, tam=17, cor="#1f2328", peso="normal", anc="start"):
    a(f'<text x="{x}" y="{y}" font-size="{tam}" fill="{cor}" font-weight="{peso}" text-anchor="{anc}">{txt}</text>')
def fio(pts, cor, larg=5, trac=False):
    d = "M" + " L".join(f"{p[0]},{p[1]}" for p in pts)
    tr = ' stroke-dasharray="12 7"' if trac else ''
    a(f'<path d="{d}" fill="none" stroke="{cor}" stroke-width="{larg}" stroke-linejoin="round" stroke-linecap="round"{tr}/>')
a(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="DejaVu Sans, Arial">')
a(f'<rect width="{W}" height="{H}" fill="#fff"/>')
t(60, 70, "PONTE H IBT-2 (BTS7960) → ARDUINO NANO: LIGAÇÃO COMPLETA", 38, "#111", "bold")
t(60, 106, "Placa vista de cima. Cada fio sai de um pino (\"ferrinho\") do conector de 8 pinos da ponte H e vai ao pino do Nano com o nome indicado. Siga o NOME impresso nas placas.", 19, "#555")

# ---------------- placa IBT-2
px, py, pw, ph = 540, 210, 470, 520
a(f'<rect x="{px}" y="{py}" width="{pw}" height="{ph}" rx="14" fill="#c62828" stroke="#7f1d1d" stroke-width="4"/>')
for (cx, cy) in [(px+22, py+22), (px+pw-22, py+22), (px+22, py+ph-22), (px+pw-22, py+ph-22)]:
    a(f'<circle cx="{cx}" cy="{cy}" r="10" fill="#fff" stroke="#7f1d1d" stroke-width="3"/>')
# dissipador
a(f'<rect x="{px+50}" y="{py+40}" width="{pw-200}" height="250" rx="6" fill="#9aa3ad" stroke="#59616b" stroke-width="3"/>')
for k in range(9):
    xx = px + 64 + k*26
    a(f'<rect x="{xx}" y="{py+52}" width="12" height="226" rx="3" fill="#c8cfd6"/>')
t(px+185, py+312, "dissipador", 15, "#fff", "bold", "middle")
# chips e componentes
for k in range(2):
    a(f'<rect x="{px+60+k*140}" y="{py+330}" width="100" height="56" rx="4" fill="#1f2328"/>')
    t(px+110+k*140, py+364, "BTS7960", 14, "#c9d1d9", "bold", "middle")
a(f'<rect x="{px+130}" y="{py+410}" width="110" height="40" rx="3" fill="#1f2328"/>'); t(px+185, py+436, "74HC244", 13, "#c9d1d9", "bold", "middle")
t(px+185, py+ph-30, "IBT-2  •  BTS7960", 18, "#fff", "bold", "middle")
# borne de parafuso (lado esquerdo)
bornes = [("B+", "#cf222e"), ("B−", "#1f2328"), ("M+", "#a333c8"), ("M−", "#6b21a8")]
for i, (n, c) in enumerate(bornes):
    by = py + 140 + i*90
    a(f'<rect x="{px-62}" y="{by-34}" width="64" height="68" rx="4" fill="#1565c0" stroke="#0d3c73" stroke-width="2"/>')
    a(f'<circle cx="{px-30}" cy="{by}" r="18" fill="#b0bec5" stroke="#455a64" stroke-width="3"/>')
    fio([(px-42, by), (px-18, by)], "#455a64", 4)
    t(px+12, by+7, n, 20, "#fff", "bold")
t(px-30, py+100, "BORNE", 14, "#1565c0", "bold", "middle")
# conector de 8 pinos (lado direito)
nomes = ["RPWM", "LPWM", "R_EN", "L_EN", "R_IS", "L_IS", "VCC", "GND"]
hy0 = py + 120
passo = 50
a(f'<rect x="{px+pw-8}" y="{hy0-26}" width="34" height="{passo*8+2}" rx="4" fill="#1f2328"/>')
pinos = {}
for i, n in enumerate(nomes):
    y = hy0 + i*passo
    a(f'<rect x="{px+pw+26}" y="{y-4}" width="46" height="8" fill="#d4af37" stroke="#8a6d1f"/>')   # ferrinho
    t(px+pw-20, y+6, f"{i+1}  {n}", 17, "#fff", "bold", "end")
    pinos[n] = (px+pw+72, y)
# jumper visual nos pinos 5V
t(px+pw+40, py+ph+24, "conector de 8 pinos", 14, "#555", "normal", "middle")

# ---------------- Arduino Nano (USB para baixo: digitais à esquerda)
nx, ny, nw = 1360, 230, 270
esq = ["TX1","RX0","RST","GND","D2","D3","D4","D5","D6","D7","D8","D9","D10","D11","D12"]
dir_ = ["VIN","GND","RST","5V","A7","A6","A5","A4","A3","A2","A1","A0","REF","3V3","D13"]
np_ = 40
ny0 = ny + 50
nh = np_*14 + 150
a(f'<rect x="{nx}" y="{ny}" width="{nw}" height="{nh}" rx="16" fill="#0b5cad" stroke="#073f78" stroke-width="4"/>')
a(f'<rect x="{nx+nw/2-50}" y="{ny+nh-20}" width="100" height="62" rx="8" fill="#c9ced6" stroke="#8a929c" stroke-width="3"/>')
t(nx+nw/2, ny+nh+22, "USB", 18, "#333", "bold", "middle")
t(nx+nw/2, ny+nh-45, "ARDUINO NANO", 20, "#fff", "bold", "middle")
npos = {}
usados = {"D7", "D8", "GND", "5V"}
for i, n in enumerate(esq):
    y = ny0 + i*np_
    u = n in usados
    a(f'<circle cx="{nx+24}" cy="{y}" r="10" fill="{"#f2c94c" if u else "#e3e6ea"}" stroke="#7a5c00" stroke-width="2"/>')
    t(nx+44, y+6, n, 17, "#fff", "bold")
    npos[("e", n)] = (nx+14, y)
for i, n in enumerate(dir_):
    y = ny0 + i*np_
    u = n in usados
    a(f'<circle cx="{nx+nw-24}" cy="{y}" r="10" fill="{"#f2c94c" if u else "#e3e6ea"}" stroke="#7a5c00" stroke-width="2"/>')
    t(nx+nw-44, y+6, n, 17, "#fff", "bold", "end")
    npos[("d", n)] = (nx+nw-14, y)
t(nx+nw/2, ny-14, "placa vista de cima, USB para BAIXO", 15, "#555", "normal", "middle")

# ---------------- fios de sinal
def etiqueta(x, y, txt, cor):
    w = 18 + len(txt)*9.5
    a(f'<rect x="{x-w/2}" y="{y-15}" width="{w}" height="30" rx="15" fill="#fff" stroke="{cor}" stroke-width="3"/>')
    t(x, y+6, txt, 15, cor, "bold", "middle")
x0 = pinos["RPWM"][0]
# RPWM -> D7
d7 = npos[("e","D7")]; y = pinos["RPWM"][1]
fio([pinos["RPWM"], (1180, y), (1180, d7[1]), d7], C["mot"], 6)
etiqueta(1275, d7[1], "D7 = DESCE", C["mot"])
d8 = npos[("e","D8")]; y = pinos["LPWM"][1]
fio([pinos["LPWM"], (1210, y), (1210, d8[1]), d8], C["sobe"], 6)
etiqueta(1290, d8[1]+0, "D8 = SOBE", C["sobe"])
# GND -> GND (esquerda)
g = npos[("e","GND")]; y = pinos["GND"][1]
fio([pinos["GND"], (1150, y), (1150, g[1]), g], C["gnd"], 6)
# 5V: R_EN, L_EN, VCC unidos e ao 5V (direita, contornando por cima)
yR, yL, yV = pinos["R_EN"][1], pinos["L_EN"][1], pinos["VCC"][1]
bx = 1110
for yy in (yR, yL, yV):
    fio([(x0, yy), (bx, yy)], C["v5"], 6)
    a(f'<circle cx="{bx}" cy="{yy}" r="7" fill="{C["v5"]}"/>')
fio([(bx, yV), (bx, 160), (nx+nw+60, 160), (nx+nw+60, npos[("d","5V")][1]), npos[("d","5V")]], C["v5"], 6)
etiqueta(1350, 160, "5V do Nano → R_EN + L_EN + VCC", C["v5"])
# IS livres
for n in ("R_IS", "L_IS"):
    x, y = pinos[n]
    t(px+pw-20, y+22, "(não ligar)", 12, "#ffd7d7", "normal", "end")

# ---------------- fonte e motor (potência)
fx, fy = 40, 300
a(f'<rect x="{fx}" y="{fy}" width="190" height="150" rx="10" fill="#eef1f4" stroke="#6b7280" stroke-width="3"/>')
t(fx+80, fy+48, "FONTE DO", 17, "#111", "bold", "middle"); t(fx+80, fy+70, "MOTOR", 17, "#111", "bold", "middle")
t(fx+80, fy+96, "(tensão do", 13, "#555", "normal", "middle"); t(fx+80, fy+112, "motor, ex.: 12 V)", 13, "#555", "normal", "middle")
a(f'<circle cx="{fx+190}" cy="{fy+30}" r="9" fill="{C["pot"]}"/>'); t(fx+170, fy+36, "V+", 15, "#cf222e", "bold", "end"); t(fx+170, fy+126, "V−", 15, "#333", "bold", "end")
a(f'<circle cx="{fx+190}" cy="{fy+120}" r="9" fill="{C["potn"]}"/>')
# fusivel
b1 = py + 140; b2 = py + 230
a(f'<rect x="{fx+215}" y="{fy+18}" width="60" height="24" rx="12" fill="#fff8c5" stroke="#9a6700" stroke-width="2"/>'); t(fx+245, fy+10, "fusível", 14, "#9a6700", "bold", "middle")
fio([(fx+199, fy+30), (fx+215, fy+30)], C["pot"], 8)
fio([(fx+275, fy+30), (px-90, fy+30), (px-90, b1), (px-48, b1)], C["pot"], 8)
fio([(fx+199, fy+120), (px-110, fy+120), (px-110, b2), (px-48, b2)], C["potn"], 8)
# motor
mx, my = 150, 660
a(f'<circle cx="{mx}" cy="{my}" r="70" fill="#9ca3af" stroke="#4b5563" stroke-width="5"/><circle cx="{mx}" cy="{my}" r="22" fill="#4b5563"/>')
a(f'<rect x="{mx+66}" y="{my-30}" width="30" height="16" fill="#d4af37"/><rect x="{mx+66}" y="{my+14}" width="30" height="16" fill="#d4af37"/>')
t(mx, my+100, "MOTOR DO SACO", 18, "#111", "bold", "middle")
m1 = py + 320; m2 = py + 410
fio([(mx+96, my-22), (px-130, my-22), (px-130, m1), (px-48, m1)], C["mot"], 8)
fio([(mx+96, my+22), (px-150, my+22), (px-150, m2), (px-48, m2)], "#6b21a8", 8)

# ---------------- tabela
ty = 1010
a(f'<rect x="60" y="{ty}" width="{W-120}" height="430" rx="14" fill="#f6f8fa" stroke="#d0d7de" stroke-width="2"/>')
t(90, ty+44, "LIGAÇÃO, PINO POR PINO", 22, "#111", "bold")
cab = ["Pino da IBT-2", "Vai em", "Fio", "Para que serve"]
cx_ = [90, 380, 640, 900]
for c, x in zip(cab, cx_):
    t(x, ty+86, c, 17, "#57606a", "bold")
linhas = [
 ("1  RPWM", "Nano D7", ("roxo", C["mot"]), "DESCE o saco (o firmware liga D7)"),
 ("2  LPWM", "Nano D8", ("lilás", C["sobe"]), "SOBE o saco (o firmware liga D8)"),
 ("3  R_EN", "Nano 5V", ("vermelho", C["v5"]), "habilita o lado direito (sempre ligado)"),
 ("4  L_EN", "Nano 5V", ("vermelho", C["v5"]), "habilita o lado esquerdo (sempre ligado)"),
 ("5  R_IS / 6  L_IS", "nada", ("—", "#8a9199"), "saída de corrente; não usada"),
 ("7  VCC", "Nano 5V", ("vermelho", C["v5"]), "alimenta a lógica da placa (5 V)"),
 ("8  GND", "Nano GND", ("preto", C["gnd"]), "terra comum (já ligado ao B− dentro da placa)"),
 ("B+ / B−", "fonte do motor", ("grosso", C["pot"]), "B+ pelo fusível no V+; B− no V−"),
 ("M+ / M−", "motor", ("grosso", C["mot"]), "se o saco descer no SOBE, inverta M+ e M−"),
]
for i, (p, v, (fn, fc), f) in enumerate(linhas):
    y = ty + 124 + i*33
    if i % 2 == 0:
        a(f'<rect x="76" y="{y-23}" width="{W-152}" height="33" fill="#eaeef2"/>')
    t(cx_[0], y, p, 17, "#1f2328", "bold"); t(cx_[1], y, v, 17, "#1f2328", "bold")
    a(f'<rect x="{cx_[2]}" y="{y-14}" width="34" height="14" rx="3" fill="{fc}"/>'); t(cx_[2]+44, y, fn, 16)
    t(cx_[3], y, f, 17)
a('</svg>')
open('folha4.svg','w').write('\n'.join(s))
