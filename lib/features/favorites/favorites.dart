import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/track.dart';
import '../../utils/json_file.dart';


/// Canciones con "me gusta", por id. Se guardan solo en el teléfono
/// (`<appSupportDir>/favorites.json`). La Tarea M (playlists) las usará como
/// lista automática.
class FavoritesNotifier extends Notifier<Map<String, Track>> {
  JsonFile? _file;

  Future<JsonFile> _jsonFile() async =>
      _file ??= JsonFile(p.join((await getApplicationSupportDirectory()).path, 'favorites.json'), logTag: 'FAVORITAS');

  @override
  Map<String, Track> build() {
    unawaited(Future.microtask(_load));
    return const {};
  }

  Future<void> _load() async {
    try {
      final json = await (await _jsonFile()).read();
      if (json is! List) return;
      state = {
        for (final item in json)
          if (item is Map<String, dynamic>) Track.fromJson(item).id: Track.fromJson(item),
      };
    } catch (error) {
      debugPrint('=== FAVORITAS: no se pudo leer: $error ===');
    }
  }

  bool isLiked(String trackId) => state.containsKey(trackId);

  void toggle(Track track) {
    state = state.containsKey(track.id) ? (Map.of(state)..remove(track.id)) : {...state, track.id: track};
    unawaited(_save());
  }

  /// Importar (Tarea Y): agrega las que no estaban. Nunca quita ni cambia
  /// nada. Devuelve los ids agregados (para poder deshacerlo).
  List<String> addAll(List<Track> tracks) {
    final added = <String>[];
    final next = {...state};
    for (final track in tracks) {
      if (!next.containsKey(track.id)) {
        next[track.id] = track;
        added.add(track.id);
      }
    }
    if (added.isNotEmpty) {
      state = next;
      unawaited(_save());
    }
    return added;
  }

  /// Deshacer una importación: quita solo estas.
  void removeIds(Iterable<String> ids) {
    final remove = ids.toSet();
    state = {
      for (final e in state.entries)
        if (!remove.contains(e.key)) e.key: e.value,
    };
    unawaited(_save());
  }

  Future<void> _save() async {
    try {
      await (await _jsonFile()).write([for (final t in state.values) t.toJson()]);
    } catch (error) {
      debugPrint('=== FAVORITAS: no se pudo guardar: $error ===');
    }
  }
}

final favoritesProvider = NotifierProvider<FavoritesNotifier, Map<String, Track>>(FavoritesNotifier.new);
