// Arma el instalador de Windows: `dart run tool/installer.dart`.
// Compila Kiji para Windows desde limpio (sin restos de compilaciones de depuración, que dejan
// un kernel_blob.bin de ~100 MB en build/flutter_assets) y lo empaqueta con Inno Setup 6
// (windows/installer/kiji_player.iss), con la versión del pubspec y el runtime de Visual C++.
// Inno Setup se busca en las carpetas de siempre o en la variable KIJI_ISCC.

import 'dart:io';

void main() async {
  if (!Platform.isWindows) _fail('El instalador de Windows se arma en Windows.');

  final version = RegExp(r'^version: ([^+\s]+)', multiLine: true)
      .firstMatch(File('pubspec.yaml').readAsStringSync())
      ?.group(1);
  if (version == null) _fail('No se encontró la versión en pubspec.yaml.');

  final iscc = _findIscc();
  final vcRuntime = _findVcRuntime();
  stdout.writeln('Kiji $version · Inno Setup: $iscc · runtime de Visual C++: $vcRuntime');

  for (final path in ['build/flutter_assets', 'build/windows/x64/runner/Release']) {
    final dir = Directory(path);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
  await _run('flutter', ['build', 'windows', '--release']);
  if (File('build/windows/x64/runner/Release/data/flutter_assets/kernel_blob.bin').existsSync()) {
    _fail('La compilación release trae kernel_blob.bin (restos de depuración).');
  }
  await _run(iscc, ['/Qp', '/DAppVersion=$version', '/DVcRuntime=$vcRuntime', 'windows/installer/kiji_player.iss']);

  final setup = File('build/installer/Kiji_Player_${version}_Windows_Setup.exe');
  if (!setup.existsSync()) _fail('Inno Setup no dejó ${setup.path}.');
  stdout.writeln('Listo: ${setup.path} (${(setup.lengthSync() / 1048576).toStringAsFixed(1)} MB)');
}

String _findIscc() {
  final env = Platform.environment;
  final candidates = [
    ?env['KIJI_ISCC'],
    '${env['LOCALAPPDATA']}\\Programs\\Inno Setup 6\\ISCC.exe',
    '${env['ProgramFiles(x86)']}\\Inno Setup 6\\ISCC.exe',
    '${env['ProgramFiles']}\\Inno Setup 6\\ISCC.exe',
  ];
  for (final path in candidates) {
    if (File(path).existsSync()) return path;
  }
  _fail('No se encontró Inno Setup 6 (ISCC.exe). Instálalo o indica la ruta en KIJI_ISCC.');
}

/// Carpeta con msvcp140.dll, vcruntime140.dll y vcruntime140_1.dll: la del redistribuible de
/// Visual Studio si está, y si no la del sistema.
String _findVcRuntime() {
  const dlls = ['msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll'];
  bool complete(String dir) => dlls.every((dll) => File('$dir\\$dll').existsSync());
  final env = Platform.environment;
  for (final root in ['${env['ProgramFiles(x86)']}\\Microsoft Visual Studio', '${env['ProgramFiles']}\\Microsoft Visual Studio']) {
    final base = Directory(root);
    if (!base.existsSync()) continue;
    final found = base
        .listSync(recursive: true, followLinks: false)
        .whereType<Directory>()
        .where((d) => RegExp(r'\\Redist\\MSVC\\[\d.]+\\x64\\Microsoft\.VC\d+\.CRT$').hasMatch(d.path) && complete(d.path))
        .map((d) => d.path)
        .toList()
      ..sort();
    if (found.isNotEmpty) return found.last;
  }
  final system = '${env['SystemRoot']}\\System32';
  if (complete(system)) return system;
  _fail('No se encontró el runtime de Visual C++ (msvcp140.dll y vcruntime140*.dll).');
}

Future<void> _run(String exe, List<String> args) async {
  // El shell solo para `flutter` (es un .bat); con él, las rutas con espacios de ISCC se cortan.
  final process = await Process.start(exe, args, runInShell: exe == 'flutter', mode: ProcessStartMode.inheritStdio);
  final code = await process.exitCode;
  if (code != 0) _fail('$exe ${args.join(' ')} terminó con código $code.');
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
