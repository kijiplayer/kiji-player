import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/backup/data/backup_notifier.dart';
import 'package:kiji_player/features/backup/data/backup_service.dart';
import 'package:kiji_player/features/backup/domain/backup_manifest.dart';
import 'package:kiji_player/features/backup/presentation/backup_screen.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:path/path.dart' as p;

void _write(Directory dir, String name, Object json) {
  final file = File(p.join(dir.path, name));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(jsonEncode(json));
}

/// Datos de Kiji de ejemplo: 2 playlists, 3 me gusta, 4 en el historial, 2
/// descargas y 1 carátula.
void _fillData(Directory data) {
  _write(data, 'settings.json', {'version': 1, 'reduceMotion': true});
  _write(data, 'playlists.json', {
    'version': 1,
    'playlists': [
      {'name': 'Rock'},
      {'name': 'Estudio'},
    ],
  });
  _write(data, 'favorites.json', [{}, {}, {}]);
  _write(data, 'history.json', [{}, {}, {}, {}]);
  _write(data, 'downloads/index.json', {
    'version': 1,
    'tracks': [
      {'videoId': 'aaa', 'title': 'Uno', 'artist': 'A', 'durationMs': 1000},
      {'videoId': 'bbb', 'title': 'Dos', 'artist': 'B'},
    ],
  });
  File(p.join(data.path, 'covers', 'yt-aaa.jpg'))
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync([1, 2, 3]);
  // Esto no va en la copia.
  _write(data, 'playback_state.json', {'queue': []});
}

void main() {
  group('nombres y reglas', () {
    test('nombre con fecha, ida y vuelta; los otros archivos no cuentan', () {
      final when = DateTime(2026, 10, 16, 8, 30, 5);
      expect(backupFileName(when), 'kiji-copia-2026-10-16-083005.zip');
      expect(backupFileName(when, suffix: 'antes-de-restaurar'), 'kiji-copia-2026-10-16-083005-antes-de-restaurar.zip');
      expect(backupDateFromName('kiji-copia-2026-10-16-083005.zip'), when);
      expect(backupDateFromName('kiji-copia-2026-10-16-083005-antes-de-restaurar.zip'), when);
      expect(backupDateFromName('mis-fotos.zip'), isNull);
      expect(backupDateFromName('kiji-copia-2026-10-16-083005.zip.tmp'), isNull);
    });

    test('se guardan las 7 más nuevas y nunca se toca otro archivo', () {
      final names = [
        for (var day = 1; day <= 9; day++) backupFileName(DateTime(2026, 10, day, 9)),
        'notas.txt',
        'kiji-otra-cosa.zip',
      ];
      final delete = backupsToDelete(names);
      expect(delete, [backupFileName(DateTime(2026, 10, 2, 9)), backupFileName(DateTime(2026, 10, 1, 9))]);
      expect(backupsToDelete(names.take(7)), isEmpty);
    });

    test('copia automática: si nunca hubo o pasó un día', () {
      final now = DateTime(2026, 10, 16, 12);
      expect(shouldAutoBackup(null, now), isTrue);
      expect(shouldAutoBackup(now.subtract(const Duration(hours: 23)), now), isFalse);
      expect(shouldAutoBackup(now.subtract(const Duration(hours: 24)), now), isTrue);
    });

    test('el manifiesto rechaza lo que no es de Kiji o es más nuevo', () {
      expect(BackupManifest.tryParse({'app': 'Otro', 'version': 1, 'createdAt': '2026-10-16T00:00:00Z'}), isNull);
      expect(BackupManifest.tryParse({'app': 'Kiji', 'version': 99, 'createdAt': '2026-10-16T00:00:00Z'}), isNull);
      expect(BackupManifest.tryParse('nada'), isNull);
      final ok = BackupManifest.tryParse({'app': 'Kiji', 'version': 1, 'createdAt': '2026-10-16T00:00:00Z'});
      expect(ok!.counts.playlists, 0);
    });
  });

  group('BackupService', () {
    late Directory root;
    late Directory data;
    late Directory folder;
    setUp(() {
      root = Directory.systemTemp.createTempSync('kiji_copia_');
      data = Directory(p.join(root.path, 'datos'))..createSync();
      folder = Directory(p.join(root.path, 'Documentos', 'Kiji'));
    });
    tearDown(() => root.deleteSync(recursive: true));

    BackupService service(Directory dir) => BackupService(dataDirectory: () async => dir, platform: 'android');

    test('la copia trae lo que corresponde y la vista previa lo cuenta', () async {
      _fillData(data);
      final file = await service(data).create(folder, now: DateTime(2026, 10, 16, 8));
      expect(p.basename(file.path), 'kiji-copia-2026-10-16-080000.zip');
      final names = [for (final f in ZipDecoder().decodeBytes(file.readAsBytesSync()).files) f.name];
      expect(names, containsAll(['settings.json', 'playlists.json', downloadsListEntry, 'covers/yt-aaa.jpg', 'manifest.json']));
      expect(names, isNot(contains('playback_state.json')));

      final preview = await service(data).preview(file);
      final c = preview.manifest.counts;
      expect([c.playlists, c.likes, c.history, c.downloads, c.covers], [2, 3, 4, 2, 1]);
      expect(preview.manifest.platform, 'android');
      expect(preview.downloads.map((d) => d.videoId), ['aaa', 'bbb']);
      expect(restorePreviewText(preview.manifest), contains('2 playlists'));
      expect(restorePreviewText(preview.manifest), contains('(de un celular Android)'));
    });

    test('restaurar reemplaza los datos, guarda antes lo actual y no pisa las descargas', () async {
      _fillData(data);
      final copy = await service(data).create(folder, now: DateTime(2026, 10, 15, 8));

      // Otro dispositivo, con datos distintos.
      final other = Directory(p.join(root.path, 'otro'))..createSync();
      _write(other, 'playlists.json', {'version': 1, 'playlists': []});
      _write(other, 'equalizer.json', {'enabled': true});
      _write(other, 'downloads/index.json', {'version': 1, 'tracks': []});
      File(p.join(other.path, 'covers', 'vieja.jpg'))
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync([9]);

      await service(other).restore(copy, safetyFolder: folder);

      expect(jsonDecode(File(p.join(other.path, 'playlists.json')).readAsStringSync())['playlists'], hasLength(2));
      expect(File(p.join(other.path, 'favorites.json')).existsSync(), isTrue);
      expect(File(p.join(other.path, 'equalizer.json')).existsSync(), isFalse, reason: 'en la copia estaba de fábrica');
      expect(File(p.join(other.path, 'covers', 'yt-aaa.jpg')).readAsBytesSync(), [1, 2, 3]);
      expect(File(p.join(other.path, 'covers', 'vieja.jpg')).existsSync(), isFalse);
      expect(jsonDecode(File(p.join(other.path, 'downloads/index.json')).readAsStringSync())['tracks'], isEmpty,
          reason: 'el índice de descargas no se pisa (el audio no está)');
      final safety = folder.listSync().map((e) => p.basename(e.path)).where((n) => n.contains('antes-de-restaurar'));
      expect(safety, hasLength(1));
    });

    test('un zip armado a mano no puede escribir fuera de su lugar; uno dañado avisa', () async {
      final archive = Archive();
      void add(String name, List<int> bytes) => archive.addFile(ArchiveFile(name, bytes.length, bytes));
      final manifest = utf8.encode(jsonEncode({'app': 'Kiji', 'version': 1, 'createdAt': '2026-10-16T00:00:00Z'}));
      add('manifest.json', manifest);
      add('covers/../../malo.json', [1]);
      add('../fuera.json', [1]);
      final evil = File(p.join(root.path, 'kiji-copia-2026-10-16-000000.zip'))
        ..writeAsBytesSync(ZipEncoder().encodeBytes(archive));
      await service(data).restore(evil, safetyFolder: folder);
      expect(File(p.join(root.path, 'malo.json')).existsSync(), isFalse);
      expect(File(p.join(root.path, 'fuera.json')).existsSync(), isFalse);
      expect(File(p.join(data.path, 'covers', 'malo.json')).existsSync(), isTrue);

      final broken = File(p.join(root.path, 'roto.zip'))..writeAsStringSync('no es un zip');
      expect(() => service(data).preview(broken), throwsA(isA<BackupException>()));
    });

    test('quedan las últimas 7 copias', () async {
      _fillData(data);
      File(p.join(folder.path, 'mis-notas.txt'))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('no tocar');
      for (var day = 1; day <= 9; day++) {
        await service(data).create(folder, now: DateTime(2026, 10, day, 9));
      }
      final files = await service(data).list(folder);
      expect(files, hasLength(7));
      expect(p.basename(files.first.path), backupFileName(DateTime(2026, 10, 9, 9)));
      expect(File(p.join(folder.path, 'mis-notas.txt')).existsSync(), isTrue);
    });
  });

  group('BackupNotifier', () {
    late Directory root;
    setUp(() => root = Directory.systemTemp.createTempSync('kiji_copia_n_'));
    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      root.deleteSync(recursive: true);
    });

    test('copia diaria automática: una por día, y nada si está apagada', () async {
      final data = Directory(p.join(root.path, 'datos'))..createSync();
      _fillData(data);
      final folder = Directory(p.join(root.path, 'Kiji'));
      var now = DateTime(2026, 10, 16, 9);
      ProviderContainer make() {
        final c = ProviderContainer(overrides: [
          settingsProvider.overrideWith(() => SettingsNotifier(directory: () async => data)),
          backupProvider.overrideWith(() => BackupNotifier(
                dataDirectory: () async => data,
                defaultFolder: () async => folder,
                clock: () => now,
                platform: 'windows',
              )),
        ]);
        addTearDown(c.dispose);
        return c;
      }

      var c = make();
      c.read(backupProvider);
      await c.read(backupProvider.notifier).ready;
      expect(c.read(backupProvider).copies, hasLength(1));

      // Mismo día: no hace otra.
      now = DateTime(2026, 10, 16, 20);
      c = make();
      c.read(backupProvider);
      await c.read(backupProvider.notifier).ready;
      expect(c.read(backupProvider).copies, hasLength(1));

      // Al día siguiente, sí.
      now = DateTime(2026, 10, 17, 9);
      c = make();
      c.read(backupProvider);
      await c.read(backupProvider.notifier).ready;
      expect(c.read(backupProvider).copies, hasLength(2));

      // Apagada: nada, aunque pasen días.
      await c.read(backupProvider.notifier).setAutoBackup(false);
      now = DateTime(2026, 10, 20, 9);
      c = make();
      c.read(backupProvider);
      await c.read(backupProvider.notifier).ready;
      expect(c.read(backupProvider).copies, hasLength(2));
    });
  });

  test('fechas en palabras', () {
    final now = DateTime(2026, 10, 16, 12);
    expect(describeDate(DateTime(2026, 10, 16, 8, 5), now), 'hoy 08:05');
    expect(describeDate(DateTime(2026, 10, 15, 21, 10), now), 'ayer 21:10');
    expect(describeDate(DateTime(2026, 10, 1, 9, 0), now), '01/10/2026 09:00');
  });
}
