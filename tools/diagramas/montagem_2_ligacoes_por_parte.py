W, H = 1800, 1930
C = {"sig":"#1f6feb","v5":"#d1242f","gnd":"#24292f","mot":"#a333c8","fim":"#1a7f37","led":"#d97706","btn":"#0e7490","fx":"#b45309","pot":"#c2410c"}
s=[]; a=s.append
a(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="DejaVu Sans, Arial">')
a(f'<rect width="{W}" height="{H}" fill="#ffffff"/>')
a('<text x="60" y="70" font-size="40" font-weight="bold" fill="#111">PUNCH CHALLENGE — LIGAÇÕES, PARTE POR PARTE</text>')
a('<text x="60" y="106" font-size="21" fill="#555">Cada fio sai de um terminal do componente e vai para o pino do Arduino Nano com o MESMO nome da etiqueta. Cores iguais às do mapa do Nano.</text>')
def painel(x, y, w, h, titulo, cor):
    a(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="16" fill="#fbfcfd" stroke="#d0d7de" stroke-width="2"/>')
    a(f'<rect x="{x}" y="{y}" width="{w}" height="54" rx="16" fill="{cor}"/>')
    a(f'<rect x="{x}" y="{y+30}" width="{w}" height="24" fill="{cor}"/>')
    a(f'<text x="{x+22}" y="{y+37}" font-size="23" font-weight="bold" fill="#fff">{titulo}</text>')
def tag(x, y, texto, cor):   # etiqueta do pino do Nano
    w = 30 + len(texto)*11.5
    a(f'<rect x="{x}" y="{y-18}" width="{w}" height="36" rx="18" fill="{cor}"/>')
    a(f'<text x="{x+w/2}" y="{y+7}" text-anchor="middle" font-size="18" font-weight="bold" fill="#fff">{texto}</text>')
    return w
def fio(pts, cor, larg=5, tracejado=False):
    d = "M" + " L".join(f"{p[0]},{p[1]}" for p in pts)
    traco = ' stroke-dasharray="12 7"' if tracejado else ''
    a(f'<path d="{d}" fill="none" stroke="{cor}" stroke-width="{larg}" stroke-linejoin="round" stroke-linecap="round"{traco}/>')
def texto(x, y, t, tam=17, cor="#333", peso="normal", anc="start"):
    a(f'<text x="{x}" y="{y}" font-size="{tam}" fill="{cor}" font-weight="{peso}" text-anchor="{anc}">{t}</text>')
def terminal(x, y, nome, lado="d"):
    a(f'<circle cx="{x}" cy="{y}" r="7" fill="#e9c46a" stroke="#8a6d1f" stroke-width="2"/>')
    if lado == "d":
        texto(x-14, y+6, nome, 16, "#fff", "bold", "end")
    else:
        texto(x+14, y+6, nome, 16, "#fff", "bold", "start")

PW, PH = 820, 560
X1, X2 = 60, 920
Y1, Y2, Y3 = 140, 730, 1320

# ---------------- A: sensor de feixe
painel(X1, Y1, PW, PH, "1. SENSOR DE FEIXE (módulo de fenda LM393)", C["fx"])
mx, my = X1+60, Y1+200
a(f'<rect x="{mx}" y="{my}" width="300" height="230" rx="12" fill="#1f4e8c" stroke="#123661" stroke-width="3"/>')
# garfo
a(f'<rect x="{mx+30}" y="{my-60}" width="44" height="120" rx="6" fill="#2b2b2b"/><rect x="{mx+110}" y="{my-60}" width="44" height="120" rx="6" fill="#2b2b2b"/>')
fio([(mx+74, my-20), (mx+110, my-20)], "#e5484d", 3, True)
a(f'<rect x="{mx+82}" y="{my-90}" width="20" height="70" fill="#f2c94c" stroke="#9a7a12"/>')
texto(mx+175, my-70, "palheta de 20 mm (amarela)", 15, "#7a5c00", "bold")
texto(mx+175, my-50, "passa ENTRE as duas torres", 15, "#7a5c00")
a(f'<circle cx="{mx+60}" cy="{my+150}" r="18" fill="#3d82d6" stroke="#fff" stroke-width="3"/>')
texto(mx+60, my+195, "trimpot", 14, "#fff", "normal", "middle")
a(f'<circle cx="{mx+130}" cy="{my+150}" r="8" fill="#5ee35e"/>')
texto(mx+130, my+195, "LED", 14, "#fff", "normal", "middle")
pins = [("VCC", "Nano 5V", C["v5"]), ("GND", "Nano GND", C["gnd"]), ("DO", "Nano D4", C["fx"]), ("AO", "Nano A0", C["fx"])]
for i, (n, t, c) in enumerate(pins):
    py = my + 50 + i*44
    terminal(mx+300, py, n)
    fio([(mx+307, py), (X1+PW-250, py)], c, 5, n == "AO")
    tag(X1+PW-250, py, t, c)
texto(X1+30, Y1+PH-60, "• Gire o trimpot até o LED do módulo mudar quando um cartão passa na fenda.", 16)
texto(X1+30, Y1+PH-34, "• AO é opcional (diagnóstico na Central). Use sensor de fenda ou infravermelho, não LDR.", 16)

# ---------------- B: botões
painel(X2, Y1, PW, PH, "2. BOTÕES DO GABINETE (contato NA)", C["btn"])
bot = [("START", "Nano D2"), ("CRÉDITO", "Nano D3"), ("MENU / CONFIG", "Nano D12")]
for i, (n, t) in enumerate(bot):
    cy = Y1 + 130 + i*105
    cx = X2 + 120
    a(f'<circle cx="{cx}" cy="{cy}" r="38" fill="#e5484d" stroke="#8b1d22" stroke-width="4"/><circle cx="{cx}" cy="{cy}" r="26" fill="#f07075"/>')
    texto(cx, cy+60, n, 16, "#222", "bold", "middle")
    a(f'<rect x="{cx+70}" y="{cy-30}" width="120" height="60" rx="6" fill="#555"/>')
    texto(cx+130, cy-36, "micro chave", 13, "#666", "normal", "middle")
    a(f'<circle cx="{cx+92}" cy="{cy+18}" r="6" fill="#e9c46a"/><circle cx="{cx+168}" cy="{cy+18}" r="6" fill="#e9c46a"/>')
    texto(cx+92, cy+4, "C", 13, "#fff", "bold", "middle"); texto(cx+168, cy+4, "NA", 13, "#fff", "bold", "middle")
    fio([(cx+168, cy+18), (cx+230, cy+18), (cx+230, cy), (X2+PW-200, cy)], C["btn"])
    tag(X2+PW-200, cy, t, C["btn"])
    fio([(cx+92, cy+18), (cx+92, cy+40), (X2+300, cy+40)], C["gnd"], 4)
fio([(X2+300, Y1+170), (X2+300, Y1+380), (X2+PW-200, Y1+380)], C["gnd"], 4)
for i in range(3):
    a(f'<circle cx="{X2+300}" cy="{Y1+170+i*105}" r="6" fill="{C["gnd"]}"/>')
tag(X2+PW-200, Y1+380, "Nano GND", C["gnd"])
texto(X2+30, Y1+PH-34, "• Terminal C (comum) de todas as chaves junto no GND; terminal NA no pino. Pull-up interno.", 16)

# ---------------- C: ponte H
painel(X1, Y2, PW, PH, "3. PONTE H BTS7960 (placa BT_2) + MOTOR", C["mot"])
hx, hy = X1+300, Y2+90
a(f'<rect x="{hx}" y="{hy}" width="230" height="400" rx="10" fill="#1565c0" stroke="#0d3c7a" stroke-width="3"/>')
a(f'<rect x="{hx+20}" y="{hy+20}" width="190" height="80" rx="6" fill="#2b2b2b"/>')
texto(hx+115, hy+56, "BT_2", 17, "#ddd", "bold", "middle"); texto(hx+115, hy+80, "conector 2×4", 13, "#bbb", "normal", "middle")
ctl = [("RPWM", "Nano D9  (DESCE)", C["mot"]), ("LPWM", "Nano D10  (SOBE)", C["mot"]), ("R_EN", "Nano 5V", C["v5"]), ("L_EN", "Nano 5V", C["v5"]),
       ("R_IS", "livre", "#9aa1a9"), ("L_IS", "livre", "#9aa1a9"), ("VCC", "Nano 5V", C["v5"]), ("GND", "Nano GND", C["gnd"])]
for i, (n, t, c) in enumerate(ctl):
    py = hy + 120 + i*38
    terminal(hx+230, py, n)
    if t == "livre":
        texto(hx+250, py+6, "livre (não ligar)", 14, "#8a9199")
        continue
    fio([(hx+237, py), (X1+PW-235, py)], c, 4)
    tag(X1+PW-235, py, t, c)
# lado de potência
pw_ = [("B+", 0), ("B-", 1), ("M+", 2), ("M-", 3)]
for n, i in pw_:
    py = hy + 150 + i*52
    a(f'<rect x="{hx-22}" y="{py-14}" width="22" height="28" fill="#2f7d32"/>')
    terminal(hx, py, n, "e")
# fonte do motor
fx_, fy_ = X1+40, Y2+120
a(f'<rect x="{fx_}" y="{fy_}" width="150" height="110" rx="8" fill="#e6e9ed" stroke="#6b7280" stroke-width="2"/>')
texto(fx_+75, fy_+38, "FONTE", 17, "#222", "bold", "middle"); texto(fx_+75, fy_+62, "DO MOTOR", 17, "#222", "bold", "middle"); texto(fx_+75, fy_+88, "(12 V do motor)", 14, "#555", "normal", "middle")
a(f'<rect x="{fx_+150}" y="{fy_+16}" width="40" height="18" rx="4" fill="#fff" stroke="#999"/>'); texto(fx_+170, fy_+12, "fusível", 13, "#555", "normal", "middle")
fio([(fx_+150, fy_+25), (fx_+150+0, fy_+25)], C["v5"], 5)
fio([(fx_+190, fy_+25), (hx-60, fy_+25), (hx-60, hy+150), (hx-22, hy+150)], C["v5"], 6)
fio([(fx_+150, fy_+90), (hx-80, fy_+90), (hx-80, hy+202), (hx-22, hy+202)], C["gnd"], 6)
# motor
mx2, my2 = X1+120, Y2+395
a(f'<circle cx="{mx2}" cy="{my2}" r="50" fill="#9ca3af" stroke="#4b5563" stroke-width="4"/><circle cx="{mx2}" cy="{my2}" r="14" fill="#4b5563"/>')
texto(mx2, my2+76, "MOTOR DO SACO", 16, "#222", "bold", "middle")
fio([(hx-22, hy+254), (hx-100, hy+254), (hx-100, my2-20), (mx2+50, my2-20)], C["mot"], 6)
fio([(hx-22, hy+306), (hx-120, hy+306), (hx-120, my2+20), (mx2+50, my2+20)], "#6b21a8", 6)
texto(X1+30, Y2+PH-36, "• D9 e D10 levam o pulso (PWM): a largura dele é a VELOCIDADE. Conector 2×4: MONTAGEM_4.", 16)
texto(X1+30, Y2+PH-12, "• Se o saco DESCER quando manda SUBIR: inverta M+ e M− (não mexa no D9/D10).", 16)

# ---------------- D: fins de curso
painel(X2, Y2, PW, PH, "4. FIM DE CURSO: SÓ O DE CIMA (sensor IR)", C["fim"])
def chave(x, y, titulo, usa, pino, opc, nota1, nota2, cor_nota):
    texto(x, y-122, nota1, 17, cor_nota, "bold")
    texto(x, y-100, nota2, 15, "#444")
    a(f'<rect x="{x}" y="{y}" width="180" height="80" rx="8" fill="#2d333b"/>')
    fio([(x+20, y), (x+150, y-45)], "#9aa1a9", 6)
    a(f'<circle cx="{x+156}" cy="{y-48}" r="13" fill="#d0d7de" stroke="#6b7280" stroke-width="3"/>')
    texto(x+110, y-66, "rolete", 13, "#555", "normal", "middle")
    texto(x+90, y+47, titulo, 17, "#fff", "bold", "middle")
    for j, n in enumerate(["C", "NA", "NF"]):
        tx = x + 30 + j*60
        a(f'<rect x="{tx-10}" y="{y+80}" width="20" height="26" fill="#c9a227"/>')
        texto(tx, y+126, n, 16, "#222", "bold", "middle")
    idx = {"NA": 1, "NF": 2}[usa]
    px = x + 30 + idx*60
    fio([(px, y+132), (px, y+175), (x+200, y+175)], C["fim"], 5, opc)
    tag(x+200, y+175, pino, C["fim"])
    fio([(x+30, y+132), (x+30, y+225), (x+200, y+225)], C["gnd"], 4)
    tag(x+200, y+225, "Nano GND", C["gnd"])
    livre = [n for n in ("NA", "NF") if n != usa][0]
    texto(x+30 + (1 if livre == "NA" else 2)*60, y+150, "livre", 13, "#8a9199", "normal", "middle")
def sensor_ir(x, y):
    texto(x, y-122, "CIMA: OBRIGATÓRIO", 17, C["fim"], "bold")
    texto(x, y-100, "sensor infravermelho (3 pinos)", 15, "#444")
    # LEDs (emissor transparente e receptor preto) olhando para cima
    a(f'<rect x="{x+40}" y="{y-46}" width="30" height="50" rx="14" fill="#e8f1fb" stroke="#8aa4c0" stroke-width="2"/>')
    a(f'<rect x="{x+110}" y="{y-46}" width="30" height="50" rx="14" fill="#2b2f36"/>')
    a(f'<rect x="{x}" y="{y}" width="180" height="80" rx="8" fill="#1565c0" stroke="#0d3c7a" stroke-width="3"/>')
    a(f'<rect x="{x+20}" y="{y+18}" width="40" height="40" rx="4" fill="#2f6fd6" stroke="#0d3c7a" stroke-width="2"/>')
    a(f'<circle cx="{x+40}" cy="{y+38}" r="12" fill="#e8eef7"/>')
    a(f'<rect x="{x+80}" y="{y+22}" width="34" height="36" rx="3" fill="#1f2328"/>')
    a(f'<rect x="{x+132}" y="{y+18}" width="14" height="9" rx="2" fill="#ff5a5a"/>')
    a(f'<rect x="{x+132}" y="{y+52}" width="14" height="9" rx="2" fill="#3ddc84"/>')
    for j, n in enumerate(["VCC", "GND", "OUT"]):
        tx = x + 30 + j*60
        a(f'<rect x="{tx-10}" y="{y+80}" width="20" height="26" fill="#c9a227"/>')
        texto(tx, y+126, n, 15, "#222", "bold", "middle")
    # OUT -> D11, GND -> GND, VCC -> 5V
    fio([(x+150, y+132), (x+150, y+160), (x+200, y+160)], C["fim"], 5)
    tag(x+200, y+160, "Nano D11", C["fim"])
    fio([(x+90, y+132), (x+90, y+205), (x+200, y+205)], C["gnd"], 4)
    tag(x+200, y+205, "Nano GND", C["gnd"])
    fio([(x+30, y+132), (x+30, y+250), (x+200, y+250)], C["v5"], 4)
    tag(x+200, y+250, "Nano 5V", C["v5"])
    # resistor de 100k entre D11 e GND
    xr = x + 182
    a(f'<circle cx="{xr}" cy="{y+160}" r="5" fill="{C["fim"]}"/>')
    a(f'<circle cx="{xr}" cy="{y+205}" r="5" fill="{C["gnd"]}"/>')
    a(f'<rect x="{xr-7}" y="{y+167}" width="14" height="30" rx="5" fill="#e9d8b4" stroke="#9a6700" stroke-width="2"/>')
    texto(xr-14, y+188, "100k", 14, "#9a6700", "bold", "end")
sensor_ir(X2+40, Y2+205)
a(f'<rect x="{X2+440}" y="{Y2+110}" width="340" height="250" rx="12" fill="#f6f8fa" stroke="#d0d7de" stroke-width="2" stroke-dasharray="8 6"/>')
texto(X2+610, Y2+160, "EMBAIXO: NADA", 19, "#57606a", "bold", "middle")
texto(X2+610, Y2+200, "A descida termina pelo", 16, "#444", "normal", "middle")
texto(X2+610, Y2+224, "TEMPO DE CURSO", 16, "#444", "bold", "middle")
texto(X2+610, Y2+248, "(Central, aba SACO).", 16, "#444", "normal", "middle")
texto(X2+610, Y2+292, "O sensor só vê quando", 15, "#666", "normal", "middle")
texto(X2+610, Y2+314, "o saco subiu o máximo.", 15, "#666", "normal", "middle")
texto(X2+30, Y2+PH-60, "• CIMA vê o alvo branco no braço e o motor corta na hora (detalhe: MONTAGEM_5).", 16)
texto(X2+30, Y2+PH-34, "• Resistor de 100k do D11 ao GND, no borne do Nano: fio OUT solto = não sobe.", 16)

# ---------------- E: fitas
painel(X1, Y3, PW, PH, "5. FITAS DE LED WS2812B (30 LEDs cada)", C["led"])
for i, (lado, pino) in enumerate([("ESQUERDA", "Nano D5"), ("DIREITA", "Nano D6")]):
    fy = Y3 + 120 + i*150
    a(f'<rect x="{X1+40}" y="{fy}" width="300" height="46" rx="6" fill="#1b1f24"/>')
    for k in range(7):
        a(f'<rect x="{X1+58+k*40}" y="{fy+10}" width="26" height="26" rx="4" fill="#fff6d6" stroke="#d97706"/>')
    texto(X1+190, fy-10, f"fita {lado}", 16, "#222", "bold", "middle")
    for j, (n, c) in enumerate([("+5V", C["v5"]), ("DIN", C["led"]), ("GND", C["gnd"])]):
        ty = fy + 66 + j*0
    # DIN com resistor
    fio([(X1+340, fy+23), (X1+400, fy+23)], C["led"], 5)
    a(f'<rect x="{X1+400}" y="{fy+11}" width="70" height="24" rx="5" fill="#e8d5a8" stroke="#8a6d1f" stroke-width="2"/>')
    texto(X1+435, fy+5, "330 Ω", 14, "#5a4510", "bold", "middle")
    fio([(X1+470, fy+23), (X1+PW-200, fy+23)], C["led"], 5)
    tag(X1+PW-200, fy+23, pino, C["led"])
    texto(X1+350, fy+60, "DIN", 14, "#555")
fy = Y3 + 400
a(f'<rect x="{X1+40}" y="{fy-40}" width="200" height="70" rx="8" fill="#e6e9ed" stroke="#6b7280" stroke-width="2"/>')
texto(X1+140, fy-10, "FONTE 5 V", 17, "#222", "bold", "middle"); texto(X1+140, fy+14, "3 A ou mais", 14, "#555", "normal", "middle")
texto(X1+260, fy-14, "+5V → +5V das duas fitas", 16, C["v5"], "bold")
texto(X1+260, fy+10, "GND → GND das fitas e Nano GND", 16, C["gnd"], "bold")
texto(X1+30, Y3+PH-12, "• 1000 µF entre +5V e GND na entrada das fitas. NUNCA alimentar as fitas pelo 5V do Nano.", 16)

# ---------------- F: USB
painel(X2, Y3, PW, PH, "6. ARDUINO, TV BOX E CÂMERA (USB)", "#57606a")
def caixa(x, y, w, h, t1, t2, cor):
    a(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="10" fill="{cor}" stroke="#4b5563" stroke-width="2"/>')
    texto(x+w/2, y+h/2-4, t1, 18, "#fff", "bold", "middle"); texto(x+w/2, y+h/2+20, t2, 14, "#eef", "normal", "middle")
caixa(X2+40, Y3+110, 200, 90, "ARDUINO NANO", "firmware V6", "#0b5cad")
caixa(X2+330, Y3+110, 200, 90, "HUB USB", "COM fonte própria", "#57606a")
caixa(X2+600, Y3+110, 190, 90, "TV BOX", "Android", "#1b1f24")
caixa(X2+330, Y3+290, 200, 90, "WEBCAM UVC", "câmera do ranking", "#6e7781")
fio([(X2+240, Y3+155), (X2+330, Y3+155)], "#6e7781", 6); fio([(X2+530, Y3+155), (X2+600, Y3+155)], "#6e7781", 6)
fio([(X2+430, Y3+200), (X2+430, Y3+290)], "#6e7781", 6)
texto(X2+30, Y3+440, "• Na primeira vez, aceite as janelas de permissão USB e CÂMERA na TV Box.", 16)
texto(X2+30, Y3+466, "• Hub sem fonte própria não segura câmera + Arduino: use hub alimentado.", 16)
a('</svg>')
open('folha2.svg','w').write('\n'.join(s))
