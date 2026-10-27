// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivo de referencia: app/src/main/kotlin/.../ui/player/PlayerColorExtractor.kt (el color del
// fondo del reproductor sale de la carátula real).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/track.dart';
import '../../providers/appearance_provider.dart';
import '../../theme/kiji_tokens.dart';
import '../../widgets/album_cover.dart';
import '../../widgets/nocturne/aurora_background.dart';

/// Colores ya calculados (por id de canción), para no repetir el trabajo.
final _coverColors = <String, Color>{};

/// El color real de la carátula de [track] si ya se calculó (lo comparten el halo y la letra).
Color? knownCoverAccent(String trackId) => _coverColors[trackId];

/// Calcula (una vez por canción) el color real de la carátula.
Future<Color?> coverAccentFor(Track track, ImageProvider? image) async {
  final known = _coverColors[track.id];
  if (known != null || image == null) return known;
  final scheme = await ColorScheme.fromImageProvider(provider: image, brightness: Brightness.dark);
  return _coverColors[track.id] = scheme.primary;
}

/// Tres colores de la carátula (principal y dos parientes), ya calculados, por id de canción.
final _coverPalettes = <String, List<Color>>{};

/// Los colores de la aurora para [track]: los de la carátula si ya se calcularon; si no, el color
/// guardado de la canción mezclado con el acento.
List<Color> auroraColorsFor(Track track) => _withAccent(
  _coverPalettes[track.id] ??
      [
        track.coverColor,
        Color.lerp(track.coverColor, KijiColors.violet, 0.5)!,
        Color.lerp(track.coverColor, KijiColors.cyan, 0.35)!,
      ],
);

/// Las carátulas casi sin color (blanco y negro, sepia, crema) darían una aurora gris: se tiñen con
/// el acento de Kiji, más cuanto menos color tienen (croma: saturación y luminosidad juntas).
List<Color> _withAccent(List<Color> colors) {
  final accents = [KijiColors.violet, KijiColors.cyan, KijiColors.violet];
  return [
    for (var i = 0; i < colors.length; i++)
      Color.lerp(colors[i], accents[i % accents.length], _tint(colors[i]))!,
  ];
}

double _tint(Color color) {
  final hsl = HSLColor.fromColor(color);
  final chroma = (1 - (2 * hsl.lightness - 1).abs()) * hsl.saturation;
  return ((0.35 - chroma) / 0.35).clamp(0.0, 1.0) * 0.7;
}

/// Animaciones del reproductor. Todas se apagan con "Reducir
/// animaciones".

/// Fondo del reproductor: la aurora con los colores **reales** de la carátula. Cambia con una
/// transición suave al cambiar de canción y se mueve (muy despacio) mientras suena.
class PlayerHalo extends ConsumerStatefulWidget {
  const PlayerHalo({super.key, required this.track, required this.playing});

  final Track track;
  final bool playing;

  @override
  ConsumerState<PlayerHalo> createState() => _PlayerHaloState();
}

class _PlayerHaloState extends ConsumerState<PlayerHalo> {
  String? _pendingFor;

  void _extract(ImageProvider? image) {
    final id = widget.track.id;
    if (_coverPalettes.containsKey(id) || image == null || _pendingFor == id) return;
    _pendingFor = id;
    // "fidelity": los colores quedan fieles a la carátula (no tonos inventados).
    ColorScheme.fromImageProvider(
      provider: image,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ).then(
      (scheme) {
        _coverColors[id] ??= scheme.primary;
        _coverPalettes[id] = [scheme.primary, scheme.tertiary, scheme.secondary];
        if (mounted && widget.track.id == id) setState(() {});
      },
      onError: (Object error) {
        debugPrint('=== REPRODUCTOR: sin color de la carátula ($error) ===');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    _extract(trackImageProvider(ref, widget.track));
    return AuroraBackground(
      colors: auroraColorsFor(widget.track),
      moving: widget.playing && !reduceMotion(context, ref),
    );
  }
}

/// La carátula entra con escala 0,9 → 1 al abrir el reproductor y, al cambiar
/// de canción, la nueva entra deslizándose.
class CoverMotion extends ConsumerWidget {
  const CoverMotion({super.key, required this.trackId, required this.child});

  final String trackId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (reduceMotion(context, ref)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.9, end: 1),
      duration: KijiMotion.emphasized,
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: AnimatedSwitcher(
        duration: KijiMotion.emphasized,
        switchInCurve: KijiMotion.emphasizedCurve,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          final incoming = child.key == ValueKey(trackId);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: Offset(incoming ? 0.35 : -0.35, 0), end: Offset.zero).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(key: ValueKey(trackId), child: child),
      ),
    );
  }
}
