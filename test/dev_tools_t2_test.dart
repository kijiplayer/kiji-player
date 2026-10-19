import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/dev_tools/dev_build.dart';
import 'package:kiji_player/features/extractor/data/engines.dart';
import 'package:kiji_player/features/extractor/data/extractor_trace.dart';
import 'package:kiji_player/features/extractor/data/path_health.dart';
import 'package:kiji_player/features/extractor/data/stream_resolver.dart';
import 'package:kiji_player/features/extractor/domain/extraction_failure.dart';
import 'package:kiji_player/features/extractor/domain/resolved_stream.dart';
import 'package:kiji_player/utils/app_log.dart';

class _FakeEngine extends ExtractionEngine {
  _FakeEngine(this.id, this.answer);
  @override
  final EngineId id;
  final EngineResult Function() answer;

  @override
  bool get isSupported => true;

  @override
  Future<EngineResult> resolve(String videoId, {bool lowQuality = false, Set<String> skip = const {}, List<String>? order}) async =>
      answer();
}

void main() {
  group('Registro en memoria (T2)', () {
    setUp(AppLog.clear);

    test('debugPrint queda en el registro y se ve en vivo', () async {
      AppLog.install();
      final live = <String>[];
      final sub = AppLog.stream.listen((l) => live.add(l.text));
      debugPrint('=== PRUEBA: hola ===');
      await Future<void>.delayed(Duration.zero);
      expect(AppLog.lines.last.text, 'PRUEBA: hola', reason: 'sin los ===');
      expect(live, ['PRUEBA: hola']);
      await sub.cancel();
    });

    test('Se queda solo con las últimas líneas', () {
      for (var i = 0; i < AppLog.capacity + 50; i++) {
        AppLog.add('línea $i');
      }
      expect(AppLog.lines.length, AppLog.capacity);
      expect(AppLog.lines.first.text, 'línea 50');
    });
  });

  group('Rastro del extractor (T2)', () {
    late Directory dir;
    final trace = ExtractorTrace.instance;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('kiji_t2');
      trace.clear();
    });
    tearDown(() async {
      // La Salud guarda sin esperar: en Windows la carpeta puede estar en uso un momento.
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        try {
          dir.deleteSync(recursive: true);
          return;
        } on FileSystemException {
          continue;
        }
      }
    });

    test('Cada búsqueda queda anotada con el camino ganador y las fallas de antes', () async {
      final health = PathHealth(directory: () async => dir.path);
      final a = _FakeEngine(EngineId.a, () => EngineResult.failed([('AUTO', classifyFailure('HTTP 403'))]));
      final b = _FakeEngine(
          EngineId.b,
          () => EngineResult.ok(
              const ResolvedStream(videoId: 'abcdefghijk', url: 'https://g/1', engine: EngineId.b, form: 'VISIONOS')));
      await StreamResolver(engines: [a, b], health: health).resolve('abcdefghijk');
      final entry = trace.entries.first;
      expect(entry.ok, isTrue);
      expect(entry.videoId, 'abcdefghijk');
      expect(entry.result, contains('B/VISIONOS'));
      expect(entry.failures.single.$1, 'A/AUTO');
    });

    test('Guarda como mucho las últimas 40, la más nueva primero', () {
      for (var i = 0; i < 45; i++) {
        trace.add(TraceEntry(at: DateTime(2026), videoId: 'v$i', elapsed: Duration.zero, result: 'falló'));
      }
      expect(trace.entries.length, ExtractorTrace.capacity);
      expect(trace.entries.first.videoId, 'v44');
    });
  });

  test('Sin --flavor dev (como Kiji normal) las herramientas no existen', () {
    expect(isDevBuild, isFalse);
  });
}
