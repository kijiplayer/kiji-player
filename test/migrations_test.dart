import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:kiji_player/features/migrations/data_migrations.dart';

void main() {
  late Directory data;

  setUp(() => data = Directory.systemTemp.createTempSync('kiji_migr_'));
  tearDown(() => data.deleteSync(recursive: true));

  void write(String name, Object json) {
    final f = File(p.join(data.path, name));
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(jsonEncode(json));
  }

  Object? read(String name) => jsonDecode(File(p.join(data.path, name)).readAsStringSync());

  /// Datos de una Kiji 0.5.x inventados: sin data_version.json.
  void oldData() {
    write('settings.json', {'reduceMotion': true});
    write('playlists.json', [
      {'id': 'p1', 'name': 'Para correr'},
    ]);
    write('favorites.json', [
      {'id': 'yt-abc', 'title': 'Canción inventada'},
    ]);
    write('downloads/index.json', {
      'abc': {'path': 'abc.m4a'},
    });
    File(p.join(data.path, 'downloads', 'abc.m4a')).writeAsBytesSync(List.filled(1000, 7));
  }

  List<Directory> backups() {
    final root = Directory(p.join(data.path, migrationBackupsFolder));
    return root.existsSync() ? root.listSync().whereType<Directory>().toList() : [];
  }

  test('Recién instalada: anota la versión y no hace copia', () async {
    final r = await DataMigrator(data).run();
    expect(r.outcome, MigrationOutcome.freshInstall);
    expect(await DataMigrator(data).storedVersion(), currentDataVersion);
    expect(backups(), isEmpty);
  });

  test('Datos de la 0.5.x: copia interna completa (sin el audio) y después migra', () async {
    oldData();
    final r = await DataMigrator(data).run();
    expect(r.outcome, MigrationOutcome.migrated);
    expect(r.from, 0);
    expect(await DataMigrator(data).storedVersion(), currentDataVersion);
    final copy = backups().single;
    for (final name in ['settings.json', 'playlists.json', 'favorites.json', p.join('downloads', 'index.json')]) {
      expect(File(p.join(copy.path, name)).existsSync(), isTrue, reason: name);
    }
    expect(File(p.join(copy.path, 'downloads', 'abc.m4a')).existsSync(), isFalse);
    // Los datos siguen iguales (la migración 1 no cambia el formato).
    expect(read('playlists.json'), [
      {'id': 'p1', 'name': 'Para correr'},
    ]);
  });

  test('Ya al día: no hace nada', () async {
    oldData();
    await DataMigrator(data).run();
    final r = await DataMigrator(data).run();
    expect(r.outcome, MigrationOutcome.upToDate);
    expect(backups().length, 1);
  });

  test('Varias migraciones en orden', () async {
    oldData();
    final order = <int>[];
    final migrations = [
      DataMigration(to: 3, what: 'c', run: (_) async => order.add(3)),
      DataMigration(to: 1, what: 'a', run: (_) async => order.add(1)),
      DataMigration(
        to: 2,
        what: 'b',
        run: (d) async {
          order.add(2);
          // Ejemplo: renombra un campo.
          final f = File(p.join(d.path, 'settings.json'));
          final s = jsonDecode(f.readAsStringSync()) as Map;
          f.writeAsStringSync(jsonEncode({...s, 'nuevo': s['reduceMotion']}));
        },
      ),
    ];
    final r = await DataMigrator(data, migrations: migrations, target: 3).run();
    expect(r.outcome, MigrationOutcome.migrated);
    expect(order, [1, 2, 3]);
    expect((read('settings.json') as Map)['nuevo'], isTrue);
  });

  test('Si una migración falla, todo vuelve como estaba', () async {
    oldData();
    final before = {
      for (final n in ['settings.json', 'playlists.json', 'favorites.json']) n: read(n),
    };
    final migrations = [
      DataMigration(to: 1, what: 'ok', run: (_) async {}),
      DataMigration(
        to: 2,
        what: 'rompe',
        run: (d) async {
          File(p.join(d.path, 'playlists.json')).writeAsStringSync('{a medio escribir');
          File(p.join(d.path, 'basura.json')).writeAsStringSync('{}');
          throw StateError('falla inventada');
        },
      ),
    ];
    final r = await DataMigrator(data, migrations: migrations, target: 2).run();
    expect(r.outcome, MigrationOutcome.failedRestored);
    expect(r.error, isA<StateError>());
    for (final e in before.entries) {
      expect(read(e.key), e.value, reason: e.key);
    }
    expect(File(p.join(data.path, 'basura.json')).existsSync(), isFalse);
    expect(File(p.join(data.path, 'downloads', 'abc.m4a')).lengthSync(), 1000);
    // La versión no avanzó: la próxima vez se vuelve a intentar.
    expect(await DataMigrator(data).storedVersion(), isNull);
  });

  test('Datos de una Kiji más nueva: no se tocan', () async {
    oldData();
    write(dataVersionFile, {'version': currentDataVersion + 5});
    final r = await DataMigrator(data).run();
    expect(r.outcome, MigrationOutcome.newerData);
    expect(backups(), isEmpty);
  });

  test('Guarda solo las 3 copias internas más nuevas', () async {
    oldData();
    for (var i = 0; i < 5; i++) {
      final version = File(p.join(data.path, dataVersionFile));
      if (version.existsSync()) version.deleteSync();
      await DataMigrator(data, now: () => DateTime(2026, 10, 20 + i)).run().then((r) {
        expect(r.outcome, MigrationOutcome.migrated);
      });
    }
    final names = backups().map((d) => p.basename(d.path)).toList()..sort();
    expect(names.length, 3);
    expect(names.first, contains('2026-10-22'));
  });
}
