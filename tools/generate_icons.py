#!/usr/bin/env python3
"""Gambar ikon GrowTrack: anak dengan tangan terangkat, panah tumbuh ke atas,
dan tangga pertumbuhan. Mengikuti logo asli GrowTrack (teal) pada resolusi tinggi.
Menghasilkan: logo master 1024, set mipmap Android, dan logo dalam aplikasi."""
from PIL import Image, ImageDraw
import os

S = 1024
BG_TOP = (13, 110, 126)      # teal terang di atas
BG_BOT = (6, 63, 76)         # teal gelap di bawah
MINT = (37, 224, 203)        # hijau mint cerah (tokoh + panah)
TEAL = (20, 184, 166)        # teal aksen (tangga)

img = Image.new('RGB', (S, S), BG_BOT)
d = ImageDraw.Draw(img)
# gradasi vertikal
for y in range(S):
    t = y / S
    d.line([(0, y), (S, y)], fill=tuple(int(BG_BOT[i] + (BG_TOP[i] - BG_BOT[i]) * (1 - t)) for i in range(3)))
# sudut membulat: tempel masker
mask = Image.new('L', (S, S), 0)
md = ImageDraw.Draw(mask)
md.rounded_rectangle([0, 0, S - 1, S - 1], radius=230, fill=255)
out = Image.new('RGBA', (S, S), (0, 0, 0, 0))
out.paste(img, (0, 0), mask)
d = ImageDraw.Draw(out)

# tangga pertumbuhan (kiri bawah): 3 batang naik
base = 950
for i, (x, h) in enumerate([(96, 90), (216, 165), (336, 240)]):
    d.rounded_rectangle([x, base - h, x + 92, base], radius=18,
                        fill=MINT if i == 2 else TEAL)

# panah ke atas (tengah atas)
cx = 560
d.polygon([(cx, 96), (cx - 128, 300), (cx - 44, 300), (cx - 44, 400),
           (cx + 44, 400), (cx + 44, 300), (cx + 128, 300)], fill=MINT)

# anak: kepala
hx, hy, hr = 560, 512, 82
d.ellipse([hx - hr, hy - hr, hx + hr, hy + hr], fill=MINT)
# lengan terangkat (garis tebal dari bahu ke tangan)
d.line([(hx - 52, 636), (392, 452)], fill=MINT, width=62)
d.line([(hx + 52, 636), (728, 452)], fill=MINT, width=62)
# badan
d.rounded_rectangle([hx - 54, 600, hx + 54, 838], radius=48, fill=MINT)
# kaki
d.line([(hx - 26, 830), (hx - 62, 952)], fill=MINT, width=54)
d.line([(hx + 26, 830), (hx + 62, 952)], fill=MINT, width=54)

base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
master = os.path.join(base_dir, 'assets', 'icon', 'logo-master.png')
out.save(master)
out.resize((512, 512), Image.LANCZOS).save(os.path.join(base_dir, 'assets', 'icon', 'logo.png'))
for dpi, px in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
    folder = os.path.join(base_dir, 'assets', 'icon', f'mipmap-{dpi}')
    os.makedirs(folder, exist_ok=True)
    out.resize((px, px), Image.LANCZOS).save(os.path.join(folder, 'ic_launcher.png'))
print('ikon selesai:', master)
