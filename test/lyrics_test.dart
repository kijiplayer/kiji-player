import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:kiji_player/features/lyrics/data/lrclib_client.dart';
import 'package:kiji_player/features/lyrics/data/lyrics_sources.dart';
import 'package:kiji_player/features/lyrics/data/lyrics_repository.dart';
import 'package:kiji_player/features/lyrics/domain/lyrics.dart';

const _lrc = '''
[ar:Daft Punk]
[ti:Around the World]
[01:04.07] The sun is warm today
[01:05.5][01:20.123] Repetida
[00:10.00]
''';

/// Servidor LRCLIB de mentira: /api/get responde [exact] (o 404) y
/// /api/search responde [search]. Cuenta los pedidos.
Future<(HttpServer, List<String>)> _fakeLrcLib({
  Map<String, dynamic>? exact,
  List<Map<String, dynamic>> search = const [],
}) async {
  final calls = <String>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    calls.add(request.uri.path);
    final res = request.response..headers.contentType = ContentType.json;
    if (request.uri.path == '/api/get') {
      if (exact == null) {
        res.statusCode = 404;
        res.write(jsonEncode({'code': 404, 'name': 'TrackNotFound'}));
      } else {
        res.write(jsonEncode(exact));
      }
    } else {
      res.write(jsonEncode(search));
    }
    await res.close();
  });
  return (server, calls);
}

LyricsRequest _req({String id = 'yt-a', String? localPath}) => (
      id: id,
      title: 'Around the World',
      artist: 'Daft Punk',
      album: null,
      durationMs: 429000,
      localPath: localPath,
    );

/// MP3 mínimo con letra en una etiqueta USLT (ID3v2.3).
List<int> _mp3WithLyrics(String lyrics) {
  final body = [0, ...ascii.encode('spa'), 0, ...latin1.encode(lyrics)];
  final size = body.length;
  final frame = [
    ...ascii.encode('USLT'),
    (size >> 24) & 0xFF, (size >> 16) & 0xFF, (size >> 8) & 0xFF, size & 0xFF,
    0, 0, ...body,
  ];
  final tagSize = frame.length;
  return [
    ...ascii.encode('ID3'), 3, 0, 0,
    (tagSize >> 21) & 0x7F, (tagSize >> 14) & 0x7F, (tagSize >> 7) & 0x7F, tagSize & 0x7F,
    ...frame,
    for (var i = 0; i < 2; i++) ...[0xFF, 0xFB, 0x90, 0x64, ...List.filled(413, 0)],
  ];
}

void main() {
  group('Formato LRC', () {
    test('Lee tiempos, repite las líneas con varias marcas e ignora los datos', () {
      final lines = parseLrc(_lrc);
      expect(lines, [
        const LyricLine(Duration(seconds: 10), ''),
        const LyricLine(Duration(minutes: 1, seconds: 4, milliseconds: 70), 'The sun is warm today'),
        const LyricLine(Duration(minutes: 1, seconds: 5, milliseconds: 500), 'Repetida'),
        const LyricLine(Duration(minutes: 1, seconds: 20, milliseconds: 123), 'Repetida'),
      ]);
    });

    test('Respeta [offset] (positivo = la letra aparece antes)', () {
      final lines = parseLrc('[offset:+500]\n[00:10.00] Hola');
      expect(lines.single.time, const Duration(seconds: 9, milliseconds: 500));
    });

    test('Texto sin marcas de tiempo no es una letra sincronizada', () {
      expect(parseLrc('Solo texto\nsin tiempos'), isEmpty);
    });

    test('Línea actual: la última que ya empezó', () {
      final lines = parseLrc(_lrc);
      expect(currentLineIndex(lines, const Duration(seconds: 5)), -1);
      expect(currentLineIndex(lines, const Duration(seconds: 10)), 0);
      expect(currentLineIndex(lines, const Duration(minutes: 1, seconds: 5)), 1);
      expect(currentLineIndex(lines, const Duration(minutes: 10)), 3);
      expect(currentLineIndex(const [], Duration.zero), -1);
    });

    test('Una letra se guarda y se lee igual', () {
      final lyrics = Lyrics(synced: parseLrc(_lrc), plain: 'texto', source: LyricsSource.lrclib);
      final restored = Lyrics.fromJson(lyrics.toJson());
      expect(restored.synced, lyrics.synced);
      expect(restored.plain, 'texto');
      expect(restored.source, LyricsSource.lrclib);
    });
  });

  group('LRCLIB', () {
    test('Coincidencia exacta', () async {
      final (server, calls) = await _fakeLrcLib(exact: {'syncedLyrics': _lrc, 'plainLyrics': 'x'});
      addTearDown(server.close);
      final lyrics = await LrcLibClient(baseUrl: 'http://127.0.0.1:${server.port}')
          .fetch(title: 'Around the World', artist: 'Daft Punk', duration: const Duration(seconds: 429));
      expect(lyrics.isSynced, isTrue);
      expect(calls, ['/api/get']);
    });

    test('Sin coincidencia exacta: busca y elige la duración más parecida', () async {
      final (server, calls) = await _fakeLrcLib(search: [
        {'duration': 300.0, 'syncedLyrics': '[00:01.00] Corta'},
        {'duration': 431.0, 'syncedLyrics': '[00:01.00] La buena'},
      ]);
      addTearDown(server.close);
      final lyrics = await LrcLibClient(baseUrl: 'http://127.0.0.1:${server.port}')
          .fetch(title: 'Around the World', artist: 'Daft Punk', duration: const Duration(seconds: 429));
      expect(lyrics.synced.single.text, 'La buena');
      expect(calls, ['/api/get', '/api/search']);
    });

    test('Si no la tiene, "no hay letra"', () async {
      final (server, _) = await _fakeLrcLib();
      addTearDown(server.close);
      final lyrics = await LrcLibClient(baseUrl: 'http://127.0.0.1:${server.port}')
          .fetch(title: 'Nada', artist: 'Nadie');
      expect(lyrics.isEmpty, isTrue);
    });

    test('Sin conexión: avisa (no es lo mismo que "no hay letra")', () async {
      final closed = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = closed.port;
      await closed.close();
      expect(
        LrcLibClient(baseUrl: 'http://127.0.0.1:$port').fetch(title: 'a', artist: 'b'),
        throwsA(isA<LyricsUnavailableException>()),
      );
    });
  });

  group('Caché y letra incluida', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('kiji_letras_'));
    tearDown(() => dir.delete(recursive: true));

    test('Una letra se pide una sola vez', () async {
      final (server, calls) = await _fakeLrcLib(exact: {'syncedLyrics': _lrc});
      addTearDown(server.close);
      final repo = LyricsRepository(
        fetchers: [LrcLibFetcher(LrcLibClient(baseUrl: 'http://127.0.0.1:${server.port}'))],
        baseDirectory: () async => dir,
      );
      await repo.get(_req());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final again = await repo.get(_req());
      expect(again.isSynced, isTrue);
      expect(calls, hasLength(1));
    });

    test('"No encontrada" se vuelve a preguntar después de 7 días', () async {
      final (server, calls) = await _fakeLrcLib();
      addTearDown(server.close);
      var now = DateTime(2026, 10, 16);
      final repo = LyricsRepository(
        fetchers: [LrcLibFetcher(LrcLibClient(baseUrl: 'http://127.0.0.1:${server.port}'))],
        baseDirectory: () async => dir,
        clock: () => now,
      );
      await repo.get(_req());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await repo.get(_req());
      expect(calls.where((c) => c == '/api/get'), hasLength(1), reason: 'dentro de los 7 días');

      now = now.add(const Duration(days: 8));
      await repo.get(_req());
      expect(calls.where((c) => c == '/api/get'), hasLength(2));
    });

    test('Canción local con la letra adentro: no sale a internet', () async {
      final song = File(p.join(dir.path, 'tema.mp3'))
        ..writeAsBytesSync(_mp3WithLyrics('[00:01.00] Letra incluida'));
      final (server, calls) = await _fakeLrcLib(exact: {'syncedLyrics': _lrc});
      addTearDown(server.close);
      final repo = LyricsRepository(
        fetchers: [LrcLibFetcher(LrcLibClient(baseUrl: 'http://127.0.0.1:${server.port}'))],
        baseDirectory: () async => dir,
      );
      final lyrics = await repo.get(_req(id: 'local-1', localPath: song.path));
      expect(lyrics.source, LyricsSource.embedded);
      expect(lyrics.synced.single.text, 'Letra incluida');
      expect(calls, isEmpty);
    });
  });
}
