// Genera los PNG del ícono a partir de assets/branding/kiji_logo.svg (la única fuente del
// logo). Uso: `dart run tool/render_logo.dart` y después
// `dart run flutter_launcher_icons` (Android e .ico de Windows).
//
// El SVG solo tiene rectángulos redondeados con color o con un degradado lineal horizontal,
// así que alcanza con un dibujante chico: se lee el SVG, se muestrea 4×4 por píxel
// (bordes suaves) y se guarda con el paquete `image`.

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

class _Rect {
  _Rect(this.id, this.x, this.y, this.w, this.h, this.rx, this.fill);
  final String? id;
  final double x, y, w, h, rx;
  final String fill;

  bool contains(double px, double py) {
    if (px < x || px > x + w || py < y || py > y + h) return false;
    final r = math.min(rx, math.min(w, h) / 2);
    final cx = px.clamp(x + r, x + w - r), cy = py.clamp(y + r, y + h - r);
    final dx = px - cx, dy = py - cy;
    return dx * dx + dy * dy <= r * r;
  }
}

class _Gradient {
  _Gradient(this.x1, this.x2, this.from, this.to);
  final double x1, x2;
  final List<int> from, to;
}

List<int> _hex(String c) => [for (var i = 1; i < 7; i += 2) int.parse(c.substring(i, i + 2), radix: 16)];

String _attr(String tag, String name) => RegExp('\\b$name="([^"]*)"').firstMatch(tag)?.group(1) ?? '';
double _num(String tag, String name) => double.tryParse(_attr(tag, name)) ?? 0;

void main() {
  final svg = File('assets/branding/kiji_logo.svg').readAsStringSync();
  final gradients = <String, _Gradient>{};
  for (final m in RegExp(r'<linearGradient([^>]*)>([\s\S]*?)</linearGradient>').allMatches(svg)) {
    final stops = [for (final s in RegExp(r'<stop[^>]*>').allMatches(m.group(2)!)) _hex(_attr(s.group(0)!, 'stop-color'))];
    gradients[_attr(m.group(1)!, 'id')] = _Gradient(_num(m.group(1)!, 'x1'), _num(m.group(1)!, 'x2'), stops.first, stops.last);
  }
  final rects = [
    for (final m in RegExp(r'<rect[^>]*>').allMatches(svg))
      _Rect(
        _attr(m.group(0)!, 'id').isEmpty ? null : _attr(m.group(0)!, 'id'),
        _num(m.group(0)!, 'x'),
        _num(m.group(0)!, 'y'),
        _num(m.group(0)!, 'width'),
        _num(m.group(0)!, 'height'),
        _num(m.group(0)!, 'rx'),
        _attr(m.group(0)!, 'fill'),
      ),
  ];

  List<int> colorAt(_Rect r, double x) {
    final ref = RegExp(r'url\(#(.+)\)').firstMatch(r.fill);
    if (ref == null) return _hex(r.fill);
    final g = gradients[ref.group(1)]!;
    final t = ((x - g.x1) / (g.x2 - g.x1)).clamp(0.0, 1.0);
    return [for (var i = 0; i < 3; i++) (g.from[i] + (g.to[i] - g.from[i]) * t).round()];
  }

  /// [scale]: qué parte del lienzo ocupa el cuadro de 200 del SVG.
  img.Image render(int size, {double scale = 1, bool background = true}) {
    final image = img.Image(width: size, height: size, numChannels: 4);
    final unit = size * scale / 200, offset = (size - size * scale) / 2;
    const n = 4;
    final layers = [for (final r in rects) if (background || r.id != 'fondo') r];
    for (var py = 0; py < size; py++) {
      for (var px = 0; px < size; px++) {
        // Composición "encima" de cada rectángulo, promediando las sub-muestras.
        var a = 0.0, cr = 0.0, cg = 0.0, cb = 0.0;
        for (var sy = 0; sy < n; sy++) {
          for (var sx = 0; sx < n; sx++) {
            final x = (px + (sx + 0.5) / n - offset) / unit, y = (py + (sy + 0.5) / n - offset) / unit;
            List<int>? c;
            for (final r in layers) {
              if (r.contains(x, y)) c = colorAt(r, x);
            }
            if (c != null) {
              a += 1;
              cr += c[0];
              cg += c[1];
              cb += c[2];
            }
          }
        }
        if (a == 0) continue;
        image.setPixelRgba(px, py, (cr / a).round(), (cg / a).round(), (cb / a).round(), (255 * a / (n * n)).round());
      }
    }
    return image;
  }

  Directory('assets/branding').createSync(recursive: true);
  File('assets/branding/kiji_logo_1024.png').writeAsBytesSync(img.encodePng(render(1024)));
  // Ícono adaptable de Android: el fondo lo pone el sistema (#0B0B14) y las barras quedan
  // dentro de la zona segura (el círculo central de 66 dp sobre 108 dp).
  File('assets/branding/kiji_logo_foreground.png').writeAsBytesSync(img.encodePng(render(1024, scale: 0.7, background: false)));
  stdout.writeln('Listo: assets/branding/kiji_logo_1024.png y kiji_logo_foreground.png');
}
