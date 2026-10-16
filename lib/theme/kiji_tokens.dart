import 'package:flutter/material.dart';

/// Tokens de diseño de **Kiji Nocturne** (mockup aprobado el
/// 15/10/2026). Todo color, radio, tamaño y tipografía de la app sale de acá,
/// para que Personalización (Tarea P) pueda cambiarlos en un solo lugar.
abstract final class KijiColors {
  /// Fondo casi negro azulado.
  static const background = Color(0xFF07070C);

  /// Acento: degradado violeta → cian.
  static const violet = Color(0xFF7C5CFF);
  static const cyan = Color(0xFF3DF5FF);

  /// Texto sobre el degradado (pestaña activa, botón play).
  static const onAccent = Color(0xFF07070C);

  static const text = Colors.white;

  /// Gris de íconos inactivos y textos secundarios.
  static const muted = Color(0xFFA9A9C4);

  /// "Vidrio": relleno translúcido y borde de 1 px que brilla apenas.
  static const glassFill = Color(0x1AFFFFFF); // blanco 10 %
  static const glassBorder = Color(0x1FFFFFFF); // blanco 12 %

  /// Lo que falta reproducir en la barra de ondas.
  static const waveRest = Color(0x29FFFFFF); // blanco 16 %

  /// Superficies sólidas (hojas, diálogos, tarjetas sin blur).
  static const surface = Color(0xFF12121C);
  static const surfaceHigh = Color(0xFF1A1A28);

  static const accentGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [violet, cyan],
  );

  static const accentGradientDiagonal = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violet, cyan],
  );
}

abstract final class KijiRadii {
  static const miniPlayer = 20.0;
  static const cover = 28.0;
  static const card = 20.0;
  static const pill = 999.0;
  static const tile = 12.0;
}

abstract final class KijiSizes {
  /// Ancho desde el que se usa el diseño de PC (barra lateral y paneles).
  static const desktopBreakpoint = 1000.0;
  static const playerCover = 320.0;
  static const playButton = 84.0;
  static const glassBlur = 18.0;
  static const progressLine = 2.0;
}

abstract final class KijiMotion {
  /// Transiciones de 200-300 ms (§7).
  static const fast = Duration(milliseconds: 200);
  static const normal = Duration(milliseconds: 260);

  /// Un ciclo del anillo que "respira" alrededor del botón play.
  static const breath = Duration(milliseconds: 2400);
}

/// Tipografía: Space Grotesk para títulos y JetBrains Mono para tiempos y
/// números. Son fuentes variables: el peso se pide con `fontVariations`
/// (además de `fontWeight`) para que se vea igual en todas las plataformas.
abstract final class KijiText {
  static const titleFamily = 'SpaceGrotesk';
  static const monoFamily = 'JetBrainsMono';

  static TextStyle title({double size = 20, FontWeight weight = FontWeight.w700, Color? color}) =>
      TextStyle(
        fontFamily: titleFamily,
        fontSize: size,
        fontWeight: weight,
        fontVariations: [FontVariation('wght', weight.value.toDouble())],
        color: color ?? KijiColors.text,
        height: 1.15,
      );

  static TextStyle mono({double size = 12, FontWeight weight = FontWeight.w500, Color? color}) =>
      TextStyle(
        fontFamily: monoFamily,
        fontSize: size,
        fontWeight: weight,
        fontVariations: [FontVariation('wght', weight.value.toDouble())],
        color: color ?? KijiColors.muted,
        letterSpacing: 0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
