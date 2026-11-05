import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/screens/player/player_screen.dart';
import 'package:kiji_player/theme/kiji_tokens.dart';
import 'package:kiji_player/widgets/nocturne/waveform_progress.dart';

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

  test('El anillo es la onda de la canción en círculo: mismas barras y avanza con ella', () {
    final bars = waveformBars('yt-inventada', ProgressPlayButton.ticks);
    expect(bars, waveformBars('yt-inventada', ProgressPlayButton.ticks), reason: 'la misma firma siempre');
    expect(bars, isNot(waveformBars('yt-otra-inventada', ProgressPlayButton.ticks)));
    expect(WaveRingPainter.playedCount(60, 0), 0);
    expect(WaveRingPainter.playedCount(60, 0.5), 30);
    expect(WaveRingPainter.playedCount(60, 1), 60);
    WaveRingPainter ring(double progress) => WaveRingPainter(
      bars: bars,
      progress: progress,
      rest: const Color(0xFF444444),
      colors: const [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
      width: 2,
      playSize: 84,
    );
    // Solo se vuelve a dibujar cuando se enciende otra marca (no con cada avance de la posición).
    expect(ring(0.501).shouldRepaint(ring(0.502)), isFalse);
    expect(ring(0.49).shouldRepaint(ring(0.52)), isTrue);
  });
}
