import 'package:flutter/material.dart';

import 'kiji_tokens.dart';

/// Nombres de colores que ya usaban las pantallas. Ahora apuntan a los tokens
/// de Kiji Nocturne ([KijiColors]), que son la única fuente de verdad.
abstract final class AppColors {
  static Color get seed => KijiColors.violet;

  static Color get background => KijiColors.background;
  static Color get surface => KijiColors.surface;
  static Color get surfaceContainer => KijiColors.surfaceHigh;

  static Color get onSurfaceMuted => KijiColors.muted;
}
