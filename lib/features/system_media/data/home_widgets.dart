import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../models/track.dart';
import '../../../providers/downloads_provider.dart';
import '../../../providers/playback_provider.dart';
import '../../../theme/kiji_tokens.dart';
import '../../customize/data/artwork_cache.dart' show ArtworkCache, artworkCacheName;
import '../../settings/data/settings_store.dart';
import 'cover_art.dart' show fullThumbnailUrl;

/// La portada de [track] como archivo del dispositivo (los widgets no bajan nada de internet): la
/// incluida en el archivo local, la de su carpeta, la de la descarga o la guardada en la caché.
/// null si no hay (el widget muestra el ícono de Kiji).
Future<String?> widgetCoverPath(Track track, {required Directory support, String? downloadsDir, String? downloadThumb}) async {
  final artwork = p.join(support.path, 'artwork');
  final candidates = <String>[
    if (track.source == TrackSource.local) ...[
      p.join(artwork, artworkCacheName(ArtworkCache.fileKey(track.audioUrl))),
      if (track.thumbnailUrl case final t? when !t.startsWith('http')) t,
    ],
    if (downloadsDir != null && downloadThumb != null) p.join(downloadsDir, downloadThumb),
    if (track.thumbnailUrl case final t? when t.startsWith('http')) ...[
      p.join(artwork, artworkCacheName(fullThumbnailUrl(t))),
      p.join(artwork, artworkCacheName(t)),
    ],
  ];
  for (final path in candidates) {
    if (await File(path).exists()) return path;
  }
  return null;
}

/// Mantiene al día los widgets de Android: la canción, si suena, el progreso, la portada y los
/// colores del estilo. Se actualiza al cambiar de canción o de play/pausa y cada 15 s mientras
/// suena (no más seguido: cuida la batería).
final homeWidgetsProvider = Provider<void>((ref) {
  if (kIsWeb || !Platform.isAndroid) return;
  const channel = MethodChannel('kiji/widgets');
  Timer? ticker;
  var sending = false;

  Future<void> send() async {
    if (sending) return;
    sending = true;
    try {
      final playback = ref.read(playbackProvider);
      final track = playback.track;
      final downloads = ref.read(downloadsProvider);
      final videoId = track?.youtubeVideoId;
      final cover = track == null
          ? null
          : await widgetCoverPath(
              track,
              support: await getApplicationSupportDirectory(),
              downloadsDir: downloads.directoryPath,
              downloadThumb: videoId == null ? null : downloads.completed[videoId]?.thumbnailFileName,
            );
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
