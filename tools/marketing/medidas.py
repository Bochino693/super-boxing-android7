"""As medidas dos gabinetes do SUPER BOXING (em centimetros).

Um lugar so: os adesivos (tamanho de cada peca), o desenho tecnico e os
renders 3D (tools/marketing/gabinete3d) leem daqui. Mudou uma medida, rode
de novo os geradores.

Convencao: X = profundidade, medida da parede de tras (0) para a frente;
Y = altura a partir do chao. Largura = W (o gabinete e simetrico).

O DESENHO: a TV grande EM PE no meio do gabinete e o saco vindo de cima,
pendurado BEM NA FRENTE da tela. O braco do saco gira no eixo do CAPO (a
cobertura de cima, que avanca sobre o jogador e leva o motor, o sensor de
feixe e o letreiro luminoso na frente). Para jogar o motor desce o braco e o
saco fica na frente do lutador da tela; para guardar, sobe o braco ate a
horizontal, para a frente (docs/MONTAGEM_3_MECANICA.png). No soco o saco
balanca para tras ate o batente, sem chegar na tela: entre o saco e a TV ha
folga e um acrilico de protecao.
"""
from __future__ import annotations

import json
from pathlib import Path

MODELOS = {
    "torre": {
        "nome": "SUPER BOXING TORRE",
        "resumo": "TV 40\" em pé no meio, saco a 1,38 m bem na frente da tela",
        "W": 78.0,                 # largura total
        "H": 224.0,                # altura total
        "chapa": 1.8,              # MDF 18 mm
        "pedestal": {"y1": 95.0, "x1": 74.0},
        "comando": {"y_frente": 96.0, "x_frente": 76.0, "y_tras": 106.0, "x_tras": 58.0},
        # a TV em pe: face (acrilico) em x, base em y0
        "tv": {"pol": 40, "vis_w": 49.8, "vis_h": 88.5, "ext_w": 52.5, "ext_h": 91.0, "y0": 108.0, "x": 56.0},
        "capo": {"y0": 203.0, "y1": 222.0, "x1": 114.0},
        "eixo": {"x": 101.0, "y": 210.0},
        "saco": {"altura": 45.0, "diametro": 30.0, "topo": 160.0},
        "letreiro": {"y0": 204.0, "y1": 221.0},        # na frente do capo, luminoso
        "camera": {"y": 200.5},                         # embaixo do letreiro
        "som": {"diam": 10.0, "y": 82.0, "dx": 19.0},   # 2 alto-falantes de 4"
        "porta_cofre": {"y0": 14.0, "y1": 52.0, "w": 36.0},
        "start": {"diam": 6.0, "dx": -15.0},            # no painel de comando, a partir do centro
        "moedeiro": {"w": 4.0, "h": 9.0, "dx": 17.0},
        # perfil da lateral (pontos grossos; a curva sai suavizada)
        "lateral": [
            (0.0, 0.0), (77.0, 0.0), (77.0, 95.0), (60.0, 107.0), (58.5, 122.0), (60.0, 180.0),
            (68.0, 196.0), (88.0, 201.0), (116.0, 202.0), (116.0, 224.0), (0.0, 224.0),
        ],
        "cantos_vivos": [0, 1, 2, 8, 9, 10],
    },
    "compacto": {
        "nome": "SUPER BOXING COMPACTO",
        "resumo": "TV 32\" em pé no meio, saco a 1,30 m (família, buffet e adolescentes)",
        "W": 66.0,
        "H": 196.0,
        "chapa": 1.8,
        "pedestal": {"y1": 88.0, "x1": 66.0},
        "comando": {"y_frente": 89.0, "x_frente": 68.0, "y_tras": 98.0, "x_tras": 52.0},
        "tv": {"pol": 32, "vis_w": 39.9, "vis_h": 70.9, "ext_w": 41.9, "ext_h": 73.4, "y0": 100.0, "x": 50.0},
        "capo": {"y0": 177.0, "y1": 194.0, "x1": 100.0},
        "eixo": {"x": 89.0, "y": 183.5},
        "saco": {"altura": 40.0, "diametro": 27.0, "topo": 150.0},
        "letreiro": {"y0": 178.0, "y1": 193.0},
        "camera": {"y": 174.5},
        "som": {"diam": 8.0, "y": 76.0, "dx": 15.0},
        "porta_cofre": {"y0": 12.0, "y1": 46.0, "w": 30.0},
        "start": {"diam": 6.0, "dx": -12.0},
        "moedeiro": {"w": 4.0, "h": 9.0, "dx": 13.0},
        "lateral": [
            (0.0, 0.0), (68.0, 0.0), (68.0, 88.0), (54.0, 99.0), (52.5, 112.0), (54.0, 158.0),
            (61.0, 171.0), (78.0, 176.0), (102.0, 176.0), (102.0, 196.0), (0.0, 196.0),
        ],
        "cantos_vivos": [0, 1, 2, 8, 9, 10],
    },
}


def perfil(modelo: str, passos: int = 4) -> list[tuple[float, float]]:
    """O contorno da lateral, suavizado (Chaikin) mantendo os cantos vivos."""
    m = MODELOS[modelo]
    pts = [tuple(p) for p in m["lateral"]]
    vivos = set(m["cantos_vivos"])
    marcados = [(p, i in vivos) for i, p in enumerate(pts)]
    for _ in range(passos):
        novo = []
        n = len(marcados)
        for i in range(n):
            p, vivo = marcados[i]
            q, vivo_q = marcados[(i + 1) % n]
            if vivo:
                novo.append((p, True))
            if not (vivo and vivo_q):
                a = (p[0] * 0.75 + q[0] * 0.25, p[1] * 0.75 + q[1] * 0.25)
                b = (p[0] * 0.25 + q[0] * 0.75, p[1] * 0.25 + q[1] * 0.75)
                if not vivo:
                    novo.append((a, False))
                novo.append((b, False)) if not vivo_q else None
            else:
                pass
        marcados = novo
    return [p for p, _ in marcados]


def exportar_json(caminho: Path) -> None:
    dados = {k: dict(v, perfil=perfil(k)) for k, v in MODELOS.items()}
    caminho.write_text(json.dumps(dados, indent=1, ensure_ascii=False), encoding="utf-8")


if __name__ == "__main__":
    import sys
    if "--json" in sys.argv:
        exportar_json(Path(__file__).resolve().parent / "gabinete3d" / "medidas.json")
        print("gravado gabinete3d/medidas.json")
    for k, m in MODELOS.items():
        p = perfil(k)
        print(k, len(p), "pontos; caixa", min(x for x, _ in p), max(x for x, _ in p), max(y for _, y in p))
        sc = m["saco"]
        print("   saco: centro a %.1f cm do chao, %.1f cm na frente da tela" % (
            sc["topo"] - sc["altura"] / 2, m["eixo"]["x"] - m["tv"]["x"]))
