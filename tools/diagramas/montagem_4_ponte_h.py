W, H = 1800, 1640
s=[]; a=s.append
C = {"v5":"#d1242f","gnd":"#24292f","desce":"#a333c8","sobe":"#8250df","pot":"#cf222e","potn":"#1f2328","mot":"#a333c8"}
def t(x, y, txt, tam=17, cor="#1f2328", peso="normal", anc="start"):
    a(f'<text x="{x}" y="{y}" font-size="{tam}" fill="{cor}" font-weight="{peso}" text-anchor="{anc}">{txt}</text>')
def fio(pts, cor, larg=5, trac=False):
    d = "M" + " L".join(f"{p[0]},{p[1]}" for p in pts)
    tr = ' stroke-dasharray="12 7"' if trac else ''
    a(f'<path d="{d}" fill="none" stroke="{cor}" stroke-width="{larg}" stroke-linejoin="round" stroke-linecap="round"{tr}/>')
def ponto(x, y, cor):
    a(f'<circle cx="{x}" cy="{y}" r="8" fill="{cor}"/>')
def etiqueta(x, y, txt, cor):
    w = 18 + len(txt)*9.5
    a(f'<rect x="{x-w/2}" y="{y-15}" width="{w}" height="30" rx="15" fill="#fff" stroke="{cor}" stroke-width="3"/>')
    t(x, y+6, txt, 15, cor, "bold", "middle")

a(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="DejaVu Sans, Arial">')
a(f'<rect width="{W}" height="{H}" fill="#fff"/>')
t(60, 66, "PONTE H BTS7960 (placa \"BT_2\" / IBT-2) → ARDUINO NANO", 36, "#111", "bold")
t(60, 102, "Só 2 fios mandam no motor: D9 = DESCE e D10 = SOBE. A largura do pulso em cada um é a VELOCIDADE (firmware V6). O resto é alimentação.", 19, "#555")

# ---------------- fonte e motor (esquerda)
fx, fy = 40, 250
a(f'<rect x="{fx}" y="{fy}" width="200" height="140" rx="10" fill="#eef1f4" stroke="#6b7280" stroke-width="3"/>')
t(fx+100, fy+44, "FONTE DO", 17, "#111", "bold", "middle"); t(fx+100, fy+66, "MOTOR", 17, "#111", "bold", "middle")
t(fx+100, fy+94, "(tensão do motor,", 13, "#555", "normal", "middle"); t(fx+100, fy+112, "ex.: 12 V ou 24 V)", 13, "#555", "normal", "middle")
a(f'<circle cx="{fx+200}" cy="{fy+30}" r="9" fill="{C["pot"]}"/>'); t(fx+186, fy+36, "V+", 15, C["pot"], "bold", "end")
a(f'<circle cx="{fx+200}" cy="{fy+110}" r="9" fill="{C["potn"]}"/>'); t(fx+186, fy+116, "V−", 15, "#333", "bold", "end")
# motor
mxc, myc = 140, 560
a(f'<circle cx="{mxc}" cy="{myc}" r="70" fill="#9aa1ab" stroke="#4b5563" stroke-width="5"/>')
a(f'<circle cx="{mxc}" cy="{myc}" r="22" fill="#4b5563"/>')
t(mxc, myc+104, "MOTOR DO SACO", 18, "#111", "bold", "middle")

# ---------------- a placa BT_2 (borne à esquerda, conector 2x4 à direita)
px, py, pw, ph = 380, 210, 380, 470
a(f'<rect x="{px}" y="{py}" width="{pw}" height="{ph}" rx="18" fill="#1565c0" stroke="#0d3c7a" stroke-width="4"/>')
for (cx, cy) in [(px+24, py+24), (px+pw-24, py+24), (px+24, py+ph-24), (px+pw-24, py+ph-24)]:
    a(f'<circle cx="{cx}" cy="{cy}" r="13" fill="#e8eef7" stroke="#0d3c7a" stroke-width="3"/>')
# borne verde (4 parafusos) na borda esquerda
bx0 = px - 30
a(f'<rect x="{bx0}" y="{py+70}" width="70" height="280" rx="6" fill="#3fb950" stroke="#1a7f37" stroke-width="3"/>')
nomes_b = ["B+", "B−", "M+", "M−"]
ys_b = [py+105, py+175, py+245, py+315]
for n, y in zip(nomes_b, ys_b):
    a(f'<circle cx="{bx0+22}" cy="{y}" r="17" fill="#d0d7de" stroke="#57606a" stroke-width="3"/>')
    a(f'<line x1="{bx0+12}" y1="{y}" x2="{bx0+32}" y2="{y}" stroke="#57606a" stroke-width="4"/>')
    t(bx0+86, y+7, n, 20, "#fff", "bold")
t(bx0+35, py-12, "borne verde", 14, "#1a7f37", "bold", "middle")
# capacitor
a(f'<circle cx="{px+70}" cy="{py+405}" r="30" fill="#1f2328" stroke="#57606a" stroke-width="3"/>')
a(f'<circle cx="{px+70}" cy="{py+405}" r="18" fill="#c9ced6"/>')
# dois BTS7960 e o 74HC244
for i in range(2):
    xx = px + 150 + i*95
    a(f'<rect x="{xx}" y="{py+150}" width="80" height="80" rx="4" fill="#1f2328"/>')
    for k in range(7):
        a(f'<rect x="{xx+6+k*10}" y="{py+230}" width="5" height="22" fill="#c9ced6"/>')
    t(xx+40, py+196, "BTS7960", 12, "#c9ced6", "bold", "middle")
a(f'<rect x="{px+170}" y="{py+290}" width="120" height="44" rx="3" fill="#1f2328"/>')
t(px+230, py+318, "74HC244", 13, "#c9ced6", "bold", "middle")
t(px+235, py+70, "BT_2", 22, "#e8eef7", "bold", "middle")
t(px+235, py+96, "(dissipador embaixo)", 14, "#e8eef7", "normal", "middle")
# conector 2x4 na placa + tabelinha
hx, hy = px+pw-90, py+ph-115
a(f'<rect x="{hx-12}" y="{hy-12}" width="64" height="40" rx="3" fill="#1f2328"/>')
for r_ in range(2):
    for c_ in range(4):
        a(f'<circle cx="{hx+c_*13}" cy="{hy+r_*16}" r="4" fill="#d4af37"/>')
a(f'<rect x="{hx-160}" y="{hy-14}" width="140" height="44" fill="none" stroke="#e8eef7" stroke-width="2"/>')
for c_ in range(1, 4):
    a(f'<line x1="{hx-160+c_*35}" y1="{hy-14}" x2="{hx-160+c_*35}" y2="{hy+30}" stroke="#e8eef7" stroke-width="1.5"/>')
a(f'<line x1="{hx-160}" y1="{hy+8}" x2="{hx-20}" y2="{hy+8}" stroke="#e8eef7" stroke-width="1.5"/>')
t(hx-90, hy+52, "tabelinha com os nomes", 13, "#e8eef7", "normal", "middle")

# ---------------- conector 2x4 AMPLIADO
cx0, cy_top, cy_bot, dx = 870, 470, 540, 100
col_x = [cx0 + i*dx for i in range(4)]   # VCC/GND, IS, EN, PWM
a(f'<rect x="{cx0-74}" y="{cy_top-44}" width="{3*dx+116}" height="{cy_bot-cy_top+88}" rx="12" fill="#f6f8fa" stroke="#57606a" stroke-width="3" stroke-dasharray="10 6"/>')
a(f'<line x1="{hx+44}" y1="{hy-12}" x2="{cx0-74}" y2="{cy_top-44}" stroke="#8a929c" stroke-width="2" stroke-dasharray="6 5"/>')
a(f'<line x1="{hx+44}" y1="{hy+28}" x2="{cx0-74}" y2="{cy_bot+44}" stroke="#8a929c" stroke-width="2" stroke-dasharray="6 5"/>')
t(px+pw/2, py+ph+34, "conector 2×4 da placa, AMPLIADO ao lado →", 16, "#111", "bold", "middle")
t(px+pw/2, py+ph+56, "os nomes são os da tabelinha impressa ao lado dele", 14, "#555", "normal", "middle")
cima = ["VCC", "R_IS", "R_EN", "RPWM"]
baixo = ["GND", "L_IS", "L_EN", "LPWM"]
pin = {}
for i in range(4):
    for nome, y in ((cima[i], cy_top), (baixo[i], cy_bot)):
        a(f'<rect x="{col_x[i]-11}" y="{y-11}" width="22" height="22" fill="#d4af37" stroke="#8a6d1f" stroke-width="2"/>')
        t(col_x[i]-16, y+6, nome, 13, "#1f2328", "bold", "end")
        pin[nome] = (col_x[i], y)

# ---------------- Arduino Nano (USB para baixo)
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
usados = {"D9", "D10", "GND", "5V"}
for i, n in enumerate(esq):
    y = ny0 + i*np_
    u = n in usados and n != "GND"
    a(f'<circle cx="{nx+24}" cy="{y}" r="10" fill="{"#f2c94c" if u else "#e3e6ea"}" stroke="#7a5c00" stroke-width="2"/>')
    t(nx+44, y+6, n, 17, "#fff", "bold")
    npos[("e", n)] = (nx+14, y)
for i, n in enumerate(dir_):
    y = ny0 + i*np_
    u = n in usados
    a(f'<circle cx="{nx+nw-24}" cy="{y}" r="10" fill="{"#f2c94c" if u else "#e3e6ea"}" stroke="#7a5c00" stroke-width="2"/>')
    t(nx+nw-44, y+6, n, 17, "#fff", "bold", "end")
    npos[("d", n)] = (nx+nw-14, y)

# ---------------- fios do conector até o Nano
d9, d10 = npos[("e","D9")], npos[("e","D10")]
v5, gd = npos[("d","5V")], npos[("d","GND")]
# RPWM -> D9 (sobe, contorna por cima, desce no canal 1250)
x, y = pin["RPWM"]
fio([(x, y-11), (x, 400), (1290, 400), (1290, d9[1]), d9], C["desce"], 6)
etiqueta(1225, 400, "D9 = DESCE", C["desce"])
# LPWM -> D10
x, y = pin["LPWM"]
fio([(x, y+11), (x, 620), (1240, 620), (1240, d10[1]), d10], C["sobe"], 6)
etiqueta(1196, 650, "D10 = SOBE", C["sobe"])
# 5V: VCC e R_EN por cima, L_EN por baixo, todos no barramento x=1700
xv, yv = pin["VCC"]; xr, yr = pin["R_EN"]; xl, yl = pin["L_EN"]
fio([(xv, yv-11), (xv, 150), (1700, 150), (1700, v5[1]), v5], C["v5"], 6)
fio([(xr, yr-11), (xr, 178), (1700, 178)], C["v5"], 6); ponto(1700, 178, C["v5"])
fio([(xl, yl+11), (xl, 1010), (1672, 1010), (1672, v5[1])], C["v5"], 6); ponto(1672, v5[1], C["v5"])
etiqueta(1290, 150, "5V do Nano → VCC + R_EN + L_EN", C["v5"])
# GND por baixo até o GND da direita, com "ponte" sobre o fio do 5V
xg, yg = pin["GND"]
yh = gd[1]
fio([(xg, yg+11), (xg, 1040), (1740, 1040), (1740, yh), (1712, yh)], C["gnd"], 6)
a(f'<path d="M1712,{yh} A12,12 0 0 0 1688,{yh}" fill="none" stroke="{C["gnd"]}" stroke-width="6"/>')
fio([(1688, yh), gd], C["gnd"], 6)
etiqueta(1290, 1040, "GND → GND do Nano", C["gnd"])
# IS livres
for n in ("R_IS", "L_IS"):
    x, y = pin[n]
    a(f'<line x1="{x-8}" y1="{y-8}" x2="{x+8}" y2="{y+8}" stroke="#cf222e" stroke-width="3"/><line x1="{x+8}" y1="{y-8}" x2="{x-8}" y2="{y+8}" stroke="#cf222e" stroke-width="3"/>')
t(pin["R_IS"][0], cy_top-22, "não ligar", 12, "#cf222e", "bold", "middle")
t(pin["L_IS"][0], cy_bot+34, "não ligar", 12, "#cf222e", "bold", "middle")

# ---------------- potência
b_pos = dict(zip(nomes_b, ys_b))
fio([(fx+200, fy+30), (300, fy+30)], C["pot"], 9)
a(f'<rect x="{252}" y="{fy+18}" width="46" height="24" rx="12" fill="#fff8c5" stroke="#9a6700" stroke-width="2"/>')
t(275, fy+10, "fusível", 13, "#9a6700", "bold", "middle")
fio([(298, fy+30), (318, fy+30), (318, b_pos["B+"]), (bx0+22, b_pos["B+"])], C["pot"], 9)
fio([(fx+200, fy+110), (300, fy+110), (300, b_pos["B−"]), (bx0+22, b_pos["B−"])], C["potn"], 9)
fio([(mxc+50, myc-50), (290, myc-50), (290, b_pos["M+"]), (bx0+22, b_pos["M+"])], C["mot"], 8)
fio([(mxc+70, myc), (318, myc), (318, b_pos["M−"]), (bx0+22, b_pos["M−"])], "#6e2a8c", 8)

# ---------------- tabela pino por pino
ty = 1100
a(f'<rect x="60" y="{ty}" width="{W-120}" height="460" rx="14" fill="#f6f8fa" stroke="#d0d7de" stroke-width="2"/>')
t(90, ty+42, "LIGAÇÃO, PINO POR PINO (confira o nome na tabelinha impressa ao lado do conector)", 22, "#111", "bold")
cx_ = [90, 330, 560, 820]
for c, h in zip(cx_, ["Pino da BT_2", "Vai em", "Fio", "Para que serve"]):
    t(c, ty+82, h, 17, "#57606a", "bold")
linhas = [
    ("RPWM", "Nano D9", ("roxo", C["desce"]), "DESCE o saco; o pulso é a velocidade da descida"),
    ("LPWM", "Nano D10", ("lilás", C["sobe"]), "SOBE o saco; o pulso é a velocidade da subida"),
    ("R_EN + L_EN", "Nano 5V", ("vermelho", C["v5"]), "\"chave geral\" da ponte: ligados = a ponte pode andar"),
    ("VCC", "Nano 5V", ("vermelho", C["v5"]), "alimenta a parte lógica da placa (5 V)"),
    ("GND", "Nano GND", ("preto", C["gnd"]), "terra comum com o Arduino"),
    ("R_IS / L_IS", "nada", ("—", "#8a9199"), "medição de corrente: não usada"),
    ("B+ / B−", "fonte do motor", ("grosso", C["pot"]), "B+ pelo fusível no V+; B− no V−"),
    ("M+ / M−", "motor", ("grosso", C["mot"]), "se o saco DESCER quando manda SUBIR: inverta M+ e M−"),
]
for i, (p_, v, (fn, fc), f) in enumerate(linhas):
    y = ty + 122 + i*38
    if i % 2 == 0:
        a(f'<rect x="76" y="{y-26}" width="{W-152}" height="38" fill="#eaeef2"/>')
    t(cx_[0], y, p_, 17, "#1f2328", "bold"); t(cx_[1], y, v, 17, "#1f2328", "bold")
    a(f'<rect x="{cx_[2]}" y="{y-14}" width="34" height="14" rx="3" fill="{fc}"/>'); t(cx_[2]+44, y, fn, 16)
    t(cx_[3], y, f, 17)
t(90, ty+438, "VELOCIDADE: Central (botão MENU) → aba SACO → VELOCIDADE DO MOTOR: SUBIDA (padrão 80%) e DESCIDA (padrão 60%). A partida é em rampa, sem tranco.", 16, "#57606a")
a('</svg>')
open('folha4.svg','w').write('\n'.join(s))
