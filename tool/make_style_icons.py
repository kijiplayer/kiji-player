"""Genera los íconos "a juego con el estilo" (0.8.3) a partir de la geometría de
assets/branding/kiji_logo.svg: el mismo logo de onda, con los colores de cada estilo.

Android: un vector por variante (frente), su color de fondo, un ícono adaptativo con su versión
monocroma y, para Android 7 (sin íconos adaptativos), el ícono de siempre.
Windows: un .ico por variante (lo usa la ventana y la barra de tareas al momento).

Uso: python tool/make_style_icons.py   (necesita Pillow para los .ico).
"""
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
RES = ROOT / 'android' / 'app' / 'src' / 'main' / 'res'
ICO = ROOT / 'assets' / 'icons' / 'windows'

# Las barras del logo (x, y, ancho, alto) en un lienzo de 200 × 200, como en el SVG.
BARS = [(50, 46, 16, 108), (80, 88, 14, 24), (104, 76, 14, 48), (128, 62, 14, 76), (152, 48, 14, 104)]

# variante: (fondo, color de la primera barra, color de la última; el medio, degradado)
VARIANTS = {
    'nocturne': ('#0B0B14', '#7C5CFF', '#3DF5FF'),
    'aurora': ('#0B0B14', '#3DFFA8', '#7C5CFF'),
    'ember': ('#0B0B14', '#FF7A45', '#FF3D8B'),
    'mint': ('#0B0B14', '#2EE6A6', '#3DB8FF'),
    'ocean': ('#0B0B14', '#3D7BFF', '#3DF5FF'),
    'graphite': ('#0F0F10', '#FFFFFF', '#8E8E93'),
    'paper': ('#F3F1EC', '#1C1A17', '#B4462B'),
}

HEADER = '<?xml version="1.0" encoding="utf-8"?>\n<!-- Generado por tool/make_style_icons.py (no editar a mano). -->\n'


def rounded(x, y, w, h):
    r = min(w, h) / 2
    return (f'M{x + r},{y} H{x + w - r} A{r},{r} 0 0 1 {x + w},{y + r} V{y + h - r} '
            f'A{r},{r} 0 0 1 {x + w - r},{y + h} H{x + r} A{r},{r} 0 0 1 {x},{y + h - r} '
            f'V{y + r} A{r},{r} 0 0 1 {x + r},{y} Z')


def vector(first, last, mono=False):
    paths = []
    for i, (x, y, w, h) in enumerate(BARS):
        d = rounded(x, y, w, h)
        if mono:
            paths.append(f'  <path android:fillColor="#FFFFFFFF" android:pathData="{d}"/>')
        elif i == 0:
            paths.append(f'  <path android:fillColor="{first}" android:pathData="{d}"/>')
        elif i == len(BARS) - 1:
            paths.append(f'  <path android:fillColor="{last}" android:pathData="{d}"/>')
        else:
            paths.append(
                f'  <path android:pathData="{d}">\n'
                f'    <aapt:attr name="android:fillColor">\n'
                f'      <gradient android:type="linear" android:startX="80" android:startY="0" '
                f'android:endX="166" android:endY="0" android:startColor="{first}" android:endColor="{last}"/>\n'
                f'    </aapt:attr>\n  </path>')
    return (HEADER + '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
            '    xmlns:aapt="http://schemas.android.com/aapt"\n'
            '    android:width="108dp" android:height="108dp" android:viewportWidth="200" android:viewportHeight="200">\n'
            + '\n'.join(paths) + '\n</vector>\n')


def adaptive(name):
    return (HEADER + '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            f'  <background android:drawable="@color/ic_kiji_bg_{name}"/>\n'
            f'  <foreground>\n    <inset android:drawable="@drawable/ic_kiji_fg_{name}" android:inset="16%"/>\n  </foreground>\n'
            '  <monochrome>\n    <inset android:drawable="@drawable/ic_kiji_mono" android:inset="16%"/>\n  </monochrome>\n'
            '</adaptive-icon>\n')


def ico(name, bg, first, last):
    from PIL import Image, ImageDraw

    size = 256
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    s = size / 200
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=46 * s, fill=bg)

    def mix(t):
        a = tuple(int(first[i:i + 2], 16) for i in (1, 3, 5))
        b = tuple(int(last[i:i + 2], 16) for i in (1, 3, 5))
        return tuple(round(a[k] + (b[k] - a[k]) * t) for k in range(3)) + (255,)

    for i, (x, y, w, h) in enumerate(BARS):
        t = 0 if i == 0 else 1 if i == len(BARS) - 1 else min(1, max(0, (x + w / 2 - 80) / 86))
        draw.rounded_rectangle((x * s, y * s, (x + w) * s, (y + h) * s), radius=min(w, h) / 2 * s, fill=mix(t))
    img.save(ICO / f'kiji_{name}.ico', sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])


def main():
    (RES / 'drawable').mkdir(exist_ok=True)
    (RES / 'mipmap-anydpi-v26').mkdir(exist_ok=True)
    ICO.mkdir(parents=True, exist_ok=True)
    colors = []
    aliases = []
    for name, (bg, first, last) in VARIANTS.items():
        (RES / 'drawable' / f'ic_kiji_fg_{name}.xml').write_text(vector(first, last), encoding='utf-8')
        (RES / 'mipmap-anydpi-v26' / f'ic_launcher_{name}.xml').write_text(adaptive(name), encoding='utf-8')
        colors.append(f'    <color name="ic_kiji_bg_{name}">{bg}</color>')
        # Android 7 (sin íconos adaptativos): el ícono de siempre.
        aliases.append(f'    <item name="ic_launcher_{name}" type="mipmap">@mipmap/ic_launcher</item>')
        ico(name, bg, first, last)
    (RES / 'drawable' / 'ic_kiji_mono.xml').write_text(vector('', '', mono=True), encoding='utf-8')
    (RES / 'values' / 'kiji_style_icons.xml').write_text(
        HEADER + '<resources>\n' + '\n'.join(colors) + '\n' + '\n'.join(aliases) + '\n</resources>\n', encoding='utf-8')
    print('listo:', ', '.join(VARIANTS))


if __name__ == '__main__':
    main()
