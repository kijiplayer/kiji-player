import 'package:path/path.dart' as p;

import '../../../models/track.dart';

/// Un grupo de la biblioteca local: un artista, un álbum o una carpeta, con sus canciones.
class LocalGroup {
  const LocalGroup({required this.key, required this.name, required this.tracks, this.subtitle, this.year});

  /// Identifica el grupo (para abrirlo y para las pruebas).
  final String key;
  final String name;

  /// El artista del álbum, o la ruta de la carpeta.
  final String? subtitle;
  final int? year;
  final List<Track> tracks;

  /// La canción cuya portada representa al grupo (la primera que tenga una propia, si se sabe).
  Track get cover => tracks.first;
}

String _fold(String s) => s.trim().toLowerCase();

/// El artista "de verdad" de una canción para agrupar: el del álbum si lo hay.
String groupArtist(Track t) => (t.albumArtist?.trim().isNotEmpty ?? false) ? t.albumArtist!.trim() : t.artist.trim();

/// Orden de las pistas de un álbum: disco, número de pista y, si faltan, el título.
int compareAlbumOrder(Track a, Track b) {
  final disc = (a.discNumber ?? 1).compareTo(b.discNumber ?? 1);
  if (disc != 0) return disc;
  final ta = a.trackNumber ?? 1 << 20, tb = b.trackNumber ?? 1 << 20;
  if (ta != tb) return ta.compareTo(tb);
  return _fold(a.title).compareTo(_fold(b.title));
}

/// Artistas (por el artista del álbum, si lo hay), por nombre. Sus canciones: por álbum y pista.
List<LocalGroup> groupByArtist(List<Track> tracks, {String unknown = ''}) {
  final groups = <String, List<Track>>{};
  final names = <String, String>{};
  for (final t in tracks) {
    if (t.source != TrackSource.local) continue;
    final name = groupArtist(t).isEmpty ? unknown : groupArtist(t);
    final key = _fold(name);
    names.putIfAbsent(key, () => name);
    groups.putIfAbsent(key, () => []).add(t);
  }
  final keys = groups.keys.toList()..sort();
  return [
    for (final key in keys)
      LocalGroup(
        key: 'artist:$key',
        name: names[key]!,
        tracks: groups[key]!
          ..sort((a, b) {
            final album = _fold(a.album ?? '').compareTo(_fold(b.album ?? ''));
            return album != 0 ? album : compareAlbumOrder(a, b);
          }),
      ),
  ];
}

/// Álbumes (el mismo nombre con el mismo artista del álbum), por nombre; sus pistas en orden. Las
/// canciones sin álbum no forman uno.
List<LocalGroup> groupByAlbum(List<Track> tracks) {
  final groups = <String, List<Track>>{};
  for (final t in tracks) {
    final album = t.album?.trim() ?? '';
    if (t.source != TrackSource.local || album.isEmpty) continue;
    groups.putIfAbsent('${_fold(album)}\u0000${_fold(groupArtist(t))}', () => []).add(t);
  }
  final albums = [
    for (final entry in groups.entries)
      LocalGroup(
        key: 'album:${entry.key}',
        name: entry.value.first.album!.trim(),
        subtitle: groupArtist(entry.value.first),
        year: entry.value.map((t) => t.year).whereType<int>().firstOrNull,
        tracks: entry.value..sort(compareAlbumOrder),
      ),
  ];
  return albums..sort((a, b) {
    final c = _fold(a.name).compareTo(_fold(b.name));
    return c != 0 ? c : _fold(a.subtitle ?? '').compareTo(_fold(b.subtitle ?? ''));
  });
}

/// Carpetas (la carpeta de cada archivo), por nombre; sus canciones por nombre de archivo.
List<LocalGroup> groupByFolderPath(List<Track> tracks) {
  final groups = <String, List<Track>>{};
  for (final t in tracks) {
    if (t.source != TrackSource.local) continue;
    groups.putIfAbsent(p.dirname(t.audioUrl), () => []).add(t);
  }
  final keys = groups.keys.toList()..sort((a, b) => _fold(p.basename(a)).compareTo(_fold(p.basename(b))));
  return [
    for (final key in keys)
      LocalGroup(
        key: 'folder:$key',
        name: p.basename(key),
        subtitle: key,
        tracks: groups[key]!..sort((a, b) => _fold(p.basename(a.audioUrl)).compareTo(_fold(p.basename(b.audioUrl)))),
      ),
  ];
}
