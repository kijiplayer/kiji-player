import 'dart:io';

import 'package:flutter/foundation.dart';

/// Cómo arrancó Kiji: con `--startup` (lo pone la entrada de «Iniciar Kiji al encender la PC"), queda
/// en la bandeja, sin ventana y sin sonar.
abstract final class KijiLaunch {
  static const startupFlag = '--startup'; // l10n-ignore
  static bool atStartup = false;
}

/// La entrada de inicio de Windows (solo de este usuario, sin permisos de administrador). Interfaz
/// para poder probarla sin tocar el registro.
abstract class StartupEntry {
  Future<bool> isEnabled();
  Future<bool> enable();
  Future<bool> disable();
}

/// `HKCU\Software\Microsoft\Windows\CurrentVersion\Run\KijiPlayer` con `reg.exe` (viene con
/// Windows). El desinstalador borra este valor.
class WindowsStartupEntry implements StartupEntry {
  WindowsStartupEntry({String? executable}) : _exe = executable ?? Platform.resolvedExecutable;

  static const key = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run'; // l10n-ignore
  static const valueName = 'KijiPlayer'; // l10n-ignore
  final String _exe;

  /// El comando que queda guardado: la ruta entre comillas y `--startup`.
  String get command => '"$_exe" ${KijiLaunch.startupFlag}';

  Future<ProcessResult?> _reg(List<String> args) async {
    try {
      return await Process.run('reg', args); // l10n-ignore
    } catch (error) {
      debugPrint('=== INICIO CON WINDOWS: no se pudo usar reg.exe: ${error.runtimeType} ===');
      return null;
    }
  }

  @override
  Future<bool> isEnabled() async {
    final result = await _reg(['query', key, '/v', valueName]); // l10n-ignore
    return result?.exitCode == 0;
  }

  @override
  Future<bool> enable() async {
    final result = await _reg(['add', key, '/v', valueName, '/t', 'REG_SZ', '/d', command, '/f']); // l10n-ignore
    final ok = result?.exitCode == 0;
    debugPrint('=== INICIO CON WINDOWS: ${ok ? 'prendido' : 'no se pudo prender'} ===');
    return ok;
  }

  @override
  Future<bool> disable() async {
    final result = await _reg(['delete', key, '/v', valueName, '/f']); // l10n-ignore
    // Si no existía, también está bien: queda apagado.
    final ok = result != null && (result.exitCode == 0 || !(await isEnabled()));
    debugPrint('=== INICIO CON WINDOWS: ${ok ? 'apagado' : 'no se pudo apagar'} ===');
    return ok;
  }
}
