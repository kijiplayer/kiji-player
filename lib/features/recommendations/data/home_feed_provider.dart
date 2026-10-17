import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/track.dart';
import '../../favorites/favorites.dart';
import '../../history/listening_history.dart';
import '../../yt_music/data/ytm_browse_parser.dart';
import '../../yt_music/data/ytm_client.dart';
import '../../yt_music/domain/yt_track_mapper.dart';
import '../../yt_music/presentation/collection_screens.dart';
import '../domain/home_feed.dart';

/// Semillas de Inicio; solo cambian cuando cambia cuáles son (no a cada
/// canción que suena).
final homeSeedsProvider = Provider<HomeSeeds>((ref) {
  final history = ref.watch(listeningHistoryProvider);
  final liked = ref.watch(favoritesProvider).values.toList();
  return HomeFeedLogic.seeds(history, liked);
});

final _seedKeyProvider = Provider<String>((ref) => ref.watch(homeSeedsProvider).key);

/// Relacionadas ya pedidas en esta sesión (por id de la semilla).
final _relatedCache = <String, List<Track>>{};

/// Inicio con recomendaciones (Tarea Z5). Sin conexión, Inicio sigue con lo
/// local (más escuchadas, descargadas, playlists).
final homeFeedProvider = FutureProvider<HomeFeed>((ref) async {
  ref.watch(_seedKeyProvider);
  final seeds = ref.read(homeSeedsProvider);
  if (seeds.all.isEmpty) return const HomeFeed();
  final client = ref.read(ytMusicClientProvider);
  await Future.wait([
    for (final seed in seeds.all)
      if (!_relatedCache.containsKey(seed.id))
        _fetchRelated(client, seed),
  ]);
  return HomeFeedLogic.build(
    seeds: seeds,
    related: Map.of(_relatedCache),
    history: ref.read(listeningHistoryProvider),
    liked: ref.read(favoritesProvider).values.toList(),
  );
});

Future<void> _fetchRelated(YtMusicClient client, Track seed) async {
  try {
    final results = await client.related(seed.youtubeVideoId!);
    _relatedCache[seed.id] = [for (final r in results) ytTrackFromResult(r, audioUrl: '')];
  } catch (error) {
    debugPrint('=== INICIO: sin relacionadas de ${seed.id}: $error ===');
  }
}

/// Volver a pedir las recomendaciones (deslizar hacia abajo en Inicio).
void refreshHomeFeed(WidgetRef ref) {
  _relatedCache.clear();
  ref.invalidate(homeFeedProvider);
}

/// "Para empezar": géneros y estados de ánimo de YouTube Music (anónimo).
final moodsProvider = FutureProvider<List<YtMood>>((ref) => ref.read(ytMusicClientProvider).moods());

final moodCategoryProvider = FutureProvider.family<List<YtShelf>, String>(
  (ref, params) => ref.read(ytMusicClientProvider).moodCategory(params),
);

final ytPlaylistTracksProvider = FutureProvider.family<List<Track>, String>((ref, playlistId) async {
  final results = await ref.read(ytMusicClientProvider).playlistTracks(playlistId);
  return [for (final r in results) ytTrackFromResult(r, audioUrl: '')];
});
