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
import '../../selection/track_selection.dart';
import '../domain/smart_lists.dart';
import '../playlists_provider.dart';
import '../../customize/presentation/track_text.dart';
import '../../customize/presentation/customize_sheets.dart';
import '../domain/playlist.dart';
import 'playlist_actions.dart';
import '../../downloads/presentation/download_status.dart';

import 'package:kiji_player/l10n/l10n.dart';
import 'package:kiji_player/widgets/nocturne/kiji_sheet.dart';

/// Datos de las listas inteligentes, calculados en el teléfono.
final smartListInputsProvider = Provider<SmartListInputs>(
  (ref) => SmartListInputs(
    now: DateTime.now(),
    liked: ref.watch(favoritesProvider).values.toList(),
    history: ref.watch(listeningHistoryProvider),
    downloaded: [for (final d in ref.watch(downloadsProvider).completed.values) d.toTrack()],
    local: ref.watch(localTracksProvider).value ?? const [],
  ),
);

/// Reproduce [tracks]; con [shuffle], activa el aleatorio y empieza por una al azar.
void _play(WidgetRef ref, List<Track> tracks, {bool shuffle = false}) {
  if (tracks.isEmpty) return;
  final notifier = ref.read(playbackProvider.notifier);
  if (shuffle && !ref.read(playbackProvider).shuffleEnabled) notifier.toggleShuffle();
  notifier.playQueue(tracks, startIndex: shuffle ? Random().nextInt(tracks.length) : 0);
}

/// Pide un nombre (crear o renombrar).
Future<String?> promptPlaylistName(BuildContext context, {String initial = '', String? title}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title ?? tx.nuevaPlaylist),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: tx.nombreDeLaPlaylist),
        onSubmitted: (value) => Navigator.pop(context, value.trim().isEmpty ? null : value.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tx.cancelar)),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            Navigator.pop(context, value.isEmpty ? null : value);
          },
          child: Text(tx.guardar),
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

  return showKijiSheet<void>(
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
                ListTile(title: Text(tx.agregarAPlaylist)),
                ListTile(
                  leading: Icon(Icons.add_rounded, color: KijiColors.cyan),
                  title: Text(tx.nuevaPlaylist),
                  onTap: () async {
                    final name = await promptPlaylistName(context);
                    if (name == null) return;
                    final created = notifier.create(name, tracks: tracks);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                    done(tx.seCreo(created.name));
                  },
                ),
                for (final playlist in playlists)
                  ListTile(
                    leading: Icon(Icons.queue_music_rounded, color: KijiColors.violet),
                    title: Text(playlist.name),
                    subtitle: Text(_count(playlist.tracks.length)),
                    onTap: () {
                      final added = notifier.addTracks(playlist.id, tracks);
                      Navigator.pop(sheetContext);
                      done(added == 0 ? tx.yaEstabaEn(playlist.name) : tx.seAgregoA(playlist.name));
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

String _count(int n) => tx.nCanciones(n);

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
              Expanded(child: Text(tx.tusPlaylists, style: KijiText.mono(size: 11))),
              TextButton.icon(
                onPressed: () async {
                  final name = await promptPlaylistName(context);
                  if (name != null) ref.read(playlistsProvider.notifier).create(name);
                },
                icon: const Icon(Icons.add_rounded),
                label: Text(tx.nueva),
              ),
            ],
          ),
        ),
        if (playlists.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(tx.todaviaNoCreasteNingunaMantenPresionada, style: TextStyle(color: KijiColors.muted)),
          ),
        for (final playlist in PlaylistOps.pinnedFirst(playlists))
          ListTile(
            leading: PlaylistCover(playlist: playlist),
            title: Row(
              children: [
                if (playlist.pinned) ...[
                  Icon(Icons.push_pin_rounded, size: 14, color: KijiColors.cyan, semanticLabel: tx.fijada),
                  const SizedBox(width: 4),
                ],
                Expanded(child: Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            subtitle: Text(_count(playlist.tracks.length), style: TextStyle(color: KijiColors.muted)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => PlaylistScreen.open(context, playlist.id),
          ),
        ListTile(
          leading: Icon(Icons.bookmarks_outlined, color: KijiColors.cyan),
          title: Text(tx.momentos2),
          subtitle: Text(
            tx.segundosGuardadosDeTusCanciones(ref.watch(momentsProvider).length),
            style: TextStyle(color: KijiColors.muted),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => MomentsScreen.open(context),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text(tx.listasInteligentesCalculadasEnTuTelefono, style: KijiText.mono(size: 11)),
        ),
        for (final list in SmartList.values)
          ListTile(
            leading: Icon(Icons.auto_awesome_rounded, color: KijiColors.cyan),
            title: Text(list.title),
            subtitle: Text(
              '${list.rule.replaceFirst(RegExp(r'\.$'), '')} · ${_count(list.compute(inputs).length)}',
              style: TextStyle(color: KijiColors.muted),
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

  /// Foto de la playlist.
  final Widget? cover;
  final String? description;

  /// El ⋯ grande con todas las opciones; null = sin botón.
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
                        Text(subtitle, style: TextStyle(color: KijiColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              if (description != null) ...[const SizedBox(height: 10), Text(description!)],
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: tracks.isEmpty ? null : () => _play(ref, tracks),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(tx.reproducir),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: tracks.isEmpty ? null : () => _play(ref, tracks, shuffle: true),
                    icon: const Icon(Icons.shuffle_rounded),
                    label: Text(tx.aleatorio),
                  ),
                  if (onMore != null) ...[
                    const Spacer(),
                    IconButton.filledTonal(
                      tooltip: tx.masOpciones,
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

/// Filtros de la playlist por estado de descarga.
enum _TrackFilter { all, downloaded, missing, failed }

/// Una playlist de Kiji: reordenar, quitar (con Deshacer), renombrar, borrar.
class PlaylistScreen extends ConsumerStatefulWidget {
  const PlaylistScreen({super.key, required this.playlistId});

  final String playlistId;

  static Future<void> open(BuildContext context, String id) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PlaylistScreen(playlistId: id)));

  @override
  ConsumerState<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends ConsumerState<PlaylistScreen> {
  _TrackFilter _filter = _TrackFilter.all;

  /// Selección múltiple: la clave de cada fila es su lugar en la playlist.
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
    final playlistId = widget.playlistId;
    final playlist = ref.watch(playlistsProvider.select((list) => list.where((pl) => pl.id == playlistId).firstOrNull));
    final notifier = ref.read(playlistsProvider.notifier);
    if (playlist == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(tx.estaPlaylistYaNoExiste)),
      );
    }

    void delete() {
      final messenger = ScaffoldMessenger.of(context);
      final removed = notifier.delete(playlist.id);
      Navigator.of(context).pop();
      if (removed != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(tx.seBorro(playlist.name)),
            duration: const Duration(seconds: 10),
            persist: false,
            action: SnackBarAction(label: tx.deshacer, onPressed: () => notifier.restore(removed.$1, removed.$2)),
          ),
        );
      }
    }

    // Estado de descarga de cada canción: para el "142 de 150" y los filtros.
    // Como texto (un carácter por canción) para que la pantalla solo se redibuje si algo cambió.
    final code = ref.watch(
      downloadsProvider.select(
        (s) => String.fromCharCodes([
          for (final t in playlist.tracks)
            48 + (t.youtubeVideoId == null ? DownloadMark.none : downloadMarkOf(s, t.youtubeVideoId!).$1).index,
        ]),
      ),
    );
    final marks = [for (final c in code.codeUnits) DownloadMark.values[c - 48]];
    final fromYouTube = playlist.tracks.where((t) => t.youtubeVideoId != null).length;
    final downloaded = marks.where((m) => m == DownloadMark.done).length;
    final failed = marks.where((m) => m == DownloadMark.failed).length;
    var filter = _filter;
    if (filter == _TrackFilter.failed && failed == 0) filter = _TrackFilter.all;
    bool matches(int i) => switch (filter) {
      _TrackFilter.all => true,
      _TrackFilter.downloaded => marks[i] == DownloadMark.done,
      _TrackFilter.missing => playlist.tracks[i].youtubeVideoId != null && marks[i] != DownloadMark.done,
      _TrackFilter.failed => marks[i] == DownloadMark.failed,
    };
    final visible = [
      for (var i = 0; i < playlist.tracks.length; i++)
        if (matches(i)) i,
    ];

    Widget tile(int index, {required bool reorderable}) {
      final track = playlist.tracks[index];
      final videoId = track.youtubeVideoId;
      final selected = _selection.contains('$index');
      return ListTile(
        key: ValueKey('${track.id}#$index'),
        selected: selected,
        selectedTileColor: KijiColors.violet.withValues(alpha: 0.14),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selection.active) ...[SelectionCheck(selected: selected), const SizedBox(width: 10)],
            TrackArtwork(track: track, size: 44, radius: 8),
          ],
        ),
        title: TrackTitleText(track, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: marks[index] == DownloadMark.failed
            ? Text(
                ref.read(downloadsProvider).active[videoId]?.errorMessage ?? tx.noSePudoDescargar2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: downloadWarningColor),
              )
            : TrackArtistText(track, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: _selection.active
            ? () => _selection.toggle('$index', track)
            : () => ref.read(playbackProvider.notifier).playQueue(playlist.tracks, startIndex: index),
        // Mantener presionada: empieza a elegir (con una sola, "Más" trae el menú de siempre).
        onLongPress: () => _selection.toggle('$index', track),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (marks[index] == DownloadMark.failed && videoId != null)
              IconButton(
                tooltip: tx.porQueNoSeDescargo,
                icon: const Icon(Icons.warning_amber_rounded, color: downloadWarningColor),
                onPressed: () => showDownloadFailureSheet(context, ref, videoId),
              ),
            IconButton(
              tooltip: tx.quitarDeLaPlaylist,
              icon: Icon(Icons.close_rounded, color: KijiColors.muted),
              onPressed: () {
                final removed = notifier.removeTrackAt(playlist.id, index);
                if (removed == null) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(tx.seQuito(removed.title)),
                      duration: const Duration(seconds: 10),
                      persist: false,
                      action: SnackBarAction(
                        label: tx.deshacer,
                        onPressed: () => notifier.insertTrack(playlist.id, index, removed),
                      ),
                    ),
                  );
              },
            ),
            if (reorderable)
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.drag_handle_rounded, semanticLabel: tx.arrastrarParaMover),
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(),
      // La barra de la selección va encima de la cabecera: la lista no se corre bajo el dedo.
      body: Stack(
        children: [
          Column(
            children: [
              _ListHeader(
                cover: PlaylistCover(playlist: playlist, size: 84, radius: 14),
                description: playlist.description,
                title: playlist.name,
                subtitle: playlist.importedFrom == null
                    ? _count(playlist.tracks.length)
                    : tx.importadaDe(_count(playlist.tracks.length), playlist.importedFrom),
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
              if (fromYouTube > 0 && (downloaded > 0 || failed > 0))
                _DownloadFilterBar(
                  downloaded: downloaded,
                  total: fromYouTube,
                  failed: failed,
                  filter: filter,
                  onFilter: (f) {
                    _selection.clear();
                    setState(() => _filter = f);
                  },
                ),
              Expanded(
                child: filter == _TrackFilter.all
                    ? ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        padding: const EdgeInsets.only(bottom: 120),
                        itemCount: playlist.tracks.length,
                        onReorderItem: (from, to) {
                          // Las claves son lugares: al mover, la selección ya no vale.
                          _selection.clear();
                          notifier.moveTrack(playlist.id, from, to);
                        },
                        itemBuilder: (context, index) => tile(index, reorderable: true),
                      )
                    : visible.isEmpty
                    ? Center(
                        child: Text(tx.ningunaCancionConEsteFiltro, style: TextStyle(color: KijiColors.muted)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 120),
                        itemCount: visible.length,
                        itemBuilder: (context, i) => tile(visible[i], reorderable: false),
                      ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SelectionBar(
              selection: _selection,
              all: {for (final i in visible) '$i': playlist.tracks[i]},
              remove: SelectionRemoveAction(
                label: tx.quitarDeLaPlaylist,
                icon: Icons.playlist_remove_rounded,
                onRemove: (keys, _) async {
                  final removed = notifier.removeTracksAt(playlist.id, {for (final k in keys) int.parse(k)});
                  if (removed.isEmpty) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(tx.nQuitadasDeLaPlaylist(removed.length)),
                        duration: const Duration(seconds: 10),
                        persist: false,
                        action: SnackBarAction(
                          label: tx.deshacer,
                          onPressed: () => notifier.insertTracks(playlist.id, removed),
                        ),
                      ),
                    );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "142 de 150 descargadas" y los filtros por estado de descarga.
class _DownloadFilterBar extends StatelessWidget {
  const _DownloadFilterBar({
    required this.downloaded,
    required this.total,
    required this.failed,
    required this.filter,
    required this.onFilter,
  });

  final int downloaded;
  final int total;
  final int failed;
  final _TrackFilter filter;
  final ValueChanged<_TrackFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    Widget chip(_TrackFilter value, String label) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(label: Text(label), selected: filter == value, onSelected: (_) => onFilter(value)),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                downloaded == total ? Icons.download_done_rounded : Icons.download_rounded,
                size: 18,
                color: KijiColors.cyan,
              ),
              const SizedBox(width: 6),
              Text(tx.deDescargadas(downloaded, total), style: KijiText.mono(size: 13, color: KijiColors.text)),
              if (failed > 0) ...[
                const SizedBox(width: 10),
                Text(tx.conError(failed), style: KijiText.mono(size: 13, color: downloadWarningColor)),
              ],
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                chip(_TrackFilter.all, tx.todas),
                chip(_TrackFilter.downloaded, tx.descargadas),
                chip(_TrackFilter.missing, tx.sinDescargar),
                if (failed > 0) chip(_TrackFilter.failed, tx.conError2),
              ],
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

  static Future<void> open(BuildContext context, SmartList list) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SmartListScreen(list: list)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = list.compute(ref.watch(smartListInputsProvider));
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          _ListHeader(title: list.title, subtitle: tx.regla(list.rule), tracks: tracks),
          if (tracks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                tx.porAhoraNoHayCancionesQue,
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
