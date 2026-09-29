#!/usr/bin/env python3
"""Prepara os recursos para o Godot 3.6 (versão TV Box S905L).

1. O boxeador.glb traz as texturas EMBUTIDAS. O Godot 4 as extraía para
   `boxeador_N.*`; o Godot 3 as deixaria dentro da cena, sem compressão
   (só a pele: 25 MB de memória). Aqui o glb passa a APONTAR para esses
   arquivos, que o Godot 3 importa comprimidos e em 1024.
2. Textura 3D com mipmaps precisa ter lados em potência de 2 no OpenGL
   ES 2.0 da Mali-450: as poucas que não tinham são esticadas para o
   próximo tamanho (o desenho não muda — a UV vai de 0 a 1 do mesmo jeito).
3. Grava as opções de importação de cada imagem e de cada som.

Rodar da raiz do projeto:  python3 tools/preparar_godot3.py
"""
import glob
import json
import re
import struct
from pathlib import Path

from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent


# ------------------------------------------------------------ 1. glb
def glb_com_texturas_externas():
    p = RAIZ / "assets/lutador3d/boxeador.glb"
    dados = p.read_bytes()
    n = struct.unpack("<I", dados[12:16])[0]
    j = json.loads(dados[20:20 + n])
    mudou = False
    for k, im in enumerate(j.get("images", [])):
        if "uri" in im:
            continue
        ext = "png" if im.get("mimeType") == "image/png" else "jpg"
        nome = "boxeador_%d.%s" % (k, ext)
        assert (p.parent / nome).exists(), nome
        im.pop("bufferView", None)
        im.pop("mimeType", None)
        im["uri"] = nome
        mudou = True
    if not mudou:
        return
    texto = json.dumps(j, separators=(",", ":")).encode()
    texto += b" " * ((4 - len(texto) % 4) % 4)
    resto = dados[20 + n:]
    corpo = struct.pack("<I", len(texto)) + b"JSON" + texto + resto
    p.write_bytes(dados[:8] + struct.pack("<I", 12 + len(corpo)) + corpo)
    print("glb: texturas externas")


# ------------------------------------------------------------ 2. potência de 2
TEXTURAS_3D = [
    "assets/arena/*.png",
    "assets/lutador3d/boxeador_*.jpg",
    "assets/lutador3d/boxeador_*.png",
    "assets/lutador3d/pele_*.png",
]


def pot(x):
    return 1 << (x - 1).bit_length()


def lados_em_potencia_de_2():
    for padrao in TEXTURAS_3D:
        for arq in glob.glob(str(RAIZ / padrao)):
            im = Image.open(arq)
            w, h = im.size
            if (w, h) != (pot(w), pot(h)):
                im.resize((pot(w), pot(h)), Image.LANCZOS).save(arq, quality=92)
                print("potência de 2:", Path(arq).name, (w, h), "->", (pot(w), pot(h)))


# ------------------------------------------------------------ 3. importação
IMPORT_TEXTURA = """[remap]

importer="texture"
type="StreamTexture"

[deps]

source_file="res://{caminho}"

[params]

compress/mode={modo}
compress/lossy_quality=0.7
compress/hdr_mode=0
compress/bptc_ldr=0
compress/normal_map={normal}
flags/repeat=0
flags/filter=true
flags/mipmaps={mipmaps}
flags/anisotropic=false
flags/srgb=2
process/fix_alpha_border=true
process/premult_alpha=false
process/HDR_as_SRGB=false
process/invert_color=false
process/normal_map_invert_y=false
stream=false
size_limit={limite}
detect_3d=false
svg/scale=1.0
"""

IMPORT_WAV = """[remap]

importer="wav"
type="AudioStreamSample"

[deps]

source_file="res://{caminho}"

[params]

force/8_bit=false
force/mono=false
force/max_rate=false
force/max_rate_hz=44100
edit/trim=false
edit/normalize=false
edit/loop_mode=0
edit/loop_begin=0
edit/loop_end=-1
compress/mode=1
"""

# Arte 2D que aparece MENOR do que foi desenhada: com mipmaps não serrilha.
# (No Godot 4 todas tinham mipmaps pelo filtro padrão do projeto.)
MIPMAPS_2D = {
    "assets/tema/logo.png", "assets/tema/fight.png", "assets/tema/never_give_up.png",
    "assets/tema/ate_o_fim.png", "assets/branding/selo_lazer.png", "assets/logo_lazersport.png",
}


def tem_alfa(arq):
    with Image.open(arq) as im:
        return im.mode in ("RGBA", "LA", "PA") or "transparency" in im.info


def opcoes_de_importacao():
    for arq in sorted(glob.glob(str(RAIZ / "assets/**/*.png"), recursive=True)
                      + glob.glob(str(RAIZ / "assets/**/*.jpg"), recursive=True)
                      + glob.glob(str(RAIZ / "docs/*.png"))):
        rel = str(Path(arq).relative_to(RAIZ)).replace("\\", "/")
        eh_3d = any(Path(arq).match(str(RAIZ / p)) for p in TEXTURAS_3D)
        fx = rel.startswith("assets/fx/")
        if eh_3d:
            # Comprimida na placa de vídeo (ETC na TV Box), com mipmaps. O
            # lutador em 1024, como na versão do Godot 4.
            # Tudo em no máximo 1024: a arena é desenhada numa janela de
            # ~550x780, e a torcida em 2048 só gastava memória.
            limite = 1024
            # COM TRANSPARÊNCIA (torcida, fachos, brilho): SEM compressão. O
            # ETC1 da Mali-450 não tem alfa e o Godot 3 então rebaixa a
            # imagem para 16 tons por canal: o degradê dos refletores virava
            # degraus — as faixas verticais no corpo da torcida.
            modo = 0 if tem_alfa(arq) else 2
            texto = IMPORT_TEXTURA.format(caminho=rel, modo=modo, mipmaps="true", limite=limite, normal=0)
        else:
            # 2D SEM MIPMAPS (menos as partículas, que já têm lados em
            # potência de 2): no OpenGL ES 2.0 da Mali-450 o Godot 3 estica
            # para potência de 2 a imagem de tamanho qualquer que tenha
            # mipmaps — o logo de 1400x823 virava 2048x1024 e dobrava de
            # memória. Foto sem transparência (o fundo) vai comprimida na
            # placa de vídeo: 6 MB viram 1 MB.
            sem_alfa = rel.endswith(".jpg")
            texto = IMPORT_TEXTURA.format(caminho=rel, modo=2 if sem_alfa else 0, limite=0, normal=0,
                                          mipmaps="true" if fx else "false")
        Path(arq + ".import").write_text(texto, encoding="utf-8")
    for arq in sorted(glob.glob(str(RAIZ / "assets/**/*.wav"), recursive=True)):
        rel = str(Path(arq).relative_to(RAIZ)).replace("\\", "/")
        Path(arq + ".import").write_text(IMPORT_WAV.format(caminho=rel), encoding="utf-8")


# ------------------------------------------------------------ 4. o boxeador
# A MALHA DO LUTADOR SEM COMPRESSÃO. A pele tem expressões (blend shapes) e
# mapa de relevo; no OpenGL ES 2.0 do Godot 3 as expressões são feitas pelo
# processador, e com a malha comprimida as tangentes saíam erradas: a pele
# ficava preta (ou branca, com o contorno de luz). Sem compressão ela sai
# igual à do Godot 4. Materiais dentro da cena (sem arquivos .material).
def importacao_do_boxeador():
    p = RAIZ / "assets/lutador3d/boxeador.glb.import"
    if not p.exists():
        return
    t = p.read_text(encoding="utf-8")
    for chave, valor in [("meshes/compress", "0"), ("meshes/octahedral_compression", "false"),
                         ("materials/storage", "0")]:
        t = re.sub(r"(?m)^%s=.*$" % re.escape(chave), "%s=%s" % (chave, valor), t)
    p.write_text(t, encoding="utf-8")


# ------------------------------------------------------------ 5. .import limpos
# O .import no repositório NÃO aponta para o cache (.import/). Num PC que
# nunca abriu o projeto, o endereço de um cache que ainda não existe fazia o
# Godot 3 reclamar "Cannot open file" de cada som e do boxeador antes de
# importá-los. Sem o endereço, ele importa do zero, calado.
def import_sem_cache():
    for arq in glob.glob(str(RAIZ / "**/*.import"), recursive=True):
        if "/.import/" in arq.replace("\\", "/"):
            continue
        p = Path(arq)
        t = p.read_text(encoding="utf-8")
        novo = re.sub(r"(?m)^(path(\.\w+)?|dest_files)=.*\n", "", t)
        novo = re.sub(r"(?ms)^metadata=\{.*?^\}\n", "", novo)
        if novo != t:
            p.write_text(novo, encoding="utf-8")


if __name__ == "__main__":
    importacao_do_boxeador()
    glb_com_texturas_externas()
    lados_em_potencia_de_2()
    opcoes_de_importacao()
    import_sem_cache()
