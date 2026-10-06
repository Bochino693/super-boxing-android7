W, H = 1800, 1930
s=[]; a=s.append
C = {"v5":"#d1242f","gnd":"#24292f","out":"#1a7f37","res":"#9a6700"}
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
def guia(x1, y1, x2, y2):
    a(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="#8a929c" stroke-width="2"/>')
    a(f'<circle cx="{x2}" cy="{y2}" r="4" fill="#8a929c"/>')

a(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="DejaVu Sans, Arial">')
a(f'<rect width="{W}" height="{H}" fill="#fff"/>')
t(60, 70, "FIM DE CURSO DE CIMA: SENSOR INFRAVERMELHO → ARDUINO NANO", 38, "#111", "bold")
t(60, 106, "O seu sensor (módulo de obstáculo IR, tipo FC-51 / LM393, 3 pinos). Firmware V5. Siga o NOME impresso ao lado de cada pino: a cor do fio não importa.", 19, "#555")

# ---------------- o módulo (deitado, pinos para a direita)
mx, my, mw, mh = 250, 280, 380, 170
yV, yG, yO = 325, 370, 415
a(f'<rect x="{mx}" y="{my}" width="{mw}" height="{mh}" rx="10" fill="#1565c0" stroke="#0d3c7a" stroke-width="4"/>')
a(f'<circle cx="{mx+mw-30}" cy="{my+28}" r="11" fill="#fff" stroke="#0d3c7a" stroke-width="3"/>')
# LEDs na ponta esquerda
a(f'<rect x="{mx-70}" y="{my+22}" width="80" height="44" rx="22" fill="#e8f1fb" stroke="#8aa4c0" stroke-width="3"/>')
a(f'<rect x="{mx-6}" y="{my+22}" width="14" height="44" fill="#c9ced6"/>')
a(f'<rect x="{mx-70}" y="{my+104}" width="80" height="44" rx="22" fill="#2b2f36" stroke="#111" stroke-width="3"/>')
a(f'<rect x="{mx-6}" y="{my+104}" width="14" height="44" fill="#c9ced6"/>')
# trimpot
a(f'<rect x="{mx+90}" y="{my+50}" width="70" height="70" rx="6" fill="#2f6fd6" stroke="#0d3c7a" stroke-width="3"/>')
a(f'<circle cx="{mx+125}" cy="{my+85}" r="22" fill="#e8eef7" stroke="#0d3c7a" stroke-width="3"/>')
a(f'<line x1="{mx+110}" y1="{my+85}" x2="{mx+140}" y2="{my+85}" stroke="#0d3c7a" stroke-width="4"/>')
a(f'<line x1="{mx+125}" y1="{my+70}" x2="{mx+125}" y2="{my+100}" stroke="#0d3c7a" stroke-width="4"/>')
# LM393
a(f'<rect x="{mx+190}" y="{my+50}" width="64" height="70" rx="4" fill="#1f2328"/>')
for i in range(4):
    a(f'<rect x="{mx+182}" y="{my+58+i*15}" width="8" height="7" fill="#c9ced6"/>')
    a(f'<rect x="{mx+254}" y="{my+58+i*15}" width="8" height="7" fill="#c9ced6"/>')
t(mx+222, my+92, "LM393", 12, "#fff", "bold", "middle")
# LEDs SMD
a(f'<rect x="{mx+285}" y="{my+40}" width="22" height="14" rx="3" fill="#ff5a5a"/>')
t(mx+296, my+32, "PWR", 13, "#fff", "bold", "middle")
a(f'<rect x="{mx+285}" y="{my+118}" width="22" height="14" rx="3" fill="#3ddc84"/>')
t(mx+296, my+152, "OBS", 13, "#fff", "bold", "middle")
# pinos
for nome, y in (("VCC", yV), ("GND", yG), ("OUT", yO)):
    a(f'<rect x="{mx+mw-6}" y="{y-12}" width="24" height="24" fill="#1f2328"/>')
    a(f'<rect x="{mx+mw+18}" y="{y-4}" width="44" height="8" fill="#d4af37" stroke="#8a6d1f"/>')
    t(mx+mw-14, y+6, nome, 16, "#fff", "bold", "end")
pv, pg, po = (mx+mw+62, yV), (mx+mw+62, yG), (mx+mw+62, yO)
# legendas da peça
guia(mx-30, my-36, mx-30, my+22); t(mx-30, my-44, "LED IR (transparente): emissor", 15, "#444", "normal", "middle")
guia(mx-30, my+mh+60, mx-30, my+148); t(mx-30, my+mh+80, "receptor (preto)", 15, "#444", "normal", "middle")
guia(mx+125, my-80, mx+125, my+62); t(mx+125, my-88, "trimpot: ajusta a distância", 15, "#444", "normal", "middle")
guia(mx+296, my+mh+60, mx+296, my+136); t(mx+296, my+mh+80, "LED OBS: acende quando vê", 15, "#444", "normal", "middle")
t(mx+mw/2, my+mh+120, "SENSOR DE CIMA (módulo IR de 3 pinos)", 20, "#111", "bold", "middle")
t(mx+mw/2, my+mh+146, "a ordem dos pinos muda de placa para placa: vale o nome impresso", 15, "#666", "normal", "middle")

# ---------------- Arduino Nano (USB para baixo: digitais à esquerda)
nx, ny, nw = 1360, 200, 270
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
usados = {"D11", "GND", "5V"}
for i, n in enumerate(esq):
    y = ny0 + i*np_
    u = n in usados
    a(f'<circle cx="{nx+24}" cy="{y}" r="10" fill="{"#f2c94c" if u else "#e3e6ea"}" stroke="#7a5c00" stroke-width="2"/>')
    t(nx+44, y+6, n, 17, "#fff", "bold")
    npos[("e", n)] = (nx+14, y)
for i, n in enumerate(dir_):
    y = ny0 + i*np_
    u = n == "5V"
    a(f'<circle cx="{nx+nw-24}" cy="{y}" r="10" fill="{"#f2c94c" if u else "#e3e6ea"}" stroke="#7a5c00" stroke-width="2"/>')
    t(nx+nw-44, y+6, n, 17, "#fff", "bold", "end")
    npos[("d", n)] = (nx+nw-14, y)
t(nx+nw/2, ny-14, "placa vista de cima, USB para BAIXO", 15, "#555", "normal", "middle")

# ---------------- fios
g = npos[("e","GND")]; d11 = npos[("e","D11")]; v5 = npos[("d","5V")]
# GND reto
fio([pg, g], C["gnd"], 6)
etiqueta(1000, yG, "GND → GND do Nano", C["gnd"])
# VCC por cima até o 5V
fio([pv, (1100, yV), (1100, 160), (1700, 160), (1700, v5[1]), v5], C["v5"], 6)
etiqueta(1230, 160, "VCC → 5V do Nano", C["v5"])
# OUT até o D11
xo = 1060
fio([po, (xo, yO), (xo, d11[1]), d11], C["out"], 6)
etiqueta(900, yO+2, "OUT → D11", C["out"])
etiqueta(1170, d11[1]+0, "D11", C["out"])
# resistor de 100k entre D11 e GND
xr = 1280
ponto(xr, g[1], C["gnd"]); ponto(xr, d11[1], C["out"])
fio([(xr, g[1]), (xr, 500)], "#6e7781", 4)
fio([(xr, 640), (xr, d11[1])], "#6e7781", 4)
a(f'<rect x="{xr-16}" y="500" width="32" height="140" rx="14" fill="#e9d8b4" stroke="#9a6700" stroke-width="3"/>')
for i, cor in enumerate(["#8b4513", "#111111", "#f2c200", "#c8a400"]):
    yy = 518 + i*28 + (8 if i == 3 else 0)
    a(f'<rect x="{xr-16}" y="{yy}" width="32" height="10" fill="{cor}"/>')
t(xr-30, 545, "RESISTOR", 16, C["res"], "bold", "end")
t(xr-30, 568, "100 kΩ", 22, C["res"], "bold", "end")
t(xr-30, 590, "(47k a 100k)", 14, "#666", "normal", "end")
t(xr-30, 612, "D11 ↔ GND", 15, C["res"], "bold", "end")
t(xr-30, 634, "marrom-preto-amarelo", 13, "#666", "normal", "end")

# observação logo abaixo
t(60, 1000, "• O resistor fica no borne do Nano: uma perna no D11, a outra no GND. É ele que faz o fio OUT solto (ou o sensor sem 5V) ler \"CHEGOU\": o saco não sobe.", 18, "#333")
t(60, 1028, "• Fio longo até o topo do gabinete: um capacitor de 100 nF entre D11 e GND, perto do Nano, evita disparo falso. Use cabo com os 3 fios juntos.", 18, "#333")

# ---------------- montagem (vista de lado)
bx, by, bw, bh = 60, 1070, 820, 520
a(f'<rect x="{bx}" y="{by}" width="{bw}" height="{bh}" rx="16" fill="#fbfcfd" stroke="#d0d7de" stroke-width="3"/>')
t(bx+24, by+42, "ONDE MONTAR (vista de lado, saco subindo)", 22, "#111", "bold")
# teto / estrutura
a(f'<rect x="{bx+40}" y="{by+80}" width="{bw-80}" height="24" fill="#8c959f"/>')
t(bx+50, by+124, "estrutura do gabinete (topo)", 14, "#555")
# suporte e sensor apontando para baixo
sxm = bx+400
a(f'<rect x="{sxm-8}" y="{by+104}" width="16" height="50" fill="#57606a"/>')
a(f'<rect x="{sxm-70}" y="{by+150}" width="140" height="34" rx="6" fill="#1565c0" stroke="#0d3c7a" stroke-width="3"/>')
a(f'<rect x="{sxm-46}" y="{by+184}" width="26" height="36" rx="12" fill="#e8f1fb" stroke="#8aa4c0" stroke-width="2"/>')
a(f'<rect x="{sxm+20}" y="{by+184}" width="26" height="36" rx="12" fill="#2b2f36"/>')
t(sxm+90, by+168, "SENSOR IR (fixo no gabinete,", 15, "#0d3c7a", "bold")
t(sxm+90, by+188, "LEDs olhando para o braço)", 15, "#0d3c7a", "bold")
# feixe IR
a(f'<path d="M{sxm-33},{by+222} L{sxm-20},{by+292} M{sxm+33},{by+222} L{sxm+20},{by+292}" stroke="#d1242f" stroke-width="3" stroke-dasharray="6 5" fill="none"/>')
# braço chegando em cima com o alvo branco
a(f'<line x1="{bx+120}" y1="{by+318}" x2="{bx+700}" y2="{by+318}" stroke="#57606a" stroke-width="20" stroke-linecap="round"/>')
a(f'<circle cx="{bx+700}" cy="{by+318}" r="22" fill="#6e7781" stroke="#24292f" stroke-width="4"/>')
t(bx+700, by+372, "eixo", 14, "#555", "normal", "middle")
a(f'<rect x="{sxm-50}" y="{by+296}" width="100" height="12" fill="#ffffff" stroke="#1f2328" stroke-width="2"/>')
t(sxm, by+356, "ALVO BRANCO colado no braço", 16, "#111", "bold", "middle")
t(sxm, by+378, "(plaquinha de plástico branco ou fita branca fosca)", 14, "#555", "normal", "middle")
# distância
a(f'<line x1="{sxm+110}" y1="{by+222}" x2="{sxm+110}" y2="{by+296}" stroke="#9a6700" stroke-width="3"/>')
a(f'<line x1="{sxm+98}" y1="{by+222}" x2="{sxm+122}" y2="{by+222}" stroke="#9a6700" stroke-width="3"/>')
a(f'<line x1="{sxm+98}" y1="{by+296}" x2="{sxm+122}" y2="{by+296}" stroke="#9a6700" stroke-width="3"/>')
t(sxm+134, by+256, "1 a 3 cm", 18, "#9a6700", "bold")
t(sxm+134, by+278, "com o saco em cima", 14, "#9a6700")
# batente
a(f'<rect x="{bx+90}" y="{by+212}" width="34" height="88" fill="#7a1f2b"/>')
t(bx+107, by+204, "batente", 14, "#555", "normal", "middle")
# seta de subida
a(f'<path d="M{bx+160},{by+440} q-6,-60 34,-96" stroke="#d4a017" stroke-width="4" fill="none" stroke-dasharray="8 6"/>')
a(f'<path d="M{bx+187},{by+336} l18,-6 l-6,18 z" fill="#d4a017"/>')
t(bx+176, by+440, "o braço sobe com o saco", 14, "#9a6700")
t(bx+24, by+bh-46, "• O sensor deve VER o alvo 5 a 10 mm ANTES de o braço encostar no batente.", 16, "#333")
t(bx+24, by+bh-22, "• Couro preto e metal escuro quase não refletem: o alvo branco é o que o sensor vê.", 16, "#333")

# ---------------- tabela: o que acontece
tx, ty, tw = 920, 1070, 820
a(f'<rect x="{tx}" y="{ty}" width="{tw}" height="{bh}" rx="16" fill="#f6f8fa" stroke="#d0d7de" stroke-width="3"/>')
t(tx+24, ty+42, "O QUE O ARDUINO ENTENDE", 22, "#111", "bold")
cols = [tx+24, tx+300, tx+430, tx+560]
for c, h in zip(cols, ["Situação", "D11", "LED OBS", "Motor"]):
    t(c, ty+84, h, 16, "#57606a", "bold")
linhas = [
    ("Saco embaixo / jogando", "5 V", "apagado", "pode subir", "#1f2328"),
    ("Saco chegou (vê o alvo)", "0 V", "ACESO", "PARA na hora", "#1a7f37"),
    ("Fio OUT solto", "0 V*", "—", "não sobe", "#1a7f37"),
    ("Sensor sem o 5V", "0 V*", "apagado", "não sobe", "#1a7f37"),
    ("Sensor sem o GND", "5 V", "apagado", "para pelo TEMPO", "#cf222e"),
    ("Desregulado (não vê)", "5 V", "apagado", "para pelo TEMPO", "#cf222e"),
]
for i, (sit, d, led, mot, cor) in enumerate(linhas):
    y = ty + 124 + i*44
    if i % 2 == 0:
        a(f'<rect x="{tx+12}" y="{y-28}" width="{tw-24}" height="44" fill="#eaeef2"/>')
    t(cols[0], y, sit, 16, "#1f2328", "bold")
    t(cols[1], y, d, 16, "#1f2328")
    t(cols[2], y, led, 16, "#1f2328")
    t(cols[3], y, mot, 16, cor, "bold")
t(tx+24, ty+412, "* o resistor de 100k puxa o D11 para 0 V: o Arduino entende \"já chegou\".", 15, "#555")
t(tx+24, ty+440, "PARA pelo TEMPO = subiu o tempo de curso inteiro sem ver o alvo: corta o motor,", 15, "#cf222e")
t(tx+24, ty+462, "avisa ERROR,FIM_CIMA e trava a subida até PARAR na Central (aba SACO).", 15, "#cf222e")
t(tx+24, ty+bh-14, "A ponte H é a da MONTAGEM_4; o resto das ligações, MONTAGEM_1 e 2.", 14, "#666")

# ---------------- ajuste em 4 passos
ay = 1630
t(60, ay, "AJUSTE EM 4 PASSOS (firmware de teste TESTE_PONTE_H ou a Central, aba SACO)", 22, "#111", "bold")
passos = [
    ("1", "Ligue: o LED PWR acende.", "Com o saco embaixo, o LED OBS", "fica APAGADO."),
    ("2", "Leve o saco até 5 a 10 mm", "ANTES do batente (com o", "comando s ou com a mão)."),
    ("3", "Gire o trimpot devagar até", "o LED OBS ACENDER nessa", "posição. Pare aí."),
    ("4", "Abaixe o saco 2 cm: o LED", "OBS tem de APAGAR. Na Central:", "\"chave de CIMA: ACIONADA\" em cima."),
]
for i, (n, l1, l2, l3) in enumerate(passos):
    x = 60 + i*425
    a(f'<rect x="{x}" y="{ay+22}" width="405" height="150" rx="14" fill="#fbfcfd" stroke="#d0d7de" stroke-width="2"/>')
    a(f'<circle cx="{x+38}" cy="{ay+64}" r="22" fill="#1a7f37"/>')
    t(x+38, ay+72, n, 22, "#fff", "bold", "middle")
    t(x+74, ay+70, l1, 17, "#1f2328", "bold")
    t(x+24, ay+110, l2, 17, "#1f2328")
    t(x+24, ay+138, l3, 17, "#1f2328")
t(60, ay+214, "Luz do sol ou lâmpada forte batendo direto no sensor atrapalha: deixe-o virado para dentro do gabinete.", 17, "#555")
t(60, ay+242, "Quem ainda usa a micro chave NF no D11: no firmware, troque FIM_CIMA_INFRAVERMELHO de 1 para 0.", 17, "#555")
a('</svg>')
open('folha5.svg','w').write('\n'.join(s))
