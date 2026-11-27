// Vidrio líquido real (0.9) con liquid_glass_renderer (Apache-2.0, versión fija en pubspec.yaml).
//
// Refracción de verdad en el borde, brillo en el filo y un poco de arcoíris, dibujados por la GPU
// (Impeller + Flutter GPU). Solo donde el dispositivo lo soporta: Android con Impeller y Flutter GPU.
// En Windows, Linux, en un Android sin Impeller, si se apaga en Configuración o si algo falla,
// Kiji usa solo el vidrio de siempre (RenderLiquidGlass), sin avisos.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart' as lgr;

abstract final class RealGlass {
  /// Prendido en Configuración (lo mantiene al día la app, desde los ajustes).
  static final userOn = ValueNotifier<bool>(true);

  /// El dispositivo puede (los shaders y la GPU cargaron sin errores).
  static final _ready = ValueNotifier<bool>(false);

  /// Algo falló al dibujarlo: hasta que Kiji se vuelva a abrir, vidrio de siempre.
  static final _broken = ValueNotifier<bool>(false);

  /// Se usa el vidrio real ahora.
  static final ValueListenable<bool> active = _Active();

  static bool _started = false;

  /// ¿Vale la pena intentarlo en esta plataforma? Solo Android con filtros de shader (Impeller).
  static bool get platformCanTry =>
      !kIsWeb && Platform.isAndroid && ui.ImageFilter.isShaderFilterSupported;

  /// Carga los shaders y la GPU (después del primer cuadro: no demora el arranque). Si algo
  /// falla, queda el vidrio de siempre.
  static Future<void> start() async {
    if (_started) return;
    _started = true;
    if (!platformCanTry) {
      debugPrint('=== VIDRIO REAL: este dispositivo usa el vidrio de siempre (sin Impeller o no es Android) ===');
      return;
    }
    final previous = FlutterError.onError;
    var failedWhileLoading = false;
    FlutterError.onError = (details) {
      if (_fromRenderer(details)) {
        failedWhileLoading = true;
        fail('${details.exception.runtimeType}');
      }
      previous?.call(details);
    };
    final watch = Stopwatch()..start();
    try {
      await lgr.LiquidGlass.precache().timeout(const Duration(seconds: 8));
    } catch (error) {
      failedWhileLoading = true;
      debugPrint('=== VIDRIO REAL: no cargó (${error.runtimeType}); queda el vidrio de siempre ===');
    }
    if (failedWhileLoading) return;
    _ready.value = true;
    debugPrint('=== VIDRIO REAL: listo en ${watch.elapsedMilliseconds} ms ===');
  }

  /// Algo del vidrio real falló: vuelve al de siempre hasta la próxima vez que se abra Kiji.
  static void fail(String why) {
    if (_broken.value) return;
    _broken.value = true;
    debugPrint('=== VIDRIO REAL: falló ($why); vuelve el vidrio de siempre ===');
  }

  static bool _fromRenderer(FlutterErrorDetails details) =>
      details.library == 'liquid_glass_renderer' || '${details.stack}'.contains('package:liquid_glass_renderer/');

  /// Solo para las pruebas.
  @visibleForTesting
  static void debugSet({bool? ready, bool? broken}) {
    if (ready != null) _ready.value = ready;
    if (broken != null) _broken.value = broken;
  }

  @visibleForTesting
  static void debugReset() {
    _started = false;
    _ready.value = false;
    _broken.value = false;
    userOn.value = true;
  }
}

class _Active extends ChangeNotifier implements ValueListenable<bool> {
  _Active() {
    for (final source in [RealGlass.userOn, RealGlass._ready, RealGlass._broken]) {
      source.addListener(_update);
    }
    _value = _compute();
  }

  late bool _value;

  bool _compute() => RealGlass.userOn.value && RealGlass._ready.value && !RealGlass._broken.value;

  void _update() {
    final next = _compute();
    if (next == _value) return;
    _value = next;
    notifyListeners();
  }

  @override
  bool get value => _value;
}
