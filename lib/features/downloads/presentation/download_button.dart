import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/track.dart';
import '../../../providers/downloads_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/kiji_tokens.dart';
import '../../../utils/byte_formatter.dart';
import 'download_status.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Ícono de descarga con 4 estados: descargar / progreso / lista / error.
/// Solo aparece para canciones de YouTube.
class DownloadButton extends ConsumerStatefulWidget {
  const DownloadButton({super.key, required this.track});

  final Track track;

  @override
  ConsumerState<DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends ConsumerState<DownloadButton> {
  bool _checking = false;

  @override
  Widget build(BuildContext context) {
    final videoId = widget.track.youtubeVideoId;
    if (videoId == null) return const SizedBox.shrink();

    final downloads = ref.watch(downloadsProvider);
    final active = downloads.active[videoId];

    if (_checking) {
      return const _Slot(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (downloads.completed.containsKey(videoId)) {
      return IconButton(
        icon: Icon(Icons.download_done_rounded, color: KijiColors.cyan),
        tooltip: tx.descargada,
        onPressed: () => confirmDeleteDownload(context, ref, widget.track.title, videoId),
      );
    }
    if (active == null) {
      return IconButton(
        icon: Icon(Icons.download_rounded, color: AppColors.onSurfaceMuted),
        tooltip: tx.descargar,
        onPressed: _startFlow,
      );
    }
    if (active.status == ActiveDownloadStatus.failed) {
      return IconButton(
        icon: const Icon(Icons.warning_amber_rounded, color: downloadWarningColor),
        tooltip: tx.noSePudoDescargarVerPor,
        onPressed: () => showDownloadFailureSheet(context, ref, videoId),
      );
    }
    return IconButton(
      tooltip: tx.cancelarDescarga,
      onPressed: () => _confirmCancel(videoId),
      // Anillo con el porcentaje. Tocarlo ofrece cancelar.
      icon: SizedBox(
        width: 30,
        height: 30,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: 2.5,
              color: KijiColors.cyan,
              backgroundColor: KijiColors.waveRest,
              value: active.status == ActiveDownloadStatus.queued ? null : active.progress,
            ),
            if (active.progress != null)
              Text('${(active.progress! * 100).round()}', style: KijiText.mono(size: 9, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Future<void> _startFlow() async {
    final videoId = widget.track.youtubeVideoId;
    setState(() => _checking = true);
    final notifier = ref.read(downloadsProvider.notifier);
    final check = await notifier.check(widget.track);
    if (!mounted) return;
    setState(() => _checking = false);

    if (!check.canDownload) {
      final failure = check.failure;
      if (failure != null) {
        // YouTube no dio el audio: queda en la lista con su motivo y sus opciones.
        notifier.recordFailure(widget.track, failure);
        await showDownloadFailureSheet(context, ref, videoId!);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(check.blockedReason ?? tx.noSePudoDescargar)));
      return;
    }

    final size = check.estimate!.sizeBytes;
    final free = check.freeBytes;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tx.descargarCancion),
        content: Text(
          tx.vaAOcuparSeGuardaDentro(
            widget.track.title,
            size == null ? tx.unTamanoDesconocido : formatBytes(size),
            free == null ? tx.noSePudoSaberElEspacioLibre : tx.teQuedanLibres(formatBytes(free)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tx.cancelar)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tx.descargar)),
        ],
      ),
    );
    if (confirmed == true) notifier.start(widget.track, check.estimate!);
  }

  Future<void> _confirmCancel(String videoId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tx.cancelarLaDescarga),
        content: Text(tx.seBorraLoQueSeHabia),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tx.seguir)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tx.cancelarDescarga)),
        ],
      ),
    );
    if (confirmed == true) await ref.read(downloadsProvider.notifier).cancel(videoId);
  }
}

/// Pregunta antes de borrar una descarga y explica qué pasa después.
Future<void> confirmDeleteDownload(BuildContext context, WidgetRef ref, String title, String videoId) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tx.borrarLaDescarga),
      content: Text(tx.dejaDeOcuparEspacioSiEsta(title)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tx.cancelar)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tx.borrar)),
      ],
    ),
  );
  if (confirmed == true) await ref.read(downloadsProvider.notifier).delete(videoId);
}

class _Slot extends StatelessWidget {
  const _Slot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(width: 48, height: 48, child: Center(child: child));
}
