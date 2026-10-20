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

import 'package:kiji_player/l10n/l10n.dart';

/// Texto para compartir una playlist: nombre y una línea por canción, con su
/// enlace de YouTube Music si tiene. No sube nada: lo manda quien comparte.
String playlistShareText(Playlist playlist) {
  final b = StringBuffer(tx.canciones2(playlist.name, playlist.tracks.length));
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
                title: Text(tx.reproducir),
                onTap: () => then(() async => onPlay()),
              ),
              ListTile(
                enabled: !empty,
                leading: const Icon(Icons.shuffle_rounded),
                title: Text(tx.aleatorio),
                onTap: () => then(() async => onShuffle()),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(tx.editar),
                subtitle: Text(tx.nombreDescripcionYColor),
                onTap: () => then(() => showCustomizePlaylistSheet(context, ref, playlist)),
              ),
              ListTile(
                leading: const Icon(Icons.photo_outlined),
                title: Text(tx.cambiarFoto),
                onTap: () => then(() => changePlaylistPhoto(context, ref, playlist)),
              ),
              ListTile(
                leading: Icon(playlist.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded),
                title: Text(playlist.pinned ? tx.desfijar : tx.fijarArriba),
                onTap: () => then(() async => notifier.setPinned(playlist.id, !playlist.pinned)),
              ),
              ListTile(
                enabled: !empty,
                leading: const Icon(Icons.download_for_offline_outlined),
                title: Text(tx.descargarTodaLaPlaylist),
                onTap: () => then(() => confirmPlaylistDownload(context, ref, playlist)),
              ),
              ListTile(
                enabled: !empty,
                leading: const Icon(Icons.share_outlined),
                title: Text(tx.compartir),
                subtitle: Text(tx.laListaDeCancionesComoTexto),
                onTap: () => then(() async {
                  try {
                    await SharePlus.instance.share(
                      ShareParams(text: playlistShareText(playlist), subject: playlist.name),
                    );
                  } catch (error) {
                    debugPrint('=== COMPARTIR: no se pudo abrir el menú: $error ===');
                  }
                }),
              ),
              ListTile(
                enabled: !empty,
                leading: const Icon(Icons.file_upload_outlined),
                title: Text(tx.exportar),
                subtitle: Text(tx.m3u8OtrasAppsOCsvPlanillas),
                onTap: () => then(() => _export(context, playlist)),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF6B6B)),
                title: Text(tx.borrarLaPlaylist),
                subtitle: Text(tx.sePuedeDeshacer),
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
      title: Text(tx.exportarComo),
      children: [
        SimpleDialogOption(onPressed: () => Navigator.pop(dialog, 'm3u8'), child: Text(tx.m3u8ParaOtrasAppsDeMusica)),
        SimpleDialogOption(onPressed: () => Navigator.pop(dialog, 'csv'), child: Text(tx.csvParaPlanillas)),
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
    messenger.showSnackBar(
      SnackBar(
        content: Text(plan.alreadyDownloaded > 0 ? tx.yaEstanTodasDescargadas : tx.estaPlaylistNoTieneCancionesDe),
      ),
    );
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
      title: Text(tx.descargarTodaLaPlaylist),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tx.cancionesParaBajar(plan.toDownload.length)),
          if (plan.alreadyDownloaded > 0) Text(tx.yaEstabanDescargadasSeSaltean(plan.alreadyDownloaded)),
          if (plan.notFromYouTube > 0) Text(tx.sonArchivosTuyosNoHaceFalta(plan.notFromYouTube)),
          const SizedBox(height: 10),
          Text(tx.ocupanUnosEstimadoPorLaDuracion(formatBytes(plan.estimatedBytes))),
          Text(free == null ? tx.espacioLibreDesconocido : tx.espacioLibre(formatBytes(free))),
          if (downloads.settings.wifiOnly) ...[
            const SizedBox(height: 10),
            Text(tx.tienesSoloConWifiSiNo, style: const TextStyle(color: KijiColors.muted)),
          ],
          if (!fits) ...[
            const SizedBox(height: 10),
            Text(tx.noEntraEnElEspacioLibre, style: const TextStyle(color: Color(0xFFFF6B6B))),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(tx.cancelar)),
        FilledButton(onPressed: fits ? () => Navigator.pop(dialog, true) : null, child: Text(tx.descargar)),
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
        ? '${tx.nDescargadas(status.done)}${status.failed > 0 ? ', ${tx.nFallaron(status.failed)}' : ''}.'
        : tx.de(
            status.paused ? tx.enPausa : tx.descargando,
            status.done + status.failed,
            status.total,
            status.failed > 0 ? tx.conErrorSufijo(status.failed) : '',
          );
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
                    tooltip: tx.cerrar,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => notifier.dismiss(playlistId),
                  )
                else ...[
                  IconButton(
                    tooltip: status.paused ? tx.seguir : tx.pausar,
                    icon: Icon(status.paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                    onPressed: () => status.paused ? notifier.resume(playlistId) : notifier.pause(playlistId),
                  ),
                  IconButton(
                    tooltip: tx.cancelar,
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
                      label: Text(tx.verCuales),
                      onPressed: () => showFailedDownloadsSheet(context, ref, only: status.failedIds),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(tx.reintentarLasFallidas),
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
