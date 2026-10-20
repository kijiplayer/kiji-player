import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../models/track.dart';
import '../../../utils/json_file.dart';
import 'cover_store.dart';


/// Lo que el usuario cambió de una canción. Solo dentro de Kiji:
/// el archivo de música no se toca.
class TrackOverride {
  const TrackOverride({this.title, this.artist, this.coverFile});

  final String? title;
  final String? artist;

  /// Foto propia: nombre del archivo en `<datos>/covers/`.
  final String? coverFile;

  bool get isEmpty => title == null && artist == null && coverFile == null;

  /// La canción como se muestra.
  Track applyTo(Track track) => title == null && artist == null ? track : track.copyWith(title: title, artist: artist);

  Map<String, dynamic> toJson() => {
    if (title != null) 'title': title,
    if (artist != null) 'artist': artist,
    if (coverFile != null) 'coverFile': coverFile,
  };

  factory TrackOverride.fromJson(Object? json) {
    String? read(String key) =>
        json is Map && json[key] is String && (json[key] as String).isNotEmpty ? json[key] as String : null;
    return TrackOverride(title: read('title'), artist: read('artist'), coverFile: read('coverFile'));
  }
}

/// Personalizaciones por id de canción, en `<datos>/track_overrides.json`
/// (entra en la copia de seguridad).
class TrackOverridesNotifier extends Notifier<Map<String, TrackOverride>> {
  TrackOverridesNotifier({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;
  JsonFile? _file;
  late final covers = CoverStore(directory: _directory);
  Future<void> _lastSave = Future.value();

  Future<void> flush() => _lastSave;

  Future<JsonFile> _jsonFile() async =>
      _file ??= JsonFile(p.join((await _directory()).path, 'track_overrides.json'), logTag: 'PERSONALIZAR');

  @override
  Map<String, TrackOverride> build() {
    unawaited(Future.microtask(_load));
    return const {};
  }

  Future<void> _load() async {
    try {
      final json = await (await _jsonFile()).read();
      if (json is Map) {
        state = {
          for (final entry in json.entries)
            if (!TrackOverride.fromJson(entry.value).isEmpty) '${entry.key}': TrackOverride.fromJson(entry.value),
        };
      }
    } catch (error) {
      debugPrint('=== PERSONALIZAR: no se pudieron leer: $error ===');
    }
  }

  void _set(String id, TrackOverride value) {
    final next = {...state};
    if (value.isEmpty) {
      next.remove(id);
    } else {
      next[id] = value;
    }
    state = next;
    _lastSave = _write();
  }

  Future<void> _write() async {
    try {
      await (await _jsonFile()).write({for (final e in state.entries) e.key: e.value.toJson()});
    } catch (error) {
      debugPrint('=== PERSONALIZAR: no se pudieron guardar: $error ===');
    }
  }

  /// Título y artista que se muestran. Vacío o igual al original = el original.
  void setText(Track original, {String? title, String? artist}) {
    final current = state[original.id] ?? const TrackOverride();
    String? clean(String? value, String base) =>
        value == null || value.trim().isEmpty || value.trim() == base ? null : value.trim();
    _set(
      original.id,
      TrackOverride(
        title: clean(title, original.title),
        artist: clean(artist, original.artist),
        coverFile: current.coverFile,
      ),
    );
  }

  Future<void> setCover(Track track, Uint8List bytes) async {
    final name = await covers.save('track-${track.id}', bytes);
    final current = state[track.id] ?? const TrackOverride();
    final old = current.coverFile;
    _set(track.id, TrackOverride(title: current.title, artist: current.artist, coverFile: name));
    await covers.delete(old);
  }

  /// "Restaurar original": sin título, artista ni foto propios.
  Future<void> restoreOriginal(Track track) async {
    final old = state[track.id]?.coverFile;
    _set(track.id, const TrackOverride());
    await covers.delete(old);
  }
}

final trackOverridesProvider = NotifierProvider<TrackOverridesNotifier, Map<String, TrackOverride>>(
  TrackOverridesNotifier.new,
);

/// Carpeta de las fotos personalizadas, resuelta una vez (para dibujarlas).
final coversFolderProvider = FutureProvider<Directory>(
  (ref) => ref.read(trackOverridesProvider.notifier).covers.folder(),
);
