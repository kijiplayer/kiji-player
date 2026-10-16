// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivo de referencia: app/src/main/kotlin/.../ui/menu/QueueMenu.kt ("reproducir a
// continuación" y "agregar a la cola").

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/track.dart';
import '../../../providers/playback_provider.dart';
import '../../playlists/presentation/playlist_screens.dart';
import '../../sleep_timer/sleep_timer_provider.dart';

/// Menú de una canción (mantener apretado en el celular, clic derecho en la
/// PC): "Reproducir a continuación" y "Agregar a la cola".
Future<void> showTrackActions(BuildContext context, WidgetRef ref, Track track) {
  final messenger = ScaffoldMessenger.of(context);
  final notifier = ref.read(playbackProvider.notifier);
  // "Pausar al terminar esta" solo tiene sentido si la canción está en la cola.
  final inQueue = ref.read(playbackProvider).queue.any((t) => t.id == track.id);

  void done(String message) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.playlist_play_rounded),
            title: const Text('Reproducir a continuación'),
            onTap: () {
              Navigator.pop(context);
              notifier.playNext(track);
              done('«${track.title}» suena después de esta');
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add_rounded),
            title: const Text('Agregar a la cola'),
            onTap: () {
              Navigator.pop(context);
              notifier.addToQueue(track);
              done('«${track.title}» se agregó al final de la cola');
            },
          ),
          ListTile(
            leading: const Icon(Icons.library_add_rounded),
            title: const Text('Agregar a playlist'),
            onTap: () {
              Navigator.pop(context);
              showAddToPlaylistSheet(context, ref, [track]);
            },
          ),
          if (inQueue)
            ListTile(
              leading: const Icon(Icons.bedtime_outlined),
              title: const Text('Pausar al terminar esta'),
              subtitle: const Text('El temporizador para cuando termine esta canción'),
              onTap: () {
                Navigator.pop(context);
                ref.read(sleepTimerProvider.notifier).startUntilTrack(track);
                done('La música se va a pausar al terminar «${track.title}»');
              },
            ),
        ],
      ),
    ),
  );
}
