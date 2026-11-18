import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../desktop/desktop_window.dart';
import '../domain/update_assets.dart';
import '../domain/update_installer.dart';
import '../update_checker.dart';

/// Windows: el instalador de siempre (Inno Setup, mismo AppId), en modo actualización. Kiji guarda
/// todo, abre el instalador y se cierra; el instalador reemplaza los archivos de la app (los datos
/// están en otra carpeta, `%APPDATA%`, y no se tocan) y vuelve a abrir Kiji.
class WindowsUpdateInstaller implements UpdateInstaller {
  WindowsUpdateInstaller({String? executable}) : _executable = executable ?? Platform.resolvedExecutable;

  final String _executable;

  /// Kiji instalada con el instalador (no una copia suelta ni la de desarrollo): junto al programa
  /// está el desinstalador de Inno Setup.
  bool get installed => File(p.join(p.dirname(_executable), 'unins000.exe')).existsSync();

  @override
  Future<ReleaseAsset?> pickAsset(Release release) async {
    if (!installed) {
      debugPrint('=== ACTUALIZAR: esta copia de Kiji no vino del instalador; solo la página ===');
      return null;
    }
    return pickWindowsAsset(release.assets, release.version);
  }

  @override
  bool get confirmBeforeInstall => true;

  @override
  Future<bool> canInstall() async => true;

  @override
  Future<void> openInstallPermission() async {}

  @override
  Future<bool?> sameSigner(File file) async => null;

  /// `/KIJIUPDATE=1`: el instalador (desde la 0.8.4) vuelve a abrir Kiji al terminar.
  static const arguments = ['/SILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CLOSEAPPLICATIONS', '/KIJIUPDATE=1'];

  @override
  Future<void> install(File file) async {
    final window = DesktopWindow.instance;
    // Primero se guarda todo; recién después se abre el instalador y se sale.
    await window.beforeExit?.call();
    await Process.start(file.path, arguments, mode: ProcessStartMode.detached);
    debugPrint('=== ACTUALIZAR: instalador abierto; Kiji se cierra ===');
    await window.exit();
  }
}
