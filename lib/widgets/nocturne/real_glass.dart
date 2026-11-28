// Vidrio líquido real (0.9): refracción de verdad en el borde del vidrio, con un shader propio
// (shaders/glass_refraction.frag) que lee el fondo de Kiji ya capturado una vez (GlassBackdrop),
// sin copiar la pantalla en cada cuadro. Si el shader no carga, si se apaga en Configuración o si
// algo falla al dibujarlo, Kiji usa el vidrio de siempre, sin avisos.
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

abstract final class RealGlass {
  static const asset = 'shaders/glass_refraction.frag'; // l10n-ignore

  /// Prendido en Configuración (lo mantiene al día la app, desde los ajustes).
  static final userOn = ValueNotifier<bool>(true);

  static final _program = ValueNotifier<ui.FragmentProgram?>(null);
  static final _broken = ValueNotifier<bool>(false);

  /// Se usa la refracción real ahora.
  static final ValueListenable<bool> active = _Active();

  /// El programa del shader, cuando está activo.
  static ui.FragmentProgram? get program => active.value ? _program.value : null;

  static bool _started = false;

  /// En todas las plataformas donde Flutter dibuja shaders (Android, Windows, Linux).
  static bool get platformCanTry => !kIsWeb;

  /// Carga el shader (después del primer cuadro: no demora el arranque).
  static Future<void> start() async {
    if (_started || !platformCanTry) return;
    _started = true;
    final watch = Stopwatch()..start();
    try {
      _program.value = await ui.FragmentProgram.fromAsset(asset);
      debugPrint('=== VIDRIO REAL: listo en ${watch.elapsedMilliseconds} ms ===');
    } catch (error) {
      debugPrint('=== VIDRIO REAL: no cargó (${error.runtimeType}); queda el vidrio de siempre ===');
    }
  }

  /// Algo falló al dibujarlo: vuelve al de siempre hasta la próxima vez que se abra Kiji.
  static void fail(String why) {
    if (_broken.value) return;
    _broken.value = true;
    debugPrint('=== VIDRIO REAL: falló ($why); vuelve el vidrio de siempre ===');
  }

  /// Solo para las pruebas.
  @visibleForTesting
  static void debugSet({ui.FragmentProgram? program, bool? broken}) {
    if (program != null) _program.value = program;
    if (broken != null) _broken.value = broken;
  }

  @visibleForTesting
  static void debugReset() {
    _started = false;
    _program.value = null;
    _broken.value = false;
    userOn.value = true;
  }
}

class _Active extends ChangeNotifier implements ValueListenable<bool> {
  _Active() {
    for (final source in [RealGlass.userOn, RealGlass._program, RealGlass._broken]) {
      source.addListener(_update);
    }
    _value = _compute();
  }

  late bool _value;

  bool _compute() => RealGlass.userOn.value && RealGlass._program.value != null && !RealGlass._broken.value;

  void _update() {
    final next = _compute();
    if (next == _value) return;
    _value = next;
    notifyListeners();
  }

  @override
  bool get value => _value;
}
