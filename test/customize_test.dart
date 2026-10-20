import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kiji_player/features/backup/data/backup_service.dart';
import 'package:kiji_player/features/customize/data/artwork_cache.dart';
import 'package:kiji_player/features/customize/data/track_overrides.dart';
import 'package:kiji_player/features/customize/presentation/track_text.dart';
import 'package:kiji_player/features/import/data/import_parsers.dart';
import 'package:kiji_player/features/import/domain/import_matcher.dart';
import 'package:kiji_player/features/import/domain/imported.dart';
import 'package:kiji_player/features/playlists/domain/playlist.dart';
import 'package:kiji_player/features/playlists/playlists_provider.dart';
import 'package:kiji_player/features/yt_music/data/ytm_client.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/widgets/album_cover.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

Track _yt(String id, {String title = 'De música ligera', String artist = 'Soda Stereo'}) => Track(
      id: 'yt-$id',
      title: title,
      artist: artist,
      coverColor: Colors.black,
      audioUrl: '',
      source: TrackSource.youtube,
    );

/// Una imagen PNG de verdad, chica.
List<int> _png(int side) => img.encodePng(img.Image(width: side, height: side));

class _NoLookup implements OnlineSongLookup {
  @override
  Future<YtMusicSearchResult?> videoDetails(String videoId) async => null;
  @override
  Future<List<YtMusicSearchResult>> searchSongs(String query) async => const [];
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('kiji_z3_'));
  tearDown(() async {
    // Windows puede tener un archivo abierto un instante: se reintenta.
    for (var i = 0; i < 10 && dir.existsSync(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Todavía en uso: se vuelve a probar.
      }
    }
  });

  group('personalizar una canción', () {
    ProviderContainer make() {
      final c = ProviderContainer(overrides: [
        trackOverridesProvider.overrideWith(() => TrackOverridesNotifier(directory: () async => dir)),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('título, artista y foto solo en Kiji; "Restaurar original" vuelve todo', () async {
      final track = _yt('abc');
      var c = make();
      c.read(trackOverridesProvider);
      await Future<void>.delayed(Duration.zero);
      final notifier = c.read(trackOverridesProvider.notifier);

      notifier.setText(track, title: 'Música ligera', artist: '  Soda Stereo  ');
      final override = c.read(trackOverridesProvider)[track.id]!;
      expect(override.title, 'Música ligera');
      expect(override.artist, isNull, reason: 'igual al original: no se guarda');
      expect(override.applyTo(track).title, 'Música ligera');
      expect(override.applyTo(track).id, track.id);

      await notifier.setCover(track, Uint8List.fromList(_png(1200)));
      final first = c.read(trackOverridesProvider)[track.id]!.coverFile!;
      final firstFile = File(p.join(dir.path, coversFolder, first));
      expect(firstFile.existsSync(), isTrue);
      final saved = img.decodeImage(firstFile.readAsBytesSync())!;
      expect(saved.width, 800, reason: 'se achica a 800 px');

      // Otra foto: la vieja se borra.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await notifier.setCover(track, Uint8List.fromList(_png(100)));
      expect(firstFile.existsSync(), isFalse);
      await notifier.flush();

      // Se guarda y se lee igual (entra en la copia de seguridad).
      c = make();
      c.read(trackOverridesProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(c.read(trackOverridesProvider)[track.id]!.title, 'Música ligera');
      expect(backedUpFiles, contains('track_overrides.json'));

      final cover = c.read(trackOverridesProvider)[track.id]!.coverFile!;
      await c.read(trackOverridesProvider.notifier).restoreOriginal(track);
      expect(c.read(trackOverridesProvider), isEmpty);
      expect(File(p.join(dir.path, coversFolder, cover)).existsSync(), isFalse);
    });

    testWidgets('los textos de la canción muestran lo personalizado', (tester) async {
      final track = _yt('abc');
      final c = ProviderContainer(overrides: [
        trackOverridesProvider.overrideWith(() => TrackOverridesNotifier(directory: () async => throw const FileSystemException('sin disco'))),
      ]);
      addTearDown(c.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(home: Column(children: [TrackTitleText(track), TrackArtistText(track)])),
      ));
      expect(find.text('De música ligera'), findsOneWidget);
      c.read(trackOverridesProvider.notifier).setText(track, title: 'Mi versión', artist: 'Gustavo');
      await tester.pump();
      expect(find.text('Mi versión'), findsOneWidget);
      expect(find.text('Gustavo'), findsOneWidget);
    });
  });

  group('playlists', () {
    test('personalizar, fijar y restaurar original', () async {
      final c = ProviderContainer(overrides: [
        playlistsProvider.overrideWith(() => PlaylistsNotifier(directory: () async => dir)),
      ]);
      addTearDown(c.dispose);
      c.read(playlistsProvider);
      await c.read(playlistsProvider.notifier).loaded;
      final notifier = c.read(playlistsProvider.notifier);
      final a = notifier.create('Rock');
      final b = notifier.create('Estudio');

      notifier.customize(a.id, name: 'Rock nacional', description: 'Para el auto', colorValue: 0xFFFF5C8A, coverFile: 'x.jpg');
      var pl = notifier.byId(a.id)!;
      expect([pl.name, pl.description, pl.colorValue, pl.coverFile, pl.originalName],
          ['Rock nacional', 'Para el auto', 0xFFFF5C8A, 'x.jpg', 'Rock']);
      expect(pl.isCustomized, isTrue);

      notifier.setPinned(b.id, true);
      expect(PlaylistOps.pinnedFirst(c.read(playlistsProvider)).map((p) => p.name), ['Estudio', 'Rock nacional']);

      final oldCover = notifier.restoreOriginal(a.id);
      pl = notifier.byId(a.id)!;
      expect(oldCover, 'x.jpg');
      expect([pl.name, pl.description, pl.colorValue, pl.coverFile], ['Rock', null, null, null]);
      expect(pl.isCustomized, isFalse);

      // Ida y vuelta por JSON, y un archivo viejo sin los campos nuevos.
      final back = Playlist.fromJson(notifier.byId(b.id)!.toJson());
      expect(back.pinned, isTrue);
      final old = Playlist.fromJson({'id': '1', 'name': 'Vieja', 'createdAt': 0, 'updatedAt': 0});
      expect([old.pinned, old.description, old.coverFile], [false, null, null]);
      await notifier.flush();
    });
  });

  group('carátulas al importar', () {
    test('Echo/Metrolist: miniatura de canciones y playlists, y si estaba fijada', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.close);
      db.execute('''
        CREATE TABLE song (id TEXT PRIMARY KEY, title TEXT, duration INTEGER, thumbnailUrl TEXT, liked INTEGER, isLocal INTEGER);
        CREATE TABLE playlist (id TEXT PRIMARY KEY, name TEXT, createdAt INTEGER, thumbnailUrl TEXT, isPinned INTEGER);
        CREATE TABLE playlist_song_map (playlistId TEXT, songId TEXT, position INTEGER);
        INSERT INTO song VALUES ('vidAAAAAAAA', 'Get Lucky', 248, 'https://lh3.googleusercontent.com/a=w60-h60', 0, 0);
        INSERT INTO playlist VALUES ('p1', 'Para correr', 1, 'https://lh3.googleusercontent.com/pl', 1);
        INSERT INTO playlist_song_map VALUES ('p1', 'vidAAAAAAAA', 0);
      ''');
      final bundle = readEchoDatabase(db);
      expect(bundle.playlists.single.thumbnailUrl, 'https://lh3.googleusercontent.com/pl');
      expect(bundle.playlists.single.pinned, isTrue);
      expect(bundle.playlists.single.songs.single.thumbnailUrl, 'https://lh3.googleusercontent.com/a=w60-h60');
    });

    test('m3u: #EXTIMG y tvg-logo, relativos a la lista', () {
      final bundle = parseM3u(
        '#EXTM3U\n'
        '#EXTIMG:tapas/uno.jpg\n'
        '#EXTINF:200,Soda Stereo - Persiana americana\nmusica/uno.mp3\n'
        '#EXTINF:180 tvg-logo="https://img/dos.jpg",Cerati - Crimen\nhttps://youtu.be/AAAAAAAAAAA\n'
        '#EXTINF:100,Sin tapa\nmusica/tres.mp3\n',
        name: 'lista',
        baseDir: '/m',
      );
      final songs = bundle.playlists.single.songs;
      expect(p.split(songs[0].thumbnailUrl!), p.split(p.normalize('/m/tapas/uno.jpg')));
      expect(songs[1].thumbnailUrl, 'https://img/dos.jpg');
      expect(songs[2].thumbnailUrl, isNull, reason: 'la imagen vale solo para la canción siguiente');
    });

    test('la canción importada lleva su miniatura', () async {
      final matcher = ImportMatcher(local: const [], online: _NoLookup());
      final track = await matcher.resolve(const ImportedSong(
        videoId: 'vidAAAAAAAA',
        title: 'Get Lucky',
        artist: 'Daft Punk',
        thumbnailUrl: 'https://lh3.googleusercontent.com/a=w60-h60',
      ));
      expect(track!.thumbnailUrl, 'https://lh3.googleusercontent.com/a=w60-h60');
    });

    testWidgets('la carátula guardada en el dispositivo se usa sin internet', (tester) async {
      final cacheDir = Directory(p.join(dir.path, 'artwork'))..createSync();
      final local = Track(
        id: 'local-1',
        title: 'Mi grabación',
        artist: 'Yo',
        coverColor: Colors.black,
        audioUrl: '/musica/uno.mp3',
        source: TrackSource.local,
      );
      expect(artworkCacheName('a'), artworkCacheName('a'));
      expect(artworkCacheName('a'), isNot(artworkCacheName('b')));
      File(p.join(cacheDir.path, artworkCacheName(ArtworkCache.fileKey(local.audioUrl))))
          .writeAsBytesSync(_png(10));

      await tester.pumpWidget(ProviderScope(
        overrides: [
          artworkFolderProvider.overrideWith((ref) async => cacheDir),
          trackOverridesProvider.overrideWith(() => TrackOverridesNotifier(directory: () async => throw const FileSystemException('sin disco'))),
        ],
        child: MaterialApp(home: Center(child: TrackArtwork(track: local))),
      ));
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(AlbumCover), findsNothing);
    });
  });
}
