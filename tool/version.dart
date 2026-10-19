// Sube la versión de Kiji en un solo paso: `dart run tool/version.dart 0.5.0-beta.2`.
// Escribe la versión, el número de compilación (siempre +1) y la fecha en pubspec.yaml y en
// lib/version.dart. Kiji y Kiji Dev salen del mismo código con la misma versión; Kiji Dev le suma
// "-dev.<compilación>".

import 'dart:io';

void main(List<String> args) {
  if (args.length != 1 || !RegExp(r'^\d+\.\d+\.\d+(-[a-z]+\.\d+)?$').hasMatch(args.single)) {
    stderr.writeln('Uso: dart run tool/version.dart 0.5.0-beta.2');
    exit(64);
  }
  final version = args.single;
  final pubspec = File('pubspec.yaml');
  final text = pubspec.readAsStringSync();
  final current = RegExp(r'^version: [^+\s]+\+(\d+)', multiLine: true).firstMatch(text);
  final build = (int.tryParse(current?.group(1) ?? '') ?? 0) + 1;
  pubspec.writeAsStringSync(text.replaceFirst(RegExp(r'^version: .*$', multiLine: true), 'version: $version+$build'));

  final now = DateTime.now();
  final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  File('lib/version.dart').writeAsStringSync('''// Lo escribe tool/version.dart (no se edita a mano).

/// Versión de Kiji (la misma en Kiji y Kiji Dev).
const kijiVersion = '$version';

/// Número de compilación: sube en cada versión (Android lo usa como versionCode).
const kijiBuild = $build;

/// Fecha en que se generó esta versión.
const kijiBuildDate = '$date';
''');
  stdout.writeln('Kiji $version (compilación $build, $date)');
}
