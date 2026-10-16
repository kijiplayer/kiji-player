import '../../../models/track.dart';
import '../domain/local_library_source.dart';
import '../domain/local_track_mapper.dart';
import 'local_library_service.dart';

/// Android: la biblioteca del sistema (MediaStore) mediante `on_audio_query`.
class AndroidMediaStoreSource implements LocalLibrarySource {
  AndroidMediaStoreSource([LocalLibraryService? service])
      : _service = service ?? LocalLibraryService();

  final LocalLibraryService _service;

  @override
  bool get usesFolders => false;

  @override
  Future<List<String>> folders() async => const [];

  @override
  Future<bool> hasAccess() => _service.hasPermission();

  @override
  Future<bool> requestAccess() => _service.requestPermission();

  @override
  Future<void> removeFolder(String folder) async {}

  @override
  Future<List<Track>> loadTracks() async {
    final songs = await _service.fetchSongs();
    return songs
        .where((song) => song.isMusic ?? true)
        .map(localTrackFromSong)
        .toList(growable: false);
  }
}
