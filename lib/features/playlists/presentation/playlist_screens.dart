// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivos de referencia: app/src/main/kotlin/.../ui/screens/playlist/LocalPlaylistScreen.kt y
// AutoPlaylistScreen.kt.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/track.dart';
import '../../../providers/downloads_provider.dart';
import '../../../providers/local_library_provider.dart';
import '../../../providers/playback_provider.dart';
import '../../../theme/kiji_tokens.dart';
import '../../../widgets/album_cover.dart';
import '../../../widgets/nocturne/glass.dart';
import '../../favorites/favorites.dart';
import '../../history/listening_history.dart';
import '../../moments/data/moments_store.dart';
import '../../moments/presentation/moments_screen.dart';
import '../../queue/presentation/track_actions.dart';
import '../domain/smart_lists.dart';
import '../playlists_provider.dart';
import '../../customize/presentation/track_text.dart';
import '../../customize/presentation/customize_sheets.dart';
import '../domain/playlist.dart';
import 'playlist_actions.dart';

/// Datos de las listas inteligentes, calculados en el teléfono.
final smartListInputsProvider = Provider<SmartListInputs>((ref) => SmartListInputs(
      now: DateTime.now(),
      liked: ref.watch(favoritesProvider).values.toList(),
      history: ref.watch(listeningHistoryProvider),
      downloaded: [for (final d in ref.watch(downloadsProvider).completed.values) d.toTrack()],
      local: ref.watch(localTracksProvider).value ?? const [],
    ));

/// Reproduce [tracks]; con [shuffle], activa el aleatorio y empieza por una al azar.
void _play(WidgetRef ref, List<Track> tracks, {bool shuffle = false}) {
  if (tracks.isEmpty) return;
  final notifier = ref.read(playbackProvider.notifier);
  if (shuffle && !ref.read(playbackProvider).shuffleEnabled) notifier.toggleShuffle();
  notifier.playQueue(tracks, startIndex: shuffle ? Random().nextInt(tracks.length) : 0);
}

/// Pide un nombre (crear o renombrar).
Future<String?> promptPlaylistName(BuildContext context, {String initial = '', String title = 'Nueva playlist'}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Nombre de la playlist'),
        onSubmitted: (value) => Navigator.pop(context, value.trim().isEmpty ? null : value.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            Navigator.pop(context, value.isEmpty ? null : value);
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}

/// "Agregar a playlist" (desde el menú de cualquier canción).
Future<void> showAddToPlaylistSheet(BuildContext context, WidgetRef ref, List<Track> tracks) {
  final messenger = ScaffoldMessenger.of(context);
  final notifier = ref.read(playlistsProvider.notifier);
  void done(String message) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Consumer(
        builder: (context, ref, _) {
          final playlists = ref.watch(playlistsProvider);
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
            child: ListView(
              shrinkWrap: true,
              children: [
                const ListTile(title: Text('Agregar a playlist')),
                ListTile(
                  leading: const Icon(Icons.add_rounded, color: KijiColors.cyan),
                  title: const Text('Nueva playlist'),
                  onTap: () async {
                    final name = await promptPlaylistName(context);
                    if (name == null) return;
                    final created = notifier.create(name, tracks: tracks);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                    done('Se creó «${created.name}»');
                  },
                ),
                for (final playlist in playlists)
                  ListTile(
                    leading: const Icon(Icons.queue_music_rounded, color: KijiColors.violet),
                    title: Text(playlist.name),
                    subtitle: Text(_count(playlist.tracks.length)),
                    onTap: () {
                      final added = notifier.addTracks(playlist.id, tracks);
                      Navigator.pop(sheetContext);
                      done(added == 0
                          ? 'Ya estaba en «${playlist.name}»'
                          : 'Se agregó a «${playlist.name}»');
                    },
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

String _count(int n) => '$n ${n == 1 ? 'canción' : 'canciones'}';

/// Pestaña Playlists de la Biblioteca: listas inteligentes y tus playlists.
class PlaylistsView extends ConsumerWidget {
  const PlaylistsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    final inputs = ref.watch(smartListInputsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(child: Text('TUS PLAYLISTS', style: KijiText.mono(size: 11))),
              TextButton.icon(
                onPressed: () async {
                  final name = await promptPlaylistName(context);
                  if (name != null) ref.read(playlistsProvider.notifier).create(name);
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nueva'),
              ),
            ],
          ),
        ),
        if (playlists.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Todavía no creaste ninguna. Mantené apretada una canción → "Agregar a playlist".',
              style: TextStyle(color: KijiColors.muted),
            ),
          ),
        for (final playlist in PlaylistOps.pinnedFirst(playlists))
          ListTile(
            leading: PlaylistCover(playlist: playlist),
            title: Row(
              children: [
                if (playlist.pinned) ...[
                  const Icon(Icons.push_pin_rounded, size: 14, color: KijiColors.cyan, semanticLabel: 'Fijada'),
                  const SizedBox(width: 4),
                ],
                Expanded(child: Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            subtitle: Text(_count(playlist.tracks.length), style: const TextStyle(color: KijiColors.muted)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => PlaylistScreen.open(context, playlist.id),
          ),
        ListTile(
          leading: const Icon(Icons.bookmarks_outlined, color: KijiColors.cyan),
          title: const Text('Momentos'),
          subtitle: Text(
            '${ref.watch(momentsProvider).length} segundos guardados de tus canciones',
            style: const TextStyle(color: KijiColors.muted),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => MomentsScreen.open(context),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text('LISTAS INTELIGENTES · CALCULADAS EN TU TELÉFONO', style: KijiText.mono(size: 11)),
        ),
        for (final list in SmartList.values)
          ListTile(
            leading: const Icon(Icons.auto_awesome_rounded, color: KijiColors.cyan),
            title: Text(list.title),
            subtitle: Text(
              '${list.rule} · ${_count(list.compute(inputs).length)}',
              style: const TextStyle(color: KijiColors.muted),
            ),
            onTap: () => SmartListScreen.open(context, list),
          ),
      ],
    );
  }
}

/// Cabecera de una lista: nombre, cantidad, Reproducir y Aleatorio.
class _ListHeader extends ConsumerWidget {
  const _ListHeader({
    required this.title,
    required this.subtitle,
    required this.tracks,
    this.cover,
    this.description,
    this.onMore,
  });

  final String title;
  final String subtitle;
  final List<Track> tracks;

  /// Foto de la playlist (Tarea Z3).
  final Widget? cover;
  final String? description;

  /// El ⋯ grande con todas las opciones (Tarea Z7); null = sin botón.
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: GradientBorder(
        fill: KijiColors.surface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (cover != null) ...[cover!, const SizedBox(width: 14)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: KijiText.title(size: 24)),
                        const SizedBox(height: 4),
                        Text(subtitle, style: const TextStyle(color: KijiColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              if (description != null) ...[
                const SizedBox(height: 10),
                Text(description!),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: tracks.isEmpty ? null : () => _play(ref, tracks),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Reproducir'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: tracks.isEmpty ? null : () => _play(ref, tracks, shuffle: true),
                    icon: const Icon(Icons.shuffle_rounded),
                    label: const Text('Aleatorio'),
                  ),
                  if (onMore != null) ...[
                    const Spacer(),
                    IconButton.filledTonal(
                      tooltip: 'Más opciones',
                      iconSize: 28,
                      onPressed: onMore,
                      icon: const Icon(Icons.more_horiz_rounded),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una playlist de Kiji: reordenar, quitar (con Deshacer), renombrar, borrar.
class PlaylistScreen extends ConsumerWidget {
  const PlaylistScreen({super.key, required this.playlistId});

  final String playlistId;

  static Future<void> open(BuildContext context, String id) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PlaylistScreen(playlistId: id)),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlist = ref.watch(playlistsProvider.select((list) => list.where((pl) => pl.id == playlistId).firstOrNull));
    final notifier = ref.read(playlistsProvider.notifier);
    if (playlist == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Esta playlist ya no existe.')));
    }

    void delete() {
      final messenger = ScaffoldMessenger.of(context);
      final removed = notifier.delete(playlist.id);
      Navigator.of(context).pop();
      if (removed != null) {
        messenger.showSnackBar(SnackBar(
          content: Text('Se borró «${playlist.name}»'),
          duration: const Duration(seconds: 10),
          persist: false,
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () => notifier.restore(removed.$1, removed.$2),
          ),
        ));
      }
    }

    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: [
          _ListHeader(
            cover: PlaylistCover(playlist: playlist, size: 84, radius: 14),
            description: playlist.description,
            title: playlist.name,
            subtitle: playlist.importedFrom == null
                ? _count(playlist.tracks.length)
                : '${_count(playlist.tracks.length)} · importada de ${playlist.importedFrom}',
            tracks: playlist.tracks,
            onMore: () => showPlaylistOptions(
              context,
              ref,
              playlist,
              onPlay: () => _play(ref, playlist.tracks),
              onShuffle: () => _play(ref, playlist.tracks, shuffle: true),
              onDelete: delete,
            ),
          ),
          PlaylistDownloadCard(playlistId: playlist.id),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.only(bottom: 120),
              itemCount: playlist.tracks.length,
              onReorderItem: (from, to) => notifier.moveTrack(playlist.id, from, to),
              itemBuilder: (context, index) {
                final track = playlist.tracks[index];
                return ListTile(
                  key: ValueKey('${track.id}#$index'),
                  leading: TrackArtwork(track: track, size: 44, radius: 8),
                  title: TrackTitleText(track, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: TrackArtistText(track, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => ref.read(playbackProvider.notifier).playQueue(playlist.tracks, startIndex: index),
                  onLongPress: () => showTrackActions(context, ref, track),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Quitar de la playlist',
                        icon: const Icon(Icons.close_rounded, color: KijiColors.muted),
                        onPressed: () {
                          final removed = notifier.removeTrackAt(playlist.id, index);
                          if (removed == null) return;
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(SnackBar(
                              content: Text('Se quitó «${removed.title}»'),
                              duration: const Duration(seconds: 10),
                              persist: false,
                              action: SnackBarAction(
                                label: 'Deshacer',
                                onPressed: () => notifier.insertTrack(playlist.id, index, removed),
                              ),
                            ));
                        },
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.drag_handle_rounded, semanticLabel: 'Arrastrar para mover'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Una lista inteligente: se calcula sola con su regla, siempre visible.
class SmartListScreen extends ConsumerWidget {
  const SmartListScreen({super.key, required this.list});

  final SmartList list;

  static Future<void> open(BuildContext context, SmartList list) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => SmartListScreen(list: list)),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = list.compute(ref.watch(smartListInputsProvider));
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          _ListHeader(title: list.title, subtitle: 'Regla: ${list.rule}', tracks: tracks),
          if (tracks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Por ahora no hay canciones que cumplan la regla.',
                textAlign: TextAlign.center,
                style: TextStyle(color: KijiColors.muted),
              ),
            ),
          for (final (index, track) in tracks.indexed)
            ListTile(
              leading: TrackArtwork(track: track, size: 44, radius: 8),
              title: TrackTitleText(track, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: TrackArtistText(track, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => ref.read(playbackProvider.notifier).playQueue(tracks, startIndex: index),
              onLongPress: () => showTrackActions(context, ref, track),
            ),
        ],
      ),
    );
  }
}
