import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../providers/downloads_provider.dart';
import '../../../providers/playback_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/byte_formatter.dart';
import '../domain/download_settings.dart';
import '../domain/downloaded_track.dart';
import '../../selection/track_selection.dart';
import '../../../theme/app_theme.dart' show KijiSelected;
import 'download_button.dart';
import '../../customize/presentation/track_text.dart';
import 'download_status.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Sección "Descargadas" de la Biblioteca: lo que se puede escuchar sin
/// conexión, cuánto ocupa, y las opciones de descarga.
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DownloadsScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(downloadsProvider.select((d) => d.completed.length));
    return Scaffold(
      appBar: AppBar(
        title: Text(tx.descargadas),
        actions: [
          if (count > 0)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: tx.borrarTodas,
              onPressed: () => confirmDeleteAllDownloads(context, ref, count),
            ),
        ],
      ),
      body: const DownloadsView(),
    );
  }
}

/// Contenido de "Descargadas": opciones, descargas en curso y terminadas.
/// Se usa como pantalla y como pestaña de la Biblioteca.
class DownloadsView extends ConsumerStatefulWidget {
  const DownloadsView({super.key, this.bottomPadding = 96});

  final double bottomPadding;

  @override
  ConsumerState<DownloadsView> createState() => _DownloadsViewState();
}

class _DownloadsViewState extends ConsumerState<DownloadsView> {
  /// Selección múltiple de las descargadas (mantener presionada una).
  final _selection = TrackSelection();

  @override
  void initState() {
    super.initState();
    _selection.addListener(_onSelection);
  }

  void _onSelection() => setState(() {});

  @override
  void dispose() {
    _selection
      ..removeListener(_onSelection)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final downloads = ref.watch(downloadsProvider);
    final completed = downloads.completed.values.toList()..sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    final active = downloads.active.values.toList();
    final selecting = _selection.active;

    // La barra de la selección va encima (de las opciones de arriba): la lista no se corre.
    return Stack(
      children: [
        Positioned.fill(
          // Lo de arriba como lista común; las descargadas, de a poco (pueden ser cientos).
          child: CustomScrollView(
            slivers: [
              SliverList.list(
                children: [
                  _SettingsCard(downloads: downloads),
                  if (active.any((d) => d.status == ActiveDownloadStatus.failed))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.warning_amber_rounded, color: downloadWarningColor),
                        label: Text(
                          tx.conErrorVerCuales(active.where((d) => d.status == ActiveDownloadStatus.failed).length),
                        ),
                        onPressed: () => showFailedDownloadsSheet(context, ref),
                      ),
                    ),
                  if (active.isNotEmpty) ...[
                    _SectionTitle(tx.descargando),
                    for (final download in active)
                      ListTile(
                        leading: _Cover(color: download.track.coverColor),
                        title: TrackTitleText(download.track, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          download.status == ActiveDownloadStatus.failed
                              ? download.errorMessage ?? tx.falloLaDescarga
                              : download.status == ActiveDownloadStatus.queued
                              ? tx.enCola
                              : download.total == null
                              ? formatBytes(download.received)
                              : tx.bytesDe(formatBytes(download.received), formatBytes(download.total!)),
                          maxLines: 2,
                        ),
                        trailing: DownloadButton(track: download.track),
                        onTap: download.status == ActiveDownloadStatus.failed && download.track.youtubeVideoId != null
                            ? () => showDownloadFailureSheet(context, ref, download.track.youtubeVideoId!)
                            : null,
                      ),
                  ],
                  _SectionTitle(
                    completed.isEmpty
                        ? tx.todaviaNoDescargasteNada
                        : '${tx.nCanciones(completed.length)} · ${formatBytes(downloads.usedBytes)}',
                  ),
                  if (completed.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(tx.buscaUnaCancionYTocaEl, style: TextStyle(color: AppColors.onSurfaceMuted)),
                    ),
                ],
              ),
              SliverList.builder(
                itemCount: completed.length,
                itemBuilder: (context, index) {
                  final track = completed[index];
                  return ListTile(
                    selected: _selection.contains(track.videoId),
                    selectedTileColor: KijiSelected.tile,
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selecting) ...[
                          SelectionCheck(selected: _selection.contains(track.videoId)),
                          const SizedBox(width: 10),
                        ],
                        _Cover(
                          color: track.coverColor,
                          imagePath: track.thumbnailFileName == null || downloads.directoryPath == null
                              ? null
                              : p.join(downloads.directoryPath!, track.thumbnailFileName!),
                        ),
                      ],
                    ),
                    title: TrackTitleText(track.toTrack(), maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${track.artist} · ${formatBytes(track.sizeBytes)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      tooltip: tx.borrarDescarga,
                      color: AppColors.onSurfaceMuted,
                      onPressed: () => confirmDeleteDownload(context, ref, track.title, track.videoId),
                    ),
                    onTap: selecting
                        ? () => _selection.toggle(track.videoId, track.toTrack())
                        : () => _playAll(ref, completed, index),
                    // Mantener presionada: empieza a elegir (con una sola, "Más" trae el menú de siempre).
                    onLongPress: () => _selection.toggle(track.videoId, track.toTrack()),
                  );
                },
              ),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    if (completed.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: OutlinedButton.icon(
                          onPressed: () => confirmDeleteAllDownloads(context, ref, completed.length),
                          icon: const Icon(Icons.delete_sweep_outlined),
                          label: Text(tx.borrarTodasLasDescargas),
                        ),
                      ),
                    SizedBox(height: widget.bottomPadding),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SelectionBar(
            selection: _selection,
            all: {for (final t in completed) t.videoId: t.toTrack()},
            remove: SelectionRemoveAction(
              label: tx.seleccionBorrarDescargas,
              icon: Icons.delete_outline_rounded,
              onRemove: (_, tracks) => deleteSelectedDownloads(context, ref, tracks),
            ),
          ),
        ),
      ],
    );
  }

  void _playAll(WidgetRef ref, List<DownloadedTrack> tracks, int index) {
    ref.read(playbackProvider.notifier).playQueue([for (final track in tracks) track.toTrack()], startIndex: index);
  }
}

/// Pregunta antes de borrar todas las descargas.
Future<void> confirmDeleteAllDownloads(BuildContext context, WidgetRef ref, int count) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tx.borrarTodasLasDescargas2),
      content: Text(tx.seBorranNDelDispositivo(count)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tx.cancelar)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tx.borrarTodas)),
      ],
    ),
  );
  if (confirmed == true) await ref.read(downloadsProvider.notifier).deleteAll();
}

class _SettingsCard extends ConsumerWidget {
  const _SettingsCard({required this.downloads});

  final DownloadsState downloads;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(downloadsProvider.notifier);
    final settings = downloads.settings;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: AppColors.surfaceContainer,
      child: Column(
        children: [
          SwitchListTile(
            title: Text(tx.descargarSoloConWifi),
            subtitle: Text(tx.noUsaTusDatosMoviles),
            value: settings.wifiOnly,
            onChanged: notifier.setWifiOnly,
          ),
          ListTile(
            title: Text(tx.limiteDeEspacio),
            subtitle: Text(
              settings.limitBytes == null
                  ? tx.sinLimite
                  : tx.usadoDe(formatBytes(downloads.usedBytes), formatBytes(settings.limitBytes!)),
            ),
            trailing: DropdownButton<int?>(
              value: settings.limitBytes,
              underline: const SizedBox.shrink(),
              items: [
                for (final option in DownloadSettings.limitOptions)
                  DropdownMenuItem(value: option, child: Text(option == null ? tx.sinLimite : formatBytes(option))),
              ],
              onChanged: notifier.setLimit,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.onSurfaceMuted)),
  );
}

class _Cover extends StatelessWidget {
  const _Cover({required this.color, this.imagePath});

  final Color color;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: color,
      child: const Icon(Icons.music_note_rounded, color: Colors.white70, size: 20),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 44,
        height: 44,
        child: imagePath == null
            ? fallback
            : Image.file(File(imagePath!), fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
      ),
    );
  }
}
