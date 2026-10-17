import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../models/track.dart';
import '../../yt_music/data/ytm_client.dart';
import '../../yt_music/domain/yt_track_mapper.dart';
import 'imported.dart';

/// Lo que el buscador necesita de YouTube Music (reemplazable en tests).
abstract interface class OnlineSongLookup {
  Future<YtMusicSearchResult?> videoDetails(String videoId);
  Future<List<YtMusicSearchResult>> searchSongs(String query);
}

/// Implementación real, con el cliente anónimo de Kiji.
class YtMusicLookup implements OnlineSongLookup {
  YtMusicLookup([YtMusicClient? client]) : _client = client ?? YtMusicClient();
  final YtMusicClient _client;

  @override
  Future<YtMusicSearchResult?> videoDetails(String videoId) => _client.videoDetails(videoId);

  @override
  Future<List<YtMusicSearchResult>> searchSongs(String query) => _client.search(query, songsOnly: true);
}

/// Texto comparable: minúsculas, sin tildes, sin "(feat. …)", "[Remastered]"
/// ni "- Radio Edit", y sin signos.
String normalizeTitle(String text) {
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const to = 'aaaaaeeeeiiiiooooouuuunc';
  var s = text.toLowerCase();
  s = s.replaceAll(RegExp(r'[\(\[][^\)\]]*[\)\]]'), ' '); // (feat. x) [Remastered 2011]
  s = s.replaceAll(RegExp(r'\s-\s.*(remaster|edit|version|versión|mix|live|en vivo).*$'), ' ');
  final b = StringBuffer();
  for (final c in s.split('')) {
    final i = from.indexOf(c);
    b.write(i == -1 ? c : to[i]);
  }
  return b.toString().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

double _similarity(String a, String b) {
  final x = normalizeTitle(a).split(' ').where((w) => w.isNotEmpty).toSet();
  final y = normalizeTitle(b).split(' ').where((w) => w.isNotEmpty).toSet();
  if (x.isEmpty || y.isEmpty) return 0;
  return x.intersection(y).length / x.union(y).length;
}

/// Puntaje (0..1+) de qué tan bien [candidate] coincide con [wanted].
@visibleForTesting
double matchScore(ImportedSong wanted, {required String title, required String artist, int? durationMs}) {
  final titleScore = _similarity(wanted.title ?? '', title);
  if (titleScore == 0) return 0;
  final wantedArtist = wanted.artist;
  final artistScore = wantedArtist == null
      ? 0.5
      : (normalizeTitle(artist).contains(normalizeTitle(wantedArtist)) ||
              normalizeTitle(wantedArtist).contains(normalizeTitle(artist)))
          ? 1.0
          : _similarity(wantedArtist, artist);
  var score = titleScore * 0.6 + artistScore * 0.4;
  final a = wanted.durationMs;
  if (a != null && durationMs != null && durationMs > 0) {
    final diff = (a - durationMs).abs() / 1000;
    if (diff <= 3) {
      score += 0.15;
    } else if (diff > 20) {
      score -= 0.25; // otra versión (en vivo, extendida…)
    }
  }
  return score;
}

/// Busca cada canción importada: videoId directo, archivo local, tu
/// biblioteca, y por último YouTube Music (eligiendo por duración).
class ImportMatcher {
  ImportMatcher({required this.local, required this.online});

  final List<Track> local;
  final OnlineSongLookup online;

  /// Puntaje mínimo para aceptar una coincidencia por título.
  static const threshold = 0.6;

  /// La canción que corresponde a [song], con su carátula si la traía
  /// (Tarea Z3).
  Future<Track?> resolve(ImportedSong song) async {
    final track = await _resolve(song);
    final thumb = song.thumbnailUrl;
    if (track == null || thumb == null || !thumb.startsWith('http') || track.thumbnailUrl != null) return track;
    return track.copyWith(thumbnailUrl: thumb);
  }

  Future<Track?> _resolve(ImportedSong song) async {
    final videoId = song.videoId;
    if (videoId != null && videoId.isNotEmpty) {
      if (song.title != null && song.title!.trim().isNotEmpty) {
        return ytTrackFromResult(
          YtMusicSearchResult(
            videoId: videoId,
            title: song.title!,
            artist: song.artist ?? 'Artista desconocido',
            album: song.album,
            durationMs: song.durationMs,
            thumbnailUrl: song.thumbnailUrl != null && song.thumbnailUrl!.startsWith('http') ? song.thumbnailUrl : null,
          ),
          audioUrl: '',
        );
      }
      // Sin título (Google Takeout): se piden los datos del video.
      final details = await online.videoDetails(videoId);
      return ytTrackFromResult(
        details ?? YtMusicSearchResult(videoId: videoId, title: 'Canción de YouTube ($videoId)', artist: 'Artista desconocido'),
        audioUrl: '',
      );
    }

    final path = song.localPath;
    if (path != null) {
      final byPath = local.where((t) => p.equals(t.audioUrl, path)).firstOrNull;
      if (byPath != null) return byPath;
      if (await File(path).exists()) {
        return Track(
          id: 'local-file-${path.hashCode.toUnsigned(32).toRadixString(16)}',
          title: song.title ?? p.basenameWithoutExtension(path),
          artist: song.artist ?? 'Artista desconocido',
          coverColor: const Color(0xFF7C5CFF),
          audioUrl: path,
          source: TrackSource.local,
          durationMs: song.durationMs ?? 0,
        );
      }
    }

    if (song.title == null || song.title!.trim().isEmpty) return null;

    // Tu biblioteca primero (sin internet).
    Track? bestLocal;
    var bestLocalScore = 0.0;
    for (final t in local) {
      final score = matchScore(song, title: t.title, artist: t.artist, durationMs: t.durationMs);
      if (score > bestLocalScore) {
        bestLocal = t;
        bestLocalScore = score;
      }
    }
    if (bestLocal != null && bestLocalScore >= threshold) return bestLocal;

    // Después YouTube Music.
    try {
      final query = [song.title, song.artist].whereType<String>().join(' ');
      final results = await online.searchSongs(query);
      YtMusicSearchResult? best;
      var bestScore = 0.0;
      for (final r in results.take(10)) {
        final score = matchScore(song, title: r.title, artist: r.artist, durationMs: r.durationMs);
        if (score > bestScore) {
          best = r;
          bestScore = score;
        }
      }
      if (best != null && bestScore >= threshold) return ytTrackFromResult(best, audioUrl: '');
    } catch (error) {
      debugPrint('=== IMPORTAR: no se pudo buscar "${song.title}": $error ===');
    }
    return null;
  }
}
