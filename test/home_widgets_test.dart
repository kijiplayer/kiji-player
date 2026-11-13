import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:kiji_player/features/customize/data/artwork_cache.dart';
import 'package:kiji_player/features/lyrics/domain/lyrics.dart';
import 'package:kiji_player/features/system_media/data/cover_art.dart';
import 'package:kiji_player/features/system_media/data/home_widgets.dart';
import 'package:kiji_player/theme/kiji_tokens.dart';
import 'package:kiji_player/models/track.dart';

void main() {
  late Directory support;
  setUp(() => support = Directory.systemTemp.createTempSync('kiji_widget_'));
  tearDown(() => support.deleteSync(recursive: true));

  File touch(String path) => File(path)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync([1]);

  test('El widget recibe una portada que ya está en el dispositivo (nunca baja nada)', () async {
    // Local con portada incluida.
    const local = Track(
      id: 'local-1',
      title: 'Glass Harbor',
      artist: 'The Velvet Tides',
      coverColor: Color(0xFF3A6EA5),
      audioUrl: '/m/glass.mp3',
      source: TrackSource.local,
    );
    expect(await localCoverPath(local, support: support), isNull, reason: 'sin portada: el ícono de Kiji');
    final embedded = touch(p.join(support.path, 'artwork', artworkCacheName(ArtworkCache.fileKey('/m/glass.mp3'))));
    expect(await localCoverPath(local, support: support), embedded.path);

    // De YouTube: la de la descarga o la guardada en la caché (en alta calidad).
    const url = 'https://lh3.googleusercontent.com/inventada=w120-h120';
    const yt = Track(
      id: 'yt-aaaaaaaaaaa',
      title: 'Slow Comet',
      artist: 'Aurelio Fen',
      coverColor: Color(0xFF3A6EA5),
      audioUrl: '',
      source: TrackSource.youtube,
      thumbnailUrl: url,
    );
    expect(await localCoverPath(yt, support: support), isNull);
    final cached = touch(p.join(support.path, 'artwork', artworkCacheName(fullThumbnailUrl(url))));
    expect(await localCoverPath(yt, support: support), cached.path);
    final thumb = touch(p.join(support.path, 'descargas', 'aaaaaaaaaaa.jpg'));
    expect(
      await localCoverPath(yt, support: support, downloadsDir: p.join(support.path, 'descargas'), downloadThumb: 'aaaaaaaaaaa.jpg'),
      thumb.path,
      reason: 'la de la descarga primero',
    );
    // La foto elegida (para la canción o su álbum) gana a todas.
    final chosen = touch(p.join(support.path, 'covers', 'elegida.jpg'));
    expect(
      await localCoverPath(yt, support: support, downloadsDir: p.join(support.path, 'descargas'), downloadThumb: 'aaaaaaaaaaa.jpg', preferred: [chosen.path]),
      chosen.path,
    );
    expect(
      await localCoverPath(yt, support: support, preferred: [p.join(support.path, 'covers', 'borrada.jpg')]),
      cached.path,
      reason: 'una elegida que ya no está no cuenta',
    );
  });

  test('Notificación: con portada guardada usa el archivo (sin internet); sin ella, la de internet', () async {
    const yt = Track(
      id: 'yt-bbbbbbbbbbb',
      title: 'Slow Comet',
      artist: 'Aurelio Fen',
      coverColor: Color(0xFF3A6EA5),
      audioUrl: '',
      source: TrackSource.youtube,
      thumbnailUrl: 'https://lh3.googleusercontent.com/inventada=w120-h120',
    );
    final file = touch(p.join(support.path, 'descargas', 'bbbbbbbbbbb.hq.jpg'));
    expect(await coverArtFor(yt, deviceCover: file.path), Uri.file(file.path));
    expect((await coverArtFor(yt))!.scheme, 'https');
  });

  test('El widget recibe el estado y los colores del estilo (y la misma onda del reproductor)', () {
    const track = Track(
      id: 'yt-ccccccccccc',
      title: 'Glass Harbor',
      artist: 'The Velvet Tides',
      coverColor: Color(0xFF3A6EA5),
      audioUrl: '',
      source: TrackSource.youtube,
    );
    addTearDown(() {
      KijiLook.style = KijiStyle.nocturne;
      KijiColors.palette = KijiPalette.nocturne;
    });
    for (final style in KijiStyle.values) {
      KijiLook.style = style;
      KijiColors.palette = KijiPalette.forStyle(style);
      final p = widgetPayload(
        track: track,
        playing: true,
        position: const Duration(seconds: 30),
        duration: const Duration(minutes: 2),
        cover: '/x/portada.jpg',
        liked: true,
        theater: false,
        lyric: null,
      );
      expect(p['style'], style.name);
      expect(p['progress'], 250);
      expect(p['accent'], KijiColors.palette.violet.toARGB32());
      expect(p['text'], KijiColors.palette.text.toARGB32());
      expect(p['light'], KijiColors.palette.isLight);
      expect(p['bars'], hasLength(widgetBars));
      expect((p['bars']! as List).every((b) => b is int && b >= 0 && b <= 100), isTrue);
      expect((p['liked'], p['theater']), (true, false));
    }
    expect(widgetPayload(track: null, playing: false, position: Duration.zero, duration: Duration.zero, cover: null, liked: false, theater: true, lyric: null)['progress'], 0);
  });

  test('La línea de la letra que suena (solo con letra sincronizada)', () {
    final lyrics = Lyrics(synced: parseLrc('[00:02.00]Primera inventada\n[00:06.00]Segunda inventada'));
    expect(lyricLineAt(lyrics, const Duration(seconds: 1)), isNull);
    expect(lyricLineAt(lyrics, const Duration(seconds: 3)), 'Primera inventada');
    expect(lyricLineAt(lyrics, const Duration(seconds: 7)), 'Segunda inventada');
    expect(lyricLineAt(const Lyrics(plain: 'Sin tiempos inventada'), const Duration(seconds: 3)), isNull);
    expect(lyricLineAt(null, Duration.zero), isNull);
  });

  test('La letra del widget cambia línea por línea: cuánto falta para la siguiente', () {
    final lyrics = Lyrics(synced: parseLrc('[00:02.00]Primera inventada\n[00:06.00]Segunda inventada'));
    expect(untilNextLine(lyrics, const Duration(seconds: 3)), const Duration(seconds: 3));
    expect(untilNextLine(lyrics, Duration.zero), const Duration(seconds: 2));
    expect(untilNextLine(lyrics, const Duration(seconds: 7)), isNull, reason: 'la última: no hay más');
    expect(untilNextLine(const Lyrics(plain: 'Sin tiempos inventada'), Duration.zero), isNull);
  });

  test('El widget Teatro recibe lo de hoy y los colores del telón', () {
    final p = widgetPayload(
      track: null,
      playing: false,
      position: Duration.zero,
      duration: Duration.zero,
      cover: null,
      liked: false,
      theater: true,
      lyric: null,
      tomatoesToday: 4,
      rosesToday: 7,
    );
    expect((p['tomatoesToday'], p['rosesToday']), (4, 7));
    expect(p['curtain'], KijiColors.theaterCurtain.toARGB32());
    expect(p['gold'], KijiColors.theaterGold.toARGB32());
  });
}
