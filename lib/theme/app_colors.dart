import 'kiji_tokens.dart';

/// Nombres de colores que ya usaban las pantallas. Ahora apuntan a los tokens
/// de Kiji Nocturne ([KijiColors]), que son la única fuente de verdad.
abstract final class AppColors {
  static const seed = KijiColors.violet;

  static const background = KijiColors.background;
  static const surface = KijiColors.surface;
  static const surfaceContainer = KijiColors.surfaceHigh;

  static const onSurfaceMuted = KijiColors.muted;
}
