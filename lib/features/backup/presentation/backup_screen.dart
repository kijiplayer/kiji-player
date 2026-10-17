// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivo de referencia: ui/screens/settings/BackupAndRestore.kt. Diseño y código propios.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/kiji_tokens.dart';
import '../../../utils/byte_formatter.dart';
import '../../../widgets/nocturne/glass.dart';
import '../../settings/data/settings_store.dart';
import '../data/backup_notifier.dart';
import '../data/backup_service.dart';
import '../domain/backup_manifest.dart';

/// Configuración → Copia de seguridad → "Copia de seguridad de Kiji" (Tarea U).
class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const BackupScreen()),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backup = ref.watch(backupProvider);
    final notifier = ref.read(backupProvider.notifier);
    final auto = ref.watch(settingsProvider.select((s) => s.autoBackup));
    final customFolder = ref.watch(settingsProvider.select((s) => s.backupFolder)) != null;
    final last = backup.lastBackup;

    return Scaffold(
      appBar: AppBar(title: const Text('Copia de seguridad')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          const Text(
            'Una copia de tus playlists, me gusta, historial, ajustes, carátulas personalizadas y la '
            'lista de tus descargas (sin el audio). Es un archivo tuyo, en tu dispositivo: no va a '
            'ningún servidor. Se guardan las últimas 7.',
            style: TextStyle(color: KijiColors.muted),
          ),
          const SizedBox(height: 16),
          Glass(
            blur: false,
            radius: KijiRadii.tile,
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Copia automática diaria'),
                    subtitle: Text(last == null ? 'Todavía no hay copias.' : 'Última copia: ${describeDate(last, DateTime.now())}'),
                    value: auto,
                    onChanged: notifier.setAutoBackup,
                  ),
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: const Text('Carpeta'),
                    subtitle: Text(backup.folder?.path ?? 'Buscando…'),
                    trailing: TextButton(onPressed: () => _chooseFolder(context, ref), child: const Text('Cambiar')),
                  ),
                  if (customFolder)
                    ListTile(
                      leading: const Icon(Icons.undo_rounded),
                      title: const Text('Volver a la carpeta de fábrica'),
                      subtitle: const Text('Documentos/Kiji'),
                      onTap: () => notifier.setFolder(null),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: backup.busy
                ? null
                : () async {
                    final ok = await notifier.backupNow();
                    if (context.mounted) _say(context, ok ? 'Copia hecha' : 'No se pudo hacer la copia');
                  },
            icon: backup.busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.backup_outlined),
            label: const Text('Hacer una copia ahora'),
          ),
          if (backup.error != null) ...[
            const SizedBox(height: 8),
            Text(backup.error!, style: const TextStyle(color: Colors.orangeAccent)),
          ],
          const SizedBox(height: 20),
          Text('COPIAS', style: KijiText.mono(size: 11)),
          const SizedBox(height: 8),
          if (backup.copies.isEmpty)
            const Text('No hay copias en esta carpeta.', style: TextStyle(color: KijiColors.muted)),
          for (final copy in backup.copies)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(describeDate(copy.date, DateTime.now())),
              subtitle: Text(formatBytes(copy.sizeBytes)),
              trailing: TextButton(
                onPressed: backup.busy ? null : () => _restore(context, ref, copy.file),
                child: const Text('Restaurar…'),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: backup.busy ? null : () => _pickAndRestore(context, ref),
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('Restaurar desde un archivo…'),
          ),
          const SizedBox(height: 4),
          const Text(
            'Por ejemplo, una copia de otro teléfono o de la PC.',
            style: TextStyle(color: KijiColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  static void _say(BuildContext context, String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _chooseFolder(BuildContext context, WidgetRef ref) async {
    final path = await FilePicker.getDirectoryPath(dialogTitle: 'Carpeta para las copias de Kiji');
    if (path == null) return;
    final problem = await ref.read(backupProvider.notifier).setFolder(path);
    if (context.mounted) _say(context, problem ?? 'Las copias se van a guardar en $path');
  }

  Future<void> _pickAndRestore(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.pickFiles(dialogTitle: 'Elegí una copia de Kiji', type: FileType.any);
    final path = picked.isEmpty ? null : picked.first.path;
    if (path == null || !context.mounted) return;
    await _restore(context, ref, File(path));
  }

  Future<void> _restore(BuildContext context, WidgetRef ref, File file) async {
    final notifier = ref.read(backupProvider.notifier);
    final BackupPreview preview;
    try {
      preview = await notifier.preview(file);
    } catch (error) {
      if (context.mounted) _say(context, '$error');
      return;
    }
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Restaurar esta copia?'),
        content: Text(restorePreviewText(preview.manifest)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restaurar')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await notifier.restore(file);
    } catch (error) {
      if (context.mounted) _say(context, 'No se pudo restaurar: $error');
      return;
    }
    if (!context.mounted) return;
    _say(context, 'Listo. Lo que tenías antes quedó en una copia "antes de restaurar".');
    if (preview.downloads.isEmpty) return;
    final again = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Volver a bajar tus descargas?'),
        content: Text(
          'La copia tiene ${preview.downloads.length} '
          '${preview.downloads.length == 1 ? 'canción descargada' : 'canciones descargadas'}. '
          'El audio no va en la copia: se puede volver a bajar de YouTube (respeta "solo con WiFi").',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ahora no')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Volver a bajar')),
        ],
      ),
    );
    if (again != true || !context.mounted) return;
    final (started, blocked) = await notifier.redownload(preview.downloads);
    if (context.mounted) {
      _say(context, blocked == null ? 'Bajando $started canciones' : 'Bajando $started. Las demás no: $blocked');
    }
  }
}

/// "hoy 08:30", "ayer 21:10" o "14/10/2026 09:00".
String describeDate(DateTime date, DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  final time = '${two(date.hour)}:${two(date.minute)}';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'hoy $time';
  if (diff == 1) return 'ayer $time';
  return '${two(date.day)}/${two(date.month)}/${date.year} $time';
}

/// Vista previa antes de restaurar.
String restorePreviewText(BackupManifest manifest) {
  final c = manifest.counts;
  String n(int count, String one, String many) => '$count ${count == 1 ? one : many}';
  final origin = switch (manifest.platform) {
    'android' => ' (de un celular Android)',
    'windows' => ' (de una PC con Windows)',
    _ => '',
  };
  final when = describeDate(manifest.createdAt, DateTime.now());
  final of = when.startsWith('hoy') || when.startsWith('ayer') ? 'de' : 'del';
  return 'Copia $of $when$origin:\n'
      '• ${n(c.playlists, 'playlist', 'playlists')}\n'
      '• ${n(c.likes, 'me gusta', 'me gusta')}\n'
      '• ${n(c.history, 'canción', 'canciones')} en el historial\n'
      '• ${n(c.downloads, 'canción descargada', 'canciones descargadas')} (el audio se vuelve a bajar)\n'
      '${c.covers > 0 ? '• ${n(c.covers, 'carátula personalizada', 'carátulas personalizadas')}\n' : ''}'
      '\nReemplaza tus playlists, me gusta, historial y ajustes actuales. Antes, Kiji guarda una '
      'copia de lo que tenés ahora, así que se puede volver atrás.';
}
