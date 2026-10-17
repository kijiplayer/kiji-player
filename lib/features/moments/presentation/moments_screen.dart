import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/track.dart';
import '../../../providers/playback_provider.dart';
import '../../../theme/kiji_tokens.dart';
import '../../../utils/duration_formatter.dart';
import '../../../widgets/album_cover.dart';
import '../../customize/presentation/track_text.dart';
import '../data/moments_store.dart';
import '../domain/moment.dart';

/// Guarda el segundo que suena como Momento y lo avisa (botón del reproductor).
void saveCurrentMoment(BuildContext context, WidgetRef ref) {
  final playback = ref.read(playbackProvider);
  final track = playback.track;
  if (track == null) return;
  final moment = ref.read(momentsProvider.notifier).add(track, playback.position);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text('Momento guardado en ${formatDuration(moment.position)}'),
      persist: false,
      action: SnackBarAction(label: 'Ver', onPressed: () => MomentsScreen.open(context)),
    ));
}

/// Ir a un Momento: la canción arranca en ese segundo.
Future<void> playMoment(WidgetRef ref, Moment moment) {
  final playback = ref.read(playbackProvider);
  final notifier = ref.read(playbackProvider.notifier);
  if (playback.track?.id == moment.track.id && playback.isInitialized) {
    return notifier.seekTo(moment.position).then((_) => notifier.play());
  }
  return notifier.playTrack(moment.track, startAt: moment.position);
}

/// Tus Momentos (Tarea Z6): tocarlos va a ese segundo; se comparten y se
/// borran (con Deshacer).
class MomentsScreen extends ConsumerWidget {
  const MomentsScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MomentsScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moments = ref.watch(momentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Momentos')),
      body: moments.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Guardá el segundo exacto de una canción (el solo, el estribillo) con el botón '
                '"Momento" del reproductor. Aparecen acá para volver a ellos con un toque.',
                style: TextStyle(color: KijiColors.muted),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: moments.length,
              itemBuilder: (context, i) => _MomentTile(moment: moments[i]),
            ),
    );
  }
}

class _MomentTile extends ConsumerWidget {
  const _MomentTile({required this.moment});

  final Moment moment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Track track = moment.track;
    return ListTile(
      leading: TrackArtwork(track: track, size: 48, radius: 10),
      title: TrackTitleText(track, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          Text(formatDuration(moment.position), style: KijiText.mono(size: 12, color: KijiColors.cyan)),
          const SizedBox(width: 8),
          Expanded(child: TrackArtistText(track, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
      onTap: () => playMoment(ref, moment),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Compartir',
            icon: const Icon(Icons.share_outlined),
            onPressed: () async {
              try {
                await SharePlus.instance.share(ShareParams(text: momentShareText(moment), subject: track.title));
              } catch (error) {
                debugPrint('=== COMPARTIR: no se pudo abrir el menú: $error ===');
              }
            },
          ),
          IconButton(
            tooltip: 'Borrar',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () {
              final notifier = ref.read(momentsProvider.notifier);
              final removed = notifier.remove(moment.id);
              if (removed == null) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: const Text('Se borró el Momento'),
                  persist: false,
                  action: SnackBarAction(label: 'Deshacer', onPressed: () => notifier.restore(removed.$1, removed.$2)),
                ));
            },
          ),
        ],
      ),
    );
  }
}
