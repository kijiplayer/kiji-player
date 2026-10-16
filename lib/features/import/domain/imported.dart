/// Una canción tal como viene de otra app, antes de buscarla en Kiji.
class ImportedSong {
  const ImportedSong({this.videoId, this.localPath, this.title, this.artist, this.album, this.durationMs});

  /// Si la trae, se usa directo (YouTube Music).
  final String? videoId;

  /// Ruta de un archivo (listas .m3u).
  final String? localPath;

  final String? title;
  final String? artist;
  final String? album;
  final int? durationMs;

  /// Algo con qué buscarla.
  bool get isUsable =>
      (videoId?.isNotEmpty ?? false) || (localPath?.isNotEmpty ?? false) || (title?.trim().isNotEmpty ?? false);

  /// Clave para no repetir la misma canción dentro de una importación.
  String get key => videoId != null
      ? 'yt:$videoId'
      : localPath != null
          ? 'file:$localPath'
          : 'txt:${title?.toLowerCase()}|${artist?.toLowerCase()}';

  @override
  String toString() => videoId ?? localPath ?? '$title — $artist';
}

class ImportedPlaylist {
  const ImportedPlaylist(this.name, this.songs);

  final String name;
  final List<ImportedSong> songs;
}

class ImportedPlay {
  const ImportedPlay(this.song, this.at);

  final ImportedSong song;
  final DateTime at;
}

/// Todo lo que trae un archivo de otra app.
class ImportBundle {
  const ImportBundle({
    required this.source,
    this.playlists = const [],
    this.liked = const [],
    this.history = const [],
  });

  /// "Echo / Metrolist (.backup)", "Exportify (.csv)", "mis_temas.m3u8"…
  final String source;
  final List<ImportedPlaylist> playlists;
  final List<ImportedSong> liked;
  final List<ImportedPlay> history;

  /// Canciones distintas en total (para la vista previa).
  int get distinctSongs => {
        for (final pl in playlists) ...pl.songs.map((s) => s.key),
        ...liked.map((s) => s.key),
        ...history.map((h) => h.song.key),
      }.length;

  bool get isEmpty => playlists.isEmpty && liked.isEmpty && history.isEmpty;
}

/// El archivo no es de ningún formato conocido, o está dañado. El mensaje
/// es para el usuario (sin detalles técnicos).
class ImportFormatException implements Exception {
  const ImportFormatException(this.message);
  final String message;

  @override
  String toString() => message;
}
