import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/local_library/data/android_media_store_source.dart';
import 'package:kiji_player/features/local_library/data/local_library_service.dart';
import 'package:kiji_player/features/local_library/data/local_scan_store.dart';
import 'package:kiji_player/features/local_library/data/local_scanner.dart';
import 'package:kiji_player/features/local_library/domain/local_exclusions.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';
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
        // Notas de voz y audios de chats (nombres inventados con el formato de WhatsApp).
        {
          'id': 10,
          'data': '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Voice Notes/202611/PTT-20261101-WA0001.m4a',
          'isMusic': true,
        },
        {'id': 11, 'data': '/storage/emulated/0/Download/AUD-20261101-WA0002.m4a', 'isMusic': true},
        {'id': 12, 'data': '/storage/emulated/0/Music/Inventada/nota.m4a', 'isMusic': true, 'isRecording': true},
        {'sin': 'id'},
      ];
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

  test('El canal propio del MediaStore trae los mismos datos que on_audio_query', () async {
    final songs = await LocalLibraryService().fetchSongs();
    expect(songs, hasLength(6), reason: 'una fila sin id no cuenta');
    expect(songs.last.isRecording, isTrue);
    final s = songs.first;
    expect((s.id, s.title, s.artist, s.album, s.track, s.duration, s.genre, s.fileExtension),
        (7, 'Glass Harbor', 'The Velvet Tides', 'Low Tide Hymns', 2003, 201000, 'Dream Pop', 'mp3'));
    expect(s.dateAdded, 1762800000);
  });

  test('La fuente de Android: solo música en formatos que suenan, con la fecha de agregado', () async {
    final tracks = await AndroidMediaStoreSource(LocalLibraryService(), _NoScan()).loadTracks();
    expect(tracks.map((t) => t.id), ['local-7'], reason: 'sin .mid, avisos, notas de voz ni grabaciones');
    expect(tracks.single.addedAtMs, 1762800000 * 1000);
    expect((tracks.single.discNumber, tracks.single.trackNumber), (2, 3));
  });

  test('Notas de voz: las carpetas de WhatsApp, Telegram y grabadoras quedan afuera (y se pueden cambiar)', () {
    const d = LocalExclusions.defaults;
    expect(d.excludes('/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Audio/AUD-x.opus'), isTrue);
    expect(d.excludes('/storage/emulated/0/Telegram/Telegram Audio/nota.ogg'), isTrue);
    expect(d.excludes('/storage/emulated/0/Recordings/Grabación inventada.m4a'), isTrue);
    expect(d.excludes(r'C:\Users\alguien\Music\WhatsApp\audio.m4a'), isTrue, reason: 'también en la PC');
    expect(d.excludes('/storage/emulated/0/Download/PTT-20261101-WA0007.opus'), isTrue, reason: 'por el nombre, donde esté');
    expect(d.excludes('/storage/emulated/0/Music/Inventada/01 - Glass Harbor.mp3'), isFalse);
    expect(d.excludes('/storage/emulated/0/Music/WhatsApp Hits Inventados/tema.mp3'), isFalse, reason: 'solo la carpeta con ese nombre exacto');
    // El usuario quita WhatsApp y agrega una ruta.
    const mine = LocalExclusions(['/storage/emulated/0/Podcasts']);
    expect(mine.excludes('/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Audio/canción.mp3'), isFalse);
    expect(mine.excludes('/storage/emulated/0/Podcasts/episodio.mp3'), isTrue);
    expect(mine.excludes('/storage/emulated/0/PodcastsViejos/episodio.mp3'), isFalse);
    expect(mine.excludes('/storage/emulated/0/Download/AUD-20261101-WA0002.m4a'), isTrue, reason: 'las notas de voz nunca');
  });

  test('"Carpetas excluidas" se guarda: null son las de fábrica', () {
    expect(const AppSettings().localExclusions.folders, LocalExclusions.defaultFolders);
    final mine = const AppSettings().copyWith(excludedFolders: ['Podcasts']);
    final back = AppSettings.fromJson(jsonDecode(jsonEncode(mine.toJson())) as Map<String, dynamic>);
    expect(back.localExclusions.folders, ['Podcasts']);
    expect(back.copyWith(defaultExcludedFolders: true).excludedFolders, isNull);
    expect(const AppSettings().copyWith(excludedFolders: []).localExclusions.excludes('/x/WhatsApp/a.mp3'), isFalse,
        reason: 'lista vacía: se lee todo');
  });
}

/// Sin leer archivos: devuelve lo que trae el MediaStore (el escaneo real se prueba aparte).
class _NoScan extends LocalScanStore {
  @override
  Future<List<Track>> scan({
    List<String>? roots,
    List<ScanEntry>? entries,
    bool force = false,
    LocalExclusions exclusions = LocalExclusions.defaults,
  }) async => [
    for (final e in entries ?? const <ScanEntry>[])
      trackFromScan(readSong(e)),
  ];
}
