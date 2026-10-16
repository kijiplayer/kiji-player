import '../../../models/track.dart';
import '../../playlists/domain/playlist.dart';

String _location(Track track) {
  final videoId = track.youtubeVideoId;
  return videoId != null ? 'https://music.youtube.com/watch?v=$videoId' : track.audioUrl;
}

/// Playlist de Kiji en formato `.m3u8` (UTF-8): rutas de archivos locales y
/// enlaces de YouTube Music. Otras apps (y Kiji mismo) la pueden leer.
String exportM3u8(Playlist playlist) {
  final b = StringBuffer('#EXTM3U\n#PLAYLIST:${playlist.name}\n');
  for (final track in playlist.tracks) {
    final seconds = track.durationMs > 0 ? (track.durationMs / 1000).round() : -1;
    b
      ..write('#EXTINF:$seconds,${track.artist} - ${track.title}\n')
      ..write('${_location(track)}\n');
  }
  return b.toString();
}

String _csvField(String value) =>
    RegExp(r'[",\n\r]').hasMatch(value) ? '"${value.replaceAll('"', '""')}"' : value;

/// Playlist de Kiji en `.csv` (una fila por canción). Las columnas tienen
/// los nombres que Kiji detecta al importar, así el archivo vuelve igual.
String exportCsv(Playlist playlist) {
  final b = StringBuffer('Title,Artist,Album,Duration (ms),Video ID,Path\n');
  for (final t in playlist.tracks) {
    b.writeln([
      t.title,
      t.artist,
      t.album ?? '',
      t.durationMs > 0 ? '${t.durationMs}' : '',
      t.youtubeVideoId ?? '',
      t.source == TrackSource.local ? t.audioUrl : '',
    ].map(_csvField).join(','));
  }
  return b.toString();
}

/// Nombre de archivo seguro para [name].
String exportFileName(String name, String extension) {
  final safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  return '${safe.isEmpty ? 'playlist' : safe}.$extension';
}
