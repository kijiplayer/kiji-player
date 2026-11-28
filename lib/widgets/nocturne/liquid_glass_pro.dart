// «Liquid Glass real» (0.9, opcional, apagado de fábrica): la barra de pestañas, el mini-reproductor
// y los botones flotantes con liquid_glass_widgets (MIT), tal como viene: vidrio incoloro, un poco
// desenfocado, refracción, brillo en el borde con arcoíris y animaciones tipo agua. Pensado para
// teléfonos de gama alta. Si el equipo no puede, queda el vidrio de siempre.
import 'dart:async';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' show LiquidGlassWidgets;

/// Por qué este equipo no puede usar el Liquid Glass real.
enum LiquidGlassProBlock {
  /// Puede.
  none,

  /// El motor de dibujo no tiene shaders de filtro (Android sin Impeller).
  noShaders,

  /// Teléfono de 32 bits.
  arm32,
}

abstract final class LiquidGlassPro {
  /// Prendido y posible (lo mantiene al día la app, desde los ajustes).
  static final active = ValueNotifier<bool>(false);

  static LiquidGlassProBlock? _block;

  /// ¿Este equipo puede? En Windows y Linux el paquete usa su versión liviana: también vale.
  static LiquidGlassProBlock get block => _block ??= _detect();

  static LiquidGlassProBlock _detect() {
    if (kIsWeb || !Platform.isAndroid) return LiquidGlassProBlock.none;
    final abi = Abi.current();
    if (abi == Abi.androidArm || abi == Abi.androidIA32) return LiquidGlassProBlock.arm32;
    if (!ui.ImageFilter.isShaderFilterSupported) return LiquidGlassProBlock.noShaders;
    return LiquidGlassProBlock.none;
  }

  static bool get supported => block == LiquidGlassProBlock.none;

  static Future<void>? _init;

  /// Carga los shaders del paquete (una vez, la primera vez que se prende).
  static Future<void> ensureInitialized() => _init ??= () async {
    final watch = Stopwatch()..start();
    try {
      await LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);
      debugPrint('=== LIQUID GLASS: listo en ${watch.elapsedMilliseconds} ms ===');
    } catch (error) {
      debugPrint('=== LIQUID GLASS: no cargó (${error.runtimeType}); queda el vidrio de siempre ===');
      active.value = false;
    }
  }();

  /// Lo llama la app cuando cambia el ajuste.
  static void setOn(bool on) {
    final next = on && supported;
    if (next) unawaited(ensureInitialized());
    active.value = next;
  }

  @visibleForTesting
  static void debugSetBlock(LiquidGlassProBlock? block) => _block = block;
}
