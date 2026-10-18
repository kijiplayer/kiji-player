import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:kiji_player/features/stream_cache/data/stream_cache.dart';
import 'package:kiji_player/features/extractor/data/path_health.dart';
import 'package:kiji_player/features/yt_music/presentation/extractor_health_screen.dart';

void main() {
  group('Salud del Extractor 2.0', () {
    test('Un camino funciona si su último resultado fue un éxito, y guarda el último problema', () {
      final health = PathHealth(directory: () async => Directory.systemTemp.path);
      expect(health['B/VISIONOS'], isNull);
      health.recordFormFailure('B/VISIONOS', 'YouTube rechazó el pedido');
      expect(health['B/VISIONOS']!.working, isFalse);
      health.recordSuccess('B/VISIONOS');
      expect(health['B/VISIONOS']!.working, isTrue);
      expect(health['B/VISIONOS']!.lastReason, 'YouTube rechazó el pedido');
    });

    test('"Hace…" en palabras simples', () {
      final now = DateTime(2026, 10, 15, 20);
      expect(agoShort(null, now), 'nunca');
      expect(agoShort(now.subtract(const Duration(minutes: 5)), now), 'hace 5 min');
      expect(agoShort(now.subtract(const Duration(hours: 2)), now), 'hace 2 h');
    });

    test('Sobrevive a guardarse y leerse', () {
      final original = PathRecord(ok: 3, fail: 1, lastOk: DateTime(2026, 10, 15, 10), lastReason: 'sin audio', recent: [false, true]);
      final restored = PathRecord.fromJson(original.toJson());
      expect(restored.ok, 3);
      expect(restored.lastReason, 'sin audio');
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
