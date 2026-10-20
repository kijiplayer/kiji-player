import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../models/track.dart';
import '../../../utils/json_file.dart';
import '../../yt_music/data/ytm_client.dart';
import '../domain/extraction_failure.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Quita los agregados típicos de un video ("(Official Video)", "[4K]"…) para buscar la canción.
String cleanSongTitle(String title) => title
    .replaceAll(
      RegExp(
        r'\s*[\(\[][^\)\]]*(official|video|vídeo|lyric|letra|audio|visualizer|4k|hd|mv|clip)[^\)\]]*[\)\]]',
        caseSensitive: false,
      ),
      '',
    )
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9áéíóúñü]+'), ' ').trim();

/// Elige entre [results] la versión "Canción" de [track]: otro videoId, el título parecido, y la
/// duración más cercana (si se sabe, a menos de 15 s). null si ninguna sirve.
@visibleForTesting
YtMusicSearchResult? pickAlternative(Track track, List<YtMusicSearchResult> results) {
  final original = track.youtubeVideoId;
  final title = _norm(cleanSongTitle(track.title));
  final firstArtist = _norm(track.artist.split(RegExp(r',|&| y | feat', caseSensitive: false)).first);
  YtMusicSearchResult? best;
  var bestDiff = 1 << 30;
  for (final r in results) {
    if (r.videoId == original) continue;
    final rt = _norm(r.title);
    if (!(rt.contains(title) || title.contains(rt))) continue;
    if (firstArtist.isNotEmpty && !_norm(r.artist).contains(firstArtist)) continue;
    final diff = (track.durationMs > 0 && (r.durationMs ?? 0) > 0) ? (track.durationMs - r.durationMs!).abs() : 0;
    if (track.durationMs > 0 && (r.durationMs ?? 0) > 0 && diff > 15000) continue;
    if (diff < bestDiff) {
      best = r;
      bestDiff = diff;
    }
  }
  return best;
}

/// Versión "Canción" (pista de audio) para un video con restricción de edad o bloqueado. Se
/// recuerda el cambio (`alternatives.json`) y también las canciones sin alternativa
/// (🔞 "Requiere cuenta"), para no volver a buscar cada vez.
class AlternativeFinder {
  AlternativeFinder(this.client, {Future<String> Function()? directory}) : _directoryPath = directory;

  static AlternativeFinder? _instance;
  static AlternativeFinder of(YtMusicClient client) => _instance ??= AlternativeFinder(client);

  final YtMusicClient client;
  final Future<String> Function()? _directoryPath;
  JsonFile? _file;
  Map<String, String>? _swaps;
  Map<String, String>? _blocked;

  Future<JsonFile> _jsonFile() async => _file ??= JsonFile(
    p.join(await (_directoryPath ?? () async => (await getApplicationSupportDirectory()).path)(), 'alternatives.json'),
    logTag: 'ALTERNATIVAS',
  );

  Future<void> _load() async {
    if (_swaps != null) return;
    _swaps = {};
    _blocked = {};
    try {
      final json = await (await _jsonFile()).read();
      if (json is Map) {
        for (final e in ((json['swaps'] as Map?) ?? const {}).entries) {
          _swaps!['${e.key}'] = '${e.value}';
        }
        for (final e in ((json['blocked'] as Map?) ?? const {}).entries) {
          _blocked!['${e.key}'] = '${e.value}';
        }
      }
    } catch (error) {
      debugPrint('=== ALTERNATIVAS: no se pudieron leer: $error ===');
    }
  }

  void _save() => unawaited(_jsonFile().then((f) => f.write({'swaps': _swaps, 'blocked': _blocked})));

  /// Lo marcado para [videoId]: el cambio recordado o el problema sin alternativa.
  Future<({String? swap, ContentProblem? blocked})> known(String videoId) async {
    await _load();
    final blocked = _blocked![videoId];
    return (swap: _swaps![videoId], blocked: blocked == null ? null : ContentProblem.values.asNameMap()[blocked]);
  }

  /// Busca la versión "Canción" de [track] (con la duración más parecida).
  Future<String?> find(Track track) async {
    await _load();
    final remembered = _swaps![track.youtubeVideoId];
    if (remembered != null) return remembered;
    try {
      final query = '${cleanSongTitle(track.title)} ${track.artist}'.trim();
      final results = await client.search(query, songsOnly: true);
      final best = pickAlternative(track, results);
      debugPrint('=== ALTERNATIVAS: ${track.youtubeVideoId} → ${best?.videoId ?? tx.sinAlternativa} ===');
      return best?.videoId;
    } catch (error) {
      debugPrint('=== ALTERNATIVAS: falló la búsqueda: ${error.runtimeType} ===');
      return null;
    }
  }

  void remember(String videoId, String alternative) {
    _swaps?[videoId] = alternative;
    _blocked?.remove(videoId);
    _save();
  }

  void markBlocked(String videoId, ContentProblem problem) {
    _blocked?[videoId] = problem.name;
    _save();
  }
}
