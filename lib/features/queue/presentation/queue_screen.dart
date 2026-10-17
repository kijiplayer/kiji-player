// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivo de referencia: app/src/main/kotlin/.../ui/player/Queue.kt (lista de la cola,
// arrastrar para reordenar y deslizar para quitar).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/track.dart';
import '../../../providers/playback_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/kiji_tokens.dart';
import '../../sleep_timer/domain/sleep_timer_logic.dart';
import '../../sleep_timer/sleep_timer_provider.dart';
import '../../../widgets/album_cover.dart';
import '../../customize/presentation/track_text.dart';

/// "Qué suena después": reordenar arrastrando, quitar (con Deshacer) y
/// saltar a una canción. El orden se guarda solo (memoria de la Tarea A).
class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const QueueScreen()),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final queue = playback.queue;
    final upNext = queue.length - playback.currentIndex - 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cola'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                queue.isEmpty
                    ? 'La cola está vacía'
                    : upNext <= 0
                        ? 'Es la última canción de la cola'
                        : '$upNext ${upNext == 1 ? 'canción' : 'canciones'} después de esta',
                style: const TextStyle(color: AppColors.onSurfaceMuted),
              ),
            ),
          ),
        ),
      ),
      body: const QueueList(),
    );
  }
}

/// La lista de la cola: reordenar arrastrando, quitar (con Deshacer) y
/// saltar a una canción. La usan la pantalla "Cola" (celular) y el panel
/// "A continuación" (PC).
class QueueList extends ConsumerWidget {
  const QueueList({super.key, this.padding = const EdgeInsets.only(bottom: 32)});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final queue = playback.queue;
    final notifier = ref.read(playbackProvider.notifier);
    final timer = ref.watch(sleepTimerProvider);
    final pauseAfterId =
        timer?.mode == SleepTimerMode.untilTrack ? timer?.targetTrackId : null;

    return queue.isEmpty
          ? const Center(
              child: Text(
                'Elegí una canción para empezar.',
                style: TextStyle(color: AppColors.onSurfaceMuted),
              ),
            )
          : ReorderableListView.builder(
              // Agarradera propia: funciona igual con el dedo y con el mouse
              //. Mantener apretado en cualquier parte también.
              buildDefaultDragHandles: false,
              padding: padding,
              itemCount: queue.length,
              // onReorderItem ya da el destino ajustado (sin el elemento movido).
              onReorderItem: notifier.moveInQueue,
              itemBuilder: (context, index) {
                final track = queue[index];
                final isCurrent = index == playback.currentIndex;
                return _QueueTile(
                  // La misma canción puede repetirse en la cola: la clave
                  // combina id y posición.
                  key: ValueKey('${track.id}#$index'),
                  index: index,
                  track: track,
                  isCurrent: isCurrent,
                  isPlaying: isCurrent && playback.isPlaying,
                  onTap: () => notifier.playFromQueue(index),
                  onRemove: () => _remove(context, ref, index),
                  pauseAfter: track.id == pauseAfterId,
                  onTogglePauseAfter: () => track.id == pauseAfterId
                      ? ref.read(sleepTimerProvider.notifier).cancel()
                      : ref.read(sleepTimerProvider.notifier).startUntilTrack(track),
                );
              },
            );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, int index) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(playbackProvider.notifier);
    final removed = await notifier.removeFromQueue(index);
    if (removed == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Se quitó «${removed.track.title}» de la cola'),
        // Tiempo de sobra para arrepentirse (Cero Sorpresas: todo es reversible).
        duration: const Duration(seconds: 10),
        persist: false,
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => notifier.undoRemove(removed),
        ),
      ));
  }
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({
    super.key,
    required this.index,
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
    required this.onRemove,
    required this.pauseAfter,
    required this.onTogglePauseAfter,
  });

  final int index;
  final Track track;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  /// Tarea H2: el temporizador pausa al terminar esta canción (luna).
  final bool pauseAfter;
  final VoidCallback onTogglePauseAfter;

  @override
  Widget build(BuildContext context) {
    return ReorderableDelayedDragStartListener(
      index: index,
      child: Dismissible(
        key: ValueKey('quitar-${track.id}#$index'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          color: Colors.red.withValues(alpha: 0.35),
          child: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white),
        ),
        onDismissed: (_) => onRemove(),
        child: Material(
          color: isCurrent ? AppColors.surfaceContainer : Colors.transparent,
          child: ListTile(
            onTap: onTap,
            leading: Stack(
              alignment: Alignment.center,
              children: [
                AlbumCover(color: track.coverColor, size: 44, iconSize: 20),
                if (isCurrent)
                  Icon(
                    isPlaying ? Icons.graphic_eq_rounded : Icons.pause_rounded,
                    color: Colors.white,
                  ),
              ],
            ),
            title: TrackTitleText(
              track,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isCurrent ? AppColors.seed : null,
                fontWeight: isCurrent ? FontWeight.w600 : null,
              ),
            ),
            subtitle: Row(
              children: [
                if (pauseAfter) ...[
                  const Icon(Icons.bedtime_rounded, size: 14, color: KijiColors.cyan),
                  const SizedBox(width: 4),
                ],
                Expanded(child: TrackArtistText(track, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<String>(
                  tooltip: 'Más opciones',
                  icon: Icon(
                    pauseAfter ? Icons.bedtime_rounded : Icons.more_vert_rounded,
                    color: pauseAfter ? KijiColors.cyan : AppColors.onSurfaceMuted,
                  ),
                  onSelected: (_) => onTogglePauseAfter(),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'pausa',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(pauseAfter ? Icons.bedtime_off_outlined : Icons.bedtime_outlined),
                        title: Text(pauseAfter
                            ? 'Quitar la pausa programada'
                            : 'Pausar al terminar esta'),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Quitar de la cola',
                  color: AppColors.onSurfaceMuted,
                  onPressed: onRemove,
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: const MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.drag_handle_rounded, semanticLabel: 'Arrastrar para mover'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
