// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivo de referencia: app/src/main/kotlin/.../ui/player/PlayerColorExtractor.kt (el color del
// fondo del reproductor sale de la carátula real).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/track.dart';
import '../../providers/appearance_provider.dart';
import '../../theme/kiji_tokens.dart';
import '../../widgets/album_cover.dart';

/// Colores ya calculados (por id de canción), para no repetir el trabajo.
final _coverColors = <String, Color>{};

/// Animaciones del reproductor (Tarea Z6). Todas se apagan con "Reducir
/// animaciones".

/// Halo del color **real** de la carátula detrás de todo: cambia con una
/// transición suave al cambiar de canción y late suave mientras suena.
class PlayerHalo extends ConsumerStatefulWidget {
  const PlayerHalo({super.key, required this.track, required this.playing});

  final Track track;
  final bool playing;

  @override
  ConsumerState<PlayerHalo> createState() => _PlayerHaloState();
}

class _PlayerHaloState extends ConsumerState<PlayerHalo> with SingleTickerProviderStateMixin {
  late final AnimationController _beat =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  late Color _color = _coverColors[widget.track.id] ?? widget.track.coverColor;
  String? _pendingFor;

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  void _extract(ImageProvider? image) {
    final id = widget.track.id;
    final known = _coverColors[id];
    if (known != null) {
      _color = known;
      return;
    }
    _color = widget.track.coverColor;
    if (image == null || _pendingFor == id) return;
    _pendingFor = id;
    ColorScheme.fromImageProvider(provider: image, brightness: Brightness.dark).then((scheme) {
      _coverColors[id] = scheme.primary;
      if (mounted && widget.track.id == id) setState(() => _color = scheme.primary);
    }, onError: (Object error) {
      debugPrint('=== REPRODUCTOR: sin color de la carátula ($error) ===');
    });
  }

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context, ref);
    _extract(trackImageProvider(ref, widget.track));
    if (widget.playing && !still && !_beat.isAnimating) {
      _beat.repeat(reverse: true);
    } else if ((!widget.playing || still) && _beat.isAnimating) {
      _beat.stop();
    }
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: _color),
      duration: still ? Duration.zero : const Duration(milliseconds: 700),
      builder: (context, color, _) => AnimatedBuilder(
        animation: _beat,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_beat.value);
          final c = color ?? _color;
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.35),
                radius: 0.95 + 0.05 * t,
                colors: [
                  c.withValues(alpha: 0.42 + 0.08 * t),
                  c.withValues(alpha: 0.12),
                  KijiColors.background,
                ],
                stops: const [0, 0.45, 1],
              ),
            ),
          );
        },
      ),
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
              position: Tween<Offset>(
                begin: Offset(incoming ? 0.35 : -0.35, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(key: ValueKey(trackId), child: child),
      ),
    );
  }
}
