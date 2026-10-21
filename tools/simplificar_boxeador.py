"""O lutador leve da TV Box: assets/lutador3d/boxeador.glb -> boxeador_tvbox.glb

    pip install numpy meshoptimizer
    python tools/simplificar_boxeador.py

POR QUE. Na Mali-450 (S905L, S905W, TX9) a placa de video nao le textura
no vertice, e o Godot 3 deforma o corpo do lutador NO PROCESSADOR, vertice
por vertice, a cada quadro. O boxeador.glb tem 43 mil vertices e 94 mil
triangulos (so o cabelo, 26 mil): isso era o processador da TV Box gasto
deformando detalhe que nem cabe na janela da arena (o lutador ocupa uns
600 px de altura), e a placa de video recortando 94 mil triangulos por
quadro.

O QUE MUDA. Cada peca perde triangulos onde a forma quase nao muda (o
meshoptimizer junta as arestas de menor erro). Os vertices que ficam sao
OS MESMOS do original: posicao, normal, UV, tangente, cor, ossos, pesos e
as quatro expressoes do rosto continuam exatos - a pintura, o relevo, as
costuras do UV e a deformacao nao mudam. So sai a geometria que nao se ve.
As texturas sao as mesmas (o glb novo aponta para os mesmos arquivos).
"""
from __future__ import annotations

import ctypes
import json
import struct
from pathlib import Path

import meshoptimizer as mo
import numpy as np

RAIZ = Path(__file__).resolve().parents[1]
ENTRADA = RAIZ / "assets" / "lutador3d" / "boxeador.glb"
SAIDA = RAIZ / "assets" / "lutador3d" / "boxeador_tvbox.glb"

## Fracao dos triangulos que fica em cada peca, e o erro maximo aceito
## (fracao do tamanho da peca). O rosto e o corpo guardam mais; cabelo,
## luvas e botas (superficies lisas de marching cubes) podem perder muito.
ALVOS = {
    "Pele": (0.45, 0.004),
    "Cabelo": (0.10, 0.02),
    "LuvaLeft": (0.15, 0.01),
    "LuvaRight": (0.15, 0.01),
    "BotaLeft": (0.15, 0.01),
    "BotaRight": (0.15, 0.01),
    "Cinturao": (0.35, 0.006),
    "Placa": (0.35, 0.006),
    "Calcao": (0.80, 0.004),
}

TIPOS = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
COMPONENTES = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def ler_glb(caminho: Path):
    d = caminho.read_bytes()
    _, _, _ = struct.unpack("<III", d[:12])
    l0, _ = struct.unpack("<II", d[12:20])
    js = json.loads(d[20:20 + l0])
    p = 20 + l0
    l1, _ = struct.unpack("<II", d[p:p + 8])
    binario = d[p + 8:p + 8 + l1]
    return js, binario


def ler_acessor(js, binario, i) -> np.ndarray:
    a = js["accessors"][i]
    bv = js["bufferViews"][a["bufferView"]]
    tipo = TIPOS[a["componentType"]]
    n = COMPONENTES[a["type"]]
    ini = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    passo = bv.get("byteStride", 0)
    tam = np.dtype(tipo).itemsize * n
    if passo and passo != tam:
        bruto = np.frombuffer(binario, np.uint8, count=passo * a["count"], offset=ini).reshape(a["count"], passo)
        return bruto[:, :tam].copy().view(tipo).reshape(a["count"], n)
    return np.frombuffer(binario, tipo, count=a["count"] * n, offset=ini).reshape(a["count"], n).copy()


class Escritor:
    def __init__(self):
        self.dados = bytearray()
        self.views = []
        self.acessores = []

    def acessor(self, arr: np.ndarray, modelo: dict, alvo: int | None, com_limites: bool) -> int:
        while len(self.dados) % 4:
            self.dados.append(0)
        bruto = np.ascontiguousarray(arr).tobytes()
        view = {"buffer": 0, "byteOffset": len(self.dados), "byteLength": len(bruto)}
        if alvo is not None:
            view["target"] = alvo
        self.dados += bruto
        self.views.append(view)
        a = {k: v for k, v in modelo.items() if k not in ("bufferView", "byteOffset", "count", "min", "max", "sparse")}
        a["bufferView"] = len(self.views) - 1
        a["count"] = int(arr.shape[0])
        if com_limites:
            a["min"] = [float(x) for x in arr.min(axis=0)]
            a["max"] = [float(x) for x in arr.max(axis=0)]
        self.acessores.append(a)
        return len(self.acessores) - 1


def _simplificar_c():
    # O invólucro Python não declara os tipos desta função (size_t e float
    # viravam lixo na pilha): a chamada vai direto na biblioteca.
    from meshoptimizer._loader import lib
    f = lib.meshopt_simplifyWithAttributes
    sz = ctypes.c_size_t
    pf = ctypes.POINTER(ctypes.c_float)
    pu = ctypes.POINTER(ctypes.c_uint)
    f.argtypes = [pu, pu, sz, pf, sz, sz, pf, sz, pf, sz, ctypes.POINTER(ctypes.c_ubyte), sz, ctypes.c_float,
                  ctypes.c_uint, pf]
    f.restype = sz
    return f


def simplificar(indices: np.ndarray, pos: np.ndarray, normais: np.ndarray, uv: np.ndarray | None,
                fracao: float, erro: float) -> np.ndarray:
    alvo = max(3, int(len(indices) * fracao) // 3 * 3)
    destino = np.zeros(len(indices), dtype=np.uint32)
    # Normal e UV entram na conta do erro: a sombra e a pintura nao "torcem".
    attrs = [normais.astype(np.float32)]
    pesos = [0.5, 0.5, 0.5]
    if uv is not None:
        attrs.append(uv.astype(np.float32))
        pesos += [1.0, 1.0]
    attr = np.ascontiguousarray(np.hstack(attrs), dtype=np.float32)
    pos = np.ascontiguousarray(pos, dtype=np.float32)
    indices = np.ascontiguousarray(indices, dtype=np.uint32)
    w = np.array(pesos, dtype=np.float32)
    f = _simplificar_c()
    pf = ctypes.POINTER(ctypes.c_float)
    pu = ctypes.POINTER(ctypes.c_uint)
    n = f(destino.ctypes.data_as(pu), indices.ctypes.data_as(pu), len(indices),
          pos.ctypes.data_as(pf), len(pos), 12, attr.ctypes.data_as(pf), attr.shape[1] * 4,
          w.ctypes.data_as(pf), len(w), None, alvo, erro, 0, None)
    novos = destino[:n].copy()
    mo.optimize_vertex_cache(novos, novos.copy(), vertex_count=len(pos))
    return novos


def main() -> None:
    js, binario = ler_glb(ENTRADA)
    esc = Escritor()
    feitos = {}

    def copiar(i, alvo=None):
        if i not in feitos:
            a = js["accessors"][i]
            arr = ler_acessor(js, binario, i)
            feitos[i] = esc.acessor(arr, a, alvo, "min" in a)
        return feitos[i]

    total_antes = [0, 0]
    total_depois = [0, 0]
    for m in js["meshes"]:
        for prim in m["primitives"]:
            attrs = prim["attributes"]
            idx = ler_acessor(js, binario, prim["indices"]).reshape(-1).astype(np.uint32)
            pos = ler_acessor(js, binario, attrs["POSITION"])
            tri_antes = len(idx) // 3
            total_antes[0] += len(pos)
            total_antes[1] += tri_antes
            fracao, erro = ALVOS.get(m["name"], (1.0, 0.0))
            if fracao < 1.0:
                uv = ler_acessor(js, binario, attrs["TEXCOORD_0"]) if "TEXCOORD_0" in attrs else None
                idx = simplificar(idx, pos, ler_acessor(js, binario, attrs["NORMAL"]), uv, fracao, erro)
            # Os vertices que sobraram, na ordem em que a placa os le.
            remapa = np.zeros(len(pos), dtype=np.uint32)
            usados = mo.optimize_vertex_fetch_remap(remapa, idx, vertex_count=len(pos))
            ordem = np.zeros(usados, dtype=np.int64)
            vivos = np.unique(idx)
            ordem[remapa[vivos]] = vivos
            idx_novo = remapa[idx]
            tipo_idx = np.uint16 if usados < 65536 else np.uint32
            modelo_idx = dict(js["accessors"][prim["indices"]])
            modelo_idx["componentType"] = 5123 if tipo_idx == np.uint16 else 5125
            prim["indices"] = esc.acessor(idx_novo.astype(tipo_idx).reshape(-1, 1), modelo_idx, 34963, False)
            for nome, i in list(attrs.items()):
                a = js["accessors"][i]
                arr = ler_acessor(js, binario, i)[ordem]
                attrs[nome] = esc.acessor(arr, a, 34962, nome == "POSITION" or "min" in a)
            for alvo in prim.get("targets", []):
                for nome, i in list(alvo.items()):
                    a = js["accessors"][i]
                    arr = ler_acessor(js, binario, i)[ordem]
                    alvo[nome] = esc.acessor(arr, a, 34962, nome == "POSITION" or "min" in a)
            total_depois[0] += usados
            total_depois[1] += len(idx_novo) // 3
            print("%-10s vertices %6d -> %6d   triangulos %6d -> %6d" % (
                m["name"], len(pos), usados, tri_antes, len(idx_novo) // 3))
    for s in js.get("skins", []):
        if "inverseBindMatrices" in s:
            s["inverseBindMatrices"] = copiar(s["inverseBindMatrices"])
    js["accessors"] = esc.acessores
    js["bufferViews"] = esc.views
    while len(esc.dados) % 4:
        esc.dados.append(0)
    js["buffers"] = [{"byteLength": len(esc.dados)}]
    js["asset"]["generator"] = "gerar_boxeador.py + simplificar_boxeador.py"
    texto = json.dumps(js, separators=(",", ":")).encode("utf-8")
    while len(texto) % 4:
        texto += b" "
    corpo = struct.pack("<II", len(texto), 0x4E4F534A) + texto + struct.pack("<II", len(esc.dados), 0x004E4942) + bytes(esc.dados)
    SAIDA.write_bytes(struct.pack("<III", 0x46546C67, 2, 12 + len(corpo)) + corpo)
    print("TOTAL vertices %d -> %d   triangulos %d -> %d" % (total_antes[0], total_depois[0], total_antes[1], total_depois[1]))
    print("gravado:", SAIDA, "(%.1f MB)" % (SAIDA.stat().st_size / 1e6))


if __name__ == "__main__":
    main()
