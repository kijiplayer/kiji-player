import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/local_library/data/android_media_store_source.dart';
import 'package:kiji_player/features/local_library/data/local_library_service.dart';
import 'package:kiji_player/features/local_library/data/local_scan_store.dart';
import 'package:kiji_player/features/local_library/data/local_scanner.dart';
import 'package:kiji_player/models/track.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('kiji/media');

  setUp(() {
    // Lo que manda MediaLibrary.kt (datos inventados).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'songs');
      return [
        {
          'id': 7,
          'data': '/storage/emulated/0/Music/Inventada/01 - Glass Harbor.mp3',
          'size': 1234,
          'dateAdded': 1762800000,
          'dateModified': 1762800100,
          'title': 'Glass Harbor',
          'artist': 'The Velvet Tides',
          'album': 'Low Tide Hymns',
          'track': 2003,
          'duration': 201000,
          'isMusic': true,
          'genre': 'Dream Pop',
        },
        {'id': 8, 'data': '/storage/emulated/0/Ringtones/tono.mid', 'isMusic': true},
        {'id': 9, 'data': '/storage/emulated/0/Notifications/aviso.mp3', 'isMusic': false},
        {'sin': 'id'},
      ];
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

  test('El canal propio del MediaStore trae los mismos datos que on_audio_query', () async {
    final songs = await LocalLibraryService().fetchSongs();
    expect(songs, hasLength(3), reason: 'una fila sin id no cuenta');
    final s = songs.first;
    expect((s.id, s.title, s.artist, s.album, s.track, s.duration, s.genre, s.fileExtension),
        (7, 'Glass Harbor', 'The Velvet Tides', 'Low Tide Hymns', 2003, 201000, 'Dream Pop', 'mp3'));
    expect(s.dateAdded, 1762800000);
  });

  test('La fuente de Android: solo música en formatos que suenan, con la fecha de agregado', () async {
    final tracks = await AndroidMediaStoreSource(LocalLibraryService(), _NoScan()).loadTracks();
    expect(tracks.map((t) => t.id), ['local-7'], reason: 'sin .mid ni avisos');
    expect(tracks.single.addedAtMs, 1762800000 * 1000);
    expect((tracks.single.discNumber, tracks.single.trackNumber), (2, 3));
  });
}

/// Sin leer archivos: devuelve lo que trae el MediaStore (el escaneo real se prueba aparte).
class _NoScan extends LocalScanStore {
  @override
  Future<List<Track>> scan({List<String>? roots, List<ScanEntry>? entries, bool force = false}) async => [
    for (final e in entries ?? const <ScanEntry>[])
      trackFromScan(readSong(e)),
  ];
}
