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
import '../../queue/presentation/track_actions.dart';
import 'download_button.dart';

/// Sección "Descargadas" de la Biblioteca: lo que se puede escuchar sin
/// conexión, cuánto ocupa, y las opciones de descarga.
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const DownloadsScreen()),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadsProvider);
    final completed = downloads.completed.values.toList()
      ..sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    final active = downloads.active.values.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Descargadas'),
        actions: [
          if (completed.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Borrar todas',
              onPressed: () => _confirmDeleteAll(context, ref, completed.length),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          _SettingsCard(downloads: downloads),
          if (active.isNotEmpty) ...[
            const _SectionTitle('Descargando'),
            for (final download in active)
              ListTile(
                leading: _Cover(color: download.track.coverColor),
                title: Text(download.track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  download.status == ActiveDownloadStatus.failed
                      ? download.errorMessage ?? 'Falló la descarga'
                      : download.status == ActiveDownloadStatus.queued
                          ? 'En cola'
                          : '${formatBytes(download.received)}'
                              '${download.total == null ? '' : ' de ${formatBytes(download.total!)}'}',
                  maxLines: 2,
                ),
                trailing: DownloadButton(track: download.track),
              ),
          ],
          _SectionTitle(
            completed.isEmpty
                ? 'Todavía no descargaste nada'
                : '${completed.length} ${completed.length == 1 ? 'canción' : 'canciones'} · '
                    '${formatBytes(downloads.usedBytes)}',
          ),
          if (completed.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Buscá una canción y tocá el ícono de descarga para escucharla sin conexión.',
                style: TextStyle(color: AppColors.onSurfaceMuted),
              ),
            ),
          for (final (index, track) in completed.indexed)
            ListTile(
              leading: _Cover(
                color: track.coverColor,
                imagePath: track.thumbnailFileName == null || downloads.directoryPath == null
                    ? null
                    : p.join(downloads.directoryPath!, track.thumbnailFileName!),
              ),
              title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${track.artist} · ${formatBytes(track.sizeBytes)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Borrar descarga',
                color: AppColors.onSurfaceMuted,
                onPressed: () => confirmDeleteDownload(context, ref, track.title, track.videoId),
              ),
              onTap: () => _playAll(ref, completed, index),
              onLongPress: () => showTrackActions(context, ref, track.toTrack()),
            ),
        ],
      ),
    );
  }

  void _playAll(WidgetRef ref, List<DownloadedTrack> tracks, int index) {
    ref.read(playbackProvider.notifier).playQueue(
          [for (final track in tracks) track.toTrack()],
          startIndex: index,
        );
  }

  Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref, int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar todas las descargas?'),
        content: Text(
          'Se borran $count ${count == 1 ? 'canción' : 'canciones'} del dispositivo. '
          'No se quitan de tu cola: vuelven a sonar desde internet.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Borrar todas')),
        ],
      ),
    );
    if (confirmed == true) await ref.read(downloadsProvider.notifier).deleteAll();
  }
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
            title: const Text('Descargar solo con WiFi'),
            subtitle: const Text('No usa tus datos móviles'),
            value: settings.wifiOnly,
            onChanged: notifier.setWifiOnly,
          ),
          ListTile(
            title: const Text('Límite de espacio'),
            subtitle: Text(
              settings.limitBytes == null
                  ? 'Sin límite'
                  : 'Usado ${formatBytes(downloads.usedBytes)} de ${formatBytes(settings.limitBytes!)}',
            ),
            trailing: DropdownButton<int?>(
              value: settings.limitBytes,
              underline: const SizedBox.shrink(),
              items: [
                for (final option in DownloadSettings.limitOptions)
                  DropdownMenuItem(
                    value: option,
                    child: Text(option == null ? 'Sin límite' : formatBytes(option)),
                  ),
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
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.onSurfaceMuted),
        ),
      );
}

class _Cover extends StatelessWidget {
  const _Cover({required this.color, this.imagePath});

  final Color color;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
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
