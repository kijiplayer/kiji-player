import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/track.dart';
import '../settings/data/settings_store.dart';
import 'data/lyrics_repository.dart';
import 'domain/lyrics.dart';

final lyricsRepositoryProvider = Provider<LyricsRepository>((ref) => LyricsRepository());

/// Pedido de letra para [track].
LyricsRequest lyricsRequestFor(Track track) => (
      id: track.id,
      title: track.title,
      artist: track.artist,
      album: track.album,
      durationMs: track.durationMs,
      localPath: track.source == TrackSource.local ? track.audioUrl : null,
    );

/// Letra de una canción. Se pide solo cuando se abre la pantalla de letras
/// (nada sale del teléfono sin que el usuario lo pida).
final lyricsProvider = FutureProvider.autoDispose.family<Lyrics, LyricsRequest>(
  (ref, request) => ref.watch(lyricsRepositoryProvider).get(
        request,
        disabled: ref.watch(settingsProvider.select((s) => s.disabledLyricsSources)),
        order: ref.watch(settingsProvider.select((s) => s.lyricsSourceOrder)),
      ),
);

/// Desfase de la letra de una canción, guardado por canción.
final lyricsOffsetProvider = FutureProvider.autoDispose.family<Duration, String>(
  (ref, id) => ref.watch(lyricsRepositoryProvider).offset(id),
);
