import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../models/track.dart';
import '../../../utils/json_file.dart';
import '../../favorites/favorites.dart';
import '../../history/listening_history.dart';
import '../../playlists/playlists_provider.dart';
import '../domain/import_matcher.dart';
import '../domain/imported.dart';

/// Resultado de buscar todas las canciones de un archivo, antes de importar.
class ImportPlan {
  const ImportPlan({required this.bundle, required this.resolved, required this.unresolved});

  final ImportBundle bundle;

  /// Canción encontrada, por [ImportedSong.key].
  final Map<String, Track> resolved;
  final List<ImportedSong> unresolved;

  /// Playlists que quedan con al menos una canción.
  int get playlistCount =>
      bundle.playlists.where((pl) => pl.songs.any((s) => resolved.containsKey(s.key))).length;
  int get songCount => resolved.length;
  int get missingCount => unresolved.length;
  int get likedCount => {for (final s in bundle.liked) if (resolved.containsKey(s.key)) s.key}.length;
  int get historyCount =>
      {for (final h in bundle.history) if (resolved.containsKey(h.song.key)) h.song.key}.length;

  bool get isEmpty => songCount == 0;
}

/// "Se van a crear 4 playlists, 210 canciones, 12 sin encontrar", y si hay,
/// me gusta e historial.
String previewText(ImportPlan plan) {
  String n(int count, String one, String many) => '$count ${count == 1 ? one : many}';
  final parts = <String>[
    'Se van a crear ${n(plan.playlistCount, 'playlist', 'playlists')}',
    n(plan.songCount, 'canción', 'canciones'),
    '${plan.missingCount} sin encontrar',
  ];
  final extra = <String>[
    if (plan.likedCount > 0) n(plan.likedCount, 'me gusta', 'me gusta'),
    if (plan.historyCount > 0) '${plan.historyCount} en el historial',
  ];
  return '${parts.join(', ')}${extra.isEmpty ? '' : '. También: ${extra.join(' y ')}'}.';
}

/// Busca todas las canciones distintas del archivo (de a [concurrency]).
Future<ImportPlan> prepareImport(
  ImportBundle bundle,
  ImportMatcher matcher, {
  void Function(int done, int total)? onProgress,
  int concurrency = 4,
}) async {
  final songs = <String, ImportedSong>{};
  for (final pl in bundle.playlists) {
    for (final s in pl.songs) {
      songs.putIfAbsent(s.key, () => s);
    }
  }
  for (final s in bundle.liked) {
    songs.putIfAbsent(s.key, () => s);
  }
  for (final h in bundle.history) {
    songs.putIfAbsent(h.song.key, () => h.song);
  }

  final pending = songs.values.toList();
  final resolved = <String, Track>{};
  final unresolved = <ImportedSong>[];
  var done = 0;
  var next = 0;
  Future<void> worker() async {
    while (next < pending.length) {
      final song = pending[next++];
      Track? track;
      try {
        track = await matcher.resolve(song);
      } catch (error) {
        debugPrint('=== IMPORTAR: falló buscar "$song": $error ===');
      }
      if (track != null) {
        resolved[song.key] = track;
      } else {
        unresolved.add(song);
      }
      onProgress?.call(++done, pending.length);
    }
  }

  await Future.wait([for (var i = 0; i < concurrency; i++) worker()]);
  return ImportPlan(bundle: bundle, resolved: resolved, unresolved: unresolved);
}

/// Una importación hecha: lo justo para deshacerla entera.
class ImportRecord {
  const ImportRecord({
    required this.id,
    required this.source,
    required this.date,
    required this.playlistIds,
    required this.likedIds,
    required this.historyIds,
    required this.missing,
  });

  final String id;
  final String source;
  final DateTime date;
  final List<String> playlistIds;
  final List<String> likedIds;
  final List<String> historyIds;

  /// Canciones que no se encontraron (para el resumen).
  final List<String> missing;

  Map<String, dynamic> toJson() => {
        'id': id,
        'source': source,
        'date': date.millisecondsSinceEpoch,
        'playlistIds': playlistIds,
        'likedIds': likedIds,
        'historyIds': historyIds,
        'missing': missing,
      };

  factory ImportRecord.fromJson(Map<String, dynamic> json) {
    List<String> list(String key) => [for (final v in json[key] as List<dynamic>? ?? const []) v as String];
    return ImportRecord(
      id: json['id'] as String,
      source: json['source'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(json['date'] as int),
      playlistIds: list('playlistIds'),
      likedIds: list('likedIds'),
      historyIds: list('historyIds'),
      missing: list('missing'),
    );
  }
}

/// Historial importado: una entrada por canción (cuántas veces y la última).
List<HistoryEntry> aggregateHistory(ImportPlan plan) {
  final byKey = <String, (DateTime, int)>{};
  for (final play in plan.bundle.history) {
    if (!plan.resolved.containsKey(play.song.key)) continue;
    final previous = byKey[play.song.key];
    byKey[play.song.key] = previous == null
        ? (play.at, 1)
        : (play.at.isAfter(previous.$1) ? play.at : previous.$1, previous.$2 + 1);
  }
  return [
    for (final e in byKey.entries)
      HistoryEntry(track: plan.resolved[e.key]!, lastPlayed: e.value.$1, playCount: e.value.$2),
  ];
}

/// Importaciones hechas (`<appSupportDir>/imports.json`), para deshacerlas.
class ImportsNotifier extends Notifier<List<ImportRecord>> {
  ImportsNotifier({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;
  JsonFile? _file;

  Future<JsonFile> _jsonFile() async =>
      _file ??= JsonFile(p.join((await _directory()).path, 'imports.json'), logTag: 'IMPORTAR');

  @override
  List<ImportRecord> build() {
    unawaited(Future.microtask(_load));
    return const [];
  }

  Future<void> _load() async {
    try {
      final json = await (await _jsonFile()).read();
      if (json is List) {
        state = [for (final r in json) ImportRecord.fromJson(r as Map<String, dynamic>)];
      }
    } catch (error) {
      debugPrint('=== IMPORTAR: no se pudo leer el registro: $error ===');
    }
  }

  Future<void> _save() async {
    try {
      await (await _jsonFile()).write([for (final r in state) r.toJson()]);
    } catch (error) {
      debugPrint('=== IMPORTAR: no se pudo guardar el registro: $error ===');
    }
  }

  /// Importa: crea playlists nuevas (con "(importada)" si el nombre existe),
  /// suma me gusta y canciones al historial. Nunca sobrescribe ni borra.
  ImportRecord apply(ImportPlan plan) {
    final playlists = ref.read(playlistsProvider.notifier);
    final playlistIds = <String>[];
    for (final pl in plan.bundle.playlists) {
      final tracks = [for (final s in pl.songs) ?plan.resolved[s.key]];
      if (tracks.isEmpty) continue;
      playlistIds.add(playlists
          .create(pl.name, tracks: tracks, suffix: '(importada)', importedFrom: plan.bundle.source)
          .id);
    }
    final likedIds = ref.read(favoritesProvider.notifier).addAll([
      for (final s in plan.bundle.liked) ?plan.resolved[s.key],
    ]);
    final historyIds = ref.read(listeningHistoryProvider.notifier).importEntries(aggregateHistory(plan));

    final record = ImportRecord(
      id: 'imp-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
      source: plan.bundle.source,
      date: DateTime.now(),
      playlistIds: playlistIds,
      likedIds: likedIds,
      historyIds: historyIds,
      missing: [
        for (final s in plan.unresolved)
          [s.title, s.artist].whereType<String>().join(' — ').ifEmpty(s.videoId ?? s.localPath ?? '?'),
      ],
    );
    state = [record, ...state];
    unawaited(_save());
    return record;
  }

  /// Deshace la importación entera: quita exactamente lo que agregó.
  void undo(ImportRecord record) {
    ref.read(playlistsProvider.notifier).deleteMany(record.playlistIds.toSet());
    ref.read(favoritesProvider.notifier).removeIds(record.likedIds);
    ref.read(listeningHistoryProvider.notifier).removeIds(record.historyIds);
    state = [for (final r in state) if (r.id != record.id) r];
    unawaited(_save());
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

final importsProvider = NotifierProvider<ImportsNotifier, List<ImportRecord>>(ImportsNotifier.new);
