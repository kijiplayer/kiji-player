import 'dart:io';

import '../update_checker.dart';
import 'update_assets.dart';

/// Lo que cambia de una plataforma a otra al actualizar Kiji desde Kiji: qué archivo bajar, cómo
/// comprobarlo y cómo instalarlo. Android y Windows en `data/`.
abstract class UpdateInstaller {
  /// El archivo de [release] para este equipo, o null si no hay (se ofrece la página).
  Future<ReleaseAsset?> pickAsset(Release release);

  /// ¿Kiji ya tiene permiso para instalar? (Android: "instalar apps desconocidas".)
  Future<bool> canInstall();

  /// Abre el ajuste del sistema donde se da ese permiso.
  Future<void> openInstallPermission();

  /// ¿El archivo está firmado con el mismo certificado que la app instalada? null: no se puede
  /// saber en esta plataforma (Windows), y basta con la suma.
  Future<bool?> sameSigner(File file);

  /// ¿Hay que pedir una confirmación más antes de instalar? (Windows: Kiji se va a cerrar.)
  bool get confirmBeforeInstall;

  /// Instala [file] (ya verificado). En Windows, Kiji se cierra y el instalador la vuelve a abrir.
  Future<void> install(File file);
}
