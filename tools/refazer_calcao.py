#!/usr/bin/env python3
"""CALÇÃO DE PERNAS RETAS: refaz a malha do calção do boxeador.glb.

    python tools/refazer_calcao.py assets/lutador3d/boxeador.glb [saida.glb]

O calção original foi modelado como uma casca única com o gancho na altura
da barra: as duas pernas ficavam emendadas no meio até embaixo e, com o
lutador em guarda (pernas abertas), o pano entre as coxas esticava como uma
saia — a "boca aberta" da bermuda. Por baixo do calção a pele não existe
(entre 0,72 m e 0,86 m o corpo é oco), então não dá para só apertar o pano.

Aqui o calção é refeito com a costura de uma bermuda de verdade:
  * quadril: mesma forma do original (raios lançados contra a malha antiga);
  * gancho a 0,77–0,79 m, fechado (nada do corpo oco aparece);
  * cada perna um tubo reto em volta da própria coxa, com folga de 2 cm,
    barra justa e dobra para dentro;
  * pesos dos ossos: a perna segue a coxa como a pele; o quadril, como antes;
  * textura nova (cetim preto, faixa lateral vermelha com vivo branco);
  * friso vermelho da barra refeito em cada perna.
Nada mais do arquivo muda (pele, luvas, botas, cinturão, ossos, animações).
"""
import io
import json
import math
import os
import struct
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy.spatial import cKDTree

Y_CINTURA = 0.957     # topo do calção (fica embaixo do cinturão)
Y_GANCHO = 0.790      # onde as pernas se separam (lados)
CAIDA_GANCHO = 0.022  # o gancho desce isto no meio (entre as pernas)
Y_BARRA = 0.636       # barra das pernas
FOLGA = 0.020         # pano a 2 cm da coxa
FOLGA_MIN = 0.011     # nunca mais perto que isto
N_QUADRIL = 64        # pontos em volta do quadril
ANEIS_QUADRIL = 9
ANEIS_PERNA = 12
COSTURA = 9           # pontos internos da costura do gancho
COR_FRISO = (0.78, 0.05, 0.09)
ADIANTE_QUADRIL = 0.045   # faixa do quadril 16° à frente da lateral
ADIANTE_PERNA = 0.060     # faixa da perna 22° à frente da lateral


# ------------------------------------------------------------------ glb
class Glb:
    def __init__(self, caminho):
        d = open(caminho, "rb").read()
        n = struct.unpack("<I", d[12:16])[0]
        self.j = json.loads(d[20:20 + n])
        bl = struct.unpack("<I", d[20 + n:24 + n])[0]
        self.bin = d[28 + n:28 + n + bl]
        self.novos = {}   # bufferView -> bytes

    def ler(self, i):
        a = self.j["accessors"][i]
        bv = self.j["bufferViews"][a["bufferView"]]
        tipo = {5126: "f4", 5123: "u2", 5121: "u1", 5125: "u4"}[a["componentType"]]
        nc = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]]
        dt = np.dtype("<" + tipo)
        passo = bv.get("byteStride", dt.itemsize * nc)
        off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        arr = np.frombuffer(self.bin, dtype=dt, count=a["count"] * passo // dt.itemsize, offset=off)
        return arr.reshape(a["count"], passo // dt.itemsize)[:, :nc].copy()

    def trocar(self, i, valores, tipo):
        """Troca os dados do acessor i (ele tem um bufferView só dele)."""
        a = self.j["accessors"][i]
        dt = np.dtype("<" + tipo)
        valores = np.ascontiguousarray(valores, dtype=dt)
        a["count"] = int(valores.shape[0])
        a["byteOffset"] = 0
        if a["type"] != "SCALAR" and a.get("min") is not None or "min" in a:
            if tipo == "f4":
                a["min"] = [float(x) for x in valores.reshape(a["count"], -1).min(axis=0)]
                a["max"] = [float(x) for x in valores.reshape(a["count"], -1).max(axis=0)]
            else:
                a.pop("min", None)
                a.pop("max", None)
        bv = self.j["bufferViews"][a["bufferView"]]
        bv.pop("byteStride", None)
        self.novos[a["bufferView"]] = valores.tobytes()

    def trocar_imagem(self, i, dados, mime):
        img = self.j["images"][i]
        img["mimeType"] = mime
        self.novos[img["bufferView"]] = dados

    def salvar(self, caminho):
        saida = bytearray()
        for k, bv in enumerate(self.j["bufferViews"]):
            if k in self.novos:
                dados = self.novos[k]
            else:
                o = bv.get("byteOffset", 0)
                dados = self.bin[o:o + bv["byteLength"]]
            while len(saida) % 4:
                saida.append(0)
            bv["byteOffset"] = len(saida)
            bv["byteLength"] = len(dados)
            saida += dados
        while len(saida) % 4:
            saida.append(0)
        self.j["buffers"][0]["byteLength"] = len(saida)
        texto = json.dumps(self.j, separators=(",", ":")).encode()
        texto += b" " * ((4 - len(texto) % 4) % 4)
        corpo = struct.pack("<I", len(texto)) + b"JSON" + texto + struct.pack("<I", len(saida)) + b"BIN\x00" + bytes(saida)
        open(caminho, "wb").write(b"glTF" + struct.pack("<II", 2, 12 + len(corpo)) + corpo)


# ------------------------------------------------------------------ geometria
def raios_contra_malha(origens, direcoes, P, F):
    """Distância do ponto mais longe em que cada raio corta a malha (ou nan)."""
    v0, v1, v2 = P[F[:, 0]], P[F[:, 1]], P[F[:, 2]]
    e1, e2 = v1 - v0, v2 - v0
    res = np.full(len(origens), np.nan)
    for k in range(len(origens)):
        o, d = origens[k], direcoes[k]
        h = np.cross(d, e2)
        a = np.einsum("ij,ij->i", e1, h)
        ok = np.abs(a) > 1e-12
        f = np.zeros_like(a)
        f[ok] = 1.0 / a[ok]
        s = o - v0
        u = f * np.einsum("ij,ij->i", s, h)
        q = np.cross(s, e1)
        v = f * (q @ d)
        t = f * np.einsum("ij,ij->i", e2, q)
        hit = ok & (u >= -1e-6) & (v >= -1e-6) & (u + v <= 1 + 1e-6) & (t > 0)
        if hit.any():
            res[k] = t[hit].max()
    return res


def suavizar_circular(r, passes=2):
    for _ in range(passes):
        r = (np.roll(r, 1) + 2 * r + np.roll(r, -1)) / 4.0
    return r


def perfil_da_coxa(pele_p, lado, y, centro, nbins=48):
    """Raio da pele da coxa em volta de `centro`, por ângulo, na altura y."""
    sel = (np.abs(pele_p[:, 1] - y) < 0.014) & (np.sign(pele_p[:, 0]) == lado) & (np.abs(pele_p[:, 0]) > 0.005)
    q = pele_p[sel]
    if len(q) < 8:
        return None
    ang = np.arctan2(q[:, 2] - centro[1], q[:, 0] - centro[0])
    rad = np.hypot(q[:, 2] - centro[1], q[:, 0] - centro[0])
    b = ((ang + math.pi) / (2 * math.pi) * nbins).astype(int) % nbins
    r = np.full(nbins, np.nan)
    for i in range(nbins):
        if (b == i).any():
            r[i] = rad[b == i].max()
    ok = ~np.isnan(r)
    idx = np.arange(nbins)
    r = np.interp(idx, idx[ok], r[ok], period=nbins)
    return suavizar_circular(r)


def raio_no_angulo(perfil, ang):
    nb = len(perfil)
    x = (ang + math.pi) / (2 * math.pi) * nb - 0.5
    i0 = np.floor(x).astype(int) % nb
    fr = x - np.floor(x)
    return perfil[i0] * (1 - fr) + perfil[(i0 + 1) % nb] * fr


def pesos_misturados(listas):
    """listas: [(peso_da_fonte, juntas[4], pesos[4])] -> 4 juntas + 4 pesos."""
    acc = {}
    for w, jj, ww in listas:
        for a, b in zip(jj, ww):
            if b > 0:
                acc[int(a)] = acc.get(int(a), 0.0) + w * float(b)
    top = sorted(acc.items(), key=lambda kv: -kv[1])[:4]
    s = sum(v for _, v in top) or 1.0
    jj = [k for k, _ in top] + [0] * (4 - len(top))
    ww = [v / s for _, v in top] + [0.0] * (4 - len(top))
    return jj, ww


def textura_do_calcao(tam=1024):
    """Cetim preto, faixa lateral vermelha com vivo branco. Metade de cima:
    quadril (u = volta do corpo a partir das costas); metade de baixo: as
    pernas (u = 0,5 no lado de fora da coxa)."""
    img = Image.new("RGB", (tam, tam), (12, 12, 16))
    px = np.zeros((tam, tam, 3), np.float32)
    u = np.linspace(0, 1, tam)[None, :]
    v = np.linspace(0, 1, tam)[:, None]
    base = np.array([13, 13, 18], np.float32)
    # brilho de cetim: faixas largas e suaves
    brilho = 0.5 + 0.5 * np.sin(u * 2 * math.pi * 6 + np.sin(v * 9) * 0.6)
    px[:] = base + (brilho[..., None] * np.array([10, 10, 14], np.float32))
    img = Image.fromarray(np.clip(px, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img)

    def faixa(u0, v0, v1, largura):
        x0, x1 = (u0 - largura / 2) * tam, (u0 + largura / 2) * tam
        y0, y1 = v0 * tam, v1 * tam
        d.rectangle([x0, y0, x1, y1], fill=(196, 16, 40))
        viv = max(2, int(0.11 * largura * tam))
        d.rectangle([x0, y0, x0 + viv, y1], fill=(240, 240, 240))
        d.rectangle([x1 - viv, y0, x1, y1], fill=(240, 240, 240))
        ouro = max(1, viv // 2)
        d.rectangle([x0 + viv + 3, y0, x0 + viv + 3 + ouro, y1], fill=(212, 170, 60))
        d.rectangle([x1 - viv - 3 - ouro, y0, x1 - viv - 3, y1], fill=(212, 170, 60))

    # As faixas ficam um pouco à frente da lateral: a câmera do jogo vê o
    # lutador de frente, e a faixa exatamente de lado sumia.
    faixa(0.25 + ADIANTE_QUADRIL, 0.0, 0.5, 0.060)   # lado esquerdo do quadril
    faixa(0.75 - ADIANTE_QUADRIL, 0.0, 0.5, 0.060)   # lado direito do quadril
    faixa(0.50 - ADIANTE_PERNA, 0.5, 1.0, 0.078)     # lado de fora de cada perna
    img = img.filter(ImageFilter.GaussianBlur(0.7))
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=92)
    return buf.getvalue()


def main(entrada, saida):
    g = Glb(entrada)
    M = {m["name"]: m for m in g.j["meshes"]}
    pc = M["Calcao"]["primitives"][0]
    pf = M["Friso"]["primitives"][0]
    pp = M["Pele"]["primitives"][0]
    C_P = g.ler(pc["attributes"]["POSITION"])
    C_F = g.ler(pc["indices"]).reshape(-1, 3)
    C_J = g.ler(pc["attributes"]["JOINTS_0"])
    C_W = g.ler(pc["attributes"]["WEIGHTS_0"])
    S_P = g.ler(pp["attributes"]["POSITION"])
    S_J = g.ler(pp["attributes"]["JOINTS_0"])
    S_W = g.ler(pp["attributes"]["WEIGHTS_0"])
    z_c = 0.010

    # ---------------- quadril: anéis com a forma do calção antigo
    ys_q = np.linspace(Y_CINTURA, Y_GANCHO, ANEIS_QUADRIL)
    phis = np.arange(N_QUADRIL) * 2 * math.pi / N_QUADRIL     # 0 = costas
    dirs = np.stack([np.sin(phis), np.zeros_like(phis), -np.cos(phis)], 1)
    aneis_q = []
    for y in ys_q:
        yr = min(max(y, 0.70), 0.950)
        org = np.tile([0.0, yr, z_c], (N_QUADRIL, 1))
        r = raios_contra_malha(org, dirs, C_P, C_F)
        r = suavizar_circular(np.where(np.isnan(r), np.nanmean(r), r), 1)
        aneis_q.append(np.stack([dirs[:, 0] * r, np.full(N_QUADRIL, y), z_c + dirs[:, 2] * r], 1))
    aneis_q = np.array(aneis_q)            # [ANEIS_QUADRIL, N, 3]
    fundo = aneis_q[-1]
    B, F = fundo[0], fundo[N_QUADRIL // 2]

    # costura do gancho: das costas (B) à frente (F), descendo no meio
    ts = np.linspace(0, 1, COSTURA + 2)[1:-1]
    costura = np.stack([np.zeros_like(ts), Y_GANCHO - CAIDA_GANCHO * np.sin(math.pi * ts),
                        B[2] + (F[2] - B[2]) * ts], 1)

    # ---------------- pernas
    pernas = []
    for lado in (-1, 1):     # -1 = direita (x < 0), +1 = esquerda
        h = N_QUADRIL // 2
        if lado < 0:
            arco = [fundo[(h + i) % N_QUADRIL] for i in range(h + 1)]           # F -> lado -> B
            topo = np.array(arco + list(costura))                               # B -> gancho -> F
        else:
            arco = [fundo[i] for i in range(h + 1)]                             # B -> lado -> F
            topo = np.array(arco + list(costura[::-1]))                         # F -> gancho -> B
        n_arco = len(arco)
        # centro da coxa na barra e logo abaixo do fim da pele
        sel = (np.abs(S_P[:, 1] - Y_BARRA) < 0.014) & (np.sign(S_P[:, 0]) == lado)
        c_barra = np.array([S_P[sel, 0].mean(), S_P[sel, 2].mean()])
        c_topo = np.array([topo[:, 0].mean(), topo[:, 2].mean()])
        ang_topo = np.arctan2(topo[:, 2] - c_topo[1], topo[:, 0] - c_topo[0])
        aneis = [topo]
        for k in range(1, ANEIS_PERNA + 1):
            t = k / ANEIS_PERNA
            s = 1 - (1 - t) ** 2.2
            c = c_topo + (c_barra - c_topo) * min(1.0, s * 1.15)
            y_k = topo[:, 1] + (Y_BARRA - topo[:, 1]) * t
            alvo = []
            for i in range(len(topo)):
                yy = y_k[i]
                ref = min(yy, 0.70)
                perfil = perfil_da_coxa(S_P, lado, ref, c)
                r_pele = raio_no_angulo(perfil, ang_topo[i]) if perfil is not None else 0.08
                r_reto = r_pele + FOLGA
                p_topo = topo[i]
                r_t = math.hypot(p_topo[0] - c_topo[0], p_topo[2] - c_topo[1])
                r = r_t + (r_reto - r_t) * s
                if yy <= 0.712:
                    r = max(r, r_pele + FOLGA_MIN)
                alvo.append([c[0] + math.cos(ang_topo[i]) * r, yy, c[1] + math.sin(ang_topo[i]) * r])
            aneis.append(np.array(alvo))
        # dobra da barra para dentro
        ult = aneis[-1]
        cc = np.array([c_barra[0], 0, c_barra[1]])
        rad = ult - np.array([cc[0], 0, cc[2]])
        rad[:, 1] = 0
        rad /= np.linalg.norm(rad, axis=1, keepdims=True)
        aneis.append(ult - rad * 0.007 + np.array([0, 0.012, 0]))
        pernas.append({"lado": lado, "aneis": np.array(aneis), "n_arco": n_arco, "c": c_barra,
                       "ang": ang_topo})

    # ---------------- monta vértices e triângulos (posição soldada primeiro)
    V, UV, PARTE = [], [], []
    def add(p, uv, parte):
        V.append(np.asarray(p, float)); UV.append(uv); PARTE.append(parte)
        return len(V) - 1
    T = []
    # quadril: coluna extra no fim para fechar a costura de textura (u=1)
    idq = np.zeros((ANEIS_QUADRIL, N_QUADRIL + 1), int)
    for a in range(ANEIS_QUADRIL):
        vq = 0.02 + 0.46 * (Y_CINTURA - ys_q[a]) / (Y_CINTURA - Y_GANCHO)
        for j in range(N_QUADRIL + 1):
            idq[a, j] = add(aneis_q[a][j % N_QUADRIL], (j / N_QUADRIL, vq), "q")
    for a in range(ANEIS_QUADRIL - 1):
        for j in range(N_QUADRIL):
            p00, p01, p10, p11 = idq[a, j], idq[a, j + 1], idq[a + 1, j], idq[a + 1, j + 1]
            T += [(p00, p10, p11), (p00, p11, p01)]
    for perna in pernas:
        an = perna["aneis"]
        nk, m = an.shape[0], an.shape[1]
        out = 0.0 if perna["lado"] > 0 else math.pi
        cb = perna["c"]
        ids = np.zeros((nk, m), int)
        uu = np.zeros(m)
        for i in range(m):
            p = an[-2][i]
            a_i = math.atan2(p[2] - cb[1], p[0] - cb[0])
            dd = (a_i - out + math.pi) % (2 * math.pi) - math.pi
            # espelhado na perna esquerda: nas duas a frente fica em u = 0,25
            uu[i] = 0.5 + (dd if perna["lado"] < 0 else -dd) / (2 * math.pi)
        for k in range(nk):
            for i in range(m):
                p = an[k][i]
                vv = 0.52 + 0.46 * min(1.0, max(0.0, (Y_GANCHO - p[1]) / (Y_GANCHO - Y_BARRA + 0.02)))
                ids[k, i] = add(p, (uu[i], vv), "p%d" % perna["lado"])
        for k in range(nk - 1):
            for i in range(m):
                i2 = (i + 1) % m
                a, b, c_, d_ = ids[k, i], ids[k, i2], ids[k + 1, i], ids[k + 1, i2]
                T += [(a, c_, d_), (a, d_, b)]
        perna["ids"] = ids
    V = np.array(V); UV = np.array(UV, float); T = np.array(T, int)

    # orientação: normal para fora (do eixo do corpo / da coxa)
    def fora(tri):
        p = V[tri]
        n = np.cross(p[:, 1] - p[:, 0], p[:, 2] - p[:, 0])
        cen = p.mean(1)
        eixo = np.zeros_like(cen)
        eixo[:, 1] = cen[:, 1]
        eixo[:, 2] = z_c
        for perna in pernas:
            sel = (np.sign(cen[:, 0]) == perna["lado"]) & (cen[:, 1] < Y_GANCHO - 0.03)
            eixo[sel, 0] = perna["c"][0]
            eixo[sel, 2] = perna["c"][1]
        return np.einsum("ij,ij->i", n, cen - eixo)
    vira = fora(T) < 0
    if vira.mean() > 0.5:
        T = T[:, [0, 2, 1]]

    # costura de textura nas pernas: triângulo que atravessa u=0/1 ganha cópias
    novos = {}
    for t in range(len(T)):
        us = UV[T[t], 0]
        if us.max() - us.min() > 0.5:
            for c in range(3):
                vi = T[t, c]
                if UV[vi, 0] < 0.5:
                    if vi not in novos:
                        novos[vi] = len(V) + len(novos)
                    T[t, c] = novos[vi]
    if novos:
        extra = sorted(novos.items(), key=lambda kv: kv[1])
        V = np.vstack([V] + [V[[k for k, _ in extra]]])
        UV = np.vstack([UV] + [UV[[k for k, _ in extra]] + np.array([1.0, 0.0])])
        PARTE += [PARTE[k] for k, _ in extra]

    # normais lisas, somadas por posição (as cópias de costura ficam iguais)
    chave = np.round(V, 6)
    _, grupo = np.unique(chave, axis=0, return_inverse=True)
    grupo = grupo.ravel()
    fn = np.cross(V[T[:, 1]] - V[T[:, 0]], V[T[:, 2]] - V[T[:, 0]])
    acc = np.zeros((grupo.max() + 1, 3))
    for c in range(3):
        np.add.at(acc, grupo[T[:, c]], fn)
    N_ = acc[grupo]
    N_ /= np.maximum(np.linalg.norm(N_, axis=1, keepdims=True), 1e-9)

    # pesos: perna segue a coxa (pele); quadril segue o calção antigo
    arv_c = cKDTree(C_P)
    pernas_pele = np.where((S_P[:, 1] < 0.74) & (S_P[:, 1] > 0.40))[0]
    arv_p = cKDTree(S_P[pernas_pele])
    J = np.zeros((len(V), 4), np.uint16)
    W = np.zeros((len(V), 4), np.float32)
    for k in range(len(V)):
        p = V[k]
        _, ic = arv_c.query(p)
        fontes = [(1.0, C_J[ic], C_W[ic])]
        if PARTE[k] != "q":
            w_pele = min(1.0, max(0.0, (0.765 - p[1]) / 0.055))
            if w_pele > 0:
                lado = 1 if PARTE[k] == "p1" else -1
                d_, ip = arv_p.query(p, k=12)
                ip = [pernas_pele[q] for q in ip if np.sign(S_P[pernas_pele[q], 0]) == lado] or [pernas_pele[ip[0]]]
                fontes = [(1.0 - w_pele, C_J[ic], C_W[ic]), (w_pele, S_J[ip[0]], S_W[ip[0]])]
        jj, ww = pesos_misturados(fontes)
        J[k] = jj
        W[k] = ww

    g.trocar(pc["attributes"]["POSITION"], V.astype(np.float32), "f4")
    g.trocar(pc["attributes"]["NORMAL"], N_.astype(np.float32), "f4")
    g.trocar(pc["attributes"]["TEXCOORD_0"], UV.astype(np.float32), "f4")
    g.trocar(pc["attributes"]["JOINTS_0"], J, "u2")
    g.trocar(pc["attributes"]["WEIGHTS_0"], W, "f4")
    g.trocar(pc["indices"], T.astype(np.uint32).reshape(-1), "u4")

    # ---------------- friso da barra (anel vermelho em cada perna)
    FV, FN, FT, FJ, FW = [], [], [], [], []
    for perna in pernas:
        an = perna["aneis"]
        barra = an[-2]
        ids_barra = perna["ids"][-2]
        cb = np.array([perna["c"][0], 0, perna["c"][1]])
        rad = barra - cb
        rad[:, 1] = 0
        rad /= np.linalg.norm(rad, axis=1, keepdims=True)
        m = len(barra)
        aneis_f = [barra + rad * 0.0035 + [0, -0.002, 0], barra + rad * 0.0045 + [0, 0.026, 0],
                   barra + rad * -0.002 + [0, 0.030, 0]]
        nrm = [rad * 0.6 + [0, -0.8, 0], rad, rad * 0.5 + [0, 0.85, 0]]
        base = len(FV)
        for a in range(3):
            for i in range(m):
                FV.append(aneis_f[a][i])
                nn = np.asarray(nrm[a][i], float)
                FN.append(nn / np.linalg.norm(nn))
                FJ.append(J[ids_barra[i]])
                FW.append(W[ids_barra[i]])
        for a in range(2):
            for i in range(m):
                i2 = (i + 1) % m
                p0, p1, p2, p3 = base + a * m + i, base + a * m + i2, base + (a + 1) * m + i, base + (a + 1) * m + i2
                FT += [(p0, p2, p3), (p0, p3, p1)]
    FV = np.array(FV, np.float32); FT = np.array(FT, np.uint32)
    p = FV[FT]
    nrm_t = np.cross(p[:, 1] - p[:, 0], p[:, 2] - p[:, 0])
    if np.einsum("ij,ij->i", nrm_t, np.array(FN)[FT[:, 0]]).mean() < 0:
        FT = FT[:, [0, 2, 1]]
    g.trocar(pf["attributes"]["POSITION"], FV, "f4")
    g.trocar(pf["attributes"]["NORMAL"], np.array(FN, np.float32), "f4")
    g.trocar(pf["attributes"]["COLOR_0"], np.tile(np.array(COR_FRISO, np.float32), (len(FV), 1)), "f4")
    g.trocar(pf["attributes"]["JOINTS_0"], np.array(FJ, np.uint16), "u2")
    g.trocar(pf["attributes"]["WEIGHTS_0"], np.array(FW, np.float32), "f4")
    g.trocar(pf["indices"], FT.reshape(-1), "u4")

    # ---------------- textura nova do calção
    mat = next(m for m in g.j["materials"] if m.get("name") == "Roupa")
    tex = g.j["textures"][mat["pbrMetallicRoughness"]["baseColorTexture"]["index"]]
    jpg = textura_do_calcao()
    imagem = g.j["images"][tex["source"]]
    if "uri" in imagem:
        # glb que aponta para o arquivo da imagem (versão S905L): só o arquivo
        externo = os.path.join(os.path.dirname(os.path.abspath(saida)), imagem["uri"])
    else:
        g.trocar_imagem(tex["source"], jpg, "image/jpeg")
        # O importador do Godot 4 EXTRAI as imagens do glb para arquivos ao
        # lado (`boxeador_<n>.jpg`) e usa esses arquivos: vai para lá também.
        externo = os.path.splitext(saida)[0] + "_%d.jpg" % tex["source"]
    open(externo, "wb").write(jpg)

    g.salvar(saida)
    print("calção: %d vértices, %d triângulos; friso: %d vértices" % (len(V), len(T), len(FV)))


if __name__ == "__main__":
    if len(sys.argv) not in (2, 3):
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2] if len(sys.argv) == 3 else sys.argv[1])
