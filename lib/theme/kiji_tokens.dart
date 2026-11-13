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
    brightness,
    background,
    violet,
    cyan,
    onAccent,
    text,
    muted,
    glassFill,
    glassBorder,
    waveRest,
    surface,
    surfaceHigh,
    like,
  ];

  @override
  bool operator ==(Object other) => other is KijiPalette && listEquals(_fields, other._fields);

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

  /// La paleta de [style]: Nocturne con el [theme] y el [accent] elegidos; Grafito y Papel con sus
  /// colores. Con un acento propio ([custom], en los tres estilos), ese color ajustado para que se lea.
  static KijiPalette forStyle(
    KijiStyle style, {
    String theme = 'dark',
    String accent = 'nocturne',
    Color? custom,
  }) {
    final base = switch (style) {
      KijiStyle.graphite => graphite,
      KijiStyle.paper => paper,
      KijiStyle.nocturne => resolve(theme: theme, accent: custom == null ? accent : 'nocturne'),
    };
    if (custom == null) return base;
    // Nocturne: un degradado del color elegido a uno vecino (el tono girado). Grafito y Papel: un
    // solo color, como su acento de siempre.
    final second = style == KijiStyle.nocturne ? _neighbor(custom) : custom;
    return base.withAccent(custom, second);
  }

  /// El tono de [color] girado 40° (el segundo color del degradado de Nocturne).
  static Color _neighbor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withHue((hsl.hue + 40) % 360).toColor();
  }

  /// Contraste WCAG entre dos colores opacos (1 a 21).
  static double contrastOf(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  /// [color] aclarado (fondo oscuro) u oscurecido (fondo claro) de a poco hasta tener contraste de
  /// 4,5:1 con todos los [behind]. Es lo que hace Kiji con un acento propio: lo muestra así, sin avisos.
  static Color readableOn(Color color, List<Color> behind, {bool light = false}) {
    var c = color.withValues(alpha: 1);
    for (var i = 0; i < 60 && behind.any((b) => contrastOf(c, b) < 4.5); i++) {
      c = Color.lerp(c, light ? Colors.black : Colors.white, 0.06)!;
    }
    return c;
  }

  /// Esta paleta con el acento [first]→[second] (ajustados para que se lean sobre el fondo y las
  /// superficies) y el texto de encima que mejor se lee (claro u oscuro, también a 4,5:1).
  KijiPalette withAccent(Color first, Color second) {
    final behind = [background, surface, surfaceHigh];
    final a = readableOn(first, behind, light: isLight);
    final b = readableOn(second, behind, light: isLight);
    // Encima del acento: el fondo (oscuro en los estilos oscuros, claro en Papel) si se lee; si no,
    // el otro extremo.
    final options = [background, if (isLight) Colors.white else Colors.black, text];
    Color on = options.first;
    for (final o in options) {
      if (math.min(contrastOf(o, a), contrastOf(o, b)) > math.min(contrastOf(on, a), contrastOf(on, b))) on = o;
    }
    return KijiPalette(
      brightness: brightness,
      background: background,
      violet: a,
      cyan: b,
      onAccent: on,
      text: text,
      muted: muted,
      glassFill: glassFill,
      glassBorder: glassBorder,
      waveRest: waveRest,
      surface: surface,
      surfaceHigh: surfaceHigh,
      like: like,
    );
  }

  /// Con un fondo propio: el gris secundario más cerca del color del texto. Así se lee a 4,5:1 sobre
  /// la foto con mucha menos capa encima, y la foto se ve.
  KijiPalette withBackgroundPhoto() => KijiPalette(
    brightness: brightness,
    background: background,
    violet: violet,
    cyan: cyan,
    onAccent: onAccent,
    text: text,
    muted: Color.lerp(muted, text, 0.55)!,
    glassFill: glassFill,
    glassBorder: glassBorder,
    waveRest: waveRest,
    surface: surface,
    surfaceHigh: surfaceHigh,
    like: like,
  );

  /// Acentos (el primer color y el segundo del degradado). En el tema claro el segundo se
  /// oscurece un poco para que se lea sobre blanco.
  static const accents = <String, (Color, Color)>{
    'nocturne': (Color(0xFF7C5CFF), Color(0xFF3DF5FF)),
    'aurora': (Color(0xFF3DFFA8), Color(0xFF7C5CFF)),
    'ember': (Color(0xFFFF7A45), Color(0xFFFF3D8B)),
    'mint': (Color(0xFF2EE6A6), Color(0xFF3DB8FF)),
    'ocean': (Color(0xFF3D7BFF), Color(0xFF3DF5FF)),
  };

  /// [color] oscurecido de a poco hasta tener contraste de 4,5:1 con el blanco encima y con el
  /// fondo claro (#F4F4FA) detrás: luminancia de 0,16 como mucho.
  static Color _readableUnderWhite(Color color) {
    var c = color;
    while (c.computeLuminance() > 0.16) {
      c = Color.lerp(c, Colors.black, 0.05)!;
    }
    return c;
  }

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
        // Oscurecidos lo justo para que el texto blanco encima (pestaña elegida, play) se lea.
        violet: _readableUnderWhite(Color.lerp(first, Colors.black, 0.08)!),
        cyan: _readableUnderWhite(Color.lerp(second, Colors.black, 0.35)!),
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

  /// Reacciones de teatro: el tomate (rojo en Nocturne, el rojo tinta en Papel, blanco y negro en
  /// Grafito), su hojita y el brillo, según el estilo.
  static Color get theaterTomato => switch (KijiLook.style) {
    KijiStyle.nocturne => const Color(0xFFD7262E),
    KijiStyle.paper => const Color(0xFFB4462B),
    KijiStyle.graphite => palette.text,
  };
  static Color get theaterLeaf => switch (KijiLook.style) {
    KijiStyle.nocturne => const Color(0xFF2E9B3A),
    KijiStyle.paper => const Color(0xFF4F6B3A),
    KijiStyle.graphite => palette.muted,
  };

  /// El telón (terciopelo) y su sombra, el dorado de los flecos y el "¡BRAVO!", el reflector y el
  /// confeti, según el estilo (Grafito en grises, Papel en tinta).
  static Color get theaterCurtain => switch (KijiLook.style) {
    KijiStyle.nocturne => const Color(0xFF8E1B2B),
    KijiStyle.paper => const Color(0xFF9C2F22),
    KijiStyle.graphite => const Color(0xFF2B2B2E),
  };
  static Color get theaterCurtainShadow => Color.lerp(theaterCurtain, const Color(0xFF000000), 0.55)!;
  static Color get theaterGold => switch (KijiLook.style) {
    KijiStyle.nocturne => const Color(0xFFE8C26A),
    KijiStyle.paper => const Color(0xFF8A6A2A),
    KijiStyle.graphite => palette.text,
  };
  static Color get theaterSpot => switch (KijiLook.style) {
    KijiStyle.paper => const Color(0xFFFFF4D6),
    _ => const Color(0xFFFFF1C8),
  };
  static List<Color> get theaterConfetti => switch (KijiLook.style) {
    KijiStyle.graphite => [palette.text, palette.muted, palette.waveRest, const Color(0xFF8C8C90)],
    _ => [palette.violet, palette.cyan, like, theaterGold, theaterTomato],
  };

  /// El cartel de "Tu Teatro" (como uno de teatro antiguo): el papel y la tinta, según el estilo.
  /// La tinta sobre el papel siempre con 4,5:1 o más (test/theater_test.dart).
  static Color get theaterPosterPaper => switch (KijiLook.style) {
    KijiStyle.nocturne => const Color(0xFF2A0D14),
    KijiStyle.paper => const Color(0xFFF3E7CC),
    KijiStyle.graphite => const Color(0xFF161618),
  };
  static Color get theaterPosterInk => switch (KijiLook.style) {
    KijiStyle.nocturne => const Color(0xFFF6E9CC),
    KijiStyle.paper => const Color(0xFF2B211A),
    KijiStyle.graphite => const Color(0xFFF2F2F2),
  };

  /// Lo destacado del cartel (títulos, puestos, adornos): dorado en Nocturne, rojo tinta en Papel.
  static Color get theaterPosterAccent => switch (KijiLook.style) {
    KijiStyle.nocturne => const Color(0xFFE8C26A),
    KijiStyle.paper => const Color(0xFF8E2A1E),
    KijiStyle.graphite => const Color(0xFFFFFFFF),
  };

  /// Las rosas del teatro: siempre rosas (no el "me gusta", que con un acento propio puede ser gris),
  /// blancas en Grafito.
  static Color get theaterRose => switch (KijiLook.style) {
    KijiStyle.nocturne => const Color(0xFFE8335F),
    KijiStyle.paper => const Color(0xFFB02A47),
    KijiStyle.graphite => palette.text,
  };

  /// Un brillo claro sobre [c] (el reflejo del tomate).
  static Color shine(Color c) => Color.lerp(c, const Color(0xFFFFFFFF), 0.6)!.withValues(alpha: 0.35);

  /// [c] más oscuro (el centro de la rosa).
  static Color shade(Color c) => Color.lerp(c, const Color(0xFF000000), 0.25)!;

  static LinearGradient get accentGradient =>
      LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [violet, cyan]);

  static LinearGradient get accentGradientDiagonal =>
      LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [violet, cyan]);
}

/// Fondo propio (Apariencia → Fondo): la capa del color del estilo que va encima de la foto o el
/// video para que el texto se lea (4,5:1 el texto y el gris secundario). Se usa la menor que
/// alcance para [tone], el tono medio de la foto (ver
/// `backgroundToneProvider`). Sin [tone] (un video, o mientras se mide) se supone el peor caso: una
/// foto blanca (estilos oscuros) o negra (Papel).
double backgroundScrim(KijiPalette palette, double opacity, {Color? tone}) {
  final worst = tone ?? (palette.isLight ? Colors.black : Colors.white);
  final behind = Color.lerp(palette.background, worst, opacity.clamp(0, 1))!;
  for (var s = 0.0; s <= 1.0; s += 0.02) {
    final result = Color.lerp(behind, palette.background, s)!;
    if (KijiPalette.contrastOf(palette.muted, result) >= 4.5 && KijiPalette.contrastOf(palette.text, result) >= 4.5) {
      return s;
    }
  }
  return 1;
}

/// Medidas del "vidrio de museo" de Grafito. Son bajas a propósito: el texto secundario tiene que
/// seguir con contraste de 4,5:1 aunque la portada sea blanca (lo comprueba `test/style_test.dart`).
abstract final class KijiMuseum {
  /// Fondo del reproductor: la portada en blanco y negro, oscurecida a este brillo y con esta opacidad.
  static const backdropBrightness = 0.72;
  static const backdropOpacity = 0.12;

  /// Paneles sobre cualquier contenido (mini-reproductor, barra de navegación, hojas): vidrio
  /// ahumado que deja ver el 12 % de lo de atrás. Es lo máximo para que el texto gris (#9A9A9E) siga
  /// en 4,5:1 aunque detrás haya una portada blanca.
  static const pane = Color(0xE0161617);
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

  /// Ancho máximo de la columna del reproductor (onda, título y controles) en una ventana ancha,
  /// y el de la pantalla completa (la portada es más grande).
  static const playerMaxWidth = 560.0;
  static const playerFullWidth = 760.0;
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

  /// Curva de lo que tiene protagonismo: un resorte en Grafito, la de Material en los demás.
  static Curve get emphasizedCurve => KijiLook.museum ? spring : Curves.easeInOutCubicEmphasized;

  /// Resorte (Grafito): nada se mueve en línea recta ni con una curva fija; llega con un rebote
  /// apenas visible. [softSpring] casi no rebota (para lo que entra desde el borde de la pantalla).
  static const spring = SpringCurve();
  static const softSpring = SpringCurve(damping: 0.9);

  /// Demora entre ítems de una lista que entra escalonada.
  static const stagger = Duration(milliseconds: 40);

  /// La onda que se dibuja de izquierda a derecha.
  static const waveReveal = Duration(milliseconds: 600);
}

/// Curva que sigue a un resorte real (amortiguado): sale rápido, se pasa un poco de la meta y se
/// asienta. [damping] 1 = sin rebote. Termina exactamente en 1.
class SpringCurve extends Curve {
  const SpringCurve({this.damping = 0.78});

  final double damping;

  @override
  double transformInternal(double t) {
    if (t >= 1) return 1;
    // Frecuencia elegida para que el resorte quede quieto (error < 0,2 %) justo al final.
    final w = 6.5 / damping;
    final decay = math.exp(-damping * w * t);
    if (damping >= 1) return 1 - decay * (1 + w * t);
    final wd = w * math.sqrt(1 - damping * damping);
    return 1 - decay * (math.cos(wd * t) + damping * w / wd * math.sin(wd * t));
  }
}

/// Tipografía de cada estilo (Nocturne: Space Grotesk y JetBrains Mono; Grafito: Inter; Papel:
/// Newsreader e Inter). Space Grotesk para títulos y JetBrains Mono para tiempos y
/// números. Son fuentes variables: el peso se pide con `fontVariations`
/// (además de `fontWeight`) para que se vea igual en todas las plataformas.
abstract final class KijiText {
  /// Configuración → Apariencia → Tipografía: con "Sistema", los títulos y números usan la
  /// fuente del teléfono o la PC (null = la de siempre del sistema).
  static bool useSystemFont = false;

  /// Una de las fuentes incluidas, elegida en Apariencia → Tipografía (null = la del estilo). Va en
  /// los títulos y el texto; los tiempos y números siguen con la del estilo.
  static String? chosenFamily;

  /// La familia de cada opción de "Tipografía" (null = la del estilo o la del sistema).
  static String? familyFor(String font) => switch (font) {
    'spacegrotesk' => 'SpaceGrotesk',
    'inter' => inter,
    'newsreader' => 'Newsreader',
    'jetbrainsmono' => 'JetBrainsMono',
    _ => null,
  };

  static String? get titleFamily => useSystemFont ? null : (chosenFamily ?? titleFamilyOf(KijiLook.style));

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
  static String? get bodyFamily =>
      useSystemFont ? null : (chosenFamily ?? (KijiLook.nocturne ? null : inter));

  /// Letra del cartel de "Tu Teatro": con serifa (Newsreader, incluida), como un cartel antiguo.
  static TextStyle poster({double size = 28, FontWeight weight = FontWeight.w700, Color? color, double spacing = 0}) => TextStyle(
    fontFamily: useSystemFont ? null : 'Newsreader',
    fontSize: size,
    fontWeight: weight,
    height: 1.1,
    letterSpacing: spacing,
    color: color ?? KijiColors.theaterPosterInk,
  );

  static TextStyle title({double size = 20, FontWeight weight = FontWeight.w700, Color? color}) => TextStyle(
    fontFamily: titleFamily,
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation('wght', weight.value.toDouble())],
    color: color ?? KijiColors.text,
    height: 1.15,
  );

  /// Título de una sección (Inicio, listas). Grafito: una etiqueta chica, espaciada y en gris (el
  /// contenido es el protagonista); los demás, un título. Con [sectionText] para el texto.
  static TextStyle section({double size = 18}) => KijiLook.museum
      ? TextStyle(
          fontFamily: bodyFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
          color: KijiColors.muted,
          height: 1.4,
        )
      : title(size: size);

  /// El texto de un título de sección (en Grafito, en mayúsculas).
  static String sectionText(String text) => KijiLook.museum ? text.toUpperCase() : text;

  /// Título grande y protagonista (saludo, canción que suena). Grafito: grande y fino.
  static TextStyle display({double size = 30}) => KijiLook.museum
      ? title(size: size + 6, weight: FontWeight.w300).copyWith(letterSpacing: -0.8, height: 1.08)
      : title(size: size);

  static TextStyle mono({double size = 12, FontWeight weight = FontWeight.w500, Color? color}) => TextStyle(
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
