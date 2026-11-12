import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/playback_provider.dart';
import '../../../theme/kiji_tokens.dart';
import '../../settings/data/settings_store.dart';
import 'device_cover.dart';

/// Mantiene al día los widgets de Android: la canción, si suena, el progreso, la portada y los
/// colores del estilo. Se actualiza al cambiar de canción o de play/pausa y cada 15 s mientras
/// suena (no más seguido: cuida la batería).
final homeWidgetsProvider = Provider<void>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  const channel = MethodChannel('kiji/widgets');
  Timer? ticker;
  var sending = false;

  Future<void> send() async {
    if (sending) return;
    sending = true;
    try {
      final playback = ref.read(playbackProvider);
      final track = playback.track;
      // Los widgets no bajan nada de internet: solo la portada que ya está en el dispositivo.
      final cover = track == null ? null : await deviceCoverFor(ref, track);
      final total = playback.duration.inMilliseconds;
      final palette = KijiColors.palette;
      await channel.invokeMethod<void>('update', {
        'title': track?.title,
        'artist': track?.artist,
        'playing': playback.isPlaying,
        'progress': total <= 0 ? 0 : (playback.position.inMilliseconds * 1000 ~/ total).clamp(0, 1000),
        'cover': cover,
        'background': palette.surface.toARGB32(),
        'text': palette.text.toARGB32(),
        'muted': palette.muted.toARGB32(),
        'accent': palette.violet.toARGB32(),
      });
    } catch (error) {
      debugPrint('=== WIDGETS: no se pudieron actualizar: ${error.runtimeType} ===');
    } finally {
      sending = false;
    }
  }

  ref.listen(
    playbackProvider.select((s) => (id: s.track?.id, playing: s.isPlaying, ready: s.isInitialized)),
    (_, next) {
      unawaited(send());
      ticker?.cancel();
      ticker = next.playing ? Timer.periodic(const Duration(seconds: 15), (_) => unawaited(send())) : null;
    },
    fireImmediately: true,
  );
  // Otro estilo o color: los widgets también (después de que la app cambie la paleta).
  ref.listen(settingsProvider.select((s) => (s.style, s.theme, s.accent, s.customAccent)), (_, _) {
    unawaited(Future<void>.delayed(const Duration(milliseconds: 400), send));
  });
  ref.onDispose(() => ticker?.cancel());
});
