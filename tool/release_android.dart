// Arma los APK de una release de Android: `dart run tool/release_android.dart`.
// Deja en build/release/ el APK universal y uno por arquitectura, con nombre fijo:
//   Kiji-Player-<versión>.apk, Kiji-Player-<versión>-arm64-v8a.apk,
//   Kiji-Player-<versión>-armeabi-v7a.apk y Kiji-Player-<versión>-x86_64.apk
// Todos llevan el mismo versionCode (se compila cada arquitectura por separado en vez de usar
// --split-per-abi, que le suma un número distinto a cada una): así se puede pasar de uno a otro.
// Al final muestra el SHA-256 de cada archivo y comprueba que estén firmados con la clave release.
// Con `--sin-firma` no exige la clave release (prueba en GitHub Actions sin los Secrets cargados).
// Funciona en Windows, Linux y macOS.

import 'dart:io';

import 'package:crypto/crypto.dart';

const _targets = {
  '': null, // universal
  'arm64-v8a': 'android-arm64',
  'armeabi-v7a': 'android-arm',
  'x86_64': 'android-x64',
};

void main(List<String> args) async {
  final requireReleaseKey = !args.contains('--sin-firma');
  final version = RegExp(r'^version: ([^+\s]+)', multiLine: true)
      .firstMatch(File('pubspec.yaml').readAsStringSync())
      ?.group(1);
  if (version == null) _fail('No se encontró la versión en pubspec.yaml.');

  final out = Directory('build/release')..createSync(recursive: true);
  for (final old in out.listSync().whereType<File>().where((f) => f.path.endsWith('.apk'))) {
    old.deleteSync();
  }
  final built = <File>[];
  for (final MapEntry(key: abi, value: platform) in _targets.entries) {
    await _run('flutter', [
      'build',
      'apk',
      '--release',
      '--flavor',
      'prod',
      if (platform != null) '--target-platform=$platform',
    ]);
    final name = abi.isEmpty ? 'Kiji-Player-$version.apk' : 'Kiji-Player-$version-$abi.apk';
    built.add(File('build/app/outputs/flutter-apk/app-prod-release.apk').copySync('${out.path}/$name'));
  }

  final apksigner = _apksigner();
  for (final apk in built) {
    final cert = await Process.run(apksigner, ['verify', '--print-certs', apk.path], runInShell: true);
    final signer = RegExp(r'certificate DN: (.+)').firstMatch('${cert.stdout}')?.group(1)?.trim();
    if (cert.exitCode != 0) _fail('${apk.path} no está firmado: ${cert.stderr}');
    if (requireReleaseKey && signer != 'CN=Kiji Player') _fail('${apk.path} no está firmado con la clave release.');
    final sha = sha256.convert(await apk.readAsBytes()).toString();
    stdout.writeln('${apk.uri.pathSegments.last}  ${(apk.lengthSync() / 1048576).toStringAsFixed(1)} MB  $sha  ($signer)');
  }
}

String _apksigner() {
  final sdk = Platform.environment['ANDROID_HOME'] ??
      Platform.environment['ANDROID_SDK_ROOT'] ??
      '${Platform.environment['LOCALAPPDATA']}\\Android\\Sdk';
  final tools = Directory('$sdk${Platform.pathSeparator}build-tools');
  if (!tools.existsSync()) _fail('No se encontró el Android SDK (ANDROID_HOME).');
  final versions = tools.listSync().whereType<Directory>().toList()..sort((a, b) => a.path.compareTo(b.path));
  for (final dir in versions.reversed) {
    for (final name in ['apksigner.bat', 'apksigner']) {
      final file = File('${dir.path}${Platform.pathSeparator}$name');
      if (file.existsSync()) return file.path;
    }
  }
  _fail('No se encontró apksigner en el Android SDK.');
}

Future<void> _run(String exe, List<String> args) async {
  final process = await Process.start(exe, args, runInShell: true, mode: ProcessStartMode.inheritStdio);
  final code = await process.exitCode;
  if (code != 0) _fail('$exe ${args.join(' ')} terminó con código $code.');
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
