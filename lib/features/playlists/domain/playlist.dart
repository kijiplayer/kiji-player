// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivo de referencia: app/src/main/kotlin/.../ui/screens/playlist/LocalPlaylistScreen.kt
// (playlists locales: crear, renombrar, reordenar y quitar).

import '../../../models/track.dart';

/// Una playlist de Kiji. Vive solo en el teléfono.
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.tracks,
    required this.createdAt,
    required this.updatedAt,
    this.importedFrom,
  });

  final String id;
  final String name;
  final List<Track> tracks;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Si vino de una importación (Tarea Y): de qué archivo o app. Sirve para
  /// "deshacer la importación".
  final String? importedFrom;

  Playlist copyWith({String? name, List<Track>? tracks, DateTime? updatedAt}) => Playlist(
        id: id,
        name: name ?? this.name,
        tracks: tracks ?? this.tracks,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        importedFrom: importedFrom,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tracks': [for (final t in tracks) t.toJson()],
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        if (importedFrom != null) 'importedFrom': importedFrom,
      };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id'] as String,
        name: json['name'] as String,
        tracks: [
          for (final t in json['tracks'] as List<dynamic>? ?? const [])
            Track.fromJson(t as Map<String, dynamic>),
        ],
        createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int),
        importedFrom: json['importedFrom'] as String?,
      );
}

/// Operaciones puras sobre playlists (testeables sin disco).
abstract final class PlaylistOps {
  /// Nombre libre: si [wanted] ya existe, agrega [suffix] (y un número si
  /// hace falta). Nunca se pisa una playlist existente (Cero Sorpresas).
  static String uniqueName(String wanted, Iterable<String> existing, {String suffix = ''}) {
    final names = {for (final n in existing) n.trim().toLowerCase()};
    final base = wanted.trim().isEmpty ? 'Playlist sin nombre' : wanted.trim();
    if (!names.contains(base.toLowerCase())) return base;
    final withSuffix = suffix.isEmpty ? base : '$base $suffix';
    if (!names.contains(withSuffix.toLowerCase())) return withSuffix;
    for (var i = 2;; i++) {
      final candidate = '$withSuffix $i';
      if (!names.contains(candidate.toLowerCase())) return candidate;
    }
  }

  /// Agrega las que no estén ya. Devuelve la playlist y cuántas se agregaron.
  static (Playlist, int) addTracks(Playlist playlist, List<Track> tracks, DateTime now) {
    final ids = {for (final t in playlist.tracks) t.id};
    final toAdd = [for (final t in tracks) if (ids.add(t.id)) t];
    if (toAdd.isEmpty) return (playlist, 0);
    return (playlist.copyWith(tracks: [...playlist.tracks, ...toAdd], updatedAt: now), toAdd.length);
  }

  static Playlist removeAt(Playlist playlist, int index, DateTime now) {
    if (index < 0 || index >= playlist.tracks.length) return playlist;
    return playlist.copyWith(tracks: [...playlist.tracks]..removeAt(index), updatedAt: now);
  }

  static Playlist insertAt(Playlist playlist, int index, Track track, DateTime now) {
    final at = index.clamp(0, playlist.tracks.length);
    return playlist.copyWith(tracks: [...playlist.tracks]..insert(at, track), updatedAt: now);
  }

  static Playlist move(Playlist playlist, int from, int to, DateTime now) {
    final n = playlist.tracks.length;
    if (from == to || from < 0 || from >= n || to < 0 || to >= n) return playlist;
    final list = [...playlist.tracks];
    final track = list.removeAt(from);
    list.insert(to, track);
    return playlist.copyWith(tracks: list, updatedAt: now);
  }
}
