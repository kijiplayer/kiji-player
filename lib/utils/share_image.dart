import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/l10n.dart';
import '../widgets/top_notice.dart';

/// Compartir una imagen de Kiji (racha, logros, tarjetas de canción, frases, letras; 0.9).
///
/// - Teléfono: el panel de compartir del sistema.
/// - PC: el panel de Windows si está; si no hay (o falla), la imagen se guarda en
///   `Imágenes\Kiji` y se avisa dónde quedó, con «Abrir carpeta».
/// - Si la imagen no se pudo preparar, se avisa (antes no pasaba nada).
abstract final class KijiShare {
  /// El panel de compartir (las pruebas lo cambian).
  static Future<ShareResult> Function(ShareParams params) share = SharePlus.instance.share;

  /// ¿Es la PC? (las pruebas lo cambian).
  static bool Function() isDesktop = () => !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  /// Dónde se dibujan las imágenes antes de compartirlas (las pruebas lo cambian).
  static Future<Directory> Function() tempFolder = getTemporaryDirectory;

  /// Dónde se guarda la imagen en la PC cuando no hay panel (las pruebas lo cambian).
  static Future<Directory> Function() savedFolder = _picturesFolder;

  static Future<Directory> _picturesFolder() async {
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    final pictures = home == null ? null : Directory(p.join(home, 'Pictures'));
    final base = pictures != null && pictures.existsSync()
        ? pictures
        : (await getDownloadsDirectory()) ?? await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, 'Kiji'));
  }

  /// Comparte [file] (un PNG ya dibujado). [name] es el nombre del archivo si hay que guardarlo.
  static Future<void> shareImage(BuildContext context, File? file, {required String name, String? text}) async {
    final overlay = context;
    if (file == null || !file.existsSync()) {
      debugPrint('=== COMPARTIR: la imagen no se pudo preparar ===');
      if (overlay.mounted) showTopNotice(overlay, message: tx.noSePudoPrepararLaImagen);
      return;
    }
    final desktop = isDesktop();
    try {
      final result = await share(ShareParams(files: [XFile(file.path, mimeType: 'image/png')], text: text));
      // En el teléfono, el panel siempre está. En la PC, «unavailable» = no hubo panel.
      if (!desktop || result.status != ShareResultStatus.unavailable) return;
    } catch (error) {
      debugPrint('=== COMPARTIR: el panel no se abrió (${error.runtimeType}) ===');
      if (!desktop) {
        if (overlay.mounted) showTopNotice(overlay, message: tx.noSePudoCompartir);
        return;
      }
    }
    // PC sin panel: se guarda la imagen y se avisa dónde.
    try {
      final folder = await savedFolder();
      await folder.create(recursive: true);
      final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-').substring(0, 19);
      final saved = await file.copy(p.join(folder.path, '$name-$stamp.png'));
      debugPrint('=== COMPARTIR: imagen guardada en la PC ===');
      if (!overlay.mounted) return;
      showTopNotice(
        overlay,
        message: tx.imagenGuardadaEn(saved.path),
        actionLabel: tx.abrirCarpeta,
        onAction: (_) => Process.run('explorer', ['/select,', saved.path]), // l10n-ignore
        duration: const Duration(seconds: 8),
      );
    } catch (error) {
      debugPrint('=== COMPARTIR: no se pudo guardar la imagen (${error.runtimeType}) ===');
      if (overlay.mounted) showTopNotice(overlay, message: tx.noSePudoCompartir);
    }
  }
}
