# Folha 1: mapa do Arduino Nano (vista de cima, USB para cima)
W, H = 1800, 1220
esq = ["D13","3V3","REF","A0","A1","A2","A3","A4","A5","A6","A7","5V","RST","GND","VIN"]
dir_ = ["D12","D11","D10","D9","D8","D7","D6","D5","D4","D3","D2","GND","RST","RX0","TX1"]
# o que liga em cada pino: (texto, cor)
C = {"sig":"#1f6feb","v5":"#d1242f","gnd":"#24292f","mot":"#a333c8","fim":"#1a7f37","led":"#d97706","btn":"#0e7490","fx":"#b45309"}
uso_esq = {"A0":("AO do sensor de feixe (diagnóstico)", C["fx"]),
           "5V":("VCC dos sensores  •  R_EN + L_EN + VCC da ponte H", C["v5"]),
           "GND":("GND comum (sensores, ponte H, fontes, chaves)", C["gnd"])}
uso_dir = {"D12":("Botão MENU / CONFIG (outro lado no GND)", C["btn"]),
           "D11":("FIM CIMA: OUT do sensor IR (+100k ao GND)", C["fim"]),
           "D10":("Ponte H  LPWM  →  SOBE (com velocidade)", C["mot"]),
           "D9":("Ponte H  RPWM  →  DESCE (com velocidade)", C["mot"]),
           "D6":("Fita LED DIREITA — DIN (com 330 Ω)", C["led"]),
           "D5":("Fita LED ESQUERDA — DIN (com 330 Ω)", C["led"]),
           "D4":("DO do sensor de feixe (medida do soco)", C["fx"]),
           "D3":("Botão CRÉDITO (outro lado no GND)", C["btn"]),
           "D2":("Botão START (outro lado no GND)", C["btn"]),
           "GND":("GND dos botões", C["gnd"])}
bx, by, bw = 760, 250, 280
passo = 46
y0 = by + 70
s = []
a = s.append
a(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="DejaVu Sans, Arial">')
a(f'<rect width="{W}" height="{H}" fill="#ffffff"/>')
a('<text x="60" y="70" font-size="40" font-weight="bold" fill="#111">PUNCH CHALLENGE — MAPA DO ARDUINO NANO</text>')
a('<text x="60" y="108" font-size="21" fill="#555">Firmware ARDUINO_SENSOR_DE_FEIXE_LM393.ino (V6) • placa vista de cima, conector USB para cima • confira sempre o NOME impresso ao lado de cada pino</text>')
# placa
ph = y0 + passo*14 + 60 - by
a(f'<rect x="{bx}" y="{by}" width="{bw}" height="{ph}" rx="18" fill="#0b5cad" stroke="#073f78" stroke-width="4"/>')
a(f'<rect x="{bx+bw/2-55}" y="{by-46}" width="110" height="80" rx="8" fill="#c9ced6" stroke="#8a929c" stroke-width="3"/>')
a(f'<text x="{bx+bw/2}" y="{by-6}" text-anchor="middle" font-size="20" font-weight="bold" fill="#333">USB</text>')
a(f'<rect x="{bx+95}" y="{by+ph/2-60}" width="90" height="90" rx="6" fill="#1b1f24"/>')
a(f'<text x="{bx+bw/2}" y="{by+ph/2-6}" text-anchor="middle" font-size="16" fill="#9aa4ae">ATmega</text>')
a(f'<text x="{bx+bw/2}" y="{by+ph/2+14}" text-anchor="middle" font-size="16" fill="#9aa4ae">328P</text>')
a(f'<text x="{bx+bw/2}" y="{by+ph-24}" text-anchor="middle" font-size="22" font-weight="bold" fill="#fff">ARDUINO NANO</text>')
def pino(x, y, nome, lado, uso):
    usado = uso is not None
    cor = uso[1] if usado else "#c4c9cf"
    a(f'<circle cx="{x}" cy="{y}" r="11" fill="{"#f2c94c" if usado else "#e3e6ea"}" stroke="#7a5c00" stroke-width="2"/>')
    tx = x + 24 if lado == "e" else x - 24
    anc = "start" if lado == "e" else "end"
    a(f'<text x="{tx}" y="{y+7}" text-anchor="{anc}" font-size="19" font-weight="bold" fill="#fff">{nome}</text>')
    if usado:
        if lado == "e":
            x2 = 70
            a(f'<line x1="{x-11}" y1="{y}" x2="{x2+620}" y2="{y}" stroke="{cor}" stroke-width="5"/>')
            a(f'<rect x="{x2}" y="{y-21}" width="620" height="42" rx="21" fill="{cor}"/>')
            a(f'<text x="{x2+20}" y="{y+7}" font-size="18" font-weight="bold" fill="#fff">{nome}  ←  {uso[0]}</text>')
        else:
            x2 = 1100
            a(f'<line x1="{x+11}" y1="{y}" x2="{x2}" y2="{y}" stroke="{cor}" stroke-width="5"/>')
            a(f'<rect x="{x2}" y="{y-21}" width="600" height="42" rx="21" fill="{cor}"/>')
            a(f'<text x="{x2+20}" y="{y+7}" font-size="18" font-weight="bold" fill="#fff">{nome}  →  {uso[0]}</text>')
    else:
        lx = x - 40 if lado == "e" else x + 40
        a(f'<text x="{lx}" y="{y+6}" text-anchor="{"end" if lado=="e" else "start"}" font-size="15" fill="#9aa1a9">livre</text>')
for i, n in enumerate(esq):
    pino(bx + 26, y0 + i*passo, n, "e", uso_esq.get(n) if not (n == "GND" and False) else None)
for i, n in enumerate(dir_):
    pino(bx + bw - 26, y0 + i*passo, n, "d", uso_dir.get(n))
# legenda
ly = H - 130
a(f'<rect x="60" y="{ly-40}" width="{W-120}" height="130" rx="14" fill="#f6f8fa" stroke="#d0d7de"/>')
leg = [("5V",C["v5"]),("GND",C["gnd"]),("Sensor de feixe",C["fx"]),("Ponte H / motor",C["mot"]),("Fim de curso (cima)",C["fim"]),("Fitas de LED",C["led"]),("Botões",C["btn"])]
x = 90
for t, c in leg:
    a(f'<rect x="{x}" y="{ly-18}" width="34" height="20" rx="4" fill="{c}"/>')
    a(f'<text x="{x+44}" y="{ly}" font-size="19" fill="#222">{t}</text>')
    x += 70 + len(t)*11
a(f'<text x="90" y="{ly+40}" font-size="18" fill="#444">Pinos em amarelo = usados. O motor e as fitas NUNCA são alimentados pelo 5V do Nano: cada um tem fonte própria, com o GND ligado ao GND do Nano.</text>')
a(f'<text x="90" y="{ly+68}" font-size="18" fill="#444">Os dois GND do Nano são o mesmo ponto. A ordem dos pinos é a do Nano comum (clone CH340 igual); se a sua placa for diferente, vale o nome impresso.</text>')
a('</svg>')
open('folha1.svg','w').write('\n'.join(s))
