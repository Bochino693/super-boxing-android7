"""O lutador leve da TV Box: assets/lutador3d/boxeador.glb -> boxeador_tvbox.glb

    pip install numpy meshoptimizer
    python tools/simplificar_boxeador.py [boxeador.glb cheio]

(O boxeador.glb cheio, de 43 mil vertices, sai do tools/gerar_boxeador.py e
nao fica no projeto: sem argumento, ele e procurado em assets/lutador3d.)

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
As texturas sao as mesmas boxeador_N.jpg/png, mas o glb novo NAO aponta
para elas: quem as poe no corpo e o jogo, na montagem
(`LutadorBoxeador3D.TEXTURAS`). Numa importacao do zero o Godot 3 importa a
pasta em ordem de nome, e um glb importado antes das proprias texturas saia
sem pintura (o lutador branco no APK).
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
## OS OLHOS. No atlas da pele cada globo ocular era uma ilha de ~52 px (em
## 2048) com a iris pintada em ~8 px: importada em 1024 e comprimida, a
## iris virava um borrao cinza e o lutador parecia cego. Os vertices do
## globo ganham uma area propria e bem maior do atlas (livre: nenhuma outra
## ilha passa por ali), projetada em volta da direcao do olhar, e la e
## pintada uma iris nitida (castanha escura, anel escuro, pupila e um ponto
## de brilho). O relevo da pele fica liso nessa area.
TEX_PELE = RAIZ / "assets" / "lutador3d" / "boxeador_2.jpg"
TEX_RELEVO = RAIZ / "assets" / "lutador3d" / "boxeador_3.png"
## Onde as ilhas dos dois olhos estavam no atlas (px em 2048) e para onde vao.
ILHA_DOS_OLHOS = (1545, 80, 1675, 150)
AREA_DOS_OLHOS = (8, 8, 192)          # x, y, lado (px em 2048)
IRIS = 0.66                           # raio angular da iris (rad): maior que o real, para ler de longe
PUPILA = 0.26

## OS CADARCOS DA BOTA SEM SERRILHADO (da versao PRO, build 208). O
## cadarco e pintado nos VERTICES da bota (branco puro sobre o couro
## preto), e nao numa textura: a cor so muda de um vertice para o outro, e
## o branco escorria em degraus pelos triangulos vizinhos - na TV, um
## "xxxx" serrilhado na frente da bota. A PRO troca a cor ao montar o
## lutador; aqui a troca e feita no arquivo (refazer a malha no jogo
## corrompe a memoria quando o corpo e deformado pelo processador, o caso
## da Mali-450). Em cinza grafite o cadarco continua la, discreto, e a bota
## le como couro preto limpo. A sola branca (abaixo de CADARCO_ACIMA_DE ou
## atras do peito do pe) nao muda.
COR_DO_CADARCO = (0.30, 0.30, 0.34)
CADARCO_ACIMA_DE = 0.05

ALVOS = {
    "Pele": (0.45, 0.004),
    "Cabelo": (0.10, 0.02),
    "LuvaLeft": (0.15, 0.01),
    "LuvaRight": (0.15, 0.01),
    # a bota tem os cadarcos pintados na cor dos vertices (agora em cinza
    # grafite, ver COR_DO_CADARCO): guarda um pouco mais
    "BotaLeft": (0.16, 0.014),
    "BotaRight": (0.16, 0.014),
    "Cinturao": (0.35, 0.006),
    "Placa": (0.35, 0.006),
    # a bermuda nova da versao PRO (barra, faixa lateral) tem o dobro dos
    # triangulos da antiga: com 0,42 fica com ~1,3 mil, um pouco mais que a
    # antiga, e a faixa e a barra continuam inteiras
    "Calcao": (0.42, 0.004),
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


def cadarco_cinza(pos: np.ndarray, cores: np.ndarray, acessor: dict) -> tuple[np.ndarray, int]:
    escala = {5126: 1.0, 5121: 255.0, 5123: 65535.0}[acessor["componentType"]]
    c = cores[:, :3].astype(np.float64) / escala
    brancos = (c > 0.8).all(axis=1) & (pos[:, 1] > CADARCO_ACIMA_DE) & (pos[:, 2] > 0.0)
    novo = cores.copy()
    cinza = np.array(COR_DO_CADARCO) * escala
    novo[brancos, :3] = cinza if escala == 1.0 else np.round(cinza)
    return novo, int(brancos.sum())


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
                fracao: float, erro: float, cores: np.ndarray | None = None) -> np.ndarray:
    alvo = max(3, int(len(indices) * fracao) // 3 * 3)
    destino = np.zeros(len(indices), dtype=np.uint32)
    # Normal e UV entram na conta do erro: a sombra e a pintura nao "torcem".
    attrs = [normais.astype(np.float32)]
    pesos = [0.5, 0.5, 0.5]
    if uv is not None:
        attrs.append(uv.astype(np.float32))
        pesos += [1.0, 1.0]
    # Cor pintada nos vertices (cadarcos da bota, costura da luva, mechas
    # do cabelo): a fronteira entre duas cores nao pode ser "comida" - sem
    # isso os cadarcos viravam um serrilhado.
    if cores is not None:
        attrs.append(cores[:, :3].astype(np.float32))
        pesos += [2.0, 2.0, 2.0]
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


def olhar(s: float) -> np.ndarray:
    o = np.array([-0.06 * s, -0.03, 1.0], np.float32)
    return o / np.linalg.norm(o)


def base_do_olhar(g: np.ndarray):
    direita = np.cross(np.array([0.0, 1.0, 0.0], np.float32), g)
    direita /= np.linalg.norm(direita)
    cima = np.cross(g, direita)
    return direita, cima


def uv_dos_olhos(pos: np.ndarray, uv: np.ndarray) -> np.ndarray:
    """UV novo para os vertices do globo ocular (os outros ficam como estao)."""
    x0, y0, x1, y1 = ILHA_DOS_OLHOS
    px = uv * 2048.0
    novo = uv.copy()
    na_ilha = (px[:, 0] >= x0) & (px[:, 0] <= x1) & (px[:, 1] >= y0) & (px[:, 1] <= y1)
    ax, ay, lado = AREA_DOS_OLHOS
    for s in (1.0, -1.0):
        olho = na_ilha & (np.sign(pos[:, 0]) == s)
        if not olho.any():
            continue
        c = pos[olho].mean(0)
        rel = pos[olho] - c
        rel /= np.maximum(np.linalg.norm(rel, axis=1, keepdims=True), 1e-9)
        g = olhar(s)
        direita, cima = base_do_olhar(g)
        a = np.arccos(np.clip(rel @ g, -1.0, 1.0))
        t = np.stack([rel @ direita, rel @ cima], 1)
        t /= np.maximum(np.linalg.norm(t, axis=1, keepdims=True), 1e-9)
        # equidistante: o angulo do olhar vira a distancia ao centro
        r = a / np.pi * 0.5
        lx = 0.5 + r * t[:, 0]
        ly = 0.5 - r * t[:, 1]
        novo[olho, 0] = (ax + lx * lado) / 2048.0
        novo[olho, 1] = (ay + ly * lado) / 2048.0
    return novo


def pintar_olhos() -> None:
    from PIL import Image
    ax, ay, lado = AREA_DOS_OLHOS
    k = (np.arange(lado) + 0.5) / lado
    lx, ly = np.meshgrid(k, k)
    dx, dy = lx - 0.5, 0.5 - ly
    a = np.hypot(dx, dy) * 2.0 * np.pi          # angulo a partir do olhar
    teta = np.arctan2(dy, dx)

    def suave(e0, e1, x):
        t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
        return t * t * (3 - 2 * t)

    def cor(h):
        return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)

    def mistura(x, y, t):
        return x + (y - x) * t[..., None]

    rng = np.random.default_rng(20261021)
    esclera = mistura(np.broadcast_to(cor("ece6df"), a.shape + (3,)), cor("c08a82"), suave(0.9, 1.9, a))
    # a palpebra de cima faz sombra na esclera
    esclera = esclera * (1.0 - 0.28 * suave(0.2, 0.9, dy * 2.0 * np.pi) * suave(0.5, 1.0, a))[..., None]
    raios = rng.random(64)[((teta + np.pi) / (2 * np.pi) * 64).astype(int) % 64]
    iris_c = mistura(np.broadcast_to(cor("3a2010"), a.shape + (3,)), cor("6e4424"),
                     np.clip(0.35 + 0.5 * raios * suave(0.15, IRIS, a), 0, 1))
    iris = 1.0 - suave(IRIS - 0.03, IRIS + 0.02, a)
    anel = suave(IRIS - 0.16, IRIS - 0.02, a) * iris
    pupila = 1.0 - suave(PUPILA - 0.02, PUPILA + 0.02, a)
    olho = mistura(esclera, iris_c, iris)
    olho = olho * (1.0 - 0.65 * anel)[..., None]
    olho = mistura(olho, cor("070505"), pupila)
    # o ponto de brilho (a luz do refletor no olho), em cima e a esquerda
    bx, by = -0.55, 0.75
    bx, by = np.array([bx, by]) / np.hypot(bx, by) * (0.30 / (2 * np.pi))
    brilho = 1.0 - suave(0.055, 0.085, np.hypot(dx - bx, dy - by) * 2 * np.pi)
    olho = mistura(olho, cor("ffffff"), brilho * 0.95)
    olho = np.clip(olho, 0, 255).astype(np.uint8)

    pele = Image.open(TEX_PELE).convert("RGB")
    escala = pele.width / 2048.0
    caixa = (int(ax * escala), int(ay * escala), int((ax + lado) * escala), int((ay + lado) * escala))
    pele.paste(Image.fromarray(olho).resize((caixa[2] - caixa[0], caixa[3] - caixa[1]), Image.LANCZOS), caixa[:2])
    pele.save(TEX_PELE, quality=95, subsampling=0)
    relevo = Image.open(TEX_RELEVO)
    plano = Image.new(relevo.mode, (caixa[2] - caixa[0], caixa[3] - caixa[1]),
                      (128, 128, 255, 255)[:len(relevo.mode)] if relevo.mode != "L" else 128)
    relevo.paste(plano, caixa[:2])
    relevo.save(TEX_RELEVO)


def main() -> None:
    import sys
    entrada = Path(sys.argv[1]) if len(sys.argv) > 1 else ENTRADA
    js, binario = ler_glb(entrada)
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
                cores = ler_acessor(js, binario, attrs["COLOR_0"]) if "COLOR_0" in attrs else None
                idx = simplificar(idx, pos, ler_acessor(js, binario, attrs["NORMAL"]), uv, fracao, erro, cores)
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
                if m["name"] == "Pele" and nome == "TEXCOORD_0":
                    arr = uv_dos_olhos(pos[ordem], arr)
                if m["name"].startswith("Bota") and nome == "COLOR_0" and not prim.get("targets"):
                    arr, n = cadarco_cinza(pos[ordem], arr, a)
                    print("%-10s cadarco: %d vertices em cinza" % (m["name"], n))
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
    # Sem texturas no glb (ver o topo): materiais ficam com nome e fatores.
    for mat in js.get("materials", []):
        mat.pop("normalTexture", None)
        mat.get("pbrMetallicRoughness", {}).pop("baseColorTexture", None)
    for chave in ("images", "textures", "samplers"):
        js.pop(chave, None)
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
    pintar_olhos()
    print("TOTAL vertices %d -> %d   triangulos %d -> %d" % (total_antes[0], total_depois[0], total_antes[1], total_depois[1]))
    print("gravado:", SAIDA, "(%.1f MB)" % (SAIDA.stat().st_size / 1e6))


if __name__ == "__main__":
    main()
