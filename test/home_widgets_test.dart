import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:kiji_player/features/customize/data/artwork_cache.dart';
import 'package:kiji_player/features/system_media/data/cover_art.dart';
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
}
