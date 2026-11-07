import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../models/track.dart';
import '../../../providers/playback_provider.dart';
import '../../../utils/json_file.dart';
import 'cover_store.dart';


/// Lo que el usuario cambió de una canción. Solo dentro de Kiji:
/// el archivo de música no se toca.
class TrackOverride {
  const TrackOverride({
    this.title,
    this.artist,
    this.coverFile,
    this.accent,
    this.backgroundFile,
    this.backgroundKind,
    this.lyricsPanel,
  });

  final String? title;
  final String? artist;

  /// Foto propia: nombre del archivo en `<datos>/covers/`.
  final String? coverFile;

  /// Estilo de esta canción (mientras suena; null = el general): color de acento (ARGB), fondo
  /// propio (en `<datos>/backgrounds/canciones/`, 'image' o 'video') y vista de la letra.
  final int? accent;
  final String? backgroundFile;
  final String? backgroundKind;
  final String? lyricsPanel;

  bool get hasStyle => accent != null || backgroundFile != null || lyricsPanel != null;

  bool get isEmpty => title == null && artist == null && coverFile == null && !hasStyle;

  TrackOverride copyWith({
    String? title,
    String? artist,
    String? coverFile,
    bool clearText = false,
    bool clearCover = false,
    int? accent,
    bool clearAccent = false,
    String? backgroundFile,
    String? backgroundKind,
    bool clearBackground = false,
    String? lyricsPanel,
    bool clearLyricsPanel = false,
  }) => TrackOverride(
    title: clearText ? null : title ?? this.title,
    artist: clearText ? null : artist ?? this.artist,
    coverFile: clearCover ? null : coverFile ?? this.coverFile,
    accent: clearAccent ? null : accent ?? this.accent,
    backgroundFile: clearBackground ? null : backgroundFile ?? this.backgroundFile,
    backgroundKind: clearBackground ? null : backgroundKind ?? this.backgroundKind,
    lyricsPanel: clearLyricsPanel ? null : lyricsPanel ?? this.lyricsPanel,
  );

  /// Sin el estilo de la canción ("Volver al estilo general"); el título, artista y foto quedan.
  TrackOverride get withoutStyle => TrackOverride(title: title, artist: artist, coverFile: coverFile);

  /// La canción como se muestra.
  Track applyTo(Track track) => title == null && artist == null ? track : track.copyWith(title: title, artist: artist);

  Map<String, dynamic> toJson() => {
    if (title != null) 'title': title,
    if (artist != null) 'artist': artist,
    if (coverFile != null) 'coverFile': coverFile,
    'accent': ?accent,
    'backgroundFile': ?backgroundFile,
    'backgroundKind': ?backgroundKind,
    'lyricsPanel': ?lyricsPanel,
  };

  factory TrackOverride.fromJson(Object? json) {
    String? read(String key) =>
        json is Map && json[key] is String && (json[key] as String).isNotEmpty ? json[key] as String : null;
    final background = read('backgroundFile');
    final panel = read('lyricsPanel');
    return TrackOverride(
      title: read('title'),
      artist: read('artist'),
      coverFile: read('coverFile'),
      accent: json is Map && json['accent'] is int ? json['accent'] as int : null,
      // Solo un nombre de archivo (nunca una ruta).
      backgroundFile: background != null && !background.contains(RegExp(r'[\\/]')) ? background : null,
      backgroundKind: read('backgroundKind') == 'video' ? 'video' : (background == null ? null : 'image'),
      lyricsPanel: const ['full', 'simple', 'showcase'].contains(panel) ? panel : null,
    );
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
      current.copyWith(clearText: true).copyWith(
        title: clean(title, original.title),
        artist: clean(artist, original.artist),
      ),
    );
  }

  Future<void> setCover(Track track, Uint8List bytes) async {
    final name = await covers.save('track-${track.id}', bytes);
    final current = state[track.id] ?? const TrackOverride();
    final old = current.coverFile;
    _set(track.id, current.copyWith(coverFile: name));
    await covers.delete(old);
  }

  /// "Restaurar original": sin título, artista ni foto propios (el estilo de la canción queda).
  Future<void> restoreOriginal(Track track) async {
    final current = state[track.id] ?? const TrackOverride();
    final old = current.coverFile;
    _set(track.id, current.copyWith(clearText: true, clearCover: true));
    await covers.delete(old);
  }

  /// Cambia el estilo de la canción [id] (lo que no se pasa queda como estaba).
  void setStyle(String id, TrackOverride Function(TrackOverride current) change) =>
      _set(id, change(state[id] ?? const TrackOverride()));

  /// "Volver al estilo general": sin color, fondo ni vista de la letra propios.
  void clearStyle(String id) => _set(id, (state[id] ?? const TrackOverride()).withoutStyle);
}

final trackOverridesProvider = NotifierProvider<TrackOverridesNotifier, Map<String, TrackOverride>>(
  TrackOverridesNotifier.new,
);

/// El estilo propio de la canción que suena (null si no tiene): manda sobre el general mientras suena.
final currentTrackStyleProvider = Provider<TrackOverride?>((ref) {
  final id = ref.watch(playbackProvider.select((p) => p.track?.id));
  if (id == null) return null;
  final style = ref.watch(trackOverridesProvider.select((all) => all[id]));
  return style != null && style.hasStyle ? style : null;
});

/// Carpeta de las fotos personalizadas, resuelta una vez (para dibujarlas).
final coversFolderProvider = FutureProvider<Directory>(
  (ref) => ref.read(trackOverridesProvider.notifier).covers.folder(),
);
