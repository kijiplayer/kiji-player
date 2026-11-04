import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/track.dart';
import '../../../providers/appearance_provider.dart';
import '../../../providers/playback_provider.dart';
import '../../../theme/kiji_tokens.dart';
import '../../loudness/data/loudness_analyzer.dart';
import '../../loudness/domain/loudness.dart';
import '../data/screen_mode_impl.dart';
import '../domain/screen_mode.dart';

/// La letra está a pantalla completa (solo mientras la pantalla de la letra está abierta).
final lyricsFullscreenProvider = StateProvider<bool>((ref) => false);

/// Lleva la ventana (o el teléfono) a pantalla completa cuando se pide, y la devuelve a lo normal
/// al salir de la letra. En la PC, Esc también sale.
class FullscreenGuard extends ConsumerStatefulWidget {
  const FullscreenGuard({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FullscreenGuard> createState() => _FullscreenGuardState();
}

class _FullscreenGuardState extends ConsumerState<FullscreenGuard> {
  // Se toman al empezar: al cerrar la pantalla ya no se puede usar `ref`.
  late final ScreenMode _mode;
  late final StateController<bool> _state;
  bool _on = false;

  @override
  void initState() {
    super.initState();
    _mode = ref.read(screenModeProvider);
    _state = ref.read(lyricsFullscreenProvider.notifier);
  }

  @override
  void dispose() {
    if (_on) {
      unawaited(_mode.setFullScreen(false));
      // Después de cerrar la pantalla (no se puede tocar el estado mientras se desarma).
      Future.microtask(() => _state.state = false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(lyricsFullscreenProvider, (_, on) {
      _on = on;
      unawaited(_mode.setFullScreen(on));
    });
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (ref.read(lyricsFullscreenProvider)) ref.read(lyricsFullscreenProvider.notifier).state = false;
        },
      },
      child: Focus(autofocus: true, child: widget.child),
    );
  }
}

/// Fondo que reacciona a la música (pantalla completa): un resplandor del color de la portada que
/// crece y brilla con el volumen real de la canción (el de la onda en vivo, sacado del archivo,
/// nunca del micrófono). Sin archivo para medir, o con "Reducir animaciones", queda quieto.
class ReactiveGlow extends ConsumerStatefulWidget {
  const ReactiveGlow({super.key, required this.track, required this.accent});

  final Track track;
  final Color accent;

  @override
  ConsumerState<ReactiveGlow> createState() => _ReactiveGlowState();
}

class _ReactiveGlowState extends ConsumerState<ReactiveGlow> with SingleTickerProviderStateMixin {
  /// Volumen (0..1) suavizado: sube rápido con cada golpe y baja despacio.
  final _level = ValueNotifier<double>(_rest);
  static const _rest = 0.25;
  late final Ticker _ticker = createTicker(_tick);
  Loudness? _loudness;
  Duration _anchor = Duration.zero, _elapsed = Duration.zero, _anchorTick = Duration.zero;

  void _tick(Duration elapsed) {
    _elapsed = elapsed;
    final loudness = _loudness;
    if (loudness == null) return;
    // Entre una posición y la siguiente se sigue con el reloj (como mucho 1 s).
    final ahead = _elapsed - _anchorTick;
    final now = _anchor + (ahead > const Duration(seconds: 1) ? const Duration(seconds: 1) : ahead);
    final target = loudness.at(now);
    final current = _level.value;
    _level.value = target > current ? current + (target - current) * 0.4 : current + (target - current) * 0.06;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _level.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing = ref.watch(playbackProvider.select((p) => p.isPlaying));
    _loudness = ref.watch(loudnessProvider(widget.track.id)).value;
    ref.listen(playbackProvider.select((p) => p.position), (_, position) {
      _anchor = position;
      _anchorTick = _elapsed;
    });
    final on = _loudness != null && playing && !reduceMotion(context, ref);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (on && !_ticker.isActive) {
        _anchor = ref.read(playbackProvider).position;
        _elapsed = _anchorTick = Duration.zero;
        _ticker.start();
      } else if (!on && _ticker.isActive) {
        _ticker.stop();
        _level.value = _rest;
      }
    });
    return RepaintBoundary(
      child: CustomPaint(
        painter: _GlowPainter(level: _level, accent: widget.accent, second: KijiColors.cyan),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter({required this.level, required this.accent, required this.second}) : super(repaint: level);

  final ValueNotifier<double> level;
  final Color accent;
  final Color second;

  @override
  void paint(Canvas canvas, Size size) {
    final l = level.value.clamp(0.0, 1.0);
    void glow(Offset center, double radius, Color color, double alpha) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
          ).createShader(rect),
      );
    }

    final longest = max(size.width, size.height);
    glow(Offset(size.width * 0.5, size.height * 0.38), longest * (0.45 + 0.25 * l), accent, 0.14 + 0.34 * l);
    glow(Offset(size.width * 0.5, size.height * 1.05), longest * (0.35 + 0.15 * l), second, 0.06 + 0.16 * l);
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.accent != accent || old.second != second;
}
