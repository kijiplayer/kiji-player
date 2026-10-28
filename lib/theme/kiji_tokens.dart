// l10n-ignore-file: textos técnicos (no se muestran en la interfaz).
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Estilo de Kiji (Configuración → Apariencia): las mismas funciones con otro aspecto.
/// Nocturne es el de fábrica.
enum KijiStyle {
  /// Oscuro, vidrio, aurora y acento en degradado.
  nocturne,

  /// Minimalista y serio: grises, el acento es el blanco, sin brillos ni degradados.
  graphite,

  /// Claro y tranquilo, como un libro: papel, tinta y un solo acento.
  paper;

  static KijiStyle parse(String? name) => values.asNameMap()[name] ?? nocturne;
}

/// El estilo activo. [KijiApp] lo pone (como la paleta) y redibuja todo al cambiarlo.
abstract final class KijiLook {
  static KijiStyle style = KijiStyle.nocturne;

  static bool get nocturne => style == KijiStyle.nocturne;

  /// Sin aurora, brillos ni degradados (Grafito y Papel).
  static bool get flat => style != KijiStyle.nocturne;

  /// Grafito: "vidrio de museo" (fondo de la portada en blanco y negro, vidrio esmerilado y
  /// animaciones propias).
  static bool get museum => style == KijiStyle.graphite;

  /// Esquinas de las portadas: las de cada pantalla en Nocturne; como mucho 6 px en Grafito y 4 en Papel.
  static double cover(double radius) => switch (style) {
    KijiStyle.nocturne => radius,
    KijiStyle.graphite => math.min(radius, 6),
    KijiStyle.paper => math.min(radius, 4),
  };
}

/// Tokens de diseño de **Kiji Nocturne**. Todo color, radio, tamaño y tipografía de la app sale
/// de aquí, para cambiarlos en un solo lugar.
/// Una paleta completa de Kiji: el tema (oscuro, más oscuro o claro) y el acento elegidos en
/// Configuración → Apariencia. [KijiColors] lee la que esté activa.
@immutable
class KijiPalette {
  const KijiPalette({
    required this.brightness,
    required this.background,
    required this.violet,
    required this.cyan,
    required this.onAccent,
    required this.text,
    required this.muted,
    required this.glassFill,
    required this.glassBorder,
    required this.waveRest,
    required this.surface,
    required this.surfaceHigh,
    this.like,
  });

  final Brightness brightness;
  final Color background;

  /// Acento: degradado de [violet] a [cyan] (con otro acento, sus dos colores).
  final Color violet;
  final Color cyan;
  final Color onAccent;
  final Color text;
  final Color muted;
  final Color glassFill;
  final Color glassBorder;
  final Color waveRest;
  final Color surface;
  final Color surfaceHigh;

  /// Color del "me gusta" (null = el primer color del acento).
  final Color? like;

  bool get isLight => brightness == Brightness.light;

  List<Object?> get _fields => [
    brightness, background, violet, cyan, onAccent, text, muted, glassFill, glassBorder, waveRest, surface,
    surfaceHigh, like,
  ];

  @override
  bool operator ==(Object other) =>
      other is KijiPalette && listEquals(_fields, other._fields);

  @override
  int get hashCode => Object.hashAll(_fields);

  /// Kiji Nocturne de siempre: oscuro con acento violeta → cian.
  static const nocturne = KijiPalette(
    brightness: Brightness.dark,
    background: Color(0xFF07070C),
    violet: Color(0xFF7C5CFF),
    cyan: Color(0xFF3DF5FF),
    onAccent: Color(0xFF07070C),
    text: Colors.white,
    muted: Color(0xFFA9A9C4),
    glassFill: Color(0x1AFFFFFF), // blanco 10 %
    glassBorder: Color(0x1FFFFFFF), // blanco 12 %
    waveRest: Color(0x29FFFFFF), // blanco 16 %
    surface: Color(0xFF12121C),
    surfaceHigh: Color(0xFF1A1A28),
  );

  /// Grafito: fondo #0F0F10, superficies #1A1A1D, texto #F2F2F2 y secundario #9A9A9E; vidrio de
  /// blanco 7 % con borde de blanco 10 %. Sin color de acento: el acento es el blanco.
  static const graphite = KijiPalette(
    brightness: Brightness.dark,
    background: Color(0xFF0F0F10),
    violet: Color(0xFFF2F2F2),
    cyan: Color(0xFFF2F2F2),
    onAccent: Color(0xFF0F0F10),
    text: Color(0xFFF2F2F2),
    muted: Color(0xFF9A9A9E),
    glassFill: Color(0x12FFFFFF), // vidrio esmerilado: blanco 7 %
    glassBorder: Color(0x1AFFFFFF), // blanco 10 %
    waveRest: Color(0x2EFFFFFF), // blanco 18 %
    surface: Color(0xFF1A1A1D),
    surfaceHigh: Color(0xFF1A1A1D),
  );

  /// Papel: fondo #F3F1EC, tinta #1B1B1A, secundario #5E5B55 y líneas #D9D5CC. El único color es
  /// #B4462B, el del "me gusta"; el resto de lo activo va en tinta.
  static const paper = KijiPalette(
    brightness: Brightness.light,
    background: Color(0xFFF3F1EC),
    violet: Color(0xFF1B1B1A),
    cyan: Color(0xFF1B1B1A),
    onAccent: Color(0xFFF3F1EC),
    text: Color(0xFF1B1B1A),
    muted: Color(0xFF5E5B55),
    glassFill: Color(0xFFF9F8F4),
    glassBorder: Color(0xFFD9D5CC),
    waveRest: Color(0xFFCFCAC0),
    surface: Color(0xFFF9F8F4),
    surfaceHigh: Color(0xFFF9F8F4),
    like: Color(0xFFB4462B),
  );

  /// La paleta de [style]: Nocturne con el [theme] y el [accent] elegidos; Grafito y Papel son fijos.
  static KijiPalette forStyle(KijiStyle style, {String theme = 'dark', String accent = 'nocturne'}) =>
      switch (style) {
        KijiStyle.graphite => graphite,
        KijiStyle.paper => paper,
        KijiStyle.nocturne => resolve(theme: theme, accent: accent),
      };

  /// Acentos (el primer color y el segundo del degradado). En el tema claro el segundo se
  /// oscurece un poco para que se lea sobre blanco.
  static const accents = <String, (Color, Color)>{
    'nocturne': (Color(0xFF7C5CFF), Color(0xFF3DF5FF)),
    'aurora': (Color(0xFF3DFFA8), Color(0xFF7C5CFF)),
    'ember': (Color(0xFFFF7A45), Color(0xFFFF3D8B)),
    'mint': (Color(0xFF2EE6A6), Color(0xFF3DB8FF)),
    'ocean': (Color(0xFF3D7BFF), Color(0xFF3DF5FF)),
  };

  /// La paleta para el [theme] ('dark', 'darker' o 'light') y el [accent] elegidos.
  static KijiPalette resolve({String theme = 'dark', String accent = 'nocturne'}) {
    final (first, second) = accents[accent] ?? accents['nocturne']!;
    return switch (theme) {
      // Más oscuro: negro puro (pantallas OLED gastan menos) y superficies más bajas.
      'darker' => KijiPalette(
        brightness: Brightness.dark,
        background: Colors.black,
        violet: first,
        cyan: second,
        onAccent: const Color(0xFF07070C),
        text: Colors.white,
        muted: const Color(0xFF9A9AB2),
        glassFill: const Color(0x12FFFFFF),
        glassBorder: const Color(0x1AFFFFFF),
        waveRest: const Color(0x24FFFFFF),
        surface: const Color(0xFF0A0A10),
        surfaceHigh: const Color(0xFF111119),
      ),
      'light' => KijiPalette(
        brightness: Brightness.light,
        background: const Color(0xFFF4F4FA),
        violet: Color.lerp(first, Colors.black, 0.08)!,
        cyan: Color.lerp(second, Colors.black, 0.35)!,
        onAccent: Colors.white,
        text: const Color(0xFF14141F),
        muted: const Color(0xFF5C5C78),
        glassFill: const Color(0x0F14141F), // tinta 6 %
        glassBorder: const Color(0x1F14141F), // tinta 12 %
        waveRest: const Color(0x2914141F),
        surface: Colors.white,
        surfaceHigh: const Color(0xFFFFFFFF),
      ),
      _ => KijiPalette(
        brightness: Brightness.dark,
        background: nocturne.background,
        violet: first,
        cyan: second,
        onAccent: nocturne.onAccent,
        text: nocturne.text,
        muted: nocturne.muted,
        glassFill: nocturne.glassFill,
        glassBorder: nocturne.glassBorder,
        waveRest: nocturne.waveRest,
        surface: nocturne.surface,
        surfaceHigh: nocturne.surfaceHigh,
      ),
    };
  }
}

/// Tokens de diseño de **Kiji Nocturne**. Todo color, radio, tamaño y tipografía de la app sale
/// de aquí, para cambiarlos en un solo lugar. Los colores salen de la paleta activa
/// ([KijiColors.palette]): `KijiApp` la cambia cuando cambian el tema o el acento y redibuja todo.
abstract final class KijiColors {
  static KijiPalette palette = KijiPalette.nocturne;

  /// Fondo casi negro azulado.
  static Color get background => palette.background;

  /// Acento: degradado violeta → cian.
  static Color get violet => palette.violet;
  static Color get cyan => palette.cyan;

  /// Texto sobre el degradado (pestaña activa, botón play).
  static Color get onAccent => palette.onAccent;

  static Color get text => palette.text;

  /// Gris de íconos inactivos y textos secundarios.
  static Color get muted => palette.muted;

  /// "Vidrio": relleno translúcido y borde de 1 px que brilla apenas.
  static Color get glassFill => palette.glassFill;
  static Color get glassBorder => palette.glassBorder;

  /// Lo que falta reproducir en la barra de ondas.
  static Color get waveRest => palette.waveRest;

  /// Superficies sólidas (hojas, diálogos, tarjetas sin blur).
  static Color get surface => palette.surface;
  static Color get surfaceHigh => palette.surfaceHigh;

  /// El "me gusta".
  static Color get like => palette.like ?? palette.violet;

  static LinearGradient get accentGradient => LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [violet, cyan],
  );

  static LinearGradient get accentGradientDiagonal => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violet, cyan],
  );
}

/// Medidas del "vidrio de museo" de Grafito. Son bajas a propósito: el texto secundario tiene que
/// seguir con contraste de 4,5:1 aunque la portada sea blanca (lo comprueba `test/style_test.dart`).
abstract final class KijiMuseum {
  /// Fondo del reproductor: la portada en blanco y negro, oscurecida a este brillo y con esta opacidad.
  static const backdropBrightness = 0.85;
  static const backdropOpacity = 0.14;

  /// Grano de película (alto rendimiento): opacidad máxima de los puntos claros y de los oscuros
  /// (los oscuros no le quitan contraste al texto claro, así que pueden ser más).
  static const grainOpacity = 0.02;
  static const grainDarkOpacity = 0.08;

  /// El brillo que recorre el vidrio de la portada al abrir el reproductor (no hay texto encima).
  static const sheenOpacity = 0.18;

  /// Paneles sobre cualquier contenido (mini-reproductor, barra de navegación, hojas): el vidrio
  /// de blanco 7 % sobre un ahumado casi opaco, para que el texto se lea encima de una portada clara.
  static const pane = Color(0xEE212123);
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

/// Efectos visuales elegidos en Configuración → Apariencia. KijiApp los pone al abrir y al
/// cambiarlos (y redibuja todo), igual que la paleta.
abstract final class KijiEffects {
  /// "Modo alto rendimiento": animaciones a la frecuencia máxima de la pantalla, más partículas,
  /// desenfoques reales y colores más intensos. Apagado de fábrica.
  static bool rich = false;

  /// "Reducir animaciones" de Kiji (el del sistema se mira con MediaQuery en cada widget).
  static bool calm = false;

  /// true si hay que evitar el movimiento decorativo en [context].
  static bool still(BuildContext context) => calm || MediaQuery.disableAnimationsOf(context);
}

abstract final class KijiMotion {
  /// Transiciones de 200-300 ms.
  static const fast = Duration(milliseconds: 200);
  static const normal = Duration(milliseconds: 260);

  /// Un ciclo del anillo que "respira" alrededor del botón play.
  static const breath = Duration(milliseconds: 2400);

  /// Movimientos con protagonismo (carátula que se expande).
  static const emphasized = Duration(milliseconds: 350);
  static const emphasizedCurve = Curves.easeInOutCubicEmphasized;

  /// Demora entre ítems de una lista que entra escalonada.
  static const stagger = Duration(milliseconds: 40);

  /// La onda que se dibuja de izquierda a derecha.
  static const waveReveal = Duration(milliseconds: 600);
}

/// Tipografía de cada estilo (Nocturne: Space Grotesk y JetBrains Mono; Grafito: Inter; Papel:
/// Newsreader e Inter). Space Grotesk para títulos y JetBrains Mono para tiempos y
/// números. Son fuentes variables: el peso se pide con `fontVariations`
/// (además de `fontWeight`) para que se vea igual en todas las plataformas.
abstract final class KijiText {
  /// Configuración → Apariencia → Tipografía: con "Sistema", los títulos y números usan la
  /// fuente del teléfono o la PC (null = la de siempre del sistema).
  static bool useSystemFont = false;

  static String? get titleFamily => useSystemFont ? null : titleFamilyOf(KijiLook.style);

  /// Letra de los títulos de cada estilo (también para las miniaturas de la elección de estilo).
  static String titleFamilyOf(KijiStyle style) => switch (style) {
    KijiStyle.nocturne => 'SpaceGrotesk',
    KijiStyle.graphite => 'Inter',
    KijiStyle.paper => 'Newsreader',
  };

  /// Letra del cuerpo en Grafito y Papel.
  static const inter = 'Inter';

  /// Tiempos y números: JetBrains Mono en Nocturne; Inter (con cifras tabulares) en los demás.
  static String? get monoFamily => useSystemFont ? null : (KijiLook.nocturne ? 'JetBrainsMono' : inter);

  /// El resto del texto: el del sistema en Nocturne; Inter en Grafito y Papel.
  static String? get bodyFamily => useSystemFont || KijiLook.nocturne ? null : inter;

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
        // Papel: etiquetas chicas (en mayúsculas) con más espaciado.
        letterSpacing: KijiLook.style == KijiStyle.paper ? 1.4 : 0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
