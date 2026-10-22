"""Prepara uma COPIA do jogo para as capturas da divulgacao (so no PC).

    python tools/marketing/captura/preparar_copia.py PASTA_DA_COPIA [--escala 1.0]

As capturas (video e recortes do lutador) rodam no renderizador GLES3 do PC,
mais bonito que o da TV Box. Elas NAO rodam no projeto original porque
precisam de quatro ajustes, feitos so na copia:
  1. scripts/perfil.gd: arena em escala cheia (--escala; 2 a 3 para os
     recortes de grafica), sem MSAA (no PC ele devolve a imagem preta) e com
     as luzes de recorte rosa e azul;
  2. boxeador_tvbox.glb: a luva e a bota esquerdas com os triangulos na ordem
     certa (no GLES3 o truque do "avesso" deixa as duas claras demais);
  3. scripts/audio_bank.gd: cada som tocado vai para um registro (o video
     remonta a trilha do jogo quadro a quadro, ver audio_do_jogo.py);
  4. as cenas de captura (tools/marketing/captura) ja vem junto.
Depois de preparar, importe uma vez (godot3 --path PASTA -e --quit) e rode:
  godot3 --video-driver GLES3 --fixed-fps 30 --windowed --resolution 1080x1920 \\
      --path PASTA res://tools/marketing/captura/captura.tscn -- --pasta=/saida/captura
  godot3 --video-driver GLES3 --fixed-fps 30 --path PASTA \\
      res://tools/marketing/captura/recortes.tscn -- --pasta=/saida/recortes --fov=34 --cada=2
"""
from __future__ import annotations

import json
import re
import shutil
import struct
import subprocess
import sys
from pathlib import Path

import numpy as np

AQUI = Path(__file__).resolve().parent
RAIZ = AQUI.parents[2]
sys.path.insert(0, str(RAIZ / "tools"))


def copiar(destino: Path) -> None:
    arquivos = subprocess.run(["git", "ls-files"], cwd=RAIZ, capture_output=True, text=True, check=True).stdout.split()
    for a in arquivos:
        if a.startswith("marketing/"):
            continue
        d = destino / a
        d.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(RAIZ / a, d)
    if (RAIZ / ".import").exists():
        shutil.copytree(RAIZ / ".import", destino / ".import", dirs_exist_ok=True)


def ajustar_perfil(destino: Path, escala: float) -> None:
    p = destino / "scripts" / "perfil.gd"
    s = p.read_text(encoding="utf-8")
    s = re.sub(r"^const ARENA_ESCALA = .*$", f"const ARENA_ESCALA = {escala}", s, flags=re.M)
    s = re.sub(r"^const ARENA_MSAA = .*$", "const ARENA_MSAA = false", s, flags=re.M)
    s = re.sub(r"^const LUZES_DE_RECORTE = .*$", "const LUZES_DE_RECORTE = true", s, flags=re.M)
    p.write_text(s, encoding="utf-8")


def desvirar_glb(destino: Path) -> None:
    import simplificar_boxeador as sb
    caminho = destino / "assets" / "lutador3d" / "boxeador_tvbox.glb"
    js, b = sb.ler_glb(caminho)
    b = bytearray(b)
    for m in js["meshes"]:
        if m["name"] not in ("LuvaLeft", "BotaLeft"):
            continue
        a = js["accessors"][m["primitives"][0]["indices"]]
        bv = js["bufferViews"][a["bufferView"]]
        tipo = sb.TIPOS[a["componentType"]]
        ini = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        tam = a["count"] * np.dtype(tipo).itemsize
        idx = np.frombuffer(bytes(b[ini:ini + tam]), tipo).reshape(-1, 3)[:, [0, 2, 1]]
        b[ini:ini + tam] = idx.astype(tipo).tobytes()
    texto = json.dumps(js, separators=(",", ":")).encode()
    while len(texto) % 4:
        texto += b" "
    while len(b) % 4:
        b.append(0)
    corpo = struct.pack("<II", len(texto), 0x4E4F534A) + texto + struct.pack("<II", len(b), 0x004E4942) + bytes(b)
    caminho.write_bytes(struct.pack("<III", 0x46546C67, 2, 12 + len(corpo)) + corpo)


def registrar_sons(destino: Path) -> None:
    p = destino / "scripts" / "audio_bank.gd"
    s = p.read_text(encoding="utf-8")

    def log(linha):
        return '\tif Engine.has_meta("sons"):\n\t\tEngine.get_meta("sons").append(' + linha + ')\n'
    trocas = {
        "func duck(db: float, segundos: float) -> void:\n": '[Engine.get_idle_frames(), "duck", db, segundos]',
        "func music(level: float) -> void:\n": '[Engine.get_idle_frames(), "music", level]',
        "func silence() -> void:\n": '[Engine.get_idle_frames(), "silence"]',
        "func attract(level: float) -> void:\n": '[Engine.get_idle_frames(), "attract", level]',
        "func score_progress(progress: float) -> void:\n": '[Engine.get_idle_frames(), "pitch", progress]',
        "func play(nome: String, volume_db: float = 0.0) -> void:\n": '[Engine.get_idle_frames(), "play", nome, volume_db]',
        "func stop(nome: String) -> void:\n": '[Engine.get_idle_frames(), "stop", nome]',
    }
    for chave, linha in trocas.items():
        if chave not in s:
            raise SystemExit("audio_bank.gd mudou: falta " + chave.strip())
        s = s.replace(chave, chave + log(linha))
    p.write_text(s, encoding="utf-8")


def main() -> None:
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    destino = Path(sys.argv[1]).resolve()
    escala = float(sys.argv[sys.argv.index("--escala") + 1]) if "--escala" in sys.argv else 1.0
    if destino.exists() and any(destino.iterdir()):
        raise SystemExit(f"{destino} ja existe e nao esta vazia")
    copiar(destino)
    ajustar_perfil(destino, escala)
    desvirar_glb(destino)
    registrar_sons(destino)
    print("copia pronta em", destino)
    print("importe uma vez: godot3 --path", destino, "-e --quit")


if __name__ == "__main__":
    main()
