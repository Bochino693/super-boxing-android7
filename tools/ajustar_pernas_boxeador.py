"""As pernas do lutador da TV Box: musculos e o calcao assentado na coxa.

    python tools/ajustar_pernas_boxeador.py

Mexe em assets/lutador3d/boxeador_tvbox.glb NO LUGAR (so numpy). Roda uma
vez: o arquivo ganha uma marca (`asset.extras.pernas`) e uma segunda
execucao nao faz nada.

POR QUE. Na tela da arena as pernas eram dois tubos: a coxa descia reta do
calcao ao joelho, a panturrilha quase nao tinha volta, e a boca do calcao
ficava ~1 cm fora da coxa, com a barra vermelha saltada mais meio
centimetro - um sino com um anel em volta, e o fundo aparecendo entre o
pano e a perna.

O QUE MUDA. Nenhum vertice ou triangulo a mais: so a POSICAO dos que ja
existem (e as normais deles).
  * a coxa ganha o volume dos musculos que desenham a perna de um atleta -
    o quadriceps na frente, a curva de fora (vasto lateral), a gota de
    dentro logo acima do joelho (vasto medial) e o posterior atras;
  * a panturrilha ganha as duas cabecas do gemeo (a de dentro maior e mais
    baixa), afinando para o tornozelo; nada muda dentro da bota;
  * o calcao e a barra vermelha descem ate a pele: a folga entre o pano e a
    coxa encolhe para um terco na boca da perna e volta ao normal ate o
    quadril. A barra fica com 40% do ressalto. As camadas (pele, pano,
    barra) continuam na mesma ordem, entao nada atravessa nada.
Pesos dos ossos, UV, cores e expressoes do rosto nao mudam.
"""
from __future__ import annotations

import json
import struct
from pathlib import Path

import numpy as np

RAIZ = Path(__file__).resolve().parents[1]
ARQUIVO = RAIZ / "assets" / "lutador3d" / "boxeador_tvbox.glb"
MARCA = "pernas-122"

## Musculos: (osso, t ao longo do osso 0..1, angulo em graus em volta do
## osso - 0 e a frente, positivo para FORA da perna, 180 atras -, largura em
## t, largura em graus, quanto cresce em metros).
MUSCULOS = [
    # coxa (t: 0 no quadril, 1 no joelho; a pele aparece a partir de ~0.3)
    ("UpLeg", 0.46, 5.0, 0.22, 55.0, 0.0065),     # quadriceps (reto femoral)
    ("UpLeg", 0.50, 75.0, 0.22, 38.0, 0.0075),    # vasto lateral: a curva de fora
    ("UpLeg", 0.82, -48.0, 0.085, 30.0, 0.0055),  # vasto medial: a gota acima do joelho
    ("UpLeg", 0.52, 180.0, 0.24, 55.0, 0.0040),   # posterior da coxa
    ("UpLeg", 0.40, -95.0, 0.20, 35.0, 0.0030),   # adutores (dentro, em cima)
    ("UpLeg", 0.985, 0.0, 0.04, 40.0, -0.0025),   # acima da patela: o joelho se desenha
    # canela (t: 0 no joelho, 1 no pe; a bota cobre de t ~0.45 para baixo)
    ("Leg", 0.27, -150.0, 0.11, 34.0, 0.0085),    # gemeo, cabeca de dentro
    ("Leg", 0.23, 148.0, 0.10, 30.0, 0.0062),     # gemeo, cabeca de fora
    ("Leg", 0.30, 32.0, 0.14, 26.0, 0.0018),      # tibial anterior
]
## Abaixo desta altura (m) a pele esta dentro da bota: nao mexe.
TOPO_DA_BOTA = 0.30
## A folga pano-pele que fica na boca da perna (fracao da original) e onde o
## ajuste some (alturas em m: da barra ate o quadril).
APERTO_NA_BOCA = 0.36
BOCA, QUADRIL = 0.665, 0.765
## O ressalto da barra vermelha que fica (fracao).
RESSALTO_DA_BARRA = 0.40

TIPOS = {5126: "f4", 5123: "u2", 5121: "u1", 5125: "u4", 5122: "i2", 5120: "i1"}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


class GLB:
    def __init__(self, caminho):
        f = Path(caminho).read_bytes()
        n = struct.unpack("<I", f[12:16])[0]
        self.j = json.loads(f[20:20 + n])
        nb = struct.unpack("<I", f[20 + n:24 + n])[0]
        self.bin = bytearray(f[28 + n:28 + n + nb])

    def _info(self, i):
        a = self.j["accessors"][i]
        bv = self.j["bufferViews"][a["bufferView"]]
        dt = np.dtype(TIPOS[a["componentType"]]).newbyteorder("<")
        nc = NC[a["type"]]
        st = bv.get("byteStride", dt.itemsize * nc)
        return a, dt, nc, st, bv.get("byteOffset", 0) + a.get("byteOffset", 0)

    def ler(self, i):
        a, dt, nc, st, o = self._info(i)
        out = np.empty((a["count"], nc), dtype=dt)
        for k in range(a["count"]):
            out[k] = np.frombuffer(self.bin, dtype=dt, count=nc, offset=o + k * st)
        return out.astype(np.float64) if dt.kind == "f" else out.astype(np.int64)

    def escrever(self, i, valores):
        a, dt, nc, st, o = self._info(i)
        assert dt.kind == "f"
        v = np.asarray(valores, dtype=dt)
        assert v.shape == (a["count"], nc)
        for k in range(a["count"]):
            self.bin[o + k * st:o + k * st + dt.itemsize * nc] = v[k].tobytes()
        if "min" in a:
            a["min"] = [float(x) for x in v.min(0)]
            a["max"] = [float(x) for x in v.max(0)]

    def malha(self, nome):
        for m in self.j["meshes"]:
            if m["name"] == nome:
                return m["primitives"][0]
        raise KeyError(nome)

    def juntas(self):
        sk = self.j["skins"][0]
        nomes = [self.j["nodes"][k]["name"].replace("mixamorig:", "") for k in sk["joints"]]
        ibm = self.ler(sk["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
        return nomes, np.array([np.linalg.inv(m)[:3, 3] for m in ibm])

    def salvar(self, caminho):
        js = json.dumps(self.j, separators=(",", ":")).encode()
        js += b" " * ((4 - len(js) % 4) % 4)
        b = bytes(self.bin) + b"\0" * ((4 - len(self.bin) % 4) % 4)
        with open(caminho, "wb") as f:
            f.write(struct.pack("<III", 0x46546C67, 2, 28 + len(js) + len(b)))
            f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
            f.write(struct.pack("<II", len(b), 0x004E4942) + b)


def normais_suaves(P, tri):
    """Normal por vertice, somando as faces em volta (vertices na mesma
    posicao - as costuras do UV - somam juntos)."""
    _, grupo = np.unique(np.round(P / 1e-6).astype(np.int64), axis=0, return_inverse=True)
    grupo = grupo.ravel()
    fn = np.cross(P[tri[:, 1]] - P[tri[:, 0]], P[tri[:, 2]] - P[tri[:, 0]])
    soma = np.zeros((grupo.max() + 1, 3))
    for k in range(3):
        np.add.at(soma, grupo[tri[:, k]], fn)
    n = soma[grupo]
    return n / (np.linalg.norm(n, axis=1, keepdims=True) + 1e-12)


class Perna:
    """O referencial de um osso da perna: eixo, frente e o lado de fora."""

    def __init__(self, a, b, fora):
        self.a = a
        self.L = np.linalg.norm(b - a)
        self.u = (b - a) / self.L
        frente = np.array([0.0, 0.0, 1.0])
        self.f = frente - self.u * (frente @ self.u)
        self.f /= np.linalg.norm(self.f)
        lado = np.cross(self.u, self.f)
        # positivo = para fora da perna
        self.s = lado if lado @ fora > 0 else -lado

    def coords(self, X):
        d = X - self.a
        t = (d @ self.u) / self.L
        radial = d - np.outer(d @ self.u, self.u)
        r = np.linalg.norm(radial, axis=1)
        ang = np.degrees(np.arctan2(radial @ self.s, radial @ self.f))
        return t, r, ang, radial / (r[:, None] + 1e-12)


def dif_angulo(a, b):
    return (a - b + 180.0) % 360.0 - 180.0


def raio_em(perna, X, t, ang, largura_t=0.05):
    """O raio da superficie `X` em (t, angulo): media ponderada dos vertices
    dela perto dali. Acima da borda de cima (a pele termina dentro do
    calcao) vale o anel mais alto."""
    tp, rp, ap, _ = perna.coords(X)
    tq = np.maximum(t, np.percentile(tp, 2) + 0.02)
    w = np.exp(-((tq[:, None] - tp[None, :]) / largura_t) ** 2
               - (dif_angulo(ang[:, None], ap[None, :]) / 22.0) ** 2)
    return (w @ rp) / (w.sum(1) + 1e-12)


def main():
    g = GLB(ARQUIVO)
    extras = g.j.setdefault("asset", {}).setdefault("extras", {})
    if extras.get("pernas") == MARCA:
        print("o lutador ja esta com as pernas novas (%s): nada a fazer" % MARCA)
        return
    nomes, juntas = g.juntas()
    J = lambda n: juntas[nomes.index(n)]

    def malha(nome):
        p = g.malha(nome)
        a = p["attributes"]
        return dict(p=p, P=g.ler(a["POSITION"]), N=g.ler(a["NORMAL"]),
                    T=g.ler(a["TANGENT"]) if "TANGENT" in a else None,
                    J=g.ler(a["JOINTS_0"]), W=g.ler(a["WEIGHTS_0"]),
                    tri=g.ler(p["indices"]).reshape(-1, 3))

    pele, calcao, friso = malha("Pele"), malha("Calcao"), malha("Friso")
    P0 = pele["P"].copy()
    Pn = pele["P"].copy()
    C0, F0 = calcao["P"].copy(), friso["P"].copy()
    Cn, Fn = C0.copy(), F0.copy()

    for lado, sinal in (("Left", 1.0), ("Right", -1.0)):
        fora = np.array([sinal, 0.0, 0.0])
        coxa = Perna(J(lado + "UpLeg"), J(lado + "Leg"), fora)
        canela = Perna(J(lado + "Leg"), J(lado + "Foot"), fora)
        ossos = {"UpLeg": (coxa, nomes.index(lado + "UpLeg")), "Leg": (canela, nomes.index(lado + "Leg"))}

        # ---- a pele: o volume dos musculos
        delta = np.zeros(len(P0))
        direcao = np.zeros((len(P0), 3))
        for osso, (perna, ij) in ossos.items():
            peso = (pele["W"] * (pele["J"] == ij)).sum(1)
            # a coxa tambem conta a parte da pele que o joelho divide
            m = (peso > 0.05) & (P0[:, 0] * sinal > 0.015) & (P0[:, 1] > TOPO_DA_BOTA)
            t, r, ang, rad = perna.coords(P0[m])
            d = np.zeros(m.sum())
            for o, tc, ac, st, sa, amp in MUSCULOS:
                if o != osso:
                    continue
                d += amp * np.exp(-((t - tc) / st) ** 2 - (dif_angulo(ang, ac) / sa) ** 2)
            # some perto da bota
            d *= np.clip((P0[m, 1] - TOPO_DA_BOTA) / 0.04, 0.0, 1.0)
            idx = np.nonzero(m)[0]
            delta[idx] += d * peso[m]
            direcao[idx] += rad * peso[m][:, None]
        n = np.linalg.norm(direcao, axis=1)
        ok = n > 1e-9
        Pn[ok] += (direcao[ok] / n[ok, None]) * delta[ok, None]

        # ---- o calcao: a folga para a pele encolhe na boca da perna
        def coxa_de(X, ymin=0.55):
            return (X[:, 0] * sinal > 0.0) & (X[:, 1] > ymin) & (X[:, 1] < QUADRIL + 0.03)
        mpele = coxa_de(P0) & (P0[:, 0] * sinal > 0.015)
        mc = coxa_de(C0) & (C0[:, 1] < QUADRIL)
        t, r, ang, rad = coxa.coords(C0[mc])
        r_pele_velha = raio_em(coxa, P0[mpele], t, ang)
        r_pele_nova = raio_em(coxa, Pn[mpele], t, ang)
        k = APERTO_NA_BOCA + (1.0 - APERTO_NA_BOCA) * np.clip((C0[mc, 1] - BOCA) / (QUADRIL - BOCA), 0.0, 1.0)
        folga = r - r_pele_velha
        # nunca encostar: no minimo 2 mm fora da pele nova
        r_alvo = np.where(folga > 0.0, np.maximum(r_pele_nova + folga * k, r_pele_nova + 0.002), r)
        Cn[mc] = C0[mc] + rad * (r_alvo - r)[:, None]

        # ---- a barra: anda junto com o pano que ela cobre (cada vertice
        # segue os quatro do calcao mais perto) e perde parte do ressalto
        mf = coxa_de(F0)
        if mf.any():
            mtodo = np.nonzero(coxa_de(C0))[0]
            d2 = ((F0[mf][:, None, :] - C0[mtodo][None, :, :]) ** 2).sum(2)
            perto = np.argsort(d2, axis=1)[:, :4]
            w = 1.0 / (np.sqrt(np.take_along_axis(d2, perto, 1)) + 1e-4)
            w /= w.sum(1, keepdims=True)
            viz = mtodo[perto]
            anda = ((Cn[viz] - C0[viz]) * w[:, :, None]).sum(1)
            Fs = F0[mf] + anda
            # o pano por baixo da barra, angulo a angulo (de 6 em 6 graus): o
            # ponto mais de fora do calcao naquela faixa de altura
            mc_barra = coxa_de(C0) & (C0[:, 1] < F0[mf, 1].max() + 0.005)
            _, rc, ac, _ = coxa.coords(Cn[mc_barra])
            faixas = np.arange(-180.0, 180.0, 6.0)
            pano = np.array([rc[np.abs(dif_angulo(ac, a)) <= 9.0].max(initial=0.0) for a in faixas])
            # faixa sem vertice do pano: interpola as vizinhas (em volta)
            cheia = pano > 0.0
            pano = np.interp(faixas, faixas[cheia], pano[cheia], period=360.0)
            t, r, ang, rad = coxa.coords(Fs)
            r_pano = pano[np.round((ang + 180.0) / 6.0).astype(int) % len(faixas)]
            fora = r > r_pano
            r_alvo = np.where(fora, r_pano + np.maximum((r - r_pano) * RESSALTO_DA_BARRA, 0.0015), r)
            Fn[mf] = Fs + rad * (r_alvo - r)[:, None]

    # ---- normais (so onde a forma mudou) e tangentes reortogonalizadas
    def gravar(md, Pnovo, nome):
        mudou = np.linalg.norm(Pnovo - md["P"], axis=1) > 1e-7
        if not mudou.any():
            return 0
        Nn = normais_suaves(Pnovo, md["tri"])
        # o vizinho de um vertice que mudou tambem muda de normal
        viz = np.zeros(len(Pnovo), bool)
        for k in range(3):
            viz[md["tri"][mudou[md["tri"]].any(1)][:, k]] = True
        N = md["N"].copy()
        N[viz] = Nn[viz]
        a = md["p"]["attributes"]
        g.escrever(a["POSITION"], Pnovo)
        g.escrever(a["NORMAL"], N)
        if md["T"] is not None:
            T = md["T"].copy()
            t3 = T[viz, :3] - N[viz] * (T[viz, :3] * N[viz]).sum(1, keepdims=True)
            T[viz, :3] = t3 / (np.linalg.norm(t3, axis=1, keepdims=True) + 1e-12)
            g.escrever(a["TANGENT"], T)
        print("%-8s %4d vertices movidos (max %.1f mm)" % (nome, mudou.sum(),
              1000 * np.linalg.norm(Pnovo - md["P"], axis=1).max()))
        return mudou.sum()

    gravar(pele, Pn, "Pele")
    gravar(calcao, Cn, "Calcao")
    gravar(friso, Fn, "Friso")
    extras["pernas"] = MARCA
    g.salvar(ARQUIVO)
    print("ok:", ARQUIVO)


if __name__ == "__main__":
    main()
