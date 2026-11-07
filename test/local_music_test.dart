import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:kiji_player/features/customize/data/artwork_cache.dart';
import 'package:kiji_player/features/local_library/data/desktop_folder_source.dart';
import 'package:kiji_player/features/local_library/data/local_scan_store.dart';
import 'package:kiji_player/features/local_library/data/local_scanner.dart';
import 'package:kiji_player/features/local_library/domain/library_order.dart';
import 'package:kiji_player/features/local_library/domain/local_groups.dart';
import 'package:kiji_player/features/local_library/domain/local_song_text.dart';
import 'package:kiji_player/features/lyrics/data/lyrics_repository.dart';
import 'package:kiji_player/models/track.dart';

import 'helpers/fake_mp3.dart';

Track _t(
  String id, {
  String title = 'T',
  String artist = 'A',
  String? album,
  String? albumArtist,
  int? track,
  int? disc,
  int? added,
  String dir = '/m',
}) => Track(
  id: id,
  title: title,
  artist: artist,
  coverColor: const Color(0xFF3A6EA5),
  audioUrl: '$dir/$id.mp3',
  source: TrackSource.local,
  album: album,
  albumArtist: albumArtist,
  trackNumber: track,
  discNumber: disc,
  addedAtMs: added,
);

void main() {
  late Directory base;
  late Directory music;

  setUp(() async {
    base = await Directory.systemTemp.createTemp('kiji_local_');
    music = await Directory(p.join(base.path, 'Musica')).create();
  });
  tearDown(() async {
    for (var i = 0; i < 20; i++) {
      try {
        await base.delete(recursive: true);
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });

  test('Sin etiquetas: el nombre del archivo, limpio', () {
    String title(String name) => titleFromFileName(name).title;
    expect(title('01 - Glass Harbor.mp3'), 'Glass Harbor');
    expect(title('12. Slow Comet.flac'), 'Slow Comet');
    expect(title('1-03 Lemon Static.m4a'), 'Lemon Static');
    expect(title('03 Orbit of You.ogg'), 'Orbit of You');
    expect(title('Track 07 - Tidal Lines.opus'), 'Tidal Lines');
    expect(title('velvet_hours__final.wav'), 'velvet hours final');
    expect(title('99 Globos Inventados.mp3'), '99 Globos Inventados', reason: 'un número sin separador es del título');
    final both = titleFromFileName('05 - The Velvet Tides - Glass Harbor.mp3');
    expect((both.artist, both.title), ('The Velvet Tides', 'Glass Harbor'));
  });

  test('Datos completos de un archivo y su portada incluida (en su tamaño original)', () {
    final file = File(p.join(music.path, 'x.mp3'))
      ..writeAsBytesSync(
        fakeMp3(
          title: 'Glass Harbor',
          artist: 'The Velvet Tides',
          album: 'Low Tide Hymns',
          albumArtist: 'Varios Inventados',
          year: '2024',
          track: '3/12',
          disc: '2/2',
          genre: 'Dream Pop',
          cover: fakePng,
        ),
      );
    final art = p.join(base.path, 'artwork');
    final song = readSong(
      ScanEntry(id: 'local-1', path: file.path, sizeBytes: file.lengthSync(), modifiedMs: 1),
      artworkDir: art,
    );
    expect(song['title'], 'Glass Harbor');
    expect(song['artist'], 'The Velvet Tides');
    expect(song['album'], 'Low Tide Hymns');
    expect(song['albumArtist'], 'Varios Inventados');
    expect(song['year'], 2024);
    expect(song['trackNumber'], 3);
    expect(song['discNumber'], 2);
    expect(song['genre'], 'Dream Pop');
    final saved = File(p.join(art, artworkCacheName(ArtworkCache.fileKey(file.path))));
    expect(saved.readAsBytesSync(), fakePng);
    expect(song.containsKey('thumbnailUrl'), isFalse, reason: 'con portada incluida no hace falta la de la carpeta');
  });

  test('Sin portada incluida, la imagen de la carpeta (cover.jpg, folder.jpg…); si no, la generada', () {
    final album = Directory(p.join(music.path, 'Album'))..createSync();
    File(p.join(album.path, 'otra.jpg')).writeAsBytesSync(fakePng);
    expect(findFolderCover(album.path), isNull, reason: 'una imagen cualquiera no es la portada');
    File(p.join(album.path, 'Folder.JPG')).writeAsBytesSync(fakePng);
    expect(p.basename(findFolderCover(album.path)!), 'Folder.JPG');
    File(p.join(album.path, 'cover.png')).writeAsBytesSync(fakePng);
    expect(p.basename(findFolderCover(album.path)!), 'cover.png', reason: 'cover va antes que folder');
    final file = File(p.join(album.path, '01 - Sin portada.mp3'))..writeAsBytesSync(fakeMp3(title: 'Sin portada'));
    final song = readSong(
      ScanEntry(id: 'local-2', path: file.path, sizeBytes: 1, modifiedMs: 1),
      artworkDir: p.join(base.path, 'artwork'),
      folderCover: findFolderCover(album.path),
    );
    expect(song['thumbnailUrl'], p.join(album.path, 'cover.png'));
  });

  test('Un archivo dañado no rompe nada: queda con lo que diga el sistema o el nombre', () {
    final file = File(p.join(music.path, '02 - Copper Fields.mp3'))..writeAsBytesSync([1, 2, 3]);
    final fromName = readSong(ScanEntry(id: 'a', path: file.path, sizeBytes: 3, modifiedMs: 1));
    expect((fromName['title'], fromName['artist']), ('Copper Fields', ''));
    final fromMediaStore = readSong(
      ScanEntry(id: 'b', path: file.path, sizeBytes: 3, modifiedMs: 1, title: 'Copper', artist: '<unknown>', track: 2004),
    );
    expect((fromMediaStore['title'], fromMediaStore['artist']), ('Copper', ''));
    expect((fromMediaStore['discNumber'], fromMediaStore['trackNumber']), (2, 4));
    // El MediaStore copia el nombre del archivo como título cuando no hay etiquetas: va el limpio.
    final copied = readSong(ScanEntry(id: 'c', path: file.path, sizeBytes: 3, modifiedMs: 1, title: '02 - Copper Fields'));
    expect(copied['title'], 'Copper Fields');
  });

  test('Caché: la segunda vez solo se lee lo nuevo o cambiado; "Volver a escanear" lee todo', () async {
    for (var i = 0; i < 5; i++) {
      File(p.join(music.path, 's$i.mp3')).writeAsBytesSync(fakeMp3(title: 'Song $i', artist: 'Inventado'));
    }
    final source = DesktopFolderSource(baseDirectory: () async => base, pickFolder: () async => music.path);
    await source.requestAccess();
    await source.loadTracks(force: true);
    expect((source.lastStats!.read, source.lastStats!.reused), (5, 0));
    // Otro escaneo (como al reabrir Kiji): nada nuevo.
    final again = DesktopFolderSource(baseDirectory: () async => base, pickFolder: () async => music.path);
    await again.loadTracks();
    expect((again.lastStats!.read, again.lastStats!.reused), (0, 5));
    // Uno nuevo y uno cambiado.
    File(p.join(music.path, 'nuevo.mp3')).writeAsBytesSync(fakeMp3(title: 'Nuevo'));
    File(p.join(music.path, 's0.mp3')).writeAsBytesSync(fakeMp3(title: 'Song 0 bis', artist: 'Inventado'));
    final third = DesktopFolderSource(baseDirectory: () async => base, pickFolder: () async => music.path);
    final tracks = await third.loadTracks();
    expect((third.lastStats!.read, third.lastStats!.reused), (2, 4));
    expect(tracks.map((t) => t.title), containsAll(['Nuevo', 'Song 0 bis']));
    await third.loadTracks(force: true);
    expect(third.lastStats!.read, 6);
  });

  test('Formatos: mp3, flac, m4a/aac, ogg, opus y wav (lo demás no se lista)', () {
    for (final ext in ['mp3', 'flac', 'm4a', 'aac', 'ogg', 'opus', 'wav', 'txt', 'jpg', 'mid']) {
      File(p.join(music.path, 'a.$ext')).writeAsBytesSync([0]);
    }
    final found = listAudioFiles([music.path]).map((e) => p.extension(e.path)).toSet();
    expect(found, {'.mp3', '.flac', '.m4a', '.aac', '.ogg', '.opus', '.wav'});
  });

  test('Artistas (por el del álbum), álbumes con sus pistas en orden y carpetas', () {
    final tracks = [
      _t('3', title: 'Tres', artist: 'Ana Inventada', album: 'Noche', track: 3),
      _t('1', title: 'Uno', artist: 'Ana Inventada', album: 'Noche', track: 1),
      _t('d2', title: 'Disco dos', artist: 'Ana Inventada', album: 'Noche', track: 1, disc: 2),
      _t('f', title: 'Feat', artist: 'Ana & Otro', albumArtist: 'Ana Inventada', album: 'Noche', track: 2),
      _t('x', title: 'Suelta', artist: 'Banda Ficticia', dir: '/otra'),
    ];
    final artists = groupByArtist(tracks);
    expect(artists.map((g) => (g.name, g.tracks.length)), [('Ana Inventada', 4), ('Banda Ficticia', 1)]);
    final albums = groupByAlbum(tracks);
    expect(albums, hasLength(1), reason: 'sin álbum no forma uno');
    expect(albums.single.tracks.map((t) => t.id), ['1', 'f', '3', 'd2']);
    final folders = groupByFolderPath(tracks);
    expect(folders.map((g) => g.name), ['m', 'otra']);
  });

  test('Recientes: lo último que se agregó primero; sin fecha, al final', () {
    final tracks = [_t('viejo', added: 100), _t('sin-fecha'), _t('nuevo', added: 900), _t('medio', added: 500)];
    expect(arrangeLibrarySongs(tracks).map((t) => t.id), ['nuevo', 'medio', 'viejo', 'sin-fecha']);
  });

  test('Letra: el .lrc junto al archivo (mismo nombre)', () async {
    final song = File(p.join(music.path, 'Glass Harbor.mp3'))..writeAsBytesSync([0]);
    expect(await readSidecarLrc(song.path), isNull);
    // Letra inventada.
    File(p.join(music.path, 'Glass Harbor.lrc')).writeAsStringSync('[00:01.00]Una línea inventada\n[00:04.50]Otra línea\n');
    final lyrics = (await readSidecarLrc(song.path))!;
    expect(lyrics.synced, hasLength(2));
    expect(lyrics.synced.first.text, 'Una línea inventada');
  });

  test('Biblioteca grande: 2.000 archivos inventados (con caché la segunda vez)', () async {
    for (var i = 0; i < 2000; i++) {
      final dir = Directory(p.join(music.path, 'Artista ${i % 40}', 'Album ${i % 160}'))..createSync(recursive: true);
      File(p.join(dir.path, '${(i % 12 + 1).toString().padLeft(2, '0')} - Cancion $i.mp3')).writeAsBytesSync(
        fakeMp3(
          title: 'Cancion inventada $i',
          artist: 'Artista ${i % 40}',
          album: 'Album ${i % 160}',
          track: '${i % 12 + 1}',
          cover: i.isEven ? fakePng : null,
        ),
      );
    }
    final store = LocalScanStore(baseDirectory: () async => base);
    final first = await store.scan(roots: [music.path], force: true);
    final cold = store.lastStats!;
    final warm = LocalScanStore(baseDirectory: () async => base);
    await warm.scan(roots: [music.path]);
    final cached = warm.lastStats!;
    // ignore: avoid_print
    print(
      'BIBLIOTECA GRANDE: ${first.length} archivos · primera vez ${cold.elapsed.inMilliseconds} ms '
      '(${cold.read} leídos) · con caché ${cached.elapsed.inMilliseconds} ms (${cached.read} leídos)',
    );
    expect(first, hasLength(2000));
    expect(cached.read, 0);
    expect(cached.elapsed, lessThan(cold.elapsed));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
