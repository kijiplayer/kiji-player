import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../models/track.dart';
import '../../../utils/app_visible.dart';
import '../../../utils/json_file.dart';
import '../../settings/data/settings_store.dart';
import '../../yt_music/data/ytm_browse_parser.dart';
import '../../yt_music/data/ytm_client.dart';
import '../../yt_music/domain/yt_track_mapper.dart';
import '../../yt_music/presentation/collection_screens.dart' show ytMusicClientProvider;
import '../domain/yt_session.dart';

/// Una playlist de la cuenta de YouTube, leída (solo lectura).
class SyncedPlaylist {
  const SyncedPlaylist({required this.id, required this.name, required this.tracks});

  final String id;
  final String name;
  final List<Track> tracks;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'tracks': [for (final t in tracks) t.toJson()]};

  static SyncedPlaylist? fromJson(Object? json) {
    if (json is! Map || json['id'] is! String || json['name'] is! String) return null;
    return SyncedPlaylist(
      id: json['id'] as String,
      name: json['name'] as String,
      tracks: [
        for (final t in (json['tracks'] as List? ?? const []))
          if (t is Map<String, dynamic>) Track.fromJson(t),
      ],
    );
  }
}

/// Lo que se leyó de la cuenta: "Me gusta" y las playlists, y cuándo.
class YtSyncState {
  const YtSyncState({this.liked = const [], this.playlists = const [], this.syncedAt, this.syncing = false});

  final List<Track> liked;
  final List<SyncedPlaylist> playlists;
  final DateTime? syncedAt;
  final bool syncing;

  bool get isEmpty => liked.isEmpty && playlists.isEmpty;
}

/// Lee la cuenta (lo que se cambia en las pruebas).
abstract interface class YtAccountReader {
  Future<Map<String, dynamic>?> browse(String browseId, YtSession session);

  /// La página siguiente (con la marca de [parseBrowseContinuation]).
  Future<Map<String, dynamic>?> continuation(String token, YtSession session);
}

class _ClientReader implements YtAccountReader {
  _ClientReader(this._client);
  final YtMusicClient _client;

  @override
  Future<Map<String, dynamic>?> browse(String browseId, YtSession session) => _client.browseWithAccount(browseId, session);

  @override
  Future<Map<String, dynamic>?> continuation(String token, YtSession session) =>
      _client.browseContinuationWithAccount(token, session);
}

final ytAccountReaderProvider = Provider<YtAccountReader>((ref) => _ClientReader(ref.read(ytMusicClientProvider)));

/// "Sincronizar con YouTube": solo con la sesión iniciada y el interruptor prendido (apagado de
/// fábrica). Solo lectura: trae "Me gusta" y las playlists de la cuenta para verlas en Kiji; nunca
/// escribe nada en la cuenta. Lo leído queda solo en el dispositivo (`yt_sync.json`, fuera de la
/// copia de seguridad). Si la sesión falla o venció, Kiji sigue como invitado, sin avisos.
class YtSyncNotifier extends Notifier<YtSyncState> {
  YtSyncNotifier({Future<Directory> Function()? directory}) : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;
  JsonFile? _file;

  /// Cada cuánto se vuelve a leer sola (al abrir Kiji).
  static const interval = Duration(hours: 12);

  /// Cuántas playlists de la cuenta se leen como mucho.
  static const maxPlaylists = 30;

  /// Páginas por lista como mucho (unas 100 canciones cada una): "Me gusta" y las playlists largas
  /// ya no quedan cortadas en la primera página.
  static const maxPages = 30;

  /// Todas las páginas de [browseId] (la primera y las siguientes, hasta [maxPages]).
  Future<List<Map<String, dynamic>>> _pages(YtAccountReader reader, String browseId, YtSession session) async {
    final first = await reader.browse(browseId, session);
    if (first == null) return const [];
    final pages = [first];
    var token = parseBrowseContinuation(first);
    final seen = <String>{};
    while (token != null && pages.length < maxPages && seen.add(token)) {
      final next = await reader.continuation(token, session);
      if (next == null) break;
      pages.add(next);
      token = parseBrowseContinuation(next);
    }
    return pages;
  }

  static List<Track> _tracks(List<Map<String, dynamic>> pages) {
    final seen = <String>{};
    return [
      for (final page in pages)
        for (final r in parseSongRows(page))
          if (seen.add(r.videoId)) ytTrackFromResult(r, audioUrl: ''),
    ];
  }

  Future<JsonFile> _json() async => _file ??= JsonFile(p.join((await _directory()).path, 'yt_sync.json'), logTag: 'SINCRONIZAR');

  bool _disposed = false;

  @override
  YtSyncState build() {
    ref.onDispose(() => _disposed = true);
    unawaited(_load().then((_) => _autoSync()));
    return const YtSyncState();
  }

  /// Con la sincronización prendida, se vuelve a leer sola cada [interval], con Kiji ya a la vista.
  Future<void> _autoSync() async {
    try {
      if (_disposed || !(await ref.read(settingsProvider.notifier).loaded).ytSync) return;
      await whenAppVisible();
      await Future<void>.delayed(const Duration(seconds: 5));
      if (!_disposed) await syncIfDue();
    } catch (error) {
      debugPrint('=== SINCRONIZAR: la lectura automática no se hizo (${error.runtimeType}) ===');
    }
  }

  Future<void> _load() async {
    try {
      final json = await (await _json()).read();
      if (json is! Map) return;
      state = YtSyncState(
        liked: [
          for (final t in (json['liked'] as List? ?? const []))
            if (t is Map<String, dynamic>) Track.fromJson(t),
        ],
        playlists: [for (final pl in (json['playlists'] as List? ?? const [])) ?SyncedPlaylist.fromJson(pl)],
        syncedAt: DateTime.tryParse('${json['syncedAt']}'),
      );
    } catch (error) {
      debugPrint('=== SINCRONIZAR: no se pudo leer lo guardado: ${error.runtimeType} ===');
    }
  }

  /// Al abrir Kiji: si está prendido, hay sesión y pasó [interval].
  Future<void> syncIfDue() async {
    final last = state.syncedAt;
    if (last != null && DateTime.now().difference(last) < interval) return;
    await syncNow();
  }

  /// Lee la cuenta ahora. Devuelve false si no se pudo (sin sesión, apagado o YouTube la rechazó).
  Future<bool> syncNow() async {
    final session = YtSessionHolder.usable;
    if (!ref.read(settingsProvider).ytSync || session == null || state.syncing) return false;
    state = YtSyncState(liked: state.liked, playlists: state.playlists, syncedAt: state.syncedAt, syncing: true);
    final reader = ref.read(ytAccountReaderProvider);
    try {
      final liked = _tracks(await _pages(reader, 'FEmusic_liked_videos', session));
      final seenIds = <String>{};
      final ids = [
        for (final page in await _pages(reader, 'FEmusic_liked_playlists', session))
          for (final pl in parseLibraryPlaylists(page))
            if (seenIds.add(pl.id)) pl,
      ];
      final before = {for (final pl in state.playlists) pl.id: pl};
      final playlists = <SyncedPlaylist>[];
      for (final pl in ids.take(maxPlaylists)) {
        try {
          final pages = await _pages(reader, 'VL${pl.id}', session);
          if (pages.isEmpty) continue;
          playlists.add(SyncedPlaylist(id: pl.id, name: pl.name, tracks: _tracks(pages)));
        } catch (error) {
          // La sesión venció: se corta todo (ver abajo). Otra falla: esta playlist queda como
          // estaba y siguen las demás (antes una sola hacía fallar toda la lectura).
          if (error is DioException && error.response?.statusCode == 401) rethrow;
          debugPrint('=== SINCRONIZAR: una playlist no se pudo leer (${error.runtimeType}); queda la de antes ===');
          final old = before[pl.id];
          if (old != null) playlists.add(old);
        }
      }
      final now = DateTime.now();
      state = YtSyncState(liked: liked, playlists: playlists, syncedAt: now);
      await (await _json()).write({
        'syncedAt': now.toIso8601String(),
        'liked': [for (final t in liked) t.toJson()],
        'playlists': [for (final pl in playlists) pl.toJson()],
      });
      debugPrint('=== SINCRONIZAR: ${liked.length} me gusta y ${playlists.length} playlists de la cuenta ===');
      return true;
    } catch (error) {
      // 401 (la sesión venció o se cerró): la cuenta queda de lado y Kiji sigue como invitado.
      if (error is DioException && error.response?.statusCode == 401) YtSessionHolder.rejected = true;
      debugPrint('=== SINCRONIZAR: no se pudo leer la cuenta (${error.runtimeType}); se sigue como invitado ===');
      state = YtSyncState(liked: state.liked, playlists: state.playlists, syncedAt: state.syncedAt);
      return false;
    }
  }

  /// Apagar la sincronización borra lo leído (Cero Sorpresas: nada queda guardado a escondidas).
  Future<void> forget() async {
    state = const YtSyncState();
    try {
      final file = File(p.join((await _directory()).path, 'yt_sync.json'));
      if (await file.exists()) await file.delete();
    } catch (error) {
      debugPrint('=== SINCRONIZAR: no se pudo borrar lo leído: ${error.runtimeType} ===');
    }
  }
}

final ytSyncProvider = NotifierProvider<YtSyncNotifier, YtSyncState>(YtSyncNotifier.new);
