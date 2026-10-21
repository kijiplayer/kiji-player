import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/track.dart';
import '../../utils/json_file.dart';
import 'domain/playlist.dart';


/// Playlists de Kiji, guardadas en `<appSupportDir>/playlists.json`.
class PlaylistsNotifier extends Notifier<List<Playlist>> {
  PlaylistsNotifier({Future<Directory> Function()? directory, DateTime Function()? clock})
    : _directory = directory ?? getApplicationSupportDirectory,
      _clock = clock ?? DateTime.now;

  final Future<Directory> Function() _directory;
  final DateTime Function() _clock;
  final _random = Random();
  JsonFile? _file;
  final Completer<void> _loaded = Completer();

  /// Se completa cuando se leyó el archivo.
  Future<void> get loaded => _loaded.future;

  Future<JsonFile> _jsonFile() async =>
      _file ??= JsonFile(p.join((await _directory()).path, 'playlists.json'), logTag: 'PLAYLISTS');

  @override
  List<Playlist> build() {
    unawaited(Future.microtask(_load));
    return const [];
  }

  Future<void> _load() async {
    try {
      final json = await (await _jsonFile()).read();
      if (json is Map<String, dynamic>) {
        state = [
          for (final item in json['playlists'] as List<dynamic>? ?? const [])
            Playlist.fromJson(item as Map<String, dynamic>),
        ];
      }
    } catch (error) {
      debugPrint('=== PLAYLISTS: no se pudieron leer: $error ===');
    } finally {
      if (!_loaded.isCompleted) _loaded.complete();
    }
  }

  Future<void> _lastSave = Future.value();

  /// Espera a que termine de escribirse el último cambio.
  Future<void> flush() => _lastSave;

  Future<void> _save() => _lastSave = _write();

  Future<void> _write() async {
    try {
      await (await _jsonFile()).write({
        'version': 1,
        'playlists': [for (final pl in state) pl.toJson()],
      });
    } catch (error) {
      debugPrint('=== PLAYLISTS: no se pudieron guardar: $error ===');
    }
  }

  String _newId() =>
      'pl-${_clock().microsecondsSinceEpoch.toRadixString(36)}${_random.nextInt(1 << 20).toRadixString(36)}';

  Playlist? byId(String id) => state.where((pl) => pl.id == id).firstOrNull;

  void _replace(Playlist updated) {
    state = [for (final pl in state) pl.id == updated.id ? updated : pl];
    unawaited(_save());
  }

  /// Crea una playlist. Si el nombre existe, se agrega [suffix] o un número:
  /// nunca se pisa nada.
  Playlist create(String name, {List<Track> tracks = const [], String suffix = '', String? importedFrom}) {
    final now = _clock();
    final unique = PlaylistOps.uniqueName(name, state.map((pl) => pl.name), suffix: suffix);
    final playlist = Playlist(
      id: _newId(),
      name: unique,
      originalName: unique,
      tracks: PlaylistOps.addTracks(
        Playlist(id: '', name: '', tracks: const [], createdAt: now, updatedAt: now),
        tracks,
        now,
      ).$1.tracks,
      createdAt: now,
      updatedAt: now,
      importedFrom: importedFrom,
    );
    state = [...state, playlist];
    unawaited(_save());
    return playlist;
  }

  void rename(String id, String name) {
    final playlist = byId(id);
    if (playlist == null || name.trim().isEmpty) return;
    final others = state.where((pl) => pl.id != id).map((pl) => pl.name);
    _replace(playlist.copyWith(name: PlaylistOps.uniqueName(name, others), updatedAt: _clock()));
  }

  /// Personaliza la playlist: nombre, descripción, color y foto
  /// (el nombre de un archivo ya guardado en covers/). Lo que no se pasa,
  /// queda igual.
  void customize(
    String id, {
    String? name,
    String? description,
    int? colorValue,
    String? coverFile,
    bool clearDescription = false,
  }) {
    final playlist = byId(id);
    if (playlist == null) return;
    final others = state.where((pl) => pl.id != id).map((pl) => pl.name);
    final String? newDescription;
    if (clearDescription) {
      newDescription = null;
    } else if (description == null) {
      newDescription = playlist.description;
    } else {
      newDescription = description.trim().isEmpty ? null : description.trim();
    }
    _replace(
      playlist.copyWith(
        name: name == null || name.trim().isEmpty || name.trim() == playlist.name
            ? null
            : PlaylistOps.uniqueName(name, others),
        description: newDescription,
        colorValue: colorValue ?? playlist.colorValue,
        coverFile: coverFile ?? playlist.coverFile,
        updatedAt: _clock(),
      ),
    );
  }

  /// "Restaurar original": nombre con el que se creó, sin foto, descripción
  /// ni color. Devuelve la foto que tenía (para borrar el archivo).
  String? restoreOriginal(String id) {
    final playlist = byId(id);
    if (playlist == null) return null;
    final others = state.where((pl) => pl.id != id).map((pl) => pl.name);
    final original = playlist.originalName;
    _replace(
      playlist.copyWith(
        name: original == null ? null : PlaylistOps.uniqueName(original, others),
        description: null,
        colorValue: null,
        coverFile: null,
        updatedAt: _clock(),
      ),
    );
    return playlist.coverFile;
  }

  void setPinned(String id, bool pinned) {
    final playlist = byId(id);
    if (playlist == null || playlist.pinned == pinned) return;
    _replace(playlist.copyWith(pinned: pinned));
  }

  /// Borra la playlist. Devuelve lo necesario para deshacerlo.
  (Playlist, int)? delete(String id) {
    final index = state.indexWhere((pl) => pl.id == id);
    if (index == -1) return null;
    final removed = state[index];
    state = [...state]..removeAt(index);
    unawaited(_save());
    return (removed, index);
  }

  /// Deshace [delete] (o [deleteMany]).
  void restore(Playlist playlist, int index) {
    if (byId(playlist.id) != null) return;
    state = [...state]..insert(index.clamp(0, state.length), playlist);
    unawaited(_save());
  }

  /// Borra varias de una vez (deshacer una importación).
  List<(Playlist, int)> deleteMany(Set<String> ids) {
    final removed = <(Playlist, int)>[];
    for (var i = 0; i < state.length; i++) {
      if (ids.contains(state[i].id)) removed.add((state[i], i));
    }
    state = [
      for (final pl in state)
        if (!ids.contains(pl.id)) pl,
    ];
    unawaited(_save());
    return removed;
  }

  /// Agrega canciones (las repetidas se saltean). Devuelve cuántas se agregaron.
  int addTracks(String id, List<Track> tracks) {
    final playlist = byId(id);
    if (playlist == null) return 0;
    final (updated, added) = PlaylistOps.addTracks(playlist, tracks, _clock());
    if (added > 0) _replace(updated);
    return added;
  }

  Track? removeTrackAt(String id, int index) {
    final playlist = byId(id);
    if (playlist == null || index < 0 || index >= playlist.tracks.length) return null;
    final track = playlist.tracks[index];
    _replace(PlaylistOps.removeAt(playlist, index, _clock()));
    return track;
  }

  /// Quita varias a la vez (selección múltiple). Devuelve las quitadas con su lugar, para
  /// poder deshacerlo con [insertTracks].
  List<(int, Track)> removeTracksAt(String id, Set<int> indexes) {
    final playlist = byId(id);
    if (playlist == null || indexes.isEmpty) return const [];
    final removed = [
      for (var i = 0; i < playlist.tracks.length; i++)
        if (indexes.contains(i)) (i, playlist.tracks[i]),
    ];
    _replace(
      playlist.copyWith(
        tracks: [
          for (var i = 0; i < playlist.tracks.length; i++)
            if (!indexes.contains(i)) playlist.tracks[i],
        ],
        updatedAt: _clock(),
      ),
    );
    return removed;
  }

  /// Deshacer [removeTracksAt]: vuelve cada una a su lugar.
  void insertTracks(String id, List<(int, Track)> removed) {
    final playlist = byId(id);
    if (playlist == null || removed.isEmpty) return;
    final tracks = [...playlist.tracks];
    for (final (index, track) in [...removed]..sort((a, b) => a.$1.compareTo(b.$1))) {
      tracks.insert(index.clamp(0, tracks.length), track);
    }
    _replace(playlist.copyWith(tracks: tracks, updatedAt: _clock()));
  }

  void insertTrack(String id, int index, Track track) {
    final playlist = byId(id);
    if (playlist == null) return;
    _replace(PlaylistOps.insertAt(playlist, index, track, _clock()));
  }

  void moveTrack(String id, int from, int to) {
    final playlist = byId(id);
    if (playlist == null) return;
    _replace(PlaylistOps.move(playlist, from, to, _clock()));
  }
}

final playlistsProvider = NotifierProvider<PlaylistsNotifier, List<Playlist>>(PlaylistsNotifier.new);
