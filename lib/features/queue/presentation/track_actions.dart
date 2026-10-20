// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivo de referencia: app/src/main/kotlin/.../ui/menu/QueueMenu.kt ("reproducir a
// continuación" y "agregar a la cola").

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/track.dart';
import '../../../providers/playback_provider.dart';
import '../../customize/presentation/customize_sheets.dart';
import '../../playback_extras/data/share_track.dart';
import '../../playlists/presentation/playlist_screens.dart';
import '../../sleep_timer/sleep_timer_provider.dart';
import '../../customize/presentation/track_text.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Menú de una canción (mantener presionado en el celular, clic derecho en la
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
            title: TrackTitleText(track, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: TrackArtistText(track, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.playlist_play_rounded),
            title: Text(tx.reproducirAContinuacion),
            onTap: () {
              Navigator.pop(context);
              notifier.playNext(track);
              done(tx.suenaDespuesDeEsta(track.title));
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add_rounded),
            title: Text(tx.agregarALaCola),
            onTap: () {
              Navigator.pop(context);
              notifier.addToQueue(track);
              done(tx.seAgregoAlFinalDeLa(track.title));
            },
          ),
          ListTile(
            leading: const Icon(Icons.library_add_rounded),
            title: Text(tx.agregarAPlaylist),
            onTap: () {
              Navigator.pop(context);
              showAddToPlaylistSheet(context, ref, [track]);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(tx.personalizar2),
            subtitle: Text(tx.fotoTituloYArtistaSoloEn),
            onTap: () {
              Navigator.pop(context);
              showCustomizeTrackSheet(context, ref, track);
            },
          ),
          ListTile(
            leading: const Icon(Icons.share_rounded),
            title: Text(tx.compartir),
            subtitle: Text(
              track.youtubeVideoId != null
                  ? tx.conUnEnlaceDeSongLink
                  : tx.elTituloYElArtistaEs,
            ),
            onTap: () {
              Navigator.pop(context);
              shareTrack(track);
            },
          ),
          if (inQueue)
            ListTile(
              leading: const Icon(Icons.bedtime_outlined),
              title: Text(tx.pausarAlTerminarEsta),
              subtitle: Text(tx.elTemporizadorParaCuandoTermineEsta),
              onTap: () {
                Navigator.pop(context);
                ref.read(sleepTimerProvider.notifier).startUntilTrack(track);
                done(tx.laMusicaSeVaAPausar(track.title));
              },
            ),
        ],
      ),
    ),
  );
}
