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

  static ThemeData darkWith({bool reduceMotion = false}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: KijiColors.violet,
      brightness: Brightness.dark,
      surface: KijiColors.surface,
    ).copyWith(
      primary: KijiColors.violet,
      secondary: KijiColors.cyan,
    );

    final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
    // Títulos en Space Grotesk; el cuerpo queda con la fuente del sistema.
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
        foregroundColor: Colors.white,
        titleTextStyle: KijiText.title(size: 22),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: KijiColors.surfaceHigh,
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: KijiColors.surfaceHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KijiRadii.card),
          side: const BorderSide(color: KijiColors.glassBorder),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: KijiColors.surfaceHigh,
        contentTextStyle: const TextStyle(color: Colors.white),
        actionTextColor: KijiColors.cyan,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KijiRadii.tile),
          side: const BorderSide(color: KijiColors.glassBorder),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: KijiColors.cyan,
        thumbColor: Colors.white,
        inactiveTrackColor: KijiColors.waveRest,
      ),
    );
  }
}
