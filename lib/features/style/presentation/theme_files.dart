import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../l10n/l10n.dart';
import '../../../theme/kiji_tokens.dart';
import '../../settings/data/settings_store.dart';
import '../data/background_store.dart';
import '../data/kiji_theme.dart';

/// Apariencia → Temas: exportar el estilo actual como `.kiji` (con la imagen de fondo, si hay una)
/// o importar uno. Un archivo que no sea un tema válido se ignora con un aviso simple.
class ThemeFileOptions extends ConsumerWidget {
  const ThemeFileOptions({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final s = ref.read(settingsProvider);
    try {
      String? imageName;
      Uint8List? imageBytes;
      // La imagen de fondo va en el tema (un video no: pesa mucho para compartir).
      if (s.backgroundFile != null && s.backgroundKind == 'image') {
        final file = await ref.read(backgroundStoreProvider).fileFor(s.backgroundFile!);
        if (await file.exists() && await file.length() <= KijiTheme.maxImageBytes) {
          imageName = 'fondo${p.extension(file.path).toLowerCase()}';
          imageBytes = await file.readAsBytes();
        }
      }
      final bytes = KijiTheme.fromSettings(s, imageName: imageName, imageBytes: imageBytes).encode();
      final saved = await FilePicker.saveFile(dialogTitle: tx.exportarTema, fileName: 'mi-tema.kiji', bytes: bytes);
      if (saved != null) messenger.showSnackBar(SnackBar(content: Text(tx.temaGuardado)));
    } catch (error) {
      debugPrint('=== TEMA: no se pudo exportar: $error ===');
      messenger.showSnackBar(SnackBar(content: Text(tx.noSePudoGuardarElArchivo)));
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await FilePicker.pickFiles(dialogTitle: tx.importarTema, type: FileType.any);
      if (picked.isEmpty) return;
      final theme = KijiTheme.decode(await picked.first.readAsBytes());
      if (theme == null) {
        messenger.showSnackBar(SnackBar(content: Text(tx.esoNoEsUnTemaDeKiji)));
        return;
      }
      await applyKijiTheme(ref, theme);
      messenger.showSnackBar(SnackBar(content: Text(tx.temaAplicado)));
    } catch (error) {
      debugPrint('=== TEMA: no se pudo importar: $error ===');
      messenger.showSnackBar(SnackBar(content: Text(tx.esoNoEsUnTemaDeKiji)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.ios_share_rounded),
            label: Text(tx.exportarTema),
            onPressed: () => _export(context, ref),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.file_open_outlined),
            label: Text(tx.importarTema),
            onPressed: () => _import(context, ref),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(tx.temasNota, style: TextStyle(color: KijiColors.muted, fontSize: 12)),
    ],
  );
}

/// Aplica [theme]: los ajustes y, si trae imagen, la copia como fondo propio.
Future<void> applyKijiTheme(WidgetRef ref, KijiTheme theme) async {
  String? background;
  final bytes = theme.imageBytes;
  if (bytes != null && theme.imageName != null) {
    final temp = File(p.join(Directory.systemTemp.path, 'kiji-tema-${DateTime.now().millisecondsSinceEpoch}${p.extension(theme.imageName!)}'));
    await temp.writeAsBytes(bytes, flush: true);
    try {
      background = await ref.read(backgroundStoreProvider).keep(temp.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }
  await ref.read(settingsProvider.notifier).update((s) {
    final applied = theme.applyTo(s);
    return background == null ? applied : applied.copyWith(backgroundFile: background, backgroundKind: 'image');
  });
  debugPrint('=== TEMA: aplicado (${theme.style}${background != null ? ', con fondo' : ''}) ===');
}
