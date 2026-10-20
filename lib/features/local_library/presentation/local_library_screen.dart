import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../models/track.dart';
import '../../../providers/downloads_provider.dart';
import '../../../providers/local_library_provider.dart';
import '../../../providers/playback_provider.dart';
import '../../../theme/kiji_tokens.dart';
import '../../../utils/byte_formatter.dart';
import '../../../utils/duration_formatter.dart';
import '../../../widgets/nocturne/staggered.dart';
import '../../../widgets/album_cover.dart';
import '../../../widgets/nocturne/glass.dart';
import '../../downloads/presentation/downloads_screen.dart';
import '../../playlists/presentation/playlist_screens.dart';
import '../../queue/presentation/track_actions.dart';
import '../../settings/data/settings_store.dart';
import '../../stream_cache/data/stream_cache.dart';
import '../domain/local_library_source.dart';
import '../../customize/presentation/track_text.dart';

import 'package:kiji_player/l10n/l10n.dart';

enum _LibraryStatus { loading, denied, empty, ready, error }

enum LibraryTab {
  songs,
  downloads,
  playlists,
  folders;

  String get label => switch (this) {
    LibraryTab.songs => tx.canciones,
    LibraryTab.downloads => tx.descargadas,
    LibraryTab.playlists => tx.playlists,
    LibraryTab.folders => tx.carpetas,
  };
}

/// Biblioteca (§7): pestañas segmentadas, tarjeta de espacio usado/libre con
/// "Todo", y cada canción con su etiqueta (YT ↓ o LOCAL) y su tamaño.
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
  // Abre en Playlists (Tarea Z3).
  LibraryTab _tab = LibraryTab.playlists;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = _LibraryStatus.loading);

    // En PC no se abre el selector de carpetas solo: se espera a que el
    // usuario toque "Elegir carpeta" (Cero Sorpresas).
    final alreadyGranted = await _source.hasAccess();
    final granted = alreadyGranted || (!_source.usesFolders && await _source.requestAccess());

    if (!granted) {
      if (mounted) setState(() => _status = _LibraryStatus.denied);
      return;
    }

    try {
      final tracks = await _source.loadTracks();
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

  Future<void> _chooseFolder() async {
    if (await _source.requestAccess()) await _load();
  }

  /// Canciones descargadas (YT ↓) y locales (LOCAL), en ese orden. Los
  /// audios cortos se ocultan si así se eligió en Configuración.
  List<Track> _allSongs() {
    final settings = ref.watch(settingsProvider);
    return [
      for (final d in ref.watch(downloadsProvider).completed.values) d.toTrack(),
      for (final track in _local)
        if (!settings.hides(track.durationMs)) track,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final songs = _allSongs();

    return RefreshIndicator(
      onRefresh: _load,
      // Las canciones que se ven al abrir entran escalonadas (Tarea Z6).
      child: StaggerScope(
        generation: _source,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              sliver: SliverList.list(
                children: [
                  Text(tx.navLibrary, style: KijiText.title(size: 28)),
                  const SizedBox(height: 14),
                  _StorageCard(
                    songCount: songs.length,
                    onPlayAll: songs.isEmpty ? null : () => ref.read(playbackProvider.notifier).playQueue(songs),
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<LibraryTab>(
                    segments: [
                      for (final tab in LibraryTab.values)
                        ButtonSegment(value: tab, label: Text(tab.label, maxLines: 1)),
                    ],
                    selected: {_tab},
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: KijiColors.violet,
                      selectedForegroundColor: Colors.white,
                      foregroundColor: KijiColors.muted,
                      side: const BorderSide(color: KijiColors.glassBorder),
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    onSelectionChanged: (selection) => setState(() => _tab = selection.first),
                  ),
                ],
              ),
            ),
            ...switch (_tab) {
              LibraryTab.songs => _songsSlivers(songs),
              LibraryTab.downloads => [const SliverFillRemaining(child: DownloadsView(bottomPadding: 180))],
              LibraryTab.playlists => [const SliverToBoxAdapter(child: PlaylistsView())],
              LibraryTab.folders => _foldersSlivers(),
            },
            const SliverToBoxAdapter(child: SizedBox(height: 180)),
          ],
        ),
      ),
    );
  }

  List<Widget> _songsSlivers(List<Track> songs) {
    final localMessage = switch (_status) {
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

    return [
      SliverList.builder(
        itemCount: songs.length,
        itemBuilder: (context, index) => StaggeredEntrance(
          index: index,
          child: _SongTile(
            track: songs[index],
            onTap: () => ref.read(playbackProvider.notifier).playQueue(songs, startIndex: index),
          ),
        ),
      ),
      if (localMessage != null) SliverToBoxAdapter(child: localMessage),
    ];
  }

  List<Widget> _foldersSlivers() {
    if (_source.usesFolders) {
      return [
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
                      leading: const Icon(Icons.folder_outlined, color: KijiColors.violet),
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
                    leading: const Icon(Icons.create_new_folder_outlined, color: KijiColors.cyan),
                    title: Text(tx.agregarCarpeta),
                    onTap: _chooseFolder,
                  ),
                ],
              );
            },
          ),
        ),
      ];
    }

    // Android: la música agrupada por la carpeta donde está.
    final settings = ref.watch(settingsProvider);
    final byFolder = groupByFolder([
      for (final track in _local)
        if (!settings.hides(track.durationMs)) track,
    ]);
    return [
      SliverList.builder(
        itemCount: byFolder.length,
        itemBuilder: (context, index) {
          final entry = byFolder.entries.elementAt(index);
          return ListTile(
            leading: const Icon(Icons.folder_outlined, color: KijiColors.violet),
            title: Text(p.basename(entry.key), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              tx.nCanciones(entry.value.length),
              style: const TextStyle(color: KijiColors.muted),
            ),
            trailing: const Icon(Icons.play_arrow_rounded),
            onTap: () => ref.read(playbackProvider.notifier).playQueue(entry.value),
          );
        },
      ),
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
    final downloads = ref.watch(downloadsProvider);
    return Glass(
      blur: false,
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<(int, int?)>(
        future: _sizes(ref, downloads),
        builder: (context, snapshot) {
          final used = snapshot.data?.$1 ?? downloads.usedBytes;
          final free = snapshot.data?.$2;
          return Row(
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
                      style: const TextStyle(color: KijiColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(onPressed: onPlayAll, icon: const Icon(Icons.play_arrow_rounded), label: Text(tx.todo)),
            ],
          );
        },
      ),
    );
  }

  Future<(int, int?)> _sizes(WidgetRef ref, DownloadsState downloads) async {
    var used = downloads.usedBytes;
    try {
      used += await StreamCache().sizeBytes();
    } catch (error) {
      debugPrint('=== BIBLIOTECA: no se pudo medir la caché: $error ===');
    }
    final dir = downloads.directoryPath;
    final free = dir == null ? null : await ref.read(storageInfoProvider).freeBytes(dir);
    return (used, free);
  }
}

/// Fila de canción con su etiqueta (YT ↓ cian, LOCAL violeta) y su tamaño.
class _SongTile extends ConsumerWidget {
  const _SongTile({required this.track, required this.onTap});

  final Track track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isYoutube = track.source == TrackSource.youtube;
    final size = track.sizeBytes;
    return GestureDetector(
      onSecondaryTap: () => showTrackActions(context, ref, track),
      child: ListTile(
        leading: TrackArtwork(track: track, size: 44, radius: 8),
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
                style: const TextStyle(color: KijiColors.muted, fontSize: 12),
              ),
            ),
          ],
        ),
        trailing: track.durationMs > 0
            ? Text(formatDuration(Duration(milliseconds: track.durationMs)), style: KijiText.mono(size: 11))
            : null,
        onTap: onTap,
        onLongPress: () => showTrackActions(context, ref, track),
      ),
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
            style: const TextStyle(color: KijiColors.muted),
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
