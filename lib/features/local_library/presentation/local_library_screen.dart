import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../models/track.dart';
import '../../../providers/downloads_provider.dart';
import '../../../providers/local_library_provider.dart';
import '../../../providers/playback_provider.dart';
import '../../../theme/app_theme.dart' show KijiSelected;
import '../../../theme/kiji_tokens.dart';
import '../../../utils/byte_formatter.dart';
import '../../../utils/duration_formatter.dart';
import '../../../widgets/nocturne/staggered.dart';
import '../../../widgets/album_cover.dart';
import '../../../widgets/nocturne/glass.dart';
import '../../downloads/presentation/batch_download_progress.dart';
import '../../downloads/presentation/downloads_screen.dart';
import '../../playlists/presentation/playlist_screens.dart';
import '../../queue/presentation/track_actions.dart';
import '../../selection/track_selection.dart';
import '../../settings/data/settings_store.dart';
import '../../settings/domain/app_settings.dart';
import '../../stream_cache/data/stream_cache.dart';
import '../domain/library_order.dart';
import '../domain/local_groups.dart';
import '../../yt_music/domain/subtitle_parser.dart' show unknownArtist;
import 'local_group_screen.dart';
import '../domain/local_library_source.dart';
import '../../playlists/playlists_provider.dart';
import '../../customize/presentation/track_text.dart';

import 'package:kiji_player/l10n/l10n.dart';

enum _LibraryStatus { loading, denied, empty, ready, error }

enum LibraryTab {
  songs,
  artists,
  albums,
  downloads,
  playlists,
  folders;

  String get label => switch (this) {
    LibraryTab.songs => tx.canciones,
    LibraryTab.artists => tx.artistas,
    LibraryTab.albums => tx.albumes,
    LibraryTab.downloads => tx.descargadas,
    LibraryTab.playlists => tx.playlists,
    LibraryTab.folders => tx.carpetas,
  };

  /// Las pestañas que muestran la música del equipo (y donde sirve "Volver a escanear").
  bool get local => this == songs || this == artists || this == albums || this == folders;
}

/// Biblioteca: pestañas con su cantidad, la tarjeta de espacio (con su barra) y "Todo"; en
/// Canciones, qué se muestra y en qué orden, en lista o en cuadrícula (se recuerda), y cada
/// canción con su etiqueta (YT ↓ o LOCAL) y su tamaño.
class LocalLibraryScreen extends ConsumerStatefulWidget {
  const LocalLibraryScreen({super.key});

  @override
  ConsumerState<LocalLibraryScreen> createState() => _LocalLibraryScreenState();
}

class _LocalLibraryScreenState extends ConsumerState<LocalLibraryScreen> {
  /// MediaStore en Android, carpetas elegidas en PC.
  LocalLibrarySource get _source => ref.read(localLibrarySourceProvider);
  _LibraryStatus _status = _LibraryStatus.loading;
  List<Track> _local = const [];

  /// Abre en la última pestaña que se usó (de fábrica, Playlists).
  late LibraryTab _tab = LibraryTab.values.asNameMap()[ref.read(settingsProvider).libraryTab] ?? LibraryTab.playlists;

  /// "Volver a escanear" en curso.
  bool _rescanning = false;

  /// Selección múltiple (mantener presionada una canción).
  final _selection = TrackSelection();

  @override
  void initState() {
    super.initState();
    _selection.addListener(_onSelection);
    _load();
  }

  void _onSelection() => setState(() {});

  @override
  void dispose() {
    _selection
      ..removeListener(_onSelection)
      ..dispose();
    super.dispose();
  }

  /// Lee la música del equipo. Lo ya leído sale de la caché (solo se leen los archivos nuevos o
  /// cambiados: así Kiji nota lo nuevo cada vez que se abre); [force] vuelve a leer todo.
  Future<void> _load({bool force = false}) async {
    setState(() => _status = _local.isEmpty ? _LibraryStatus.loading : _status);

    // En PC no se abre el selector de carpetas solo: se espera a que el
    // usuario toque "Elegir carpeta" (Cero Sorpresas).
    final alreadyGranted = await _source.hasAccess();
    final granted = alreadyGranted || (!_source.usesFolders && await _source.requestAccess());

    if (!granted) {
      if (mounted) setState(() => _status = _LibraryStatus.denied);
      return;
    }

    try {
      final tracks = await _source.loadTracks(force: force);
      if (!mounted) return;
      setState(() {
        _local = tracks;
        _status = tracks.isEmpty ? _LibraryStatus.empty : _LibraryStatus.ready;
      });
      ref.invalidate(localTracksProvider);
    } catch (error) {
      debugPrint('=== BIBLIOTECA: no se pudo leer la música local: $error ===');
      if (mounted) setState(() => _status = _LibraryStatus.error);
    }
  }

  /// "Volver a escanear": vuelve a leer todos los archivos (por si se cambiaron etiquetas o
  /// portadas sin cambiar la fecha).
  Future<void> _rescan() async {
    if (_rescanning) return;
    setState(() => _rescanning = true);
    final messenger = ScaffoldMessenger.of(context);
    await _load(force: true);
    if (!mounted) return;
    setState(() => _rescanning = false);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(tx.bibliotecaEscaneada(_local.length))));
  }

  void _setTab(LibraryTab tab) {
    _selection.clear();
    setState(() => _tab = tab);
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(libraryTab: tab.name));
  }

  Future<void> _chooseFolder() async {
    if (await _source.requestAccess()) await _load();
  }

  /// Canciones descargadas (YT ↓) y locales (LOCAL), en ese orden. Los
  /// audios cortos se ocultan si así se eligió en Configuración.
  List<Track> _allSongs() {
    final settings = ref.watch(settingsProvider);
    final downloaded = ref.watch(downloadsProvider.select((d) => d.completed)).values.toList()
      ..sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    return [
      for (final d in downloaded) d.toTrack(),
      for (final track in _local)
        if (!settings.hides(track.durationMs)) track,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final all = _allSongs();
    final settings = ref.watch(settingsProvider);
    final songs = arrangeLibrarySongs(all, sort: settings.librarySort, filter: settings.libraryFilter);
    final grid = settings.libraryView == 'grid';
    final visibleLocal = [
      for (final t in _local)
        if (!settings.hides(t.durationMs)) t,
    ];
    final artists = groupByArtist(visibleLocal, unknown: unknownArtist);
    final albums = groupByAlbum(visibleLocal);
    final counts = {
      LibraryTab.songs: all.length,
      LibraryTab.artists: artists.length,
      LibraryTab.albums: albums.length,
      LibraryTab.downloads: ref.watch(downloadsProvider.select((d) => d.completed.length)),
      LibraryTab.playlists: ref.watch(playlistsProvider.select((p) => p.length)),
    };

    final list = RefreshIndicator(
      onRefresh: _load,
      // Las canciones que se ven al abrir entran escalonadas.
      child: StaggerScope(
        generation: _source,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              sliver: SliverList.list(
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(tx.navLibrary, style: KijiText.title(size: 28))),
                      // Volver a leer todos los archivos de música del equipo.
                      if (_tab.local && _status != _LibraryStatus.denied)
                        IconButton(
                          key: const Key('library-rescan'),
                          tooltip: tx.volverAEscanear,
                          onPressed: _rescanning ? null : _rescan,
                          icon: _rescanning
                              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.refresh_rounded),
                        ),
                      // Lista o cuadrícula (canciones y playlists).
                      if (_tab == LibraryTab.songs || _tab == LibraryTab.playlists || _tab == LibraryTab.albums)
                        IconButton(
                          key: const Key('library-view-toggle'),
                          tooltip: grid ? tx.verEnLista : tx.verEnCuadricula,
                          icon: Icon(grid ? Icons.view_list_rounded : Icons.grid_view_rounded),
                          onPressed: () => ref
                              .read(settingsProvider.notifier)
                              .update((s) => s.copyWith(libraryView: grid ? 'list' : 'grid')),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _StorageCard(
                    songCount: all.length,
                    onPlayAll: songs.isEmpty ? null : () => ref.read(playbackProvider.notifier).playQueue(songs),
                  ),
                  // Varias bajando a la vez: el avance de todas juntas (en Descargadas ya va arriba).
                  if (_tab != LibraryTab.downloads) const BatchDownloadProgress(padding: EdgeInsets.only(top: 10)),
                  const SizedBox(height: 14),
                  LibraryTabs(selected: _tab, counts: counts, onChanged: _setTab),
                  if (_tab == LibraryTab.songs) ...[
                    const SizedBox(height: 10),
                    _SongsToolbar(sort: settings.librarySort, filter: settings.libraryFilter),
                  ],
                ],
              ),
            ),
            ...switch (_tab) {
              LibraryTab.songs => _songsSlivers(songs, grid: grid, filtered: songs.length != all.length),
              LibraryTab.downloads => [const SliverFillRemaining(child: DownloadsView(bottomPadding: 180))],
              LibraryTab.playlists => [SliverToBoxAdapter(child: PlaylistsView(grid: grid))],
              LibraryTab.artists => _groupSlivers(artists, LocalGroupKind.artist, grid: false),
              LibraryTab.albums => _groupSlivers(albums, LocalGroupKind.album, grid: grid),
              LibraryTab.folders => _foldersSlivers(),
            },
            const SliverToBoxAdapter(child: SizedBox(height: 180)),
          ],
        ),
      ),
    );
    // La barra de la selección queda fija arriba mientras se elige.
    return Stack(
      children: [
        list,
        if (_tab == LibraryTab.songs && _selection.active)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: SelectionBar(
                selection: _selection,
                all: {for (final t in songs) t.id: t},
                remove: songs.any((t) => _selection.contains(t.id) && t.source == TrackSource.youtube)
                    ? SelectionRemoveAction(
                        label: tx.seleccionBorrarDescargas,
                        icon: Icons.delete_outline_rounded,
                        onRemove: (_, tracks) => deleteSelectedDownloads(context, ref, tracks),
                      )
                    : null,
              ),
            ),
          ),
      ],
    );
  }

  /// Tocar una canción: Ctrl/Shift + clic (PC) o, mientras se elige, la marca; si no, suena
  /// desde ahí con las demás de la lista.
  void _tapSong(List<Track> songs, int index) {
    final track = songs[index];
    if (_selection.tapWithKeys(track.id, track, [for (final t in songs) MapEntry(t.id, t)])) return;
    if (_selection.active) {
      _selection.toggle(track.id, track);
    } else {
      ref.read(playbackProvider.notifier).playQueue(songs, startIndex: index);
    }
  }

  /// Artistas o álbumes (o carpetas): cada uno abre su pantalla con sus canciones.
  List<Widget> _groupSlivers(List<LocalGroup> groups, LocalGroupKind kind, {required bool grid}) {
    final message = _localMessage();
    if (groups.isEmpty) return [if (message != null) SliverToBoxAdapter(child: message)];
    String details(LocalGroup g) => switch (kind) {
      LocalGroupKind.artist => [
        tx.nCanciones(g.tracks.length),
        if (g.tracks.map((t) => t.album).whereType<String>().toSet().length case final n when n > 0) tx.nAlbumes(n),
      ].join(' · '),
      LocalGroupKind.album => [?g.subtitle, if (g.year case final y?) '$y'].join(' · '),
      LocalGroupKind.folder || LocalGroupKind.playlist => tx.nCanciones(g.tracks.length),
    };
    if (grid) {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.74,
            ),
            itemCount: groups.length,
            itemBuilder: (context, i) => InkWell(
              key: Key('local-group-${groups[i].key}'),
              borderRadius: BorderRadius.circular(KijiLook.cover(12) + 4),
              onTap: () => LocalGroupScreen.open(context, groups[i], kind),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) => TrackArtwork(
                          track: groups[i].cover,
                          size: c.biggest.shortestSide,
                          radius: KijiLook.cover(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(groups[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: KijiText.title(size: 14)),
                    Text(
                      details(groups[i]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: KijiColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ];
    }
    return [
      SliverList.builder(
        itemCount: groups.length,
        itemBuilder: (context, i) {
          final g = groups[i];
          final art = TrackArtwork(track: g.cover, size: 48, radius: kind == LocalGroupKind.artist ? 24 : 8);
          return ListTile(
            key: Key('local-group-${g.key}'),
            leading: kind == LocalGroupKind.folder ? Icon(Icons.folder_outlined, color: KijiColors.violet) : art,
            title: Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              details(g),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: KijiColors.muted),
            ),
            trailing: IconButton(
              tooltip: tx.reproducir,
              icon: const Icon(Icons.play_arrow_rounded),
              onPressed: () => ref.read(playbackProvider.notifier).playQueue(g.tracks),
            ),
            onTap: () => LocalGroupScreen.open(context, g, kind),
          );
        },
      ),
    ];
  }

  /// Por qué no se ve la música del equipo (sin permiso, sin carpeta, vacía, error), o null.
  Widget? _localMessage() => switch (_status) {
    _LibraryStatus.loading => const Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator()),
    ),
    _LibraryStatus.denied =>
      _source.usesFolders
          ? _InfoCard(
              icon: Icons.folder_open_rounded,
              message: tx.eligeLaCarpetaDondeGuardasTu,
              actionLabel: tx.elegirCarpeta,
              onAction: _chooseFolder,
            )
          : _InfoCard(
              icon: Icons.lock_outline_rounded,
              message: tx.kijiNecesitaPermisoParaLeerTu,
              actionLabel: tx.concederPermiso,
              onAction: _load,
            ),
    _LibraryStatus.error => _InfoCard(
      icon: Icons.error_outline_rounded,
      message: tx.noSePudoLeerLaBiblioteca,
      actionLabel: tx.reintentar,
      onAction: _load,
    ),
    _LibraryStatus.empty => _InfoCard(icon: Icons.music_off_rounded, message: tx.noSeEncontroMusicaEnEste),
    _LibraryStatus.ready => null,
  };

  List<Widget> _songsSlivers(List<Track> songs, {required bool grid, required bool filtered}) {
    final localMessage = _localMessage();

    return [
      if (songs.isEmpty && filtered)
        SliverToBoxAdapter(
          child: _InfoCard(icon: Icons.filter_alt_off_rounded, message: tx.noHayCancionesConEsteFiltro),
        )
      else if (grid)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.74,
            ),
            itemCount: songs.length,
            itemBuilder: (context, index) => StaggeredEntrance(
              index: index,
              child: _SongCard(
                track: songs[index],
                selecting: _selection.active,
                selected: _selection.contains(songs[index].id),
                onSelect: () => _selection.toggle(songs[index].id, songs[index]),
                onTap: () => _tapSong(songs, index),
              ),
            ),
          ),
        )
      else
        SliverList.builder(
          itemCount: songs.length,
          itemBuilder: (context, index) => StaggeredEntrance(
            index: index,
            child: _SongTile(
              track: songs[index],
              selecting: _selection.active,
              selected: _selection.contains(songs[index].id),
              onSelect: () => _selection.toggle(songs[index].id, songs[index]),
              onTap: () => _tapSong(songs, index),
            ),
          ),
        ),
      if (localMessage != null && !(filtered && _status == _LibraryStatus.ready))
        SliverToBoxAdapter(child: localMessage),
    ];
  }

  List<Widget> _foldersSlivers() {
    final settings = ref.watch(settingsProvider);
    final groups = groupByFolderPath([
      for (final track in _local)
        if (!settings.hides(track.durationMs)) track,
    ]);
    return [
      // PC: las carpetas que lee Kiji (varias), para agregar o quitar.
      if (_source.usesFolders)
        SliverToBoxAdapter(
          child: FutureBuilder<List<String>>(
            future: _source.folders(),
            builder: (context, snapshot) {
              final folders = snapshot.data ?? const <String>[];
              return Column(
                children: [
                  ListTile(title: Text(tx.carpetasQueLeeKiji), subtitle: Text(tx.quitarUnaCarpetaNoBorraNingun)),
                  for (final folder in folders)
                    ListTile(
                      leading: Icon(Icons.folder_special_outlined, color: KijiColors.violet),
                      title: Text(folder, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: const Icon(Icons.close_rounded),
                        tooltip: tx.dejarDeLeerEstaCarpeta,
                        onPressed: () async {
                          await _source.removeFolder(folder);
                          await _load();
                        },
                      ),
                    ),
                  ListTile(
                    key: const Key('library-add-folder'),
                    leading: Icon(Icons.create_new_folder_outlined, color: KijiColors.cyan),
                    title: Text(tx.agregarCarpeta),
                    onTap: _chooseFolder,
                  ),
                  if (groups.isNotEmpty) const Divider(height: 24),
                ],
              );
            },
          ),
        ),
      ..._groupSlivers(groups, LocalGroupKind.folder, grid: false),
    ];
  }
}

/// Canciones agrupadas por carpeta (ordenadas por nombre de carpeta).
Map<String, List<Track>> groupByFolder(List<Track> tracks) {
  final groups = <String, List<Track>>{};
  for (final track in tracks) {
    if (track.source != TrackSource.local) continue;
    groups.putIfAbsent(p.dirname(track.audioUrl), () => []).add(track);
  }
  final keys = groups.keys.toList()..sort((a, b) => p.basename(a).toLowerCase().compareTo(p.basename(b).toLowerCase()));
  return {for (final key in keys) key: groups[key]!};
}

/// Espacio que usa Kiji (descargas + caché) y espacio libre, con "Todo".
class _StorageCard extends ConsumerWidget {
  const _StorageCard({required this.songCount, required this.onPlayAll});

  final int songCount;
  final VoidCallback? onPlayAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Solo cuando cambian las descargas terminadas (no con cada avance de una en curso): cada
    // redibujado vuelve a medir el espacio en disco.
    ref.watch(downloadsProvider.select((d) => (d.completed, d.directoryPath)));
    final downloads = ref.read(downloadsProvider);
    return Glass(
      blur: false,
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<(int, int?)>(
        future: _sizes(ref, downloads),
        builder: (context, snapshot) {
          final cache = snapshot.data?.$1 ?? 0;
          final used = downloads.usedBytes + cache;
          final free = snapshot.data?.$2;
          final limit = downloads.settings.limitBytes;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tx.espacio, style: KijiText.mono(size: 10)),
                        const SizedBox(height: 4),
                        Text(tx.usadosPorKiji(formatBytes(used)), style: KijiText.title(size: 16)),
                        Text(
                          free == null ? tx.nCanciones(songCount) : tx.libresCanciones(formatBytes(free), songCount),
                          style: TextStyle(color: KijiColors.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: onPlayAll,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(tx.todo),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Descargas y caché sobre el total (el límite elegido o, si no, lo usado más lo libre).
              StorageBar(
                downloads: downloads.usedBytes,
                cache: cache,
                total: limit ?? (free == null ? null : used + free),
              ),
              const SizedBox(height: 6),
              Text(
                tx.descargasYCache(formatBytes(downloads.usedBytes), formatBytes(cache)),
                style: KijiText.mono(size: 10),
              ),
            ],
          );
        },
      ),
    );
  }

  /// (caché, libre).
  Future<(int, int?)> _sizes(WidgetRef ref, DownloadsState downloads) async {
    var cache = 0;
    try {
      cache = await StreamCache().sizeBytes();
    } catch (error) {
      debugPrint('=== BIBLIOTECA: no se pudo medir la caché: $error ===');
    }
    final dir = downloads.directoryPath;
    final free = dir == null ? null : await ref.read(storageInfoProvider).freeBytes(dir);
    return (cache, free);
  }
}

/// Barra del espacio: descargas (acento) y caché (gris) sobre [total]. Sin [total], solo las dos
/// partes entre sí.
class StorageBar extends StatelessWidget {
  const StorageBar({super.key, required this.downloads, required this.cache, this.total});

  final int downloads;
  final int cache;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final whole = max(1, max(total ?? 0, downloads + cache));
    // Lo poco se ve igual (un mínimo de 2 %).
    double part(int bytes) => bytes <= 0 ? 0 : max(0.02, bytes / whole);
    return Semantics(
      label: tx.espacio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KijiRadii.pill),
        child: SizedBox(
          height: 6,
          child: LayoutBuilder(
            builder: (context, c) => Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: KijiColors.waveRest)),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: c.maxWidth * min(1, part(downloads) + part(cache)),
                  child: ColoredBox(color: KijiColors.muted.withValues(alpha: 0.6)),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: c.maxWidth * min(1, part(downloads)),
                  child: DecoratedBox(decoration: BoxDecoration(gradient: KijiColors.accentGradient)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila de canción con su etiqueta (YT ↓ cian, LOCAL violeta) y su tamaño.
class _SongTile extends ConsumerWidget {
  const _SongTile({
    required this.track,
    required this.onTap,
    this.selecting = false,
    this.selected = false,
    required this.onSelect,
  });

  final Track track;
  final VoidCallback onTap;

  /// Selección múltiple: mientras se elige, tocar marca o desmarca.
  final bool selecting;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isYoutube = track.source == TrackSource.youtube;
    final size = track.sizeBytes;
    return GestureDetector(
      onSecondaryTap: () => showTrackActions(context, ref, track),
      child: ListTile(
        selected: selected,
        selectedTileColor: KijiSelected.tile,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selecting) ...[SelectionCheck(selected: selected), const SizedBox(width: 10)],
            TrackArtwork(track: track, size: 44, radius: 8),
          ],
        ),
        title: TrackTitleText(track, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Row(
          children: [
            SourceTag(youtube: isYoutube),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                [track.artist, if (size != null) formatBytes(size)].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: KijiColors.muted, fontSize: 12),
              ),
            ),
          ],
        ),
        trailing: track.durationMs > 0
            ? Text(formatDuration(Duration(milliseconds: track.durationMs)), style: KijiText.mono(size: 11))
            : null,
        onTap: onTap,
        // Mantener presionada: empieza a elegir (con una sola, "Más" trae el menú de siempre).
        onLongPress: onSelect,
      ),
    );
  }
}

/// Una canción en la vista de cuadrícula: la portada grande, el título y el artista.
class _SongCard extends ConsumerWidget {
  const _SongCard({
    required this.track,
    required this.onTap,
    required this.onSelect,
    this.selecting = false,
    this.selected = false,
  });

  final Track track;
  final VoidCallback onTap;
  final VoidCallback onSelect;
  final bool selecting;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radius = KijiLook.cover(12);
    return GestureDetector(
      onSecondaryTap: () => showTrackActions(context, ref, track),
      child: Material(
        color: selected ? KijiSelected.tile : Colors.transparent,
        borderRadius: BorderRadius.circular(radius + 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius + 4),
          onTap: onTap,
          onLongPress: onSelect,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final side = c.biggest.shortestSide;
                      return Stack(
                        children: [
                          TrackArtwork(track: track, size: side, radius: radius),
                          if (selecting) Positioned(top: 6, left: 6, child: SelectionCheck(selected: selected)),
                          Positioned(
                            right: 6,
                            bottom: 6,
                            child: SourceTag(youtube: track.source == TrackSource.youtube),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
                TrackTitleText(track, maxLines: 1, overflow: TextOverflow.ellipsis, style: KijiText.title(size: 14)),
                Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: KijiColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pestañas de la Biblioteca, con cuántas hay en cada una. Nocturne: una cápsula de vidrio con la
/// elegida en el acento; Grafito: texto con una línea fina blanca debajo de la elegida; Papel: igual,
/// con la línea en su rojo.
class LibraryTabs extends StatelessWidget {
  const LibraryTabs({super.key, required this.selected, required this.onChanged, this.counts = const {}});

  final LibraryTab selected;
  final ValueChanged<LibraryTab> onChanged;
  final Map<LibraryTab, int> counts;

  @override
  Widget build(BuildContext context) {
    final pill = KijiLook.nocturne;
    final line = KijiLook.style == KijiStyle.paper ? KijiColors.like : KijiColors.text;
    final c = KijiSelected.colors;
    Widget tab(LibraryTab t) {
      final on = t == selected;
      final color = pill ? (on ? c.onFill : KijiColors.muted) : (on ? KijiColors.text : KijiColors.muted);
      final count = counts[t];
      return Semantics(
        selected: on,
        button: true,
        child: InkWell(
          key: Key('library-tab-${t.name}'),
          borderRadius: BorderRadius.circular(KijiRadii.pill),
          onTap: () => onChanged(t),
          child: AnimatedContainer(
            duration: KijiMotion.fast,
            padding: EdgeInsets.symmetric(horizontal: pill ? 14 : 4, vertical: 9),
            margin: EdgeInsets.only(right: pill ? 2 : 18),
            decoration: pill
                ? BoxDecoration(
                    color: on ? c.fill : Colors.transparent,
                    borderRadius: BorderRadius.circular(KijiRadii.pill),
                  )
                : BoxDecoration(
                    border: Border(bottom: BorderSide(color: on ? line : Colors.transparent, width: 2)),
                  ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.label,
                  maxLines: 1,
                  style: TextStyle(fontSize: 13, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: color),
                ),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Text('$count', style: KijiText.mono(size: 10, color: color)),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final row = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [for (final t in LibraryTab.values) tab(t)]),
    );
    if (!pill) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: KijiColors.glassBorder)),
        ),
        child: row,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KijiColors.glassFill,
        borderRadius: BorderRadius.circular(KijiRadii.pill),
        border: Border.all(color: KijiColors.glassBorder),
      ),
      child: Padding(padding: const EdgeInsets.all(3), child: row),
    );
  }
}

/// Canciones: qué se muestra (todas, las descargadas o las del equipo) y el orden. Se recuerda.
class _SongsToolbar extends ConsumerWidget {
  const _SongsToolbar({required this.sort, required this.filter});

  final String sort;
  final String filter;

  static String sortLabel(String sort) => switch (sort) {
    'title' => tx.titulo,
    'artist' => tx.artista,
    'duration' => tx.duracion,
    _ => tx.ordenRecientes,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(settingsProvider.notifier);
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (value, label) in [
                  ('all', tx.todas),
                  ('downloaded', tx.descargadas),
                  ('local', tx.enEsteEquipo),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: Key('library-filter-$value'),
                      label: Text(label),
                      selected: filter == value,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      shape: const StadiumBorder(),
                      onSelected: (_) => notifier.update((s) => s.copyWith(libraryFilter: value)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        PopupMenuButton<String>(
          key: const Key('library-sort'),
          tooltip: tx.ordenar,
          initialValue: sort,
          onSelected: (value) => notifier.update((s) => s.copyWith(librarySort: value)),
          itemBuilder: (context) => [
            for (final value in AppSettings.librarySorts) PopupMenuItem(value: value, child: Text(sortLabel(value))),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sort_rounded, size: 18, color: KijiColors.muted),
                const SizedBox(width: 4),
                Text(sortLabel(sort), style: TextStyle(fontSize: 13, color: KijiColors.muted)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Etiqueta "YT ↓" (descargada de YouTube, cian) o "LOCAL" (violeta).
class SourceTag extends StatelessWidget {
  const SourceTag({super.key, required this.youtube});

  final bool youtube;

  @override
  Widget build(BuildContext context) {
    final color = youtube ? KijiColors.cyan : KijiColors.violet;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.7)),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(youtube ? 'YT ↓' : tx.local, style: KijiText.mono(size: 9, color: color)), // l10n-ignore
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.message, this.actionLabel, this.onAction});

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: KijiColors.muted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: KijiColors.muted),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
