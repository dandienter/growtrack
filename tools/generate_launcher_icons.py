#!/usr/bin/env python3
"""Bangkitkan ikon launcher dari logo resmi Posyandu (assets/icon/posyandu-logo.png).

Menghasilkan per densitas di launcher/mipmap-<dpi>/:
- ic_launcher.png: latar gradasi teal (menyatu dengan tema aplikasi),
  logo di dalam lingkaran putih di tengah, gaya sama seperti AppBar dan
  kartu sapaan Beranda.
- ic_launcher_foreground.png: logo transparan 74% untuk ikon adaptif
  (latarnya warna putih dari values XML di workflow build).

Jalankan dari folder proyek: python3 tools/generate_launcher_icons.py
"""
import os

from PIL import Image, ImageDraw

DASAR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SUMBER = os.path.join(DASAR, 'assets', 'icon', 'posyandu-logo.png')
DENSITAS = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
TEAL_ATAS = (18, 184, 166)    # ujung terang gradasi
TEAL_BAWAH = (10, 110, 103)   # #0A6E67, ujung gelap gradasi Beranda


def gradasi(n):
    """Kanvas n x n gradasi vertikal teal."""
    kolom = Image.new('RGB', (1, n))
    for y in range(n):
        t = y / max(n - 1, 1)
        kolom.putpixel((0, y), tuple(
            round(TEAL_ATAS[c] + (TEAL_BAWAH[c] - TEAL_ATAS[c]) * t)
            for c in range(3)))
    return kolom.resize((n, n)).convert('RGBA')


def main() -> None:
    src = Image.open(SUMBER).convert('RGBA')
    for dpi, n in DENSITAS.items():
        folder = os.path.join(DASAR, 'launcher', f'mipmap-{dpi}')
        os.makedirs(folder, exist_ok=True)

        # Ikon warisan: gradasi + lingkaran putih + logo.
        kanvas = gradasi(n)
        gambar = ImageDraw.Draw(kanvas)
        d = int(n * 0.86)
        x0 = (n - d) // 2
        gambar.ellipse([x0, x0, x0 + d, x0 + d], fill=(255, 255, 255, 255))
        s = int(n * 0.70)
        kanvas.alpha_composite(
            src.resize((s, s), Image.LANCZOS), ((n - s) // 2, (n - s) // 2))
        kanvas.convert('RGB').save(os.path.join(folder, 'ic_launcher.png'))

        # Ikon adaptif: foreground logo saja di atas transparan.
        fg = Image.new('RGBA', (n, n), (0, 0, 0, 0))
        s2 = int(n * 0.74)
        fg.alpha_composite(
            src.resize((s2, s2), Image.LANCZOS), ((n - s2) // 2, (n - s2) // 2))
        fg.save(os.path.join(folder, 'ic_launcher_foreground.png'))
        print(dpi, 'ok')


if __name__ == '__main__':
    main()
