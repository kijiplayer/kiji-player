import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:kiji_player/features/stream_cache/data/stream_cache.dart';
import 'package:kiji_player/features/yt_music/data/extractor_health.dart';
import 'package:kiji_player/features/yt_music/presentation/extractor_health_screen.dart';

void main() {
  group('Salud del Extractor', () {
    setUp(() => ExtractorHealth.instance.resetForTest());

    test('Un cliente funciona si su último resultado fue un éxito', () {
      final health = ExtractorHealth.instance;
      expect(health.all['VISIONOS']!.neverUsed, isTrue);

      health.recordFailure('VISIONOS', 'YouTube rechazó el pedido');
      expect(health.all['VISIONOS']!.working, isFalse);

      health.recordSuccess('VISIONOS');
      expect(health.all['VISIONOS']!.working, isTrue);
      // Conserva el motivo de la falla anterior para mostrarlo si vuelve a fallar.
      expect(health.all['VISIONOS']!.lastFailureReason, 'YouTube rechazó el pedido');
    });

    test('Se describe en palabras simples', () {
      final now = DateTime(2026, 10, 15, 20);
      expect(describeHealth(const ClientHealth(), now), 'Sin usar todavía');
      expect(
        describeHealth(ClientHealth(lastSuccess: now.subtract(const Duration(minutes: 5))), now),
        'Funcionando (hace 5 min)',
      );
      expect(
        describeHealth(
          ClientHealth(
            lastFailure: now.subtract(const Duration(hours: 2)),
            lastFailureReason: 'Se cortó durante la reproducción',
          ),
          now,
        ),
        'Falló hace 2 h: Se cortó durante la reproducción',
      );
    });

    test('ClientHealth sobrevive a guardarse y leerse', () {
      final original = ClientHealth(
        lastSuccess: DateTime(2026, 10, 15, 10),
        lastFailure: DateTime(2026, 10, 15, 9),
        lastFailureReason: 'sin audio',
      );
      final restored = ClientHealth.fromJson(original.toJson());
      expect(restored.lastSuccess, original.lastSuccess);
      expect(restored.lastFailureReason, 'sin audio');
      expect(restored.working, isTrue);
    });
  });

  group('Caché de streaming', () {
    late Directory base;
    late StreamCache cache;

    setUp(() async {
      base = await Directory.systemTemp.createTemp('kiji_cache_');
      cache = StreamCache(baseDirectory: () async => base);
    });

    tearDown(() => base.delete(recursive: true));

    Future<File> write(String name, int bytes, DateTime modified) async {
      final file = File(p.join((await cache.directory()).path, name));
      await file.writeAsBytes(List.filled(bytes, 1));
      await file.setLastModified(modified);
      return file;
    }

    test('Solo cuenta como guardada la canción que terminó de bajar', () async {
      await write('abc.webm.part', 10, DateTime(2026));
      expect(await cache.completeFile('abc'), isNull);

      await write('abc.webm', 10, DateTime(2026));
      expect(await cache.completeFile('abc'), isNotNull);
    });

    test('Al pasarse del límite borra primero lo menos usado', () async {
      final viejo = await write('viejo.m4a', 400, DateTime(2026, 1, 1));
      final medio = await write('medio.m4a', 400, DateTime(2026, 6, 1));
      final nuevo = await write('nuevo.m4a', 400, DateTime(2026, 10, 1));

      await cache.evict(limitBytes: 900);

      expect(viejo.existsSync(), isFalse);
      expect(medio.existsSync(), isTrue);
      expect(nuevo.existsSync(), isTrue);
    });

    test('Nunca borra la canción que está sonando ni las que se están bajando', () async {
      final sonando = await write('sonando.m4a', 500, DateTime(2020));
      final bajando = await write('otra.m4a.part', 500, DateTime.now());
      final vieja = await write('vieja.m4a', 500, DateTime(2021));

      await cache.evict(limitBytes: 100, keepVideoId: 'sonando');

      expect(sonando.existsSync(), isTrue);
      expect(bajando.existsSync(), isTrue);
      expect(vieja.existsSync(), isFalse);
    });

    test('Borra lo que quedó a medio bajar hace más de una hora', () async {
      final abandonada = await write('vieja.webm.part', 100, DateTime(2020));
      final reciente = await write('otra.webm.part', 100, DateTime.now());

      await cache.evict(limitBytes: 1024 * 1024);

      expect(abandonada.existsSync(), isFalse);
      expect(reciente.existsSync(), isTrue);
    });

    test('Vaciar la caché la deja en cero', () async {
      await write('a.m4a', 100, DateTime(2026));
      await cache.clear();
      expect(await cache.sizeBytes(), 0);
    });
  });
}
