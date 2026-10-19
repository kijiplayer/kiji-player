import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Medidor de cuadros de Kiji Dev (rendimiento): cada [every] anota en el registro cuánto
/// tardaron los cuadros en armarse (build) y en dibujarse (raster), y cuántos pasaron de 16 ms.
/// Solo anota si hubo cuadros (con la pantalla quieta Flutter no dibuja).
abstract final class FrameStats {
  static const every = Duration(seconds: 3);
  static final _build = <int>[];
  static final _raster = <int>[];
  static DateTime _since = DateTime.now();
  static bool _started = false;

  static void start() {
    if (_started) return;
    _started = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  static void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _build.add(t.buildDuration.inMicroseconds);
      _raster.add(t.rasterDuration.inMicroseconds);
    }
    final now = DateTime.now();
    if (now.difference(_since) < every || _build.isEmpty) return;
    debugPrint('=== CUADROS: ${summarize(_build, _raster)} ===');
    _build.clear();
    _raster.clear();
    _since = now;
  }

  /// "cuadros=42 build 3.1/6.0/9.2 ms raster 4.0/7.5/12.1 ms (mediana/p90/máx) >16ms=1".
  @visibleForTesting
  static String summarize(List<int> buildUs, List<int> rasterUs) {
    String stats(List<int> us) {
      final s = [...us]..sort();
      String ms(int v) => (v / 1000).toStringAsFixed(1);
      return '${ms(s[s.length ~/ 2])}/${ms(s[(s.length * 0.9).floor().clamp(0, s.length - 1)])}/${ms(s.last)}';
    }

    var slow = 0;
    for (var i = 0; i < buildUs.length; i++) {
      if (buildUs[i] + rasterUs[i] > 16000) slow++;
    }
    return 'cuadros=${buildUs.length} build ${stats(buildUs)} ms raster ${stats(rasterUs)} ms '
        '(mediana/p90/máx) >16ms=$slow';
  }
}
