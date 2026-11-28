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
import '../../playlists/domain/playlist.dart';
import '../../playlists/playlists_provider.dart';
import '../../settings/data/settings_store.dart';
import '../../yt_music/data/ytm_browse_parser.dart';
import '../../yt_music/data/ytm_client.dart';
import '../../yt_music/domain/yt_track_mapper.dart';
import '../../yt_music/presentation/collection_screens.dart' show ytMusicClientProvider;
import '../domain/yt_playlist_merge.dart';
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

/// Por qué no se pudo leer la cuenta la última vez.
enum SyncProblem {
  /// YouTube rechazó la sesión (venció o se cerró en otro lado): hay que volver a iniciarla.
  sessionRejected,

  /// Sin conexión o YouTube no respondió: se puede reintentar.
  failed,
}

/// Lo que se leyó de la cuenta: "Me gusta", lo agregado a la biblioteca (lo más reciente primero)
/// y las playlists, y cuándo.
class YtSyncState {
  const YtSyncState({
    this.liked = const [],
    this.recent = const [],
    this.playlists = const [],
    this.syncedAt,
    this.syncing = false,
    this.problem,
    this.sent = 0,
    this.merged = const [],
  });

  final List<Track> liked;

  /// Canciones agregadas a la biblioteca de YouTube Music (como las ordena YouTube: recientes primero).
  final List<Track> recent;
  final List<SyncedPlaylist> playlists;
  final DateTime? syncedAt;
  final bool syncing;
  final SyncProblem? problem;

  /// Última sincronización: cuántos cambios de Kiji se mandaron a YouTube Music.
  final int sent;

  /// Playlists que cambiaron en Kiji y en YouTube desde la vez anterior (se juntaron los cambios
  /// de los dos lados; se avisa).
  final List<String> merged;

  bool get isEmpty => liked.isEmpty && recent.isEmpty && playlists.isEmpty;

  YtSyncState copyWith({bool? syncing, SyncProblem? Function()? problem}) => YtSyncState(
    liked: liked,
    recent: recent,
    playlists: playlists,
    syncedAt: syncedAt,
    syncing: syncing ?? this.syncing,
    problem: problem == null ? this.problem : problem(),
    sent: sent,
    merged: merged,
  );
}

/// YouTube rechazó la sesión: 401/403, o respondió como a alguien sin sesión.
class SessionRejected implements Exception {
  const SessionRejected();
}

/// ¿La respuesta es la de alguien sin sesión? (YouTube a veces responde 200 sin la cuenta.)
bool isLoggedOutResponse(Map<String, dynamic>? page) {
  final context = page?['responseContext'];
  if (context is! Map) return false;
  final web = context['mainAppWebResponseContext'];
  return web is Map && web['loggedOut'] == true;
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

/// Manda a la cuenta los cambios de una playlist (sincronizar de ida y vuelta, 0.9).
abstract interface class YtAccountWriter {
  Future<bool> editPlaylist(String playlistId, List<Map<String, dynamic>> actions, YtSession session);
}

class _ClientWriter implements YtAccountWriter {
  _ClientWriter(this._client);
  final YtMusicClient _client;

  @override
  Future<bool> editPlaylist(String playlistId, List<Map<String, dynamic>> actions, YtSession session) =>
      _client.editPlaylistWithAccount(playlistId, actions, session);
}

final ytAccountWriterProvider = Provider<YtAccountWriter>((ref) => _ClientWriter(ref.read(ytMusicClientProvider)));

/// Una playlist de la cuenta tal como se leyó ahora (antes de juntarla con la de Kiji).
class _Remote {
  const _Remote(this.id, this.name, this.tracks, this.setVideoIds, this.editable);
  final String id;
  final String name;
  final List<Track> tracks;
  final Map<String, String> setVideoIds;
  final bool editable;
}

/// "Sincronizar con YouTube": solo con la sesión iniciada y el interruptor prendido (apagado de
/// fábrica). Trae "Me gusta" (solo lectura) y las playlists de la cuenta, que en Kiji son playlists
/// como las demás (vinculadas, ver [YtLink]); al sincronizar, lo que se agregó o quitó en Kiji se
/// manda a YouTube Music (0.9). Todo va directo entre el dispositivo y YouTube. Lo leído queda
/// solo en el dispositivo (`yt_sync.json` y `playlists.json`; los dos van en la copia completa). Si YouTube rechaza la sesión, se avisa ("Vuelve a iniciarla") y Kiji sigue
/// como invitado.
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
    Map<String, dynamic>? first;
    try {
      first = await reader.browse(browseId, session);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) throw const SessionRejected();
      rethrow;
    }
    if (isLoggedOutResponse(first)) throw const SessionRejected();
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
    unawaited(_load().then((_) => _adoptStored()).then((_) => _autoSync()));
    return const YtSyncState();
  }

  /// Con la sincronización prendida, se vuelve a leer sola cada [interval], con Kiji ya a la vista.
  Future<void> _autoSync() async {
    try {
      if (_disposed || !(await ref.read(settingsProvider.notifier).loaded).ytSync) return;
      await whenAppVisible();
      await Future<void>.delayed(const Duration(seconds: 5));
      // Sola: solo lee. Lo cambiado en Kiji se manda únicamente al tocar «Sincronizar».
      if (!_disposed) await syncIfDue(push: false);
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
        recent: [
          for (final t in (json['recent'] as List? ?? const []))
            if (t is Map<String, dynamic>) Track.fromJson(t),
        ],
        playlists: [for (final pl in (json['playlists'] as List? ?? const [])) ?SyncedPlaylist.fromJson(pl)],
        syncedAt: DateTime.tryParse('${json['syncedAt']}'),
      );
    } catch (error) {
      debugPrint('=== SINCRONIZAR: no se pudo leer lo guardado: ${error.runtimeType} ===');
    }
  }

  /// Al pasar a la 0.9: las playlists de la cuenta que ya se habían leído (antes solo se veían)
  /// pasan a ser playlists de Kiji vinculadas, con lo último que se leyó como base. Así no
  /// desaparecen de la Biblioteca hasta la próxima lectura. Si es de otra persona, la próxima
  /// sincronización lo sabe y no le manda nada.
  Future<void> _adoptStored() async {
    if (state.playlists.isEmpty) return;
    try {
      if (!(await ref.read(settingsProvider.notifier).loaded).ytSync) return;
      final store = ref.read(playlistsProvider.notifier);
      await store.loaded.timeout(const Duration(seconds: 5));
      final have = {
        for (final pl in ref.read(playlistsProvider)) ?pl.yt?.id,
      };
      for (final pl in state.playlists) {
        if (have.contains(pl.id)) continue;
        store.putLinked(
          name: pl.name,
          tracks: pl.tracks,
          link: YtLink(id: pl.id, base: [for (final t in pl.tracks) ?t.youtubeVideoId]),
        );
      }
    } catch (error) {
      debugPrint('=== SINCRONIZAR: no se pudieron pasar las playlists guardadas (${error.runtimeType}) ===');
    }
  }

  /// Al abrir Kiji: si está prendido, hay sesión y pasó [interval].
  Future<void> syncIfDue({bool push = false}) async {
    final last = state.syncedAt;
    if (last != null && DateTime.now().difference(last) < interval) return;
    await syncNow(push: push);
  }

  /// Sincroniza ahora («Sincronizar»): lee la cuenta y, con [push], manda a YouTube Music lo que
  /// se agregó o quitó en Kiji (al abrir Kiji solo se lee). Devuelve false si no se pudo (sin
  /// sesión, apagado o YouTube la rechazó); el motivo queda en [YtSyncState.problem] y se muestra.
  Future<bool> syncNow({bool push = true}) async {
    // Aunque la sesión se haya marcado como rechazada, "Leer ahora" vuelve a probar: si YouTube la
    // acepta, la marca se borra.
    final session = YtSessionHolder.current;
    if (!ref.read(settingsProvider).ytSync || session == null || state.syncing) return false;
    state = state.copyWith(syncing: true);
    final reader = ref.read(ytAccountReaderProvider);
    try {
      // "Me gusta" es la playlist LM; las canciones de la biblioteca, lo agregado (recientes primero).
      final liked = _tracks(await _pages(reader, 'VLLM', session));
      final recent = _tracks(await _pages(reader, 'FEmusic_liked_videos', session));
      final seenIds = <String>{};
      final ids = [
        for (final page in await _pages(reader, 'FEmusic_liked_playlists', session))
          for (final pl in parseLibraryPlaylists(page))
            if (pl.id != 'LM' && seenIds.add(pl.id)) pl,
      ];
      final before = {for (final pl in state.playlists) pl.id: pl};
      final playlists = <SyncedPlaylist>[];
      final remotes = <_Remote>[];
      for (final pl in ids.take(maxPlaylists)) {
        try {
          final pages = await _pages(reader, 'VL${pl.id}', session);
          if (pages.isEmpty) continue;
          final setVideoIds = {for (final page in pages) ...parsePlaylistSetVideoIds(page)};
          // Al pie de las playlists propias YouTube Music agrega «Sugerencias» (cambian en cada
          // lectura): no son de la playlist. Las canciones de verdad traen su setVideoId.
          final tracks = [
            for (final t in _tracks(pages))
              if (setVideoIds.isEmpty || setVideoIds.containsKey(t.youtubeVideoId)) t,
          ];
          playlists.add(SyncedPlaylist(id: pl.id, name: pl.name, tracks: tracks));
          remotes.add(_Remote(pl.id, pl.name, tracks, setVideoIds, isEditablePlaylist(pages.first)));
        } catch (error) {
          // La sesión venció: se corta todo (ver abajo). Otra falla: esta playlist queda como
          // estaba y siguen las demás (antes una sola hacía fallar toda la lectura).
          if (error is SessionRejected) rethrow;
          debugPrint('=== SINCRONIZAR: una playlist no se pudo leer (${error.runtimeType}); queda la de antes ===');
          final old = before[pl.id];
          if (old != null) playlists.add(old);
        }
      }
      final (sent, merged) = await _syncPlaylists(remotes, session, push: push);
      final now = DateTime.now();
      YtSessionHolder.rejected = false;
      state = YtSyncState(liked: liked, recent: recent, playlists: playlists, syncedAt: now, sent: sent, merged: merged);
      await (await _json()).write({
        'syncedAt': now.toIso8601String(),
        'liked': [for (final t in liked) t.toJson()],
        'recent': [for (final t in recent) t.toJson()],
        'playlists': [for (final pl in playlists) pl.toJson()],
      });
      debugPrint(
        '=== SINCRONIZAR: ${liked.length} me gusta, ${recent.length} en la biblioteca, ${playlists.length} playlists, '
        '$sent cambios enviados${merged.isEmpty ? '' : ', ${merged.length} con cambios de los dos lados'} ===',
      );
      return true;
    } on SessionRejected {
      // La sesión venció o se cerró: se avisa (Configuración y Biblioteca) y Kiji sigue como invitado.
      YtSessionHolder.rejected = true;
      debugPrint('=== SINCRONIZAR: YouTube rechazó la sesión; hay que volver a iniciarla ===');
      state = state.copyWith(syncing: false, problem: () => SyncProblem.sessionRejected);
      return false;
    } catch (error) {
      final detail = error is DioException ? ' ${error.type.name} ${error.response?.statusCode ?? ''}' : '';
      debugPrint('=== SINCRONIZAR: no se pudo leer la cuenta (${error.runtimeType}$detail) ===');
      state = state.copyWith(syncing: false, problem: () => SyncProblem.failed);
      return false;
    }
  }

  /// Junta cada playlist de la cuenta con su copia en Kiji y manda a YouTube lo que cambió en Kiji.
  /// Devuelve cuántos cambios se mandaron y qué playlists cambiaron en los dos lados.
  Future<(int, List<String>)> _syncPlaylists(List<_Remote> remotes, YtSession session, {required bool push}) async {
    var sent = 0;
    final merged = <String>[];
    try {
      final store = ref.read(playlistsProvider.notifier);
      await store.loaded.timeout(const Duration(seconds: 5));
      final writer = ref.read(ytAccountWriterProvider);
      final remoteIds = {for (final r in remotes) r.id};
      for (final remote in remotes) {
        final local = ref.read(playlistsProvider).where((pl) => pl.yt?.id == remote.id).firstOrNull;
        final remoteVideos = [for (final t in remote.tracks) ?t.youtubeVideoId];
        if (local == null) {
          // Nueva en la cuenta: su copia en Kiji, igual a la de YouTube.
          store.putLinked(
            name: remote.name,
            tracks: remote.tracks,
            link: YtLink(id: remote.id, base: remoteVideos, editable: remote.editable, syncedAt: DateTime.now()),
          );
          continue;
        }
        final link = local.yt!;
        final plan = mergeYtPlaylist(
          base: link.base,
          local: [for (final t in local.tracks) ?t.youtubeVideoId],
          remote: remoteVideos,
          // Sin [push] no se manda nada: lo de Kiji queda pendiente para «Sincronizar».
          editable: remote.editable && push,
        );
        if (plan.changedInKiji || plan.changedInYouTube) {
          final baseSet = link.base.toSet(), remoteSet = remoteVideos.toSet();
          debugPrint(
            '=== SINCRONIZAR: playlist de ${remoteVideos.length}: en YouTube '
            '+${remoteSet.difference(baseSet).length} −${baseSet.difference(remoteSet).length}, '
            'en Kiji +${plan.toAdd.length} −${plan.toRemove.length} ===',
          );
        }
        var pushed = !plan.needsPush;
        if (plan.needsPush) {
          final actions = <Map<String, dynamic>>[
            for (final id in plan.toAdd)
              {'action': 'ACTION_ADD_VIDEO', 'addedVideoId': id, 'dedupeOption': 'DEDUPE_OPTION_SKIP'},
            for (final id in plan.toRemove)
              if (remote.setVideoIds[id] case final setId?)
                {'action': 'ACTION_REMOVE_VIDEO', 'setVideoId': setId, 'removedVideoId': id},
          ];
          try {
            pushed = actions.isNotEmpty && await writer.editPlaylist(remote.id, actions, session);
          } catch (error) {
            final status = error is DioException ? error.response?.statusCode : null;
            if (status == 401 || status == 403) throw const SessionRejected();
            pushed = false;
            debugPrint('=== SINCRONIZAR: no se pudo mandar a YouTube un cambio de una playlist (${error.runtimeType}) ===');
          }
          if (pushed) sent += actions.length;
        }
        if (plan.conflict && remote.editable && push) merged.add(remote.name);
        // Las canciones: las que ya estaban en Kiji (con lo que se haya guardado de ellas) y las
        // nuevas de YouTube. Las que no tienen id de video quedan al final, como estaban.
        final byVideo = {
          for (final t in remote.tracks) ?t.youtubeVideoId: t,
          for (final t in local.tracks) ?t.youtubeVideoId: t,
        };
        store.putLinked(
          id: local.id,
          name: remote.name,
          tracks: [
            for (final id in plan.result) ?byVideo[id],
            for (final t in local.tracks)
              if (t.youtubeVideoId == null) t,
          ],
          link: YtLink(
            id: remote.id,
            // Si YouTube aceptó, la base es lo que quedó; si no, lo que tiene YouTube (lo de Kiji
            // se vuelve a mandar la próxima vez).
            base: pushed && remote.editable && push ? plan.result : remoteVideos,
            editable: remote.editable,
            syncedAt: DateTime.now(),
          ),
        );
      }
      // Ya no está en la cuenta (se borró o se dejó de guardar): queda en Kiji, sin vínculo.
      for (final pl in [...ref.read(playlistsProvider)]) {
        if (pl.yt != null && !remoteIds.contains(pl.yt!.id)) store.unlink(pl.id);
      }
    } on SessionRejected {
      rethrow;
    } catch (error) {
      debugPrint('=== SINCRONIZAR: las playlists vinculadas no se pudieron actualizar (${error.runtimeType}) ===');
    }
    return (sent, merged);
  }

  /// Apagar la sincronización borra lo leído (Cero Sorpresas: nada queda guardado a escondidas).
  Future<void> forget() async {
    state = const YtSyncState();
    // Las copias de las playlists de la cuenta también se van (eran de YouTube, no de Kiji).
    try {
      final linked = {
        for (final pl in ref.read(playlistsProvider))
          if (pl.yt != null) pl.id,
      };
      if (linked.isNotEmpty) ref.read(playlistsProvider.notifier).deleteMany(linked);
    } catch (error) {
      debugPrint('=== SINCRONIZAR: no se pudieron quitar las playlists de la cuenta: ${error.runtimeType} ===');
    }
    try {
      final file = File(p.join((await _directory()).path, 'yt_sync.json'));
      if (await file.exists()) await file.delete();
    } catch (error) {
      debugPrint('=== SINCRONIZAR: no se pudo borrar lo leído: ${error.runtimeType} ===');
    }
  }
}

final ytSyncProvider = NotifierProvider<YtSyncNotifier, YtSyncState>(YtSyncNotifier.new);
