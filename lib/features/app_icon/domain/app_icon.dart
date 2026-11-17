import 'package:flutter/painting.dart';

import '../../../theme/kiji_tokens.dart';

/// "Ícono a juego con el estilo" (0.8.3): qué ícono le toca a cada estilo. Nocturne, uno por
/// acento (con un acento propio, el de los cinco que más se le parezca: Android no puede dibujar
/// íconos nuevos, solo elegir entre los que trae la app); Grafito y Papel, el suyo.
const appIconVariants = ['nocturne', 'aurora', 'ember', 'mint', 'ocean', 'graphite', 'paper'];

/// El ícono de siempre (opción apagada).
const defaultAppIcon = 'default';

String appIconFor({required KijiStyle style, required String accent, int? customAccent}) {
  switch (style) {
    case KijiStyle.graphite:
      return 'graphite';
    case KijiStyle.paper:
      return 'paper';
    case KijiStyle.nocturne:
      if (KijiPalette.accents.containsKey(accent)) return accent;
      if (customAccent == null) return 'nocturne';
      return nearestAccent(Color(customAccent));
  }
}

/// El acento de Kiji más parecido a [color] (por el tono; sin saturación, el de siempre).
String nearestAccent(Color color) {
  final hsv = HSVColor.fromColor(color);
  if (hsv.saturation < 0.15) return 'nocturne';
  var best = 'nocturne';
  var bestDistance = double.infinity;
  for (final MapEntry(key: name, value: (first, _)) in KijiPalette.accents.entries) {
    final hue = HSVColor.fromColor(first).hue;
    final raw = (hue - hsv.hue).abs();
    final distance = raw > 180 ? 360 - raw : raw;
    if (distance < bestDistance) {
      bestDistance = distance;
      best = name;
    }
  }
  return best;
}

/// Cambia el ícono de la app (Android: alias del lanzador; Windows: ícono de la ventana).
abstract class AppIconChanger {
  const AppIconChanger();

  /// Hay íconos por estilo en esta plataforma.
  bool get supported;

  /// Android: el cambio puede cerrar la app un momento en algunos lanzadores, así que se aplica
  /// al salir de Kiji y sin música. Windows: al momento.
  bool get appliesOnExit;

  /// El ícono que tiene ahora ([defaultAppIcon] si es el de siempre).
  Future<String> current();

  /// Pone [variant] (una de [appIconVariants] o [defaultAppIcon]). false si no se pudo.
  Future<bool> apply(String variant);
}
