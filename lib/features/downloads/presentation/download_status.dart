import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/track.dart';
import '../../../providers/downloads_provider.dart';
import '../../../theme/kiji_tokens.dart';
import '../domain/download_failure.dart';
import '../../account/domain/yt_session.dart';
import '../../account/presentation/account_screens.dart';
import '../../extractor/domain/extraction_failure.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Color del aviso de una descarga con error.
const downloadWarningColor = Color(0xFFFFB84D);

/// Estado de descarga de una canción, para dibujarlo en cualquier lista.
enum DownloadMark { none, done, queued, downloading, failed }

/// (estado, porcentaje 0–100 o null) de [videoId]. Con `select` solo se redibuja la fila que cambió.
(DownloadMark, int?) downloadMarkOf(DownloadsState state, String videoId) {
  if (state.completed.containsKey(videoId)) return (DownloadMark.done, null);
  final active = state.active[videoId];
  if (active == null) return (DownloadMark.none, null);
  return switch (active.status) {
    ActiveDownloadStatus.failed => (DownloadMark.failed, null),
    ActiveDownloadStatus.queued => (DownloadMark.queued, null),
    ActiveDownloadStatus.downloading => (
      DownloadMark.downloading,
      active.progress == null ? null : (active.progress! * 100).round().clamp(0, 100),
    ),
  };
}

/// Lo que se dibuja encima de la carátula de una canción en las listas:
/// ✓ descargada · anillo con el % mientras baja · reloj en espera · ⚠ con error.
class DownloadStateOverlay extends ConsumerWidget {
  const DownloadStateOverlay({super.key, required this.videoId, required this.size});

  final String videoId;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (mark, percent) = ref.watch(downloadsProvider.select((s) => downloadMarkOf(s, videoId)));
    final badge = size * 0.36;
    Widget corner(Color color, IconData icon, String label) => Positioned(
      right: -2,
      bottom: -2,
      child: Semantics(
        label: label,
        child: Container(
          width: badge,
          height: badge,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: KijiColors.background, width: 1.5),
          ),
          child: Icon(icon, size: badge * 0.68, color: KijiColors.background),
        ),
      ),
    );
    return switch (mark) {
      DownloadMark.none => const SizedBox.shrink(),
      DownloadMark.done => corner(KijiColors.cyan, Icons.check_rounded, tx.descargada),
      DownloadMark.queued => corner(KijiColors.muted, Icons.schedule_rounded, tx.enEsperaParaDescargar),
      DownloadMark.failed => corner(downloadWarningColor, Icons.priority_high_rounded, tx.laDescargaFallo),
      DownloadMark.downloading => Positioned.fill(
        child: Semantics(
          label: tx.descargando2(percent == null ? '' : tx.porCiento(percent)),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(size * 0.18),
            ),
            alignment: Alignment.center,
            child: SizedBox(
              width: size * 0.7,
              height: size * 0.7,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: KijiColors.cyan,
                    backgroundColor: KijiColors.waveRest,
                    value: percent == null ? null : percent / 100,
                  ),
                  if (percent != null && size >= 40)
                    Text(
                      '$percent',
                      style: KijiText.mono(size: size * 0.22, color: Colors.white),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    };
  }
}

/// Por qué falló una descarga y qué se puede hacer: Reintentar, Buscar otra versión o quitarla.
Future<void> showDownloadFailureSheet(BuildContext context, WidgetRef ref, String videoId) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final download = ref.watch(downloadsProvider.select((s) => s.active[videoId]));
        if (download == null || download.status != ActiveDownloadStatus.failed) {
          final done = ref.read(downloadsProvider).completed.containsKey(videoId);
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Text(done ? tx.listoYaEstaDescargada : tx.descargandoOtraVez),
          );
        }
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  download.track.title,
                  style: KijiText.title(size: 18),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(download.track.artist, style: const TextStyle(color: KijiColors.muted)),
                const SizedBox(height: 14),
                _FailureReason(download: download),
                const SizedBox(height: 16),
                ..._failureActions(context, ref, videoId, download, closeOnAction: true),
              ],
            ),
          ),
        );
      },
    ),
  );
}

List<Widget> _failureActions(
  BuildContext context,
  WidgetRef ref,
  String videoId,
  ActiveDownload download, {
  bool closeOnAction = false,
}) {
  final notifier = ref.read(downloadsProvider.notifier);
  final failure = download.failure;
  final contentOnly = failure?.kind == DownloadFailureKind.content;
  void close() {
    if (closeOnAction) Navigator.of(context).pop();
  }

  return [
    if (download.searching)
      const Center(
        child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
      )
    else ...[
      if (failure?.canSearchAlternative ?? true)
        FilledButton.icon(
          icon: const Icon(Icons.manage_search_rounded),
          label: Text(tx.buscarOtraVersion),
          onPressed: () async {
            final found = await notifier.searchAlternative(videoId);
            if (!found && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tx.noHayOtraVersionDeEsta)));
            } else {
              close();
            }
          },
        ),
      // Restricción de edad: solo una cuenta lo resuelve (opcional, sin insistir).
      if (failure?.problem == ContentProblem.ageRestricted && !YtSessionHolder.signedIn) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.login_rounded),
          label: Text(tx.iniciarSesionParaBajarla),
          onPressed: () async {
            close();
            if (await LoginScreen.open(context)) notifier.retry(videoId);
          },
        ),
      ],
      const SizedBox(height: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.refresh_rounded),
        label: Text(contentOnly ? tx.reintentarIgual : tx.reintentarPruebaOtrasFormas),
        onPressed: () {
          notifier.retry(videoId);
          close();
        },
      ),
      TextButton.icon(
        icon: const Icon(Icons.close_rounded),
        label: Text(tx.quitarDeLaLista),
        onPressed: () {
          notifier.cancel(videoId);
          close();
        },
      ),
    ],
  ];
}

class _FailureReason extends StatelessWidget {
  const _FailureReason({required this.download});

  final ActiveDownload download;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.warning_amber_rounded, color: downloadWarningColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            download.failure?.message ?? DownloadFailure.unknown.message,
            style: const TextStyle(height: 1.35),
          ),
        ),
      ],
    );
  }
}

/// "Ver cuáles": las descargas que fallaron, con su motivo y qué hacer con cada una.
Future<void> showFailedDownloadsSheet(BuildContext context, WidgetRef ref, {Iterable<String>? only}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scroll) => Consumer(
        builder: (context, ref, _) {
          final failed = [
            for (final e in ref.watch(downloadsProvider).active.entries)
              if (e.value.status == ActiveDownloadStatus.failed && (only == null || only.contains(e.key))) e,
          ];
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              Text(
                failed.isEmpty ? tx.noQuedaNingunaConError : tx.noSePudieronDescargar(failed.length),
                style: KijiText.title(size: 20),
              ),
              if (failed.isNotEmpty) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(tx.reintentarTodas),
                  onPressed: () {
                    final n = ref.read(downloadsProvider.notifier).retryAll(failed.map((e) => e.key));
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tx.reintentando(n))));
                  },
                ),
              ],
              for (final e in failed)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _FailedCard(videoId: e.key, download: e.value),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _FailedCard extends ConsumerWidget {
  const _FailedCard({required this.videoId, required this.download});

  final String videoId;
  final ActiveDownload download;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KijiColors.surfaceHigh,
        borderRadius: BorderRadius.circular(KijiRadii.tile),
        border: Border.all(color: KijiColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            download.track.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            download.track.artist,
            style: const TextStyle(color: KijiColors.muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          _FailureReason(download: download),
          const SizedBox(height: 10),
          ..._failureActions(context, ref, videoId, download),
        ],
      ),
    );
  }
}

/// La canción de [track] tiene un estado de descarga que mostrar.
bool showsDownloadState(Track track) => track.youtubeVideoId != null;
