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
      onPrimary: KijiColors.onAccent,
      secondary: KijiColors.cyan,
      onSecondary: KijiColors.onAccent,
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
    ).withSelection(KijiSelected.colors);
  }
}

/// Colores de lo "elegido": relleno, su texto, lo no elegido, el borde y el fondo apagado.
typedef SelectionColors = ({Color fill, Color onFill, Color muted, Color border, Color off});

/// Todo lo "elegido" (pestañas, chips, filtros, interruptores, radios, casillas y botones
/// activos): relleno del acento con el texto en [KijiColors.onAccent]. En Grafito el acento es el
/// blanco, así que el texto es oscuro; en Papel, la tinta, y el texto es claro. Cada par está en
/// `test/selected_contrast_test.dart`.
abstract final class KijiSelected {
  static SelectionColors get colors => (
    fill: KijiColors.violet,
    onFill: KijiColors.onAccent,
    muted: KijiColors.muted,
    border: KijiColors.glassBorder,
    off: KijiColors.surfaceHigh,
  );

  /// Para las partes siempre oscuras (la letra): con una paleta clara, lo elegido va en blanco
  /// (Grafito y Papel) o con el acento (Nocturne claro), y lo demás en el gris de Nocturne.
  static SelectionColors get onDark {
    final p = KijiColors.palette;
    if (!p.isLight) return colors;
    return (
      fill: KijiLook.nocturne ? p.violet : KijiPalette.graphite.text,
      onFill: KijiLook.nocturne ? p.onAccent : KijiPalette.graphite.background,
      muted: KijiPalette.nocturne.muted,
      border: KijiPalette.nocturne.glassBorder,
      off: KijiPalette.nocturne.surfaceHigh,
    );
  }

  /// Fila elegida en una lista (selección múltiple): el acento muy suave detrás del texto normal.
  static Color get tile => KijiColors.violet.withValues(alpha: 0.14);
}

extension KijiSelectionTheme on ThemeData {
  /// Este tema con los componentes "elegidos" pintados con [c].
  ThemeData withSelection(SelectionColors c) {
    WidgetStateProperty<Color?> pick(Color selected, Color? other) =>
        WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? selected : other);
    return copyWith(
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: pick(c.fill, Colors.transparent),
          foregroundColor: pick(c.onFill, c.muted),
          iconColor: pick(c.onFill, c.muted),
          side: WidgetStatePropertyAll(BorderSide(color: c.border)),
        ),
      ),
      chipTheme: ChipThemeData(
        selectedColor: c.fill,
        checkmarkColor: c.onFill,
        side: BorderSide(color: c.border),
        // El chip resuelve el color del texto por estado (no el estilo entero).
        labelStyle: TextStyle(
          color: WidgetStateColor.resolveWith((s) => s.contains(WidgetState.selected) ? c.onFill : c.muted),
          fontWeight: FontWeight.w600,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: pick(c.onFill, c.muted),
        trackColor: pick(c.fill, c.off),
        trackOutlineColor: pick(c.fill, c.muted),
      ),
      radioTheme: RadioThemeData(fillColor: pick(c.fill, c.muted)),
      checkboxTheme: CheckboxThemeData(
        fillColor: pick(c.fill, Colors.transparent),
        checkColor: WidgetStatePropertyAll(c.onFill),
        side: BorderSide(color: c.muted, width: 1.5),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(backgroundColor: c.fill, foregroundColor: c.onFill),
      ),
      tabBarTheme: TabBarThemeData(labelColor: c.fill, unselectedLabelColor: c.muted, indicatorColor: c.fill),
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
      data: Theme.of(context).withSelection(KijiSelected.onDark).copyWith(
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
