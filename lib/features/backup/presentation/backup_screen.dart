// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivo de referencia: ui/screens/settings/BackupAndRestore.kt. Diseño y código propios.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/kiji_tokens.dart';
import '../../../utils/byte_formatter.dart';
import '../../../utils/clock_format.dart';
import '../../../widgets/nocturne/glass.dart';
import '../../settings/data/settings_store.dart';
import '../data/backup_notifier.dart';
import '../data/backup_service.dart';
import '../domain/backup_manifest.dart';
import '../data/backup_folder.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Configuración → Copia de seguridad → "Copia de seguridad de Kiji".
class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BackupScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backup = ref.watch(backupProvider);
    final notifier = ref.read(backupProvider.notifier);
    final auto = ref.watch(settingsProvider.select((s) => s.autoBackup));
    final customFolder = ref.watch(settingsProvider.select((s) => s.backupFolder)) != null;
    final last = backup.lastBackup;

    return Scaffold(
      appBar: AppBar(title: Text(tx.copiaDeSeguridad)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Text(tx.unaCopiaDeTusPlaylistsMe, style: const TextStyle(color: KijiColors.muted)),
          const SizedBox(height: 16),
          Glass(
            blur: false,
            radius: KijiRadii.tile,
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(tx.copiaAutomaticaDiaria),
                    subtitle: Text(
                      last == null ? tx.todaviaNoHayCopias : tx.ultimaCopia(describeDate(last, DateTime.now())),
                    ),
                    value: auto,
                    onChanged: notifier.setAutoBackup,
                  ),
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(tx.carpeta),
                    subtitle: Text(backup.folder?.path ?? tx.buscando),
                    trailing: TextButton(onPressed: () => _chooseFolder(context, ref), child: Text(tx.cambiar)),
                  ),
                  if (customFolder)
                    ListTile(
                      leading: const Icon(Icons.undo_rounded),
                      title: Text(tx.volverALaCarpetaDeFabrica),
                      subtitle: const Text('Documentos/$backupFolderName'),
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
                    if (context.mounted) _say(context, ok ? tx.copiaHecha : tx.noSePudoHacerLaCopia2);
                  },
            icon: backup.busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.backup_outlined),
            label: Text(tx.hacerUnaCopiaAhora),
          ),
          if (backup.error != null) ...[
            const SizedBox(height: 8),
            Text(backup.error!, style: const TextStyle(color: Colors.orangeAccent)),
          ],
          const SizedBox(height: 20),
          Text(tx.copias, style: KijiText.mono(size: 11)),
          const SizedBox(height: 8),
          if (backup.copies.isEmpty) Text(tx.noHayCopiasEnEstaCarpeta, style: const TextStyle(color: KijiColors.muted)),
          for (final copy in backup.copies)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(describeDate(copy.date, DateTime.now())),
              subtitle: Text(formatBytes(copy.sizeBytes)),
              trailing: TextButton(
                onPressed: backup.busy ? null : () => _restore(context, ref, copy.file),
                child: Text(tx.restaurar),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: backup.busy ? null : () => _pickAndRestore(context, ref),
            icon: const Icon(Icons.file_open_outlined),
            label: Text(tx.restaurarDesdeUnArchivo),
          ),
          const SizedBox(height: 4),
          Text(tx.porEjemploUnaCopiaDeOtro, style: const TextStyle(color: KijiColors.muted, fontSize: 12)),
        ],
      ),
    );
  }

  static void _say(BuildContext context, String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _chooseFolder(BuildContext context, WidgetRef ref) async {
    final path = await FilePicker.getDirectoryPath(dialogTitle: tx.carpetaParaLasCopiasDeKiji);
    if (path == null) return;
    final problem = await ref.read(backupProvider.notifier).setFolder(path);
    if (context.mounted) _say(context, problem ?? tx.lasCopiasSeVanAGuardar(path));
  }

  Future<void> _pickAndRestore(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.pickFiles(dialogTitle: tx.eligeUnaCopiaDeKiji, type: FileType.any);
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
        title: Text(tx.restaurarEstaCopia),
        content: Text(restorePreviewText(preview.manifest)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tx.cancelar)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tx.restaurar2)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await notifier.restore(file);
    } catch (error) {
      if (context.mounted) _say(context, tx.noSePudoRestaurar(error));
      return;
    }
    if (!context.mounted) return;
    _say(context, tx.listoLoQueTeniasAntesQuedo);
    if (preview.downloads.isEmpty) return;
    final again = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tx.volverABajarTusDescargas),
        content: Text(
          tx.laCopiaTieneElAudioNo(tx.nCancionesDescargadas(preview.downloads.length)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tx.ahoraNo)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tx.volverABajar)),
        ],
      ),
    );
    if (again != true || !context.mounted) return;
    final (started, blocked) = await notifier.redownload(preview.downloads);
    if (context.mounted) {
      _say(context, blocked == null ? tx.bajandoNCanciones(started) : tx.bajandoLasDemasNo(started, blocked));
    }
  }
}

/// "hoy 08:30", "ayer 21:10" o "14/10/2026 09:00" (o "9:10 PM", según el formato de hora).
String describeDate(DateTime date, DateTime now, {bool? use24Hour}) {
  String two(int n) => n.toString().padLeft(2, '0');
  final time = formatClock(date, use24Hour: use24Hour);
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return tx.hoyA(time);
  if (diff == 1) return tx.ayerA(time);
  return '${two(date.day)}/${two(date.month)}/${date.year} $time';
}

/// Vista previa antes de restaurar.
String restorePreviewText(BackupManifest manifest) {
  final c = manifest.counts;
  String n(int count, String one, String many) => '$count ${count == 1 ? one : many}';
  final now = DateTime.now();
  final origin = switch (manifest.platform) {
    'android' => tx.deUnCelularAndroid,
    'windows' => tx.deUnaPcConWindows,
    _ => '',
  };
  final when = describeDate(manifest.createdAt, now);
  // "de hoy" / "del 20/10/2026" en español; en inglés, sin artículo.
  final daysAgo = DateTime(now.year, now.month, now.day)
      .difference(DateTime(manifest.createdAt.year, manifest.createdAt.month, manifest.createdAt.day))
      .inDays;
  final of = daysAgo <= 1 ? tx.copiaArticuloDiaRelativo : tx.copiaArticuloFecha;
  return tx.copiaEnElHistorialElAudio(
    of,
    when,
    origin,
    tx.nPlaylists(c.playlists),
    tx.nMeGusta(c.likes),
    tx.nCanciones(c.history),
    n(c.downloads, tx.cancionDescargada, tx.cancionesDescargadas),
    c.covers > 0 ? '• ${n(c.covers, tx.caratulaPersonalizada, tx.caratulasPersonalizadas)}\n' : '',
  );
}
