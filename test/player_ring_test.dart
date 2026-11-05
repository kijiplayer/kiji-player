import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/theme/kiji_tokens.dart';

void main() {
  test('El anillo de progreso del play se ve en los tres estilos (3:1, es un gráfico)', () {
    for (final style in KijiStyle.values) {
      final p = KijiPalette.forStyle(style);
      final ring = switch (style) {
        KijiStyle.nocturne => [p.violet, p.cyan],
        KijiStyle.graphite => [p.text],
        KijiStyle.paper => [p.like ?? p.violet],
      };
      for (final color in ring) {
        expect(KijiPalette.contrastOf(color, p.background), greaterThanOrEqualTo(3), reason: style.name);
      }
      // El ícono sobre el play (Grafito: disco del color del texto con el ícono del fondo).
      final (on, fill) = style == KijiStyle.graphite ? (p.background, p.text) : (p.onAccent, p.violet);
      expect(KijiPalette.contrastOf(on, fill), greaterThanOrEqualTo(4.5), reason: '${style.name}: ícono del play');
    }
  });
}
