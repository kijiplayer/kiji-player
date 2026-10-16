import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'package:kiji_player/features/favorites/favorites.dart';
import 'package:kiji_player/features/history/listening_history.dart';
import 'package:kiji_player/features/import/data/import_parsers.dart';
import 'package:kiji_player/features/import/data/import_service.dart';
import 'package:kiji_player/features/import/data/playlist_export.dart';
import 'package:kiji_player/features/import/domain/import_matcher.dart';
import 'package:kiji_player/features/import/domain/imported.dart';
import 'package:kiji_player/features/playlists/domain/playlist.dart';
import 'package:kiji_player/features/playlists/playlists_provider.dart';
import 'package:kiji_player/features/yt_music/data/ytm_client.dart';
import 'package:kiji_player/models/track.dart';

/// `song.db` mínimo con las tablas de Echo / Metrolist (Room).
File _makeEchoDb(Directory dir) {
  final file = File(p.join(dir.path, 'song.db'));
  final db = sqlite3.open(file.path);
  db.execute('''
    CREATE TABLE song (id TEXT PRIMARY KEY, title TEXT NOT NULL, duration INTEGER NOT NULL,
      albumName TEXT, liked INTEGER NOT NULL DEFAULT 0, isLocal INTEGER NOT NULL DEFAULT 0);
    CREATE TABLE artist (id TEXT PRIMARY KEY, name TEXT NOT NULL);
    CREATE TABLE song_artist_map (songId TEXT, artistId TEXT, position INTEGER);
    CREATE TABLE playlist (id TEXT PRIMARY KEY, name TEXT NOT NULL, createdAt INTEGER);
    CREATE TABLE playlist_song_map (id INTEGER PRIMARY KEY AUTOINCREMENT, playlistId TEXT,
      songId TEXT, position INTEGER);
    CREATE TABLE event (id INTEGER PRIMARY KEY AUTOINCREMENT, songId TEXT, timestamp INTEGER,
      playTime INTEGER);
    INSERT INTO song VALUES ('vidAAAAAAAA', 'Get Lucky', 248, 'RAM', 1, 0);
    INSERT INTO song VALUES ('vidBBBBBBBB', 'Instant Crush', 337, 'RAM', 0, 0);
    INSERT INTO song VALUES ('local-77', 'Mi grabación', 61, NULL, 0, 1);
    INSERT INTO artist VALUES ('a1', 'Daft Punk'), ('a2', 'Pharrell Williams'), ('a3', 'Julian Casablancas');
    INSERT INTO song_artist_map VALUES ('vidAAAAAAAA', 'a1', 0), ('vidAAAAAAAA', 'a2', 1),
      ('vidBBBBBBBB', 'a1', 0), ('vidBBBBBBBB', 'a3', 1);
    INSERT INTO playlist VALUES ('p1', 'Para correr', 1), ('p2', 'Vacía', 2);
    INSERT INTO playlist_song_map (playlistId, songId, position) VALUES
      ('p1', 'vidBBBBBBBB', 1), ('p1', 'vidAAAAAAAA', 0), ('p1', 'local-77', 2);
    INSERT INTO event (songId, timestamp, playTime) VALUES
      ('vidAAAAAAAA', 1760000000000, 200000), ('vidAAAAAAAA', 1760100000000, 200000);
  ''');
  db.close();
  return file;
}

/// `.backup` de Echo: zip con song.db y settings.preferences_pb (que no se
/// tiene que leer).
List<int> _makeBackup(Directory dir) {
  final db = _makeEchoDb(dir).readAsBytesSync();
  final settings = utf8.encode('cookie=SECRETA; visitorData=xyz');
  final archive = Archive()
    ..add(ArchiveFile('settings.preferences_pb', settings.length, settings))
    ..add(ArchiveFile('song.db', db.length, db));
  return ZipEncoder().encodeBytes(archive);
}

const _exportify = '''
"Track URI","Track Name","Artist Name(s)","Album Name","Duration (ms)"
"spotify:track:1","Get Lucky (feat. Pharrell Williams)","Daft Punk, Pharrell Williams","Random Access Memories","248413"
"spotify:track:2","Canción, con coma","Artista Uno","Álbum","180000"
''';

const _takeout = '''
Video ID,Playlist Video Creation Timestamp
vidAAAAAAAA,2024-01-01T10:00:00+00:00
vidCCCCCCCC,2024-01-02T10:00:00+00:00
''';

/// YouTube Music de mentira para el buscador.
class _FakeLookup implements OnlineSongLookup {
  final searched = <String>[];

  @override
  Future<YtMusicSearchResult?> videoDetails(String videoId) async =>
      YtMusicSearchResult(videoId: videoId, title: 'Título de $videoId', artist: 'Artista YT', durationMs: 200000);

  @override
  Future<List<YtMusicSearchResult>> searchSongs(String query) async {
    searched.add(query);
    return const [
      YtMusicSearchResult(videoId: 'live1234567', title: 'Get Lucky (Live)', artist: 'Daft Punk', durationMs: 600000),
      YtMusicSearchResult(videoId: 'good1234567', title: 'Get Lucky', artist: 'Daft Punk', durationMs: 248000),
      YtMusicSearchResult(videoId: 'other123456', title: 'Otra cosa', artist: 'Otro', durationMs: 248000),
    ];
  }
}

Track _local(String id, String title, String artist, {int durationMs = 0}) => Track(
      id: 'local-$id',
      title: title,
      artist: artist,
      coverColor: const Color(0xFF7C5CFF),
      audioUrl: '/musica/$id.mp3',
      source: TrackSource.local,
      durationMs: durationMs,
    );

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('kiji_importar_'));
  tearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {
      // En Windows sqlite puede tardar un instante en soltar el archivo.
    }
  });

  group('.backup de Echo / Metrolist', () {
    test('Lee playlists (en orden), artistas, me gusta e historial; ignora los ajustes', () async {
      final bundle = await parseImportBytes(Uint8List.fromList(_makeBackup(dir)), 'echo.backup', tempDir: dir);
      expect(bundle.source, contains('Echo'));
      expect(bundle.playlists.map((pl) => pl.name), ['Para correr'], reason: 'la vacía no se importa');
      final songs = bundle.playlists.single.songs;
      expect(songs.map((s) => s.title), ['Get Lucky', 'Instant Crush', 'Mi grabación']);
      expect(songs.first.videoId, 'vidAAAAAAAA');
      expect(songs.first.artist, 'Daft Punk, Pharrell Williams');
      expect(songs.first.durationMs, 248000);
      expect(songs.last.videoId, isNull, reason: 'las locales no tienen videoId');
      expect(bundle.liked.map((s) => s.title), ['Get Lucky']);
      expect(bundle.history, hasLength(2));
      // No queda ninguna copia temporal de la base.
      expect(dir.listSync().whereType<Directory>().where((d) => p.basename(d.path).startsWith('kiji_import_')), isEmpty);
    });

    test('Zip dañado o sin song.db: mensaje simple', () async {
      await expectLater(
        parseImportBytes(Uint8List.fromList([0x50, 0x4B, 1, 2, 3, 4]), 'roto.backup', tempDir: dir),
        throwsA(isA<ImportFormatException>()),
      );
      final onlySettings = ZipEncoder().encodeBytes(Archive()..add(ArchiveFile('settings.preferences_pb', 3, [1, 2, 3])));
      await expectLater(
        parseImportBytes(Uint8List.fromList(onlySettings), 'sin_db.backup', tempDir: dir),
        throwsA(isA<ImportFormatException>().having((e) => e.message, 'mensaje', contains('song.db'))),
      );
    });
  });

  group('.m3u / .m3u8', () {
    test('Rutas relativas, file:// y enlaces de YouTube, con #EXTINF', () {
      final bundle = parseM3u('''
#EXTM3U
#PLAYLIST:Viaje
#EXTINF:248,Daft Punk - Get Lucky
https://music.youtube.com/watch?v=vidAAAAAAAA&list=xyz
#EXTINF:61,Yo - Mi grabación
grabaciones/mia.mp3
file:///C:/Musica/tema.flac
https://youtu.be/vidBBBBBBBB
''', name: 'viaje', baseDir: '/home/usuario/listas');
      final pl = bundle.playlists.single;
      expect(pl.name, 'Viaje');
      expect(pl.songs[0].videoId, 'vidAAAAAAAA');
      expect(pl.songs[0].title, 'Get Lucky');
      expect(pl.songs[0].artist, 'Daft Punk');
      expect(pl.songs[0].durationMs, 248000);
      expect(p.normalize(pl.songs[1].localPath!), p.normalize('/home/usuario/listas/grabaciones/mia.mp3'));
      expect(pl.songs[2].localPath, isNotNull);
      expect(pl.songs[3].videoId, 'vidBBBBBBBB');
    });
  });

  group('.csv', () {
    test('Separa campos con comillas y comas', () {
      expect(parseCsv('a,"b, c","d ""e"""\n1,2,3'), [
        ['a', 'b, c', 'd "e"'],
        ['1', '2', '3'],
      ]);
      expect(parseCsv('x;y\n1;2').first, ['x', 'y'], reason: 'punto y coma');
    });

    test('Exportify (Spotify): título, primer artista, álbum y duración en ms', () {
      final bundle = parseCsvPlaylist(_exportify, name: 'Mis favoritas');
      expect(bundle.source, contains('Exportify'));
      final songs = bundle.playlists.single.songs;
      expect(songs.first.title, 'Get Lucky (feat. Pharrell Williams)');
      expect(songs.first.artist, 'Daft Punk');
      expect(songs.first.durationMs, 248413);
      expect(songs.last.title, 'Canción, con coma');
      expect(songs.every((s) => s.videoId == null), isTrue);
    });

    test('Google Takeout de YouTube Music: detecta la columna "Video ID"', () {
      final bundle = parseCsvPlaylist(_takeout, name: 'Me gusta');
      expect(bundle.source, contains('Takeout'));
      expect(bundle.playlists.single.songs.map((s) => s.videoId), ['vidAAAAAAAA', 'vidCCCCCCCC']);
    });

    test('Sin columnas conocidas: mensaje simple', () {
      expect(() => parseCsvPlaylist('foo,bar\n1,2', name: 'x'), throwsA(isA<ImportFormatException>()));
    });
  });

  group('Buscar cada canción', () {
    test('Con videoId va directo; sin título, pide los datos del video', () async {
      final lookup = _FakeLookup();
      final matcher = ImportMatcher(local: const [], online: lookup);
      final direct = await matcher.resolve(const ImportedSong(videoId: 'vidAAAAAAAA', title: 'Get Lucky', artist: 'Daft Punk'));
      expect(direct!.youtubeVideoId, 'vidAAAAAAAA');
      expect(direct.title, 'Get Lucky');
      final onlyId = await matcher.resolve(const ImportedSong(videoId: 'vidCCCCCCCC'));
      expect(onlyId!.title, 'Título de vidCCCCCCCC');
      expect(lookup.searched, isEmpty, reason: 'con videoId no se busca por texto');
    });

    test('Primero tu biblioteca (sin tildes ni "(feat.)"), sin salir a internet', () async {
      final lookup = _FakeLookup();
      final matcher = ImportMatcher(
        local: [_local('1', 'Canción con Tílde', 'Artista Uno', durationMs: 180000)],
        online: lookup,
      );
      final track = await matcher.resolve(
        const ImportedSong(title: 'Cancion con tilde (feat. Alguien)', artist: 'artista uno', durationMs: 181000),
      );
      expect(track!.id, 'local-1');
      expect(lookup.searched, isEmpty);
    });

    test('Si no está, YouTube Music, eligiendo la duración más parecida (no la versión en vivo)', () async {
      final matcher = ImportMatcher(local: const [], online: _FakeLookup());
      final track = await matcher.resolve(
        const ImportedSong(title: 'Get Lucky (feat. Pharrell Williams)', artist: 'Daft Punk', durationMs: 248413),
      );
      expect(track!.youtubeVideoId, 'good1234567');
    });

    test('Nada parecido: queda "sin encontrar"', () async {
      final matcher = ImportMatcher(local: const [], online: _FakeLookup());
      expect(await matcher.resolve(const ImportedSong(title: 'Zzzz qqqq', artist: 'Nadie')), isNull);
    });
  });

  test('Vista previa: cuenta playlists, canciones y sin encontrar', () async {
    final bundle = ImportBundle(source: 'prueba', playlists: [
      const ImportedPlaylist('A', [
        ImportedSong(videoId: 'vidAAAAAAAA', title: 'Get Lucky'),
        ImportedSong(title: 'Zzzz qqqq', artist: 'Nadie'),
      ]),
      const ImportedPlaylist('B', [ImportedSong(title: 'Zzzz qqqq', artist: 'Nadie')]),
    ]);
    final progress = <int>[];
    final plan = await prepareImport(
      bundle,
      ImportMatcher(local: const [], online: _FakeLookup()),
      onProgress: (done, _) => progress.add(done),
    );
    expect(plan.playlistCount, 1, reason: 'B quedó sin canciones');
    expect(plan.songCount, 1);
    expect(plan.missingCount, 1);
    expect(previewText(plan), 'Se van a crear 1 playlist, 1 canción, 1 sin encontrar.');
    expect(progress.last, 2);
  });

  test('Importar nunca pisa nada, y "Deshacer" quita exactamente lo agregado', () async {
    final container = ProviderContainer(overrides: [
      playlistsProvider.overrideWith(() => PlaylistsNotifier(directory: () async => dir)),
      importsProvider.overrideWith(() => ImportsNotifier(directory: () async => dir)),
    ]);
    addTearDown(container.dispose);
    container.read(playlistsProvider);
    await container.read(playlistsProvider.notifier).loaded;
    container.read(favoritesProvider);
    container.read(listeningHistoryProvider);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    // Lo que ya tenía el usuario.
    final mine = container.read(playlistsProvider.notifier).create('Para correr');
    final alreadyLiked = _local('9', 'Ya me gustaba', 'Yo');
    container.read(favoritesProvider.notifier).toggle(alreadyLiked);

    final bundle = await parseImportBytes(Uint8List.fromList(_makeBackup(dir)), 'echo.backup', tempDir: dir);
    final plan = await prepareImport(
      bundle,
      ImportMatcher(local: [_local('77', 'Mi grabación', 'Yo')], online: _FakeLookup()),
    );
    final record = container.read(importsProvider.notifier).apply(plan);

    final names = container.read(playlistsProvider).map((pl) => pl.name).toList();
    expect(names, ['Para correr', 'Para correr (importada)']);
    expect(container.read(playlistsProvider).last.tracks, hasLength(3));
    expect(container.read(favoritesProvider).keys, containsAll(['local-9', 'yt-vidAAAAAAAA']));
    expect(record.likedIds, ['yt-vidAAAAAAAA']);
    final history = container.read(listeningHistoryProvider);
    expect(history.single.playCount, 2, reason: 'dos reproducciones de la misma canción');

    container.read(importsProvider.notifier).undo(record);
    expect(container.read(playlistsProvider).map((pl) => pl.id), [mine.id]);
    expect(container.read(favoritesProvider).keys, ['local-9'], reason: 'lo que ya tenía queda');
    expect(container.read(listeningHistoryProvider), isEmpty);
    expect(container.read(importsProvider), isEmpty);

    // Que terminen los guardados en segundo plano antes de borrar la carpeta.
    await container.read(playlistsProvider.notifier).flush();
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });

  group('Exportar', () {
    final playlist = Playlist(
      id: 'p',
      name: 'Mía: lo mejor',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      tracks: [
        const Track(
          id: 'yt-vidAAAAAAAA',
          title: 'Get Lucky',
          artist: 'Daft Punk',
          coverColor: Color(0xFF7C5CFF),
          audioUrl: '',
          source: TrackSource.youtube,
          durationMs: 248000,
          album: 'RAM, 2013',
        ),
        _local('1', 'Canción "rara"', 'Yo', durationMs: 61000),
      ],
    );

    test('.m3u8 que Kiji vuelve a leer igual', () {
      final back = parseM3u(exportM3u8(playlist), name: 'x').playlists.single;
      expect(back.name, 'Mía: lo mejor');
      expect(back.songs.first.videoId, 'vidAAAAAAAA');
      expect(back.songs.first.title, 'Get Lucky');
      expect(back.songs.last.localPath, '/musica/1.mp3');
    });

    test('.csv que Kiji vuelve a leer igual (con comas y comillas)', () {
      final back = parseCsvPlaylist(exportCsv(playlist), name: 'x').playlists.single.songs;
      expect(back.first.videoId, 'vidAAAAAAAA');
      expect(back.first.album, 'RAM, 2013');
      expect(back.last.title, 'Canción "rara"');
      expect(back.last.localPath, '/musica/1.mp3');
    });

    test('Nombre de archivo sin caracteres prohibidos', () {
      expect(exportFileName('Mía: lo mejor?', 'm3u8'), 'Mía_ lo mejor_.m3u8');
    });
  });
}
