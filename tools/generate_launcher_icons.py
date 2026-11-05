#!/usr/bin/env python3
"""Bangkitkan ikon launcher dari logo resmi Posyandu (assets/icon/posyandu-logo.png).

Menghasilkan launcher/mipmap-<dpi>/ic_launcher.png (logo di atas putih, 96%)
dan ic_launcher_foreground.png (logo transparan 74%, zona aman ikon adaptif).
Jalankan dari folder proyek: python3 tools/generate_launcher_icons.py
"""
import os

from PIL import Image

DASAR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SUMBER = os.path.join(DASAR, 'assets', 'icon', 'posyandu-logo.png')
DENSITAS = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}


def main() -> None:
    src = Image.open(SUMBER).convert('RGBA')
    for dpi, n in DENSITAS.items():
        folder = os.path.join(DASAR, 'launcher', f'mipmap-{dpi}')
        os.makedirs(folder, exist_ok=True)
        kanvas = Image.new('RGBA', (n, n), (255, 255, 255, 255))
        s = int(n * 0.96)
        kanvas.alpha_composite(
            src.resize((s, s), Image.LANCZOS), ((n - s) // 2, (n - s) // 2))
        kanvas.convert('RGB').save(os.path.join(folder, 'ic_launcher.png'))
        fg = Image.new('RGBA', (n, n), (0, 0, 0, 0))
        s2 = int(n * 0.74)
        fg.alpha_composite(
            src.resize((s2, s2), Image.LANCZOS), ((n - s2) // 2, (n - s2) // 2))
        fg.save(os.path.join(folder, 'ic_launcher_foreground.png'))
        print(dpi, 'ok')


if __name__ == '__main__':
    main()
