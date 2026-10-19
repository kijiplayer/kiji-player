import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:kiji_player/features/downloads/data/download_service.dart';
import 'package:kiji_player/features/downloads/data/downloads_repository.dart';
import 'package:kiji_player/features/downloads/domain/download_settings.dart';
import 'package:kiji_player/features/downloads/domain/downloaded_track.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/utils/byte_formatter.dart';

DownloadedTrack _entry(String videoId, {int size = 100}) => DownloadedTrack(
      videoId: videoId,
      title: 'Canción $videoId',
      artist: 'Artista',
      coverColor: const Color(0xFF7C5CFF),
      fileName: '$videoId.m4a',
      sizeBytes: size,
      downloadedAt: DateTime(2026, 10, 15),
    );

/// Servidor HTTP local que sirve [body] respetando el header Range, como
/// googlevideo. Si [forbidden] es true responde 403 (URL vencida).
Future<HttpServer> _serve(Uint8List body, {bool Function()? forbidden}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final response = request.response;
    if (forbidden?.call() ?? false) {
      response.statusCode = 403;
      await response.close();
      return;
    }
    final match = RegExp(r'bytes=(\d+)-(\d+)?').firstMatch(request.headers.value('range') ?? '');
    if (match == null) {
      response.add(body);
      await response.close();
      return;
    }
    final start = int.parse(match.group(1)!);
    if (start >= body.length) {
      response.statusCode = 416;
      await response.close();
      return;
    }
    final end = (int.tryParse(match.group(2) ?? '') ?? body.length - 1).clamp(0, body.length - 1);
    response.statusCode = 206;
    response.headers.set('content-range', 'bytes $start-$end/${body.length}');
    response.add(body.sublist(start, end + 1));
    await response.close();
  });
  return server;
}

void main() {
  late Directory dir;
  late DownloadsRepository repository;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kiji_descargas_');
    repository = DownloadsRepository(baseDirectory: () async => dir);
  });

  tearDown(() => dir.delete(recursive: true));

  group('DownloadsRepository', () {
    test('Agrega, encuentra el archivo y lo borra', () async {
      await File(await repository.pathFor('abc.m4a')).writeAsString('audio');
      await repository.add(_entry('abc'));

      expect(await repository.fileFor('abc'), isNotNull);
      expect(await repository.totalBytes(), 100);

      await repository.remove('abc');
      expect(await repository.fileFor('abc'), isNull);
      expect(File(await repository.pathFor('abc.m4a')).existsSync(), isFalse);
    });

    test('El índice sobrevive a reabrir la app', () async {
      await File(await repository.pathFor('abc.m4a')).writeAsString('audio');
      await repository.add(_entry('abc'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final reopened = DownloadsRepository(baseDirectory: () async => dir);
      expect((await reopened.all()).keys, ['abc']);
    });

    test('Si el archivo de audio desapareció, la descarga no figura', () async {
      await repository.add(_entry('borrada'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final reopened = DownloadsRepository(baseDirectory: () async => dir);
      expect(await reopened.all(), isEmpty);
    });

    test('Las descargas viejas quedan con el artista limpio', () async {
      await File(await repository.pathFor('abc.m4a')).writeAsString('audio');
      final dirty = DownloadedTrack(
        videoId: 'abc',
        title: 'One More Time',
        artist: 'Canción • Daft Punk',
        coverColor: const Color(0xFF7C5CFF),
        fileName: 'abc.m4a',
        sizeBytes: 5,
        downloadedAt: DateTime(2026, 10, 15),
      );
      final indexFile = File(p.join(dir.path, 'downloads', 'index.json'));
      await indexFile.writeAsString(
        '{"version":1,"tracks":[${jsonEncode(dirty.toJson())}]}',
      );

      expect((await repository.all())['abc']!.artist, 'Daft Punk');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(await indexFile.readAsString(), isNot(contains('Canción')));
    });

    test('Índice dañado: se borra y arranca vacío', () async {
      final indexFile = File(p.join(dir.path, 'downloads', 'index.json'));
      await indexFile.parent.create(recursive: true);
      await indexFile.writeAsString('{"tracks": [');

      expect(await repository.all(), isEmpty);
      expect(indexFile.existsSync(), isFalse);
    });

    test('Las preferencias se guardan (por defecto: solo WiFi, sin límite)', () async {
      expect((await repository.loadSettings()).wifiOnly, isTrue);
      expect((await repository.loadSettings()).limitBytes, isNull);

      await repository.saveSettings(const DownloadSettings(wifiOnly: false, limitBytes: 1024));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final reopened = DownloadsRepository(baseDirectory: () async => dir);
      final settings = await reopened.loadSettings();
      expect(settings.wifiOnly, isFalse);
      expect(settings.limitBytes, 1024);
    });
  });

  group('DownloadService', () {
    // 9 MiB: obliga a bajar en 3 partes de 4 MiB.
    final body = Uint8List.fromList(List.generate(9 * 1024 * 1024, (i) => i % 251));

    test('Baja por partes, informa el progreso y deja el archivo completo', () async {
      final server = await _serve(body);
      addTearDown(server.close);
      final service = DownloadService(repository, dio: Dio());
      final progress = <int>[];

      final (fileName, size) = await service.download(
        'vid',
        DownloadEstimate(
          url: 'http://127.0.0.1:${server.port}/audio',
          extension: 'm4a',
          sizeBytes: body.length,
        ),
        cancelToken: CancelToken(),
        onProgress: (received, _) => progress.add(received),
      );

      expect(fileName, 'vid.m4a');
      expect(size, body.length);
      expect(progress.length, 3);
      expect(await File(await repository.pathFor(fileName)).readAsBytes(), body);
      expect(File('${await repository.pathFor(fileName)}.part').existsSync(), isFalse);
    });

    test('Reanuda desde el .part sin volver a bajar lo que ya tenía', () async {
      final server = await _serve(body);
      addTearDown(server.close);
      final part = File('${await repository.pathFor('vid.m4a')}.part');
      await part.writeAsBytes(body.sublist(0, 5 * 1024 * 1024));
      final progress = <int>[];

      await DownloadService(repository, dio: Dio()).download(
        'vid',
        DownloadEstimate(
          url: 'http://127.0.0.1:${server.port}/audio',
          extension: 'm4a',
          sizeBytes: body.length,
        ),
        cancelToken: CancelToken(),
        onProgress: (received, _) => progress.add(received),
      );

      expect(progress, [body.length]); // una sola parte: los 4 MiB que faltaban
      expect(await File(await repository.pathFor('vid.m4a')).readAsBytes(), body);
    });

    test('Un .part de otro archivo (otra forma, otro tamaño) no se mezcla: empieza de cero', () async {
      final server = await _serve(body);
      addTearDown(server.close);
      final path = await repository.pathFor('vid.m4a');
      await File('$path.part').writeAsBytes(List.filled(1000, 7));
      await File('$path.part.size').writeAsString('${body.length + 999}');

      await DownloadService(repository, dio: Dio()).download(
        'vid',
        DownloadEstimate(url: 'http://127.0.0.1:${server.port}/audio', extension: 'm4a', sizeBytes: body.length),
        cancelToken: CancelToken(),
        onProgress: (_, _) {},
      );

      expect(await File(path).readAsBytes(), body);
      expect(File('$path.part.size').existsSync(), isFalse);
    });

    test('Una URL vencida (403) se informa para pedir otra', () async {
      final server = await _serve(body, forbidden: () => true);
      addTearDown(server.close);

      expect(
        DownloadService(repository, dio: Dio()).download(
          'vid',
          DownloadEstimate(
            url: 'http://127.0.0.1:${server.port}/audio',
            extension: 'm4a',
            sizeBytes: body.length,
          ),
          cancelToken: CancelToken(),
          onProgress: (_, _) {},
        ),
        throwsA(isA<ExpiredUrlException>()),
      );
    });
  });

  test('Una descarga se vuelve pista de YouTube (así borrarla no la saca de la cola)', () {
    final track = _entry('abc').toTrack();
    expect(track.source, TrackSource.youtube);
    expect(track.youtubeVideoId, 'abc');
    expect(track.audioUrl, isEmpty);
  });

  test('formatBytes', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(4404019), '4,2 MB');
    expect(formatBytes(1610612736), '1,5 GB');
  });
}
