import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/kiji_tokens.dart';
import '../../settings/data/settings_store.dart';

/// "Carpetas excluidas": lo que no se lee como música (notas de voz, audios de chats, grabadoras).
/// Se quita o se agrega (por nombre o eligiendo una carpeta) y se puede volver a las de fábrica.
class ExcludedFoldersScreen extends ConsumerWidget {
  const ExcludedFoldersScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ExcludedFoldersScreen()));

  Future<void> _set(WidgetRef ref, List<String> folders) =>
      ref.read(settingsProvider.notifier).update((s) => s.copyWith(excludedFolders: folders));

  Future<void> _addByName(BuildContext context, WidgetRef ref, List<String> current) async {
    final name = await showDialog<String>(context: context, builder: (_) => const _NameDialog());
    final clean = name?.trim() ?? '';
    if (clean.isEmpty || current.any((f) => f.toLowerCase() == clean.toLowerCase())) return;
    await _set(ref, [...current, clean]);
  }

  Future<void> _pick(WidgetRef ref, List<String> current) async {
    try {
      final path = await FilePicker.getDirectoryPath(dialogTitle: tx.carpetasExcluidas);
      if (path == null || current.contains(path)) return;
      await _set(ref, [...current, path]);
    } catch (error) {
      debugPrint('=== BIBLIOTECA: no se pudo elegir la carpeta a excluir: ${error.runtimeType} ===');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(settingsProvider.select((s) => s.localExclusions.folders));
    final isDefault = ref.watch(settingsProvider.select((s) => s.excludedFolders == null));
    return Scaffold(
      appBar: AppBar(title: Text(tx.carpetasExcluidas)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(tx.carpetasExcluidasDescripcion, style: TextStyle(color: KijiColors.muted)),
          ),
          if (folders.isEmpty) ListTile(title: Text(tx.ningunaCarpetaExcluida)),
          for (final folder in folders)
            ListTile(
              key: ValueKey('excluded-$folder'),
              leading: const Icon(Icons.folder_off_outlined),
              title: Text(folder, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                tooltip: tx.quitar,
                icon: const Icon(Icons.close_rounded),
                onPressed: () => _set(ref, [for (final f in folders) if (f != folder) f]),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('excluded-add-name'),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(tx.agregarCarpetaPorNombre),
                  onPressed: () => _addByName(context, ref, folders),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.folder_open_outlined),
                  label: Text(tx.elegirCarpeta),
                  onPressed: () => _pick(ref, folders),
                ),
                if (!isDefault)
                  TextButton(
                    key: const Key('excluded-defaults'),
                    onPressed: () =>
                        ref.read(settingsProvider.notifier).update((s) => s.copyWith(defaultExcludedFolders: true)),
                    child: Text(tx.volverALasDeFabrica),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(tx.carpetasExcluidasNota, style: TextStyle(color: KijiColors.muted, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// Pide el nombre de una carpeta (el campo vive lo mismo que el diálogo).
class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tx.agregarCarpetaPorNombre),
    content: TextField(
      key: const Key('excluded-name'),
      controller: _controller,
      autofocus: true,
      decoration: InputDecoration(labelText: tx.nombreDeLaCarpeta),
      onSubmitted: (v) => Navigator.pop(context, v),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text(tx.cancelar)),
      FilledButton(
        key: const Key('excluded-name-ok'),
        onPressed: () => Navigator.pop(context, _controller.text),
        child: Text(tx.agregar),
      ),
    ],
  );
}
