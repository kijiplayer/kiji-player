// Notas de una release, en inglés y español: `dart run tool/release_notes.dart <carpeta> [salida.md]`.
// Toma las novedades de fastlane (changelogs/<compilación>.txt de en-US y es-ES), la lista de
// archivos de <carpeta> (los APK y el instalador) y sus SHA-256. El formato es el de siempre, con
// "## Español" como título de la segunda parte: el aviso de actualizaciones de Kiji lo usa para
// mostrar solo el idioma de la app.

import 'dart:io';

import 'package:crypto/crypto.dart';

/// Certificado de la clave release (CN=Kiji Player).
const certificateSha256 = '4734c315830c368bff97784bcccaad5b20650ff04405377d25a5d754c740b1f3';

void main(List<String> args) {
  if (args.isEmpty) _fail('Uso: dart run tool/release_notes.dart <carpeta-con-los-archivos> [salida.md]');
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final match = RegExp(r'^version: ([^+\s]+)\+(\d+)', multiLine: true).firstMatch(pubspec);
  if (match == null) _fail('No se encontró "version: x.y.z+n" en pubspec.yaml.');
  final version = match.group(1)!, build = match.group(2)!;

  final files = Directory(args[0]).listSync().whereType<File>().where((f) => _describe(f.path, version) != null).toList()
    ..sort((a, b) => _order(a.path).compareTo(_order(b.path)));
  if (files.isEmpty) _fail('No hay APK ni instalador en ${args[0]}.');
  final rows = [
    for (final f in files)
      (
        name: f.uri.pathSegments.last,
        what: _describe(f.path, version)!,
        sha: sha256.convert(f.readAsBytesSync()).toString(),
      ),
  ];

  String changelog(String locale) {
    final file = File('fastlane/metadata/android/$locale/changelogs/$build.txt');
    if (!file.existsSync()) _fail('Falta ${file.path} (las novedades de la compilación $build).');
    return file
        .readAsStringSync()
        .trim()
        .split('\n')
        .map((l) => l.trim().startsWith('•') ? '- ${l.trim().substring(1).trim()}' : l.trimRight())
        .join('\n');
  }

  String table(bool spanish) => [
    spanish ? '| Archivo | Para | SHA-256 |' : '| File | For | SHA-256 |',
    '|---|---|---|',
    for (final r in rows) '| `${r.name}` | ${spanish ? r.what.$2 : r.what.$1} | `${r.sha}` |',
  ].join('\n');

  final universal = 'Kiji-Player-$version.apk';
  final notes = '''
**English** · [Español](#español)

## What's new in $version

${changelog('en-US')}

## Downloads

${table(false)}

If you're not sure which APK to pick, use `$universal`. All APKs are signed with the certificate `CN=Kiji Player`, SHA-256 `$certificateSha256`.

---

## Español

## Novedades de $version

${changelog('es-ES')}

## Descargas

${table(true)}

Si no sabes cuál elegir, usa `$universal`. Todos los APK están firmados con el certificado `CN=Kiji Player`, SHA-256 `$certificateSha256`.
''';
  if (args.length > 1) {
    File(args[1]).writeAsStringSync(notes);
    stdout.writeln('Notas en ${args[1]} (${rows.length} archivos).');
  } else {
    stdout.write(notes);
  }
}

/// (inglés, español) de cada archivo; null si no es parte de la release.
(String, String)? _describe(String path, String version) {
  final name = path.split(RegExp(r'[\\/]')).last;
  return switch (name) {
    _ when name == 'Kiji-Player-$version-arm64-v8a.apk' => (
      'Most phones from the last years',
      'La mayoría de los celulares de los últimos años',
    ),
    _ when name == 'Kiji-Player-$version-armeabi-v7a.apk' => ('Older 32-bit phones', 'Celulares viejos de 32 bits'),
    _ when name == 'Kiji-Player-$version-x86_64.apk' => (
      'Emulators and some Chromebooks',
      'Emuladores y algunas Chromebook',
    ),
    _ when name == 'Kiji-Player-$version.apk' => (
      'Any Android 7+ device (all of the above in one, bigger)',
      'Cualquier Android 7 o más nuevo (todos en uno, más pesado)',
    ),
    _ when name == 'Kiji_Player_${version}_Windows_Setup.exe' => (
      'Windows 10/11 (64-bit)',
      'Windows 10/11 (64 bits)',
    ),
    _ => null,
  };
}

int _order(String path) => switch (path) {
  _ when path.endsWith('arm64-v8a.apk') => 0,
  _ when path.endsWith('armeabi-v7a.apk') => 1,
  _ when path.endsWith('x86_64.apk') => 2,
  _ when path.endsWith('.apk') => 3,
  _ => 4,
};

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
