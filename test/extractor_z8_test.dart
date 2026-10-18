import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/extractor/data/engines.dart';
import 'package:kiji_player/features/extractor/data/path_health.dart';
import 'package:kiji_player/features/extractor/data/stream_resolver.dart';
import 'package:kiji_player/features/extractor/domain/extraction_failure.dart';
import 'package:kiji_player/features/extractor/domain/resolved_stream.dart';
import 'package:kiji_player/features/stream_cache/data/chunked_source.dart';

class _FakeEngine extends ExtractionEngine {
  _FakeEngine(this.id, this.answer);
  @override
  final EngineId id;
  final EngineResult Function(Set<String> skip) answer;
  int calls = 0;

  @override
  bool get isSupported => true;

  @override
  Future<EngineResult> resolve(String videoId, {bool lowQuality = false, Set<String> skip = const {}, List<String>? order}) async {
    calls++;
    return answer(skip);
  }
}

ResolvedStream _stream(EngineId engine, String form, {String url = 'https://g/1', int? length, int? chunk}) =>
    ResolvedStream(videoId: 'abcdefghijk', url: url, engine: engine, form: form, contentLength: length, chunkSize: chunk);

/// googlevideo falso: entrega bytes 0..n-1 por rangos; la URL "mala" responde 403.
class _FakeGoogleVideo extends Interceptor {
  _FakeGoogleVideo(this.size, {this.badUrl});
  final int size;
  final String? badUrl;
  final requests = <String>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final range = '${options.headers['Range']}';
    requests.add('${options.uri} $range');
    if (options.uri.toString() == badUrl) {
      handler.resolve(Response(requestOptions: options, statusCode: 403, data: <int>[]));
      return;
    }
    final m = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(range)!;
    final from = int.parse(m.group(1)!), to = int.parse(m.group(2)!).clamp(0, size - 1);
    handler.resolve(Response(
      requestOptions: options,
      statusCode: 206,
      data: [for (var i = from; i <= to; i++) i % 256],
      headers: Headers.fromMap({'content-range': ['bytes $from-$to/$size']}),
    ));
  }
}

void main() {
  group('Clasificación (la clave del "1 de 11")', () {
    test('Restricción de edad, en inglés y en español: es de la canción y alcanza con una forma', () {
      for (final text in [
        'LOGIN_REQUIRED: Sign in to confirm your age',
        'Este video puede ser inadecuado para algunos usuarios',
        'Confirma tu edad',
      ]) {
        final f = classifyFailure(text);
        expect(f.scope, FailureScope.content, reason: text);
        expect(f.problem, ContentProblem.ageRestricted, reason: text);
        expect(f.isConclusive, isTrue);
      }
    });

    test('El control anti-bot es de la forma, aunque diga "Sign in"', () {
      expect(classifyFailure("LOGIN_REQUIRED: Sign in to confirm you're not a bot").scope, FailureScope.form);
      expect(classifyFailure('Confirma que no eres un bot').scope, FailureScope.form);
    });

    test('Fallas de la forma', () {
      for (final text in [
        'YouTube solo deja bajar el primer minuto (HTTP 403 al final del archivo)',
        'No se pudo descifrar la firma: sin respuesta',
        'El audio no responde (HTTP 403)',
        'Solo ofrece SABR',
      ]) {
        expect(classifyFailure(text).scope, FailureScope.form, reason: text);
      }
    });

    test('Privado, borrado, bloqueado en el país y no disponible', () {
      expect(classifyFailure('This video is private').problem, ContentProblem.private);
      expect(classifyFailure('This video has been removed by the uploader').problem, ContentProblem.removed);
      expect(classifyFailure('The uploader has not made this video available in your country').problem, ContentProblem.regionBlocked);
      expect(classifyFailure('Video unavailable').problem, ContentProblem.unavailable);
      expect(classifyFailure('Este video no está disponible').problem, ContentProblem.unavailable);
    });

    test('"No disponible" de una sola forma no alcanza; de dos, sí', () {
      final one = [classifyFailure('Video unavailable'), classifyFailure('HTTP 403')];
      expect(contentVerdict(one), isNull, reason: 'WEB_REMIX sin PO token dice "unavailable" de todo');
      final two = [classifyFailure('Video unavailable'), classifyFailure('This video is unavailable')];
      expect(contentVerdict(two), ContentProblem.unavailable);
    });
  });

  group('Motor A (respuesta del canal)', () {
    test('Audio encontrado', () {
      final r = innerTubeXResult('abcdefghijk', {
        'url': 'https://rr1---sn.googlevideo.com/videoplayback?x',
        'headers': {'User-Agent': 'UA'},
        'mime': 'audio/webm; codecs="opus"',
        'kbps': 160,
        'client': 'WEB_REMIX',
        'profileId': 'WEB_REMIX',
        'contentLength': 4000000,
        'chunkSize': 1048576,
        'isHls': false,
      });
      expect(r.ok, isTrue);
      expect(r.stream!.path, 'A/WEB_REMIX');
      expect(r.stream!.chunkSize, 1048576);
      expect(r.stream!.extension, 'webm');
      expect('${r.stream}', isNot(contains('googlevideo')), reason: 'nunca la URL firmada en los registros');
    });

    test('Edad y no disponible: confirmados por InnerTubeX', () {
      final age = innerTubeXResult('x', {'error': 'content', 'reason': 'age_restricted'});
      expect(age.failures.single.$2.problem, ContentProblem.ageRestricted);
      final na = innerTubeXResult('x', {'error': 'content', 'reason': 'unavailable'});
      expect(na.failures.single.$2.isConclusive, isTrue);
      final form = innerTubeXResult('x', {'error': 'form', 'reason': 'no_stream', 'message': 'nada'});
      expect(form.failures.single.$2.scope, FailureScope.form);
    });
  });

  group('Orquestador y salud', () {
    late Directory dir;
    late PathHealth health;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('kiji_z8');
      health = PathHealth(directory: () async => dir.path);
    });
    tearDown(() async {
      // Las escrituras van en segundo plano; Windows no deja borrar mientras siguen.
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        try {
          dir.deleteSync(recursive: true);
          return;
        } on FileSystemException {
          continue;
        }
      }
    });

    test('A falla por la forma → B lo encuentra; la falla de A cuenta, el éxito de B también', () async {
      final a = _FakeEngine(EngineId.a, (_) => EngineResult.failed([('AUTO', classifyFailure('HTTP 403'))]));
      final b = _FakeEngine(EngineId.b, (_) => EngineResult.ok(_stream(EngineId.b, 'VISIONOS')));
      final resolver = StreamResolver(engines: [a, b], health: health);
      final out = await resolver.resolve('abcdefghijk');
      expect(out.stream?.path, 'B/VISIONOS');
      expect(health['A/AUTO']!.fail, 1);
      expect(health['B/VISIONOS']!.ok, 1);
    });

    test('Restricción de edad: se marca la canción y NINGUNA forma queda como rota', () async {
      final a = _FakeEngine(EngineId.a, (_) => EngineResult.failed([('AUTO', classifyFailure('Sign in to confirm your age'))]));
      final b = _FakeEngine(EngineId.b, (_) => EngineResult.failed([('WEB_REMIX', classifyFailure('confirm your age'))]));
      final resolver = StreamResolver(engines: [a, b], health: health);
      final out = await resolver.resolve('abcdefghijk');
      expect(out.problem, ContentProblem.ageRestricted);
      expect(b.calls, 0, reason: 'A ya lo confirmó: no hace falta seguir probando');
      expect(health.all, isEmpty, reason: 'las fallas de contenido no se anotan');
    });

    test('Caminos ya fallados se saltean (por motor)', () async {
      Set<String>? seen;
      final b = _FakeEngine(EngineId.b, (skip) {
        seen = skip;
        return EngineResult.ok(_stream(EngineId.b, 'TVHTML5'));
      });
      final a = _FakeEngine(EngineId.a, (_) => throw StateError('no debería llamarse'));
      final resolver = StreamResolver(engines: [a, b], health: health);
      await resolver.resolve('abcdefghijk', skipPaths: {'A/AUTO', 'B/VISIONOS'});
      expect(a.calls, 0);
      expect(seen, {'VISIONOS'});
    });

    test('El orden se ajusta solo según los éxitos recientes', () {
      for (var i = 0; i < 5; i++) {
        health.recordFormFailure('B/VISIONOS', '403');
        health.recordSuccess('B/TVHTML5');
      }
      expect(health.order('B', ['VISIONOS', 'WEB_REMIX', 'TVHTML5']), ['TVHTML5', 'WEB_REMIX', 'VISIONOS']);
    });
  });

  group('Fuente por pedazos', () {
    test('Pide por rangos acotados y, si rechazan la URL a mitad, sigue desde el mismo byte con otra', () async {
      const size = 2500;
      final google = _FakeGoogleVideo(size, badUrl: 'https://g/vieja');
      final dio = Dio()..interceptors.add(google);
      var refreshed = 0;
      final source = ChunkedYtSource(
        stream: _stream(EngineId.b, 'WEB_REMIX', url: 'https://g/buena', length: size, chunk: 1000),
        dio: dio,
        refresh: (refused) async {
          refreshed++;
          return _stream(EngineId.b, 'TVHTML5', url: 'https://g/otra', length: size, chunk: 1000);
        },
      );
      final first = await source.fetchChunk(0, 999);
      expect(first.length, 1000);
      // La URL vence: la siguiente pasa a ser la "vieja" y YouTube la rechaza.
      final broken = ChunkedYtSource(
        stream: _stream(EngineId.b, 'WEB_REMIX', url: 'https://g/vieja', length: size, chunk: 1000),
        dio: dio,
        refresh: (refused) async {
          refreshed++;
          return _stream(EngineId.b, 'TVHTML5', url: 'https://g/otra', length: size, chunk: 1000);
        },
      );
      final middle = await broken.fetchChunk(1000, 1999);
      expect(middle.first, 1000 % 256, reason: 'sigue desde el mismo byte');
      expect(refreshed, 1);
      expect(broken.current.form, 'TVHTML5');
      expect(google.requests.where((r) => r.contains('bytes=1000-1999')).length, 2);
    });

    test('Lee el archivo entero en pedazos y lo guarda en la caché', () async {
      const size = 2500;
      final dir = Directory.systemTemp.createTempSync('kiji_chunk');
      addTearDown(() => dir.deleteSync(recursive: true));
      final google = _FakeGoogleVideo(size);
      final file = File('${dir.path}/abcdefghijk.m4a');
      final source = ChunkedYtSource(
        stream: _stream(EngineId.b, 'VISIONOS', url: 'https://g/1', length: size, chunk: 1000),
        dio: Dio()..interceptors.add(google),
        cacheFile: file,
        refresh: (_) async => null,
      );
      final response = await source.request();
      final bytes = [for (final part in await response.stream.toList()) ...part];
      expect(bytes.length, size);
      expect(google.requests.length, 3, reason: '3 pedazos de 1000 como máximo');
      for (var i = 0; i < 20 && !file.existsSync(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(file.lengthSync(), size);
    });
  });
}
