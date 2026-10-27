import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'kiji_tokens.dart';

/// Transición entre pantallas de Kiji: fundido + escala 0,96 → 1
/// al entrar; la de abajo se aleja un poco. Con "Reducir animaciones", sin
/// movimiento.
class KijiPageTransitionsBuilder extends PageTransitionsBuilder {
  const KijiPageTransitionsBuilder({this.still = false});

  final bool still;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (still || MediaQuery.disableAnimationsOf(context)) return child;
    final enter = CurvedAnimation(parent: animation, curve: KijiMotion.emphasizedCurve);
    final leave = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: enter,
      child: ScaleTransition(
        scale: Tween(begin: 0.96, end: 1.0).animate(enter),
        child: ScaleTransition(scale: Tween(begin: 1.0, end: 0.98).animate(leave), child: child),
      ),
    );
  }
}

abstract final class AppTheme {
  static ThemeData get dark => darkWith();

  /// Tema de Material para la paleta activa ([KijiColors.palette]): oscuro, más oscuro o claro.
  static ThemeData darkWith({bool reduceMotion = false}) {
    final brightness = KijiColors.palette.brightness;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: KijiColors.violet,
      brightness: brightness,
      surface: KijiColors.surface,
    ).copyWith(
      primary: KijiColors.violet,
      secondary: KijiColors.cyan,
      onSurface: KijiColors.text,
    );

    // El cuerpo: la fuente del sistema en Nocturne; Inter en Grafito y Papel.
    final base = ThemeData(useMaterial3: true, brightness: brightness, fontFamily: KijiText.bodyFamily);
    // Títulos con la letra del estilo (Space Grotesk, Inter o Newsreader).
    final textTheme = base.textTheme.copyWith(
      displaySmall: KijiText.title(size: 34),
      headlineMedium: KijiText.title(size: 28),
      headlineSmall: KijiText.title(size: 24),
      titleLarge: KijiText.title(size: 22),
      titleMedium: KijiText.title(size: 16, weight: FontWeight.w600),
      titleSmall: KijiText.title(size: 14, weight: FontWeight.w600),
    );

    final transitions = KijiPageTransitionsBuilder(still: reduceMotion);
    return base.copyWith(
      pageTransitionsTheme: PageTransitionsTheme(builders: {
        for (final platform in TargetPlatform.values) platform: transitions,
      }),
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: KijiColors.background,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: KijiColors.text,
        titleTextStyle: KijiText.title(size: 22),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: KijiColors.surfaceHigh,
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: KijiColors.surfaceHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KijiRadii.card),
          side: BorderSide(color: KijiColors.glassBorder),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: KijiColors.surfaceHigh,
        contentTextStyle: TextStyle(color: KijiColors.text),
        actionTextColor: KijiColors.cyan,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KijiRadii.tile),
          side: BorderSide(color: KijiColors.glassBorder),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: KijiColors.cyan,
        thumbColor: KijiColors.text,
        inactiveTrackColor: KijiColors.waveRest,
      ),
    );
  }
}

/// Partes que son siempre oscuras (la letra y sus hojas, que se leen sobre la carátula
/// difuminada), sea cual sea el tema elegido: textos, íconos y controles de Material en claro.
/// El acento sigue siendo el elegido.
class AlwaysDark extends StatelessWidget {
  const AlwaysDark({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: KijiColors.violet,
      brightness: Brightness.dark,
      surface: KijiPalette.nocturne.surface,
    ).copyWith(primary: KijiColors.violet, secondary: KijiColors.cyan, onSurface: Colors.white);
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        colorScheme: scheme,
        textTheme: Theme.of(context).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
        dividerColor: Colors.white12,
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: IconTheme.merge(data: const IconThemeData(color: Colors.white), child: child),
      ),
    );
  }
}
