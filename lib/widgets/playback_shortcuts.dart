import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/playback_provider.dart';

/// Atajos de teclado para la PC, y para tablets o celulares
/// con teclado:
/// - Espacio: reproducir / pausar.
/// - ← / →: retroceder / adelantar 5 segundos.
/// - ↑ / ↓: subir / bajar el volumen.
/// - Teclas multimedia del teclado: reproducir/pausar, siguiente, anterior.
///
/// Mientras se escribe en un campo de texto (el buscador), las teclas
/// escriben y no controlan la música.
class PlaybackShortcuts extends ConsumerWidget {
  const PlaybackShortcuts({super.key, required this.child});

  final Widget child;

  static const seekStep = Duration(seconds: 5);
  static const volumeStep = 0.1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
        if (_isTyping()) return KeyEventResult.ignored;

        final playback = ref.read(playbackProvider.notifier);
        final key = event.logicalKey;
        final repeat = event is KeyRepeatEvent;

        if (!repeat &&
            (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.mediaPlayPause)) {
          playback.togglePlayPause();
        } else if (!repeat && key == LogicalKeyboardKey.mediaTrackNext) {
          playback.nextTrack();
        } else if (!repeat && key == LogicalKeyboardKey.mediaTrackPrevious) {
          playback.previousTrack();
        } else if (key == LogicalKeyboardKey.arrowRight) {
          playback.seekBy(seekStep);
        } else if (key == LogicalKeyboardKey.arrowLeft) {
          playback.seekBy(-seekStep);
        } else if (key == LogicalKeyboardKey.arrowUp) {
          playback.changeVolume(volumeStep);
        } else if (key == LogicalKeyboardKey.arrowDown) {
          playback.changeVolume(-volumeStep);
        } else {
          return KeyEventResult.ignored;
        }
        return KeyEventResult.handled;
      },
      child: child,
    );
  }

  /// true si el foco está en un campo de texto.
  static bool _isTyping() {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) return false;
    return focused.widget is EditableText ||
        focused.findAncestorWidgetOfExactType<EditableText>() != null;
  }
}
