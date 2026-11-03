"""Writes PLACEHOLDER Glad brand art. Replace the outputs with the real logo and
loading GIF, then run tool/apply_glad_logo.py (CI does this automatically).

  assets/brand/glad_logo.png     1024x1024 full-bleed logo (app icon, splash)
  assets/brand/glad_logo_fg.png  1024x1024 transparent mark for the adaptive
                                 icon foreground (optional)
  assets/brand/glad_loader.gif   loading animation shown by the in-app loader
"""
import math, os, sys
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'brand')
S = 1024

def font(size):
    for p in ('/usr/share/fonts/opentype/inter/Inter-Bold.otf',
              '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'):
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()

def gradient():
    img = Image.new('RGB', (S, S))
    px = img.load()
    a, b = (139, 92, 246), (67, 56, 202)
    for y in range(S):
        for x in range(S):
            t = (x + y) / (2 * (S - 1))
            px[x, y] = tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))
    return img

def glyph(color=(255, 255, 255, 255)):
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    f = font(640)
    bbox = d.textbbox((0, 0), 'G', font=f)
    w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    d.text(((S - w) / 2 - bbox[0], (S - h) / 2 - bbox[1]), 'G', font=f, fill=color)
    return layer

logo = gradient().convert('RGBA')
logo.alpha_composite(glyph())
logo.save(os.path.join(OUT, 'glad_logo.png'))
glyph().save(os.path.join(OUT, 'glad_logo_fg.png'))

# Loader: a spinning arc with a pulsing dot, on the app background colour.
N, SZ = 32, 256
frames = []
for i in range(N):
    im = Image.new('RGB', (SZ, SZ), (10, 10, 20))
    d = ImageDraw.Draw(im)
    box = (48, 48, SZ - 48, SZ - 48)
    d.ellipse(box, outline=(31, 31, 58), width=14)
    start = (360 * i / N) - 90
    d.arc(box, start, start + 100, fill=(139, 92, 246), width=14)
    r = 12 + 6 * math.sin(2 * math.pi * i / N)
    d.ellipse((SZ / 2 - r, SZ / 2 - r, SZ / 2 + r, SZ / 2 + r), fill=(139, 92, 246))
    frames.append(im)
frames[0].save(os.path.join(OUT, 'glad_loader.gif'), save_all=True,
               append_images=frames[1:], duration=40, loop=0, optimize=True)
print('placeholders written')
