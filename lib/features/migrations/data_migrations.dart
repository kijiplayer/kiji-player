// l10n-ignore-file: textos del registro (no se muestran en la interfaz).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Versión del formato de los datos de Kiji (playlists, me gusta, ajustes…). Sube cuando una
/// versión nueva necesita cambiar cómo se guardan; cada salto tiene su [DataMigration].
const currentDataVersion = 1;

/// Archivo con la versión de los datos (va también en las copias de seguridad).
const dataVersionFile = 'data_version.json';

/// Carpeta con las copias internas que se hacen antes de migrar (se guardan las 3 últimas).
const migrationBackupsFolder = 'migration_backups';

/// Un cambio en el formato de los datos, de `to - 1` a [to]. Tiene que poder correr dos veces
/// sin romper nada: al restaurar una copia vieja se vuelve a pasar por todas.
class DataMigration {
  const DataMigration({required this.to, required this.what, required this.run});

  final int to;

  /// Qué hace, para el registro.
  final String what;
  final Future<void> Function(Directory data) run;
}

/// Las migraciones de Kiji, en orden.
final kijiMigrations = <DataMigration>[
  // 0.6.0: desde acá los datos llevan versión. No cambia nada del formato de la 0.5.x.
  DataMigration(to: 1, what: 'versión de datos registrada', run: (_) async {}),
];

/// Cómo terminó la revisión al abrir.
enum MigrationOutcome { upToDate, freshInstall, migrated, newerData, failedRestored, skippedNoBackup }

class MigrationResult {
  const MigrationResult(this.outcome, {this.from, this.to, this.backupPath, this.error});

  final MigrationOutcome outcome;
  final int? from;
  final int? to;

  /// Copia interna hecha antes de migrar.
  final String? backupPath;
  final Object? error;

  @override
  String toString() => '${outcome.name} ($from → $to)';
}

/// Pone al día los datos al abrir una versión nueva de Kiji. Antes de tocar nada hace una
/// copia interna de todos los datos (sin el audio descargado); si una migración falla,
/// vuelve todo como estaba y Kiji abre con los datos de antes.
class DataMigrator {
  DataMigrator(
    this.data, {
    List<DataMigration>? migrations,
    this.target = currentDataVersion,
    DateTime Function()? now,
    this.keepBackups = 3,
  }) : migrations = migrations ?? kijiMigrations,
       _now = now ?? DateTime.now;

  final Directory data;
  final List<DataMigration> migrations;
  final int target;
  final int keepBackups;
  final DateTime Function() _now;

  File get _versionFile => File(p.join(data.path, dataVersionFile));

  /// Versión guardada; null si no hay archivo.
  Future<int?> storedVersion() async {
    try {
      if (!await _versionFile.exists()) return null;
      final json = jsonDecode(await _versionFile.readAsString());
      return json is Map && json['version'] is int ? json['version'] as int : 0;
    } catch (error) {
      debugPrint('=== MIGRACIONES: versión de datos ilegible, se toma como 0: $error ===');
      return 0;
    }
  }

  Future<void> _writeVersion(int version) async {
    await data.create(recursive: true);
    final temp = File('${_versionFile.path}.tmp');
    await temp.writeAsString(jsonEncode({'version': version}), flush: true);
    if (await _versionFile.exists()) await _versionFile.delete();
    await temp.rename(_versionFile.path);
  }

  /// Archivos de datos que se copian antes de migrar: los JSON de la carpeta y el índice
  /// de descargas (el audio no, para no duplicar cientos de MB).
  Future<List<File>> _dataFiles() async {
    if (!await data.exists()) return const [];
    final files = <File>[
      for (final entity in await data.list().toList())
        if (entity is File && entity.path.endsWith('.json')) entity,
    ];
    final index = File(p.join(data.path, 'downloads', 'index.json'));
    if (await index.exists()) files.add(index);
    return files;
  }

  Future<MigrationResult> run() async {
    final stored = await storedVersion();
    final files = await _dataFiles();
    final hasUserData = files.any((f) => p.basename(f.path) != dataVersionFile);
    if (stored == null && !hasUserData) {
      // Recién instalada: nada que migrar.
      await _writeVersion(target);
      return MigrationResult(MigrationOutcome.freshInstall, to: target);
    }
    final from = stored ?? 0;
    if (from == target) return MigrationResult(MigrationOutcome.upToDate, from: from, to: target);
    if (from > target) {
      // Datos de una Kiji más nueva (se volvió a una versión anterior): no se tocan.
      debugPrint('=== MIGRACIONES: datos de una versión más nueva ($from > $target), no se tocan ===');
      return MigrationResult(MigrationOutcome.newerData, from: from, to: target);
    }

    final pending = [
      for (final m in migrations)
        if (m.to > from && m.to <= target) m,
    ]..sort((a, b) => a.to.compareTo(b.to));

    final Directory backup;
    try {
      backup = await _backup(files, from);
    } catch (error) {
      // Sin copia no se migra: Kiji abre con los datos como están.
      debugPrint('=== MIGRACIONES: no se pudo hacer la copia interna, no se migra: $error ===');
      return MigrationResult(MigrationOutcome.skippedNoBackup, from: from, to: target, error: error);
    }

    var current = from;
    try {
      for (final migration in pending) {
        debugPrint('=== MIGRACIONES: ${migration.to - 1} → ${migration.to}: ${migration.what} ===');
        await migration.run(data);
        current = migration.to;
      }
      await _writeVersion(target);
      debugPrint('=== MIGRACIONES: datos al día ($from → $target), copia en ${p.basename(backup.path)} ===');
      await _prune();
      return MigrationResult(MigrationOutcome.migrated, from: from, to: target, backupPath: backup.path);
    } catch (error, stack) {
      debugPrint('=== MIGRACIONES: falló la migración a ${current + 1}: $error ===');
      debugPrint('$stack');
      await _restore(backup, files);
      return MigrationResult(
        MigrationOutcome.failedRestored,
        from: from,
        to: current,
        backupPath: backup.path,
        error: error,
      );
    }
  }

  Future<Directory> _backup(List<File> files, int from) async {
    final stamp = _now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final folder = Directory(p.join(data.path, migrationBackupsFolder, 'v$from-$stamp'));
    await folder.create(recursive: true);
    for (final file in files) {
      final relative = p.relative(file.path, from: data.path);
      final copy = File(p.join(folder.path, relative));
      await copy.parent.create(recursive: true);
      await file.copy(copy.path);
    }
    // Se comprueba que la copia está entera antes de seguir.
    for (final file in files) {
      final copy = File(p.join(folder.path, p.relative(file.path, from: data.path)));
      if (!await copy.exists() || await copy.length() != await file.length()) {
        throw FileSystemException('copia incompleta', copy.path);
      }
    }
    return folder;
  }

  /// Vuelve todo como estaba: los archivos copiados se reponen y los que creó la migración
  /// a medias se borran.
  Future<void> _restore(Directory backup, List<File> original) async {
    try {
      final originalPaths = {for (final f in original) p.normalize(f.path)};
      for (final file in await _dataFiles()) {
        if (!originalPaths.contains(p.normalize(file.path))) await file.delete();
      }
      for (final file in original) {
        final copy = File(p.join(backup.path, p.relative(file.path, from: data.path)));
        await copy.copy(file.path);
      }
      debugPrint('=== MIGRACIONES: datos devueltos a como estaban ===');
    } catch (error) {
      // Queda la copia en migration_backups para recuperarla a mano.
      debugPrint('=== MIGRACIONES: no se pudo volver atrás ($error); la copia sigue en ${backup.path} ===');
    }
  }

  Future<void> _prune() async {
    try {
      final root = Directory(p.join(data.path, migrationBackupsFolder));
      // "v<versión>-<fecha ISO>": las más nuevas primero, por fecha.
      String stamp(Directory d) => p.basename(d.path).split('-').skip(1).join('-');
      final folders = [
        for (final e in await root.list().toList())
          if (e is Directory) e,
      ]..sort((a, b) => stamp(b).compareTo(stamp(a)));
      for (final old in folders.skip(keepBackups)) {
        await old.delete(recursive: true);
      }
    } catch (error) {
      debugPrint('=== MIGRACIONES: no se pudieron borrar copias viejas: $error ===');
    }
  }
}
