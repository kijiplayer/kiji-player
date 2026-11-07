import 'package:flutter/foundation.dart';

import '../../../models/track.dart';
import '../domain/local_library_source.dart';
import 'local_library_service.dart';
import 'local_scan_store.dart';
import 'local_scanner.dart';

/// Android: la lista sale de la biblioteca del sistema (MediaStore, mediante `on_audio_query`),
/// con su fecha de agregado; los datos completos y la portada, de cada archivo (con caché: solo
/// se leen los nuevos o cambiados). Si un archivo no se puede leer, queda lo del MediaStore.
class AndroidMediaStoreSource implements LocalLibrarySource {
  AndroidMediaStoreSource([LocalLibraryService? service, LocalScanStore? store])
    : _service = service ?? LocalLibraryService(),
      _store = store ?? LocalScanStore();

  final LocalLibraryService _service;
  final LocalScanStore _store;

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
  Future<List<Track>> loadTracks({bool force = false}) async {
    final songs = await _service.fetchSongs();
    final entries = <ScanEntry>[];
    for (final song in songs) {
      if (song.isMusic == false) continue;
      // Formatos que Kiji reproduce (lo demás se saltea sin avisos).
      final ext = song.fileExtension.toLowerCase();
      if (!localAudioExtensions.contains('.$ext')) {
        debugPrint('=== BIBLIOTECA: se saltea un formato que no se lee (.$ext) ===');
        continue;
      }
      entries.add(
        ScanEntry(
          id: 'local-${song.id}',
          path: song.data,
          sizeBytes: song.size,
          // El MediaStore da segundos.
          modifiedMs: (song.dateModified ?? 0) * 1000,
          addedAtMs: song.dateAdded == null ? null : song.dateAdded! * 1000,
          title: song.title,
          artist: song.artist,
          album: song.album,
          genre: song.genre,
          track: song.track,
          durationMs: song.duration,
        ),
      );
    }
    final tracks = await _store.scan(entries: entries, force: force);
    return [...tracks]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }
}
