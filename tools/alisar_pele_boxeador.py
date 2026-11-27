## Tira os gomos pintados do tronco (os riscos escuros) e deixa a pele lisa.
## Uso: python3 alisar.py entrada.jpg saida.jpg
import sys
import numpy as np
from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
im = np.asarray(Image.open(src).convert("RGB")).astype(np.float32)
H, W, _ = im.shape
L0 = im @ np.array([0.299, 0.587, 0.114], np.float32)

def box(a, r):
    p = np.pad(a, ((r + 1, r), (0, 0)), mode="edge")
    c = np.cumsum(p, axis=0)
    a = (c[2 * r + 1:] - c[:-2 * r - 1]) / (2 * r + 1)
    p = np.pad(a, ((0, 0), (r + 1, r)), mode="edge")
    c = np.cumsum(p, axis=1)
    return (c[:, 2 * r + 1:] - c[:, :-2 * r - 1]) / (2 * r + 1)

yy, xx = np.mgrid[0:H, 0:W]
# O tronco no mapa UV (2048 px): peito e abdômen.
cx, cy, rx, ry = 790.0, 720.0, 420.0, 470.0
d = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
peso = np.clip((1.0 - d) / 0.30, 0.0, 1.0)
# Os mamilos ficam.
for (mx, my) in [(665, 625), (890, 620)]:
    r = np.sqrt((xx - mx) ** 2 + (yy - my) ** 2)
    peso *= np.clip((r - 16.0) / 10.0, 0.0, 1.0)

# Envelope de cima: o traço escuro sobe até o tom da pele em volta; a
# forma larga (luz e sombra do corpo) fica.
Le = L0.copy()
for _ in range(16):
    B = box(box(Le, 18), 18)
    Le = np.maximum(Le, B - 1.0)
Le = box(box(Le, 6), 6)
fator = np.clip(Le / np.maximum(L0, 1.0), 1.0, 2.5)
lisa = im * fator[..., None]
# Alisa o tom (sem ruído de traço que sobrou).
lisa = np.stack([box(box(box(lisa[..., c], 14), 14), 14) for c in range(3)], -1)
w = peso[..., None]
out = im * (1.0 - w) + lisa * w
Image.fromarray(np.clip(out + 0.5, 0, 255).astype(np.uint8)).save(dst, quality=95, subsampling=0)
