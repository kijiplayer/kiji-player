import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/customize/data/artwork_cache.dart';
import 'package:kiji_player/features/system_media/data/cover_art.dart';
import 'package:kiji_player/models/track.dart';

/// Servidor de mentira: anota qué URL se pidieron y devuelve unos bytes cualquiera.
class _FakeServer implements HttpClientAdapter {
  final requested = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requested.add(options.uri.toString());
    return ResponseBody.fromBytes([1, 2, 3], 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('Listas: la miniatura de la búsqueda se pide a 544 px', () {
    expect(
      largerThumbnailUrl('https://lh3.googleusercontent.com/abc=w60-h60-l90-rj'),
      'https://lh3.googleusercontent.com/abc=w544-h544-l90-rj',
    );
    // Las de i.ytimg.com no tienen tamaño en la URL: quedan igual.
    expect(
      largerThumbnailUrl('https://i.ytimg.com/vi/abc/hqdefault.jpg'),
      'https://i.ytimg.com/vi/abc/hqdefault.jpg',
    );
  });

  test('Alta calidad: notificación, bloqueo y Windows a 1200 px; el reproductor, al tamaño en pantalla', () {
    const song = 'https://yt3.googleusercontent.com/abc=w120-h120-l90-rj';
    expect(fullThumbnailUrl(song), 'https://yt3.googleusercontent.com/abc=w1200-h1200-l90-rj');
    expect(fullThumbnailUrl('https://yt3.ggpht.com/xyz=s120'), 'https://yt3.ggpht.com/xyz=w1200-h1200');
    expect(thumbnailUrlForPixels(song, 88), contains('=w544-h544'));
    expect(thumbnailUrlForPixels(song, 900), contains('=w1200-h1200'));
    expect(thumbnailUrlForPixels(song, 1600), contains('=w2048-h2048'));
    // Una URL de otro sitio con "=s" no se toca.
    expect(fullThumbnailUrl('https://example.com/a?b=s120'), 'https://example.com/a?b=s120');
  });

  test('La portada de la notificación y de Windows es la de alta calidad', () async {
    const track = Track(
      id: 'yt:inventado',
      title: 'Canción Inventada',
      artist: 'Grupo Inventado',
      coverColor: Colors.teal,
      audioUrl: '',
      source: TrackSource.youtube,
      thumbnailUrl: 'https://lh3.googleusercontent.com/abc=w120-h120-l90-rj',
    );
    expect((await coverArtFor(track)).toString(), 'https://lh3.googleusercontent.com/abc=w1200-h1200-l90-rj');
  });

  test('La caché de carátulas guarda la de alta calidad, no la chica de la URL', () async {
    final dir = Directory.systemTemp.createTempSync('kiji_caratulas_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final server = _FakeServer();
    final cache = ArtworkCache(directory: () async => dir, dio: Dio()..httpClientAdapter = server);
    const url = 'https://lh3.googleusercontent.com/abc=w120-h120-l90-rj';

    expect(await cache.download([url]), 1);
    expect(server.requested, ['https://lh3.googleusercontent.com/abc=w1200-h1200-l90-rj']);
    final saved = File('${(await cache.folder()).path}/${artworkCacheName(fullThumbnailUrl(url))}');
    expect(saved.existsSync(), isTrue);

    // Ya guardada: no se vuelve a bajar.
    expect(await cache.download([url]), 0);
  });
}
