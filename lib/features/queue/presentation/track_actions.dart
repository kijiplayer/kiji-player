// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivo de referencia: app/src/main/kotlin/.../ui/menu/QueueMenu.kt ("reproducir a
// continuación" y "agregar a la cola").

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/track.dart';
import '../../../providers/downloads_provider.dart';
import '../../../providers/playback_provider.dart';
import '../../downloads/presentation/download_button.dart' show confirmDeleteDownload;
import '../../selection/track_selection.dart' show TrackSelection, downloadSelection;
import '../../local_library/presentation/tag_editor_sheet.dart';
import '../../share_cards/now_playing_card.dart' show showShareCardScreen;
import '../../../widgets/global_mini_player.dart' show kijiNavigatorKey;
import '../../customize/presentation/customize_sheets.dart';
import '../../playback_extras/data/share_track.dart';
import '../../playlists/presentation/playlist_screens.dart';
import '../../sleep_timer/sleep_timer_provider.dart';
import '../../customize/presentation/track_text.dart';

import 'package:kiji_player/l10n/l10n.dart';
import 'package:kiji_player/widgets/nocturne/kiji_sheet.dart';

/// Menú de una canción (mantener presionado en el celular, clic derecho en la
/// PC): "Reproducir a continuación" y "Agregar a la cola".
Future<void> showTrackActions(BuildContext context, WidgetRef ref, Track track) {
  final messenger = ScaffoldMessenger.of(context);
  // El de la pantalla de atrás: el de la hoja deja de servir al cerrarla.
  // Si quien abrió el menú ya no existe (la barra de selección se va al soltarla), el navegador
  // principal.
  BuildContext outer() => context.mounted ? context : (kijiNavigatorKey.currentContext ?? context);
  final notifier = ref.read(playbackProvider.notifier);
  // "Pausar al terminar esta" solo tiene sentido si la canción está en la cola.
  final inQueue = ref.read(playbackProvider).queue.any((t) => t.id == track.id);
  final downloaded = ref.read(downloadsProvider).completed.containsKey(track.youtubeVideoId);

  void done(String message) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  return showKijiSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(child: Column(
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
          // Descargar o, si ya está, «Quitar descarga» (0.9: en el mismo lugar donde se descarga).
          if (track.youtubeVideoId case final videoId?)
            if (downloaded)
              ListTile(
                key: const Key('track-action-remove-download'),
                leading: const Icon(Icons.file_download_off_outlined),
                title: Text(tx.quitarDescarga),
                onTap: () {
                  Navigator.pop(context);
                  confirmDeleteDownload(outer(), ref, track.title, videoId);
                },
              )
            else
              ListTile(
                key: const Key('track-action-download'),
                leading: const Icon(Icons.download_rounded),
                title: Text(tx.descargar),
                onTap: () {
                  Navigator.pop(context);
                  downloadSelection(outer(), ref, TrackSelection()..toggle(track.id, track));
                },
              ),
          // Canciones del dispositivo: editar las etiquetas en el archivo (0.9, solo en la PC: en Android
          // hace falta pedir permiso de escritura por archivo con MediaStore.createWriteRequest; 1.0).
          if (track.source == TrackSource.local && defaultTargetPlatform != TargetPlatform.android)
            ListTile(
              key: const Key('track-action-edit-tags'),
              leading: const Icon(Icons.sell_outlined),
              title: Text(tx.editarEtiquetas),
              onTap: () {
                Navigator.pop(context);
                showTagEditorSheet(outer(), ref, track);
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
          // Tarjeta para historias o publicaciones (0.9): portada, título y artista; sin letras.
          ListTile(
            key: const Key('track-action-share-card'),
            leading: const Icon(Icons.style_outlined),
            title: Text(tx.compartirTarjeta),
            subtitle: Text(tx.compartirTarjetaNota),
            onTap: () {
              Navigator.pop(context);
              showShareCardScreen(outer(), track);
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
      )),
    ),
  );
}
