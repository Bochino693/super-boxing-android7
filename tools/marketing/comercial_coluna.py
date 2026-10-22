"""O COMERCIAL do SUPER BOXING com o gabinete COLUNA (vertical e horizontal).

    python tools/marketing/comercial_coluna.py --captura PASTA --cenas PASTA [--saida marketing/video]

  --captura  quadros do jogo (q00000.jpg...) + captura.json (tools/marketing/captura)
  --cenas    as cenas da maquina em 3D (revelar_*.png, soco_*.png, orbita_*.png)
             de tools/marketing/coluna3d, com o jogo de verdade na tela
O cartao final usa marketing/gabinetes/renders/coluna_heroi_recorte.png.

O roteiro (uns 36 s): o logo entra com o soco, a maquina acende no escuro,
o jogo (START, o lutador, o golpe), a bola levando o soco na maquina, o
nocaute e o TOP 20, a volta em torno da maquina e o cartao final. O som e o
do proprio jogo (a captura remontada) mais os efeitos dele nas cenas 3D.
Reaproveita os trechos e a gravacao de montar_video.py.
Requer: numpy, scipy, pillow e o ffmpeg no PATH.
"""
from __future__ import annotations

import argparse
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

import montar_video as mv
from montar_video import FPS, H, V, Seg, colar, ease_out, fundo, legenda_v, misturar, quadro_h, rampa, vazio

import arte  # noqa: E402
import audio_do_jogo  # noqa: E402

RENDER_FINAL = arte.RAIZ / "marketing" / "gabinetes" / "renders" / "coluna_heroi_recorte.png"


def seg_cena(R, tam, pasta, prefixo, sons, legenda=None, eventos=(), musica_db=-11.0, legenda_em=0.0):
    """Uma cena 3D da maquina (quadros em pe, 1080x1920) com os sons dela."""
    fs = sorted(Path(pasta).glob(f"{prefixo}_*.png"))
    n = len(fs)

    def q(i):
        img = Image.open(fs[i]).convert("RGB")
        if img.size != V:
            img = img.resize(V, Image.LANCZOS)
        t = i / FPS
        if tam == V:
            rgba = img.convert("RGBA")
            if legenda and t >= legenda_em:
                legenda_v(R, rgba, legenda, t - legenda_em)
            return rgba.convert("RGB")
        return quadro_h(R, img, t, n / FPS, legenda if t >= legenda_em else None)
    audio = vazio(n)
    misturar(audio, sons["music"], 0.0, musica_db, n / FPS)
    for nome, t, db in eventos:
        misturar(audio, sons.get(nome), t, db)
    rampa(audio, 0.03, 0.03)
    return Seg(n, q, audio, prefixo)


def seg_final_coluna(R, tam, sons):
    """O cartao final: a maquina recortada, o chamado e a marca da casa."""
    n = int(4.4 * FPS)
    maq = Image.open(RENDER_FINAL).convert("RGBA")
    maq = maq.crop(maq.getbbox())
    brilho = Image.new("RGBA", maq.size, (0, 0, 0, 0))
    a = maq.split()[3].filter(ImageFilter.GaussianBlur(40))
    brilho = arte.pintar(a.point(lambda v: int(v * 0.55)), (70, 110, 255), brilho)
    # o rodape escurece em degrade para o chamado (vertical)
    rodape = Image.new("RGBA", V, (0, 0, 0, 0))
    dr = ImageDraw.Draw(rodape)
    y0 = int(V[1] * 0.64)
    for y in range(y0, V[1]):
        dr.line([(0, y), (V[0], y)], fill=(8, 4, 20, int(190 * min(1.0, (y - y0) / (V[1] * 0.08)))))

    def q(i):
        t = i / FPS
        img = fundo(R, tam, t, n / FPS)
        k = ease_out(t / 0.6)
        zoom = 1.0 + 0.04 * t / (n / FPS)
        if tam == V:
            alt = V[1] * 0.62 * zoom
            e = alt / maq.height
            cy = V[1] * 0.355 + (1 - k) * 160
            colar(img, brilho, V[0] / 2, cy, e)
            colar(img, maq, V[0] / 2, cy, e)
            img.alpha_composite(rodape)
            colar(img, R.texto("LEVE PARA O", 92), V[0] / 2, V[1] * 0.735, 1.0, min(1, t / 0.4))
            colar(img, R.texto("SEU ESPAÇO!", 120), V[0] / 2, V[1] * 0.800, 1.0, min(1, max(0, t - 0.2) / 0.4))
            colar(img, R.lazer, V[0] / 2, V[1] * 0.905, 0.55, min(1, max(0, t - 0.5) / 0.4))
        else:
            alt = H[1] * 0.92 * zoom
            e = alt / maq.height
            cx = H[0] * 0.70
            colar(img, brilho, cx, H[1] * 0.50 + (1 - k) * 120, e)
            colar(img, maq, cx, H[1] * 0.50 + (1 - k) * 120, e)
            colar(img, R.logo, H[0] * 0.28, H[1] * 0.28, H[0] * 0.38 / R.logo.width * (1 + 0.02 * math.sin(t * 3)))
            colar(img, R.texto("LEVE PARA O SEU ESPAÇO!", 70), H[0] * 0.28, H[1] * 0.60, 1.0, min(1, t / 0.4))
            colar(img, R.lazer, H[0] * 0.28, H[1] * 0.82, 0.8, min(1, max(0, t - 0.4) / 0.4))
        return img.convert("RGB")
    audio = vazio(n)
    misturar(audio, sons["torcida_recorde"], 0.1, -4)
    misturar(audio, sons["music"], 0.0, -10, n / FPS)
    rampa(audio, fim=1.2)
    return Seg(n, q, audio, "final")


def roteiro(R, tam, cap, cenas, sons):
    ini = {}
    for i, e in cap.trechos():
        ini.setdefault(e, []).append(i)
    fim_intro = ini["IDLE"][0]
    armado = ini["ARMED"]
    segs = [mv.seg_abertura(R, tam, sons)]
    segs.append(seg_cena(R, tam, cenas, "revelar", sons, ("A NOVA SUPER BOXING", "jogo 3D • tela em pé • LED"),
                         [("subgrave", 0.30, -4), ("start", 0.32, -6), ("arena_publico", 1.0, -12)], -13.0, 1.1))
    segs.append(mv.seg_jogo(R, tam, cap, fim_intro + 20, armado[0] + 10, ("APERTE START", "e prepare o soco")))
    segs.append(mv.seg_jogo(R, tam, cap, 290, 329, ("LUTADOR 3D", "ele sente cada soco")))
    segs.append(mv.seg_jogo(R, tam, cap, 329, 420))
    segs.append(seg_cena(R, tam, cenas, "soco", sons, ("SOQUE DE VERDADE!", "a força vira pontos na tela"),
                         [("subgrave", 1.0, -2), ("hit", 1.0, -2), ("couro", 1.01, -3), ("torcida_incentivo", 1.3, -8)],
                         -14.0, 1.4))
    segs.append(mv.seg_jogo(R, tam, cap, 481, 562, ("NOCAUTE!", "pontos de 0 a 9999")))
    segs.append(mv.seg_jogo(R, tam, cap, 562, 640, None, 1.5))
    segs.append(mv.seg_jogo(R, tam, cap, 640, 700, ("TOP 20", "o recorde da casa")))
    segs.append(seg_cena(R, tam, cenas, "orbita", sons, ("FEITA PARA CHAMAR ATENÇÃO", "capô com bola • chapa xadrez • LED"),
                         [("torcida_festa", 0.2, -12)], -9.0, 0.6))
    segs.append(seg_final_coluna(R, tam, sons))
    return segs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--captura", required=True)
    ap.add_argument("--cenas", required=True)
    ap.add_argument("--saida", default=str(arte.RAIZ / "marketing" / "video"))
    ap.add_argument("--formatos", default="vertical,horizontal")
    args = ap.parse_args()
    cap = mv.Captura(Path(args.captura))
    sons = {k: audio_do_jogo.carregar(k) for k in ["subgrave", "hit", "couro", "go", "music", "torcida_recorde", "start",
                                                     "arena_publico", "torcida_incentivo", "torcida_festa"]}
    R = mv.Recursos()
    saida = Path(args.saida)
    if "vertical" in args.formatos:
        mv.gravar(roteiro(R, V, cap, args.cenas, sons), V, saida / "super_boxing_comercial_coluna_vertical_1080x1920.mp4")
    if "horizontal" in args.formatos:
        mv.gravar(roteiro(R, H, cap, args.cenas, sons), H, saida / "super_boxing_comercial_coluna_horizontal_1920x1080.mp4")


if __name__ == "__main__":
    main()
