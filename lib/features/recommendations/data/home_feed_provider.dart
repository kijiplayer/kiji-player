import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/track.dart';
import '../../downloads/data/auto_downloads.dart' show connectivityChangesProvider;
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

/// Pedidos en curso (el mismo id no se pide dos veces a la vez) y cuándo falló cada uno (no se
/// reintenta enseguida).
final _relatedInFlight = <String, Future<void>>{};
final _relatedFailedAt = <String, DateTime>{};
const relatedRetryAfter = Duration(minutes: 2);

/// ¿Hay conexión? (se cambia en las pruebas).
final homeOnlineCheckProvider = Provider<Future<bool> Function()>((ref) => () async {
  try {
    final result = await Connectivity().checkConnectivity();
    return !result.every((r) => r == ConnectivityResult.none);
  } catch (error) {
    debugPrint('=== INICIO: no se pudo saber si hay conexión: ${error.runtimeType} ===');
    return true;
  }
});

/// Inicio con recomendaciones. Sin conexión, Inicio sigue con lo local (más escuchadas,
/// descargadas, playlists), no pide nada a YouTube y, al volver la conexión, se completa solo.
final homeFeedProvider = FutureProvider<HomeFeed>((ref) async {
  ref.watch(_seedKeyProvider);
  final seeds = ref.read(homeSeedsProvider);
  if (seeds.all.isEmpty) return const HomeFeed();
  final client = ref.read(ytMusicClientProvider);
  final now = DateTime.now();
  final missing = [
    for (final seed in seeds.all)
      if (!_relatedCache.containsKey(seed.id) && !_failedRecently(seed.id, now)) seed,
  ];
  if (missing.isNotEmpty) {
    if (await ref.read(homeOnlineCheckProvider)()) {
      await Future.wait([for (final seed in missing) _relatedInFlight.putIfAbsent(seed.id, () => _fetchRelated(client, seed))]);
    } else {
      debugPrint('=== INICIO: sin conexión; las recomendaciones esperan a que vuelva ===');
      // Cuando vuelve la conexión, Inicio se arma de nuevo (una sola vez).
      StreamSubscription<List<ConnectivityResult>>? waiting;
      waiting = ref.read(connectivityChangesProvider).listen((result) {
        if (result.every((r) => r == ConnectivityResult.none)) return;
        unawaited(waiting?.cancel());
        ref.invalidateSelf();
      }, onError: (Object _) {});
      ref.onDispose(() => waiting?.cancel());
    }
  }
  return HomeFeedLogic.build(
    seeds: seeds,
    related: Map.of(_relatedCache),
    history: ref.read(listeningHistoryProvider),
    liked: ref.read(favoritesProvider).values.toList(),
  );
});

bool _failedRecently(String id, DateTime now) {
  final at = _relatedFailedAt[id];
  return at != null && now.difference(at) < relatedRetryAfter;
}

Future<void> _fetchRelated(YtMusicClient client, Track seed) async {
  try {
    final results = await client.related(seed.youtubeVideoId!);
    _relatedCache[seed.id] = [for (final r in results) ytTrackFromResult(r, audioUrl: '')];
    _relatedFailedAt.remove(seed.id);
  } catch (error) {
    _relatedFailedAt[seed.id] = DateTime.now();
    debugPrint('=== INICIO: sin relacionadas de ${seed.id}: ${error.runtimeType} ===');
  } finally {
    _relatedInFlight.remove(seed.id)?.ignore();
  }
}

/// Volver a pedir las recomendaciones (deslizar hacia abajo en Inicio).
void refreshHomeFeed(WidgetRef ref) {
  _relatedCache.clear();
  _relatedFailedAt.clear();
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
