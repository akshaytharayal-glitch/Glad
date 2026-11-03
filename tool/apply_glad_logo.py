"""Spreads assets/brand/glad_logo.png into every place the app shows its logo:
Android launcher icons (legacy + adaptive layers), the in-app logo mark, the
Appearance previews and the wordmark. Run from the repo root:

    pip install pillow && python3 tool/apply_glad_logo.py

CI runs this before every build, so replacing assets/brand/glad_logo.png (and
optionally glad_logo_fg.png / glad_wordmark.png) is all a logo change needs.
"""
import os, sys
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
BRAND = os.path.join(ROOT, 'assets', 'brand')
ICON = os.path.join(ROOT, 'assets', 'icon')
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')

def load(name):
    p = os.path.join(BRAND, name)
    return Image.open(p).convert('RGBA') if os.path.exists(p) else None

logo = load('glad_logo.png')
if logo is None:
    sys.exit('assets/brand/glad_logo.png is missing')
if logo.width != logo.height:
    side = min(logo.size)
    logo = logo.crop(((logo.width - side) // 2, (logo.height - side) // 2,
                      (logo.width + side) // 2, (logo.height + side) // 2))
fg = load('glad_logo_fg.png')
opaque = logo.getchannel('A').getextrema()[0] == 255

def sized(img, n):
    return img.resize((n, n), Image.LANCZOS)

def rounded(img, radius_frac=0.22):
    n = img.width
    mask = Image.new('L', (n, n), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, n - 1, n - 1), int(n * radius_frac), fill=255)
    out = img.copy()
    out.putalpha(Image.composite(img.getchannel('A'), Image.new('L', (n, n), 0), mask))
    return out

def adaptive_fg(n):
    """Adaptive-icon foreground: n x n canvas, artwork inside the 66% safe zone
    when we have a transparent mark, otherwise the full-bleed logo."""
    if fg is not None:
        canvas = Image.new('RGBA', (n, n), (0, 0, 0, 0))
        m = sized(fg, int(n * 0.66))
        canvas.alpha_composite(m, ((n - m.width) // 2, (n - m.height) // 2))
        return canvas
    return sized(logo, n)

# In-app images
sized(logo, 1024).save(os.path.join(ICON, 'app_icon.png'))
mark = sized(logo, 512)
(rounded(mark) if opaque else mark).save(os.path.join(ICON, 'logo_mark.png'))
for name in ('preview_default', 'preview_crescent', 'preview_classic'):
    (rounded(sized(logo, 256)) if opaque else sized(logo, 256)).save(
        os.path.join(ICON, name + '.png'))

# Wordmark: use the supplied one, else render "Glad" in white.
wm = load('glad_wordmark.png')
if wm is None:
    wm = Image.new('RGBA', (640, 220), (0, 0, 0, 0))
    d = ImageDraw.Draw(wm)
    f = None
    for p in ('/usr/share/fonts/opentype/inter/Inter-Bold.otf',
              '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'):
        if os.path.exists(p):
            f = ImageFont.truetype(p, 170); break
    f = f or ImageFont.load_default()
    b = d.textbbox((0, 0), 'Glad', font=f)
    d.text(((640 - (b[2] - b[0])) / 2 - b[0], (220 - (b[3] - b[1])) / 2 - b[1]),
           'Glad', font=f, fill=(255, 255, 255, 255))
wm.save(os.path.join(ICON, 'wordmark.png'))

# Android launcher icons
densities = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0}
for dens, k in densities.items():
    folder = os.path.join(RES, 'mipmap-' + dens)
    legacy = sized(logo, int(48 * k))
    legacy = rounded(legacy) if opaque else legacy
    for name in ('ic_launcher', 'ic_launcher_classic', 'ic_launcher_crescent'):
        legacy.save(os.path.join(folder, name + '.png'))
    f = adaptive_fg(int(108 * k))
    for name in ('ic_launcher_fg', 'ic_launcher_classic_fg'):
        f.save(os.path.join(folder, name + '.png'))
print('Glad logo applied')
