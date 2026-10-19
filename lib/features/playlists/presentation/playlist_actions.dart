import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../providers/downloads_provider.dart';
import '../../../theme/kiji_tokens.dart';
import '../../../utils/byte_formatter.dart';
import '../../../utils/save_text_file.dart';
import '../../customize/presentation/customize_sheets.dart';
import '../../downloads/data/playlist_download.dart';
import '../../import/data/playlist_export.dart';
import '../domain/playlist.dart';
import '../playlists_provider.dart';
import '../../downloads/presentation/download_status.dart';

/// Texto para compartir una playlist: nombre y una línea por canción, con su
/// enlace de YouTube Music si tiene. No sube nada: lo manda quien comparte.
String playlistShareText(Playlist playlist) {
  final b = StringBuffer('«${playlist.name}» (${playlist.tracks.length} canciones)\n');
  for (final (i, t) in playlist.tracks.indexed) {
    final id = t.youtubeVideoId;
    b.writeln('${i + 1}. ${t.artist} – ${t.title}${id == null ? '' : ' https://music.youtube.com/watch?v=$id'}');
  }
  return b.toString().trimRight();
}

/// El ⋯ grande de la cabecera: todas las opciones de la playlist (Tarea Z7).
Future<void> showPlaylistOptions(
  BuildContext context,
  WidgetRef ref,
  Playlist playlist, {
  required VoidCallback onPlay,
  required VoidCallback onShuffle,
  required VoidCallback onDelete,
}) {
  final notifier = ref.read(playlistsProvider.notifier);
  final empty = playlist.tracks.isEmpty;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) {
      void then(Future<void> Function() action) {
        Navigator.pop(sheet);
        action();
      }

      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: Text(playlist.name, style: KijiText.title(size: 18))),
              ListTile(
                enabled: !empty,
                leading: const Icon(Icons.play_arrow_rounded),
                title: const Text('Reproducir'),
                onTap: () => then(() async => onPlay()),
              ),
              ListTile(
                enabled: !empty,
                leading: const Icon(Icons.shuffle_rounded),
                title: const Text('Aleatorio'),
                onTap: () => then(() async => onShuffle()),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Editar'),
                subtitle: const Text('Nombre, descripción y color'),
                onTap: () => then(() => showCustomizePlaylistSheet(context, ref, playlist)),
              ),
              ListTile(
                leading: const Icon(Icons.photo_outlined),
                title: const Text('Cambiar foto'),
                onTap: () => then(() => changePlaylistPhoto(context, ref, playlist)),
              ),
              ListTile(
                leading: Icon(playlist.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded),
                title: Text(playlist.pinned ? 'Desfijar' : 'Fijar arriba'),
                onTap: () => then(() async => notifier.setPinned(playlist.id, !playlist.pinned)),
              ),
              ListTile(
                enabled: !empty,
                leading: const Icon(Icons.download_for_offline_outlined),
                title: const Text('Descargar toda la playlist'),
                onTap: () => then(() => confirmPlaylistDownload(context, ref, playlist)),
              ),
              ListTile(
                enabled: !empty,
                leading: const Icon(Icons.share_outlined),
                title: const Text('Compartir'),
                subtitle: const Text('La lista de canciones como texto'),
                onTap: () => then(() async {
                  try {
                    await SharePlus.instance.share(ShareParams(text: playlistShareText(playlist), subject: playlist.name));
                  } catch (error) {
                    debugPrint('=== COMPARTIR: no se pudo abrir el menú: $error ===');
                  }
                }),
              ),
              ListTile(
                enabled: !empty,
                leading: const Icon(Icons.file_upload_outlined),
                title: const Text('Exportar'),
                subtitle: const Text('.m3u8 (otras apps) o .csv (planillas)'),
                onTap: () => then(() => _export(context, playlist)),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF6B6B)),
                title: const Text('Borrar la playlist'),
                subtitle: const Text('Se puede deshacer'),
                onTap: () => then(() async => onDelete()),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _export(BuildContext context, Playlist playlist) async {
  final format = await showDialog<String>(
    context: context,
    builder: (dialog) => SimpleDialog(
      title: const Text('Exportar como'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(dialog, 'm3u8'),
          child: const Text('.m3u8 — para otras apps de música'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(dialog, 'csv'),
          child: const Text('.csv — para planillas'),
        ),
      ],
    ),
  );
  if (format == null || !context.mounted) return;
  await saveTextFile(
    context,
    exportFileName(playlist.name, format),
    format == 'csv' ? exportCsv(playlist) : exportM3u8(playlist),
  );
}

/// Antes de bajar toda la playlist: cuánto ocupa (estimado), cuánto espacio
/// libre queda y qué se saltea.
Future<void> confirmPlaylistDownload(BuildContext context, WidgetRef ref, Playlist playlist) async {
  final downloads = ref.read(downloadsProvider);
  final plan = planPlaylistDownload(playlist.tracks, downloads.completed.keys.toSet());
  final messenger = ScaffoldMessenger.of(context);
  if (plan.toDownload.isEmpty) {
    messenger.showSnackBar(SnackBar(
      content: Text(plan.alreadyDownloaded > 0
          ? 'Ya están todas descargadas.'
          : 'Esta playlist no tiene canciones de YouTube para descargar.'),
    ));
    return;
  }
  int? free;
  final dir = downloads.directoryPath;
  if (dir != null) free = await ref.read(storageInfoProvider).freeBytes(dir);
  if (!context.mounted) return;
  final fits = free == null || plan.estimatedBytes < free;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('Descargar toda la playlist'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${plan.toDownload.length} canciones para bajar.'),
          if (plan.alreadyDownloaded > 0) Text('${plan.alreadyDownloaded} ya estaban descargadas: se saltean.'),
          if (plan.notFromYouTube > 0) Text('${plan.notFromYouTube} son archivos tuyos: no hace falta bajarlas.'),
          const SizedBox(height: 10),
          Text('Ocupan unos ${formatBytes(plan.estimatedBytes)} (estimado por la duración).'),
          Text(free == null ? 'Espacio libre: desconocido.' : 'Espacio libre: ${formatBytes(free)}.'),
          if (downloads.settings.wifiOnly) ...[
            const SizedBox(height: 10),
            const Text(
              'Tienes "solo con WiFi": si no hay WiFi, la descarga espera en pausa.',
              style: TextStyle(color: KijiColors.muted),
            ),
          ],
          if (!fits) ...[
            const SizedBox(height: 10),
            const Text('No entra en el espacio libre del dispositivo.', style: TextStyle(color: Color(0xFFFF6B6B))),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancelar')),
        FilledButton(
          onPressed: fits ? () => Navigator.pop(dialog, true) : null,
          child: const Text('Descargar'),
        ),
      ],
    ),
  );
  if (ok == true) ref.read(playlistDownloadsProvider.notifier).start(playlist.id, plan);
}

/// Progreso de la descarga de la playlist, con Pausar/Seguir y Cancelar.
class PlaylistDownloadCard extends ConsumerWidget {
  const PlaylistDownloadCard({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(playlistDownloadsProvider.select((all) => all[playlistId]));
    if (status == null) return const SizedBox.shrink();
    final notifier = ref.read(playlistDownloadsProvider.notifier);
    final finished = status.finished;
    final title = finished
        ? '${status.done} ${status.done == 1 ? 'descargada' : 'descargadas'}'
            '${status.failed > 0 ? ', ${status.failed} ${status.failed == 1 ? 'falló' : 'fallaron'}' : ''}.'
        : '${status.paused ? 'En pausa' : 'Descargando'}: ${status.done + status.failed} de ${status.total}'
            '${status.failed > 0 ? ' (${status.failed} con error)' : ''}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        decoration: BoxDecoration(
          color: KijiColors.surfaceHigh,
          borderRadius: BorderRadius.circular(KijiRadii.tile),
          border: Border.all(color: KijiColors.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(finished ? Icons.download_done_rounded : Icons.downloading_rounded, color: KijiColors.cyan),
                const SizedBox(width: 10),
                Expanded(child: Text(title)),
                if (finished)
                  IconButton(
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => notifier.dismiss(playlistId),
                  )
                else ...[
                  IconButton(
                    tooltip: status.paused ? 'Seguir' : 'Pausar',
                    icon: Icon(status.paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                    onPressed: () => status.paused ? notifier.resume(playlistId) : notifier.pause(playlistId),
                  ),
                  IconButton(
                    tooltip: 'Cancelar',
                    icon: const Icon(Icons.stop_rounded),
                    onPressed: () => notifier.cancel(playlistId),
                  ),
                ],
              ],
            ),
            if (!finished) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: LinearProgressIndicator(value: status.progress),
              ),
            ],
            if (status.message != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 8),
                child: Text(status.message!, style: const TextStyle(color: KijiColors.muted, fontSize: 13)),
              ),
            if (finished && status.failedIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.list_alt_rounded),
                      label: const Text('Ver cuáles'),
                      onPressed: () => showFailedDownloadsSheet(context, ref, only: status.failedIds),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar las fallidas'),
                      onPressed: () => notifier.retryFailed(playlistId),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
