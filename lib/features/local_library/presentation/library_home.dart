import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/track.dart';
import '../../../providers/downloads_provider.dart';
import '../../../providers/local_library_provider.dart';
import '../../../providers/playback_provider.dart';
import '../../../providers/shell_provider.dart';
import '../../../theme/kiji_tokens.dart';
import '../../../widgets/album_cover.dart';
import '../../../widgets/list_search_field.dart';
import '../../../widgets/nocturne/glass.dart';
import '../../../widgets/scroll_to_top_on_reselect.dart';
import '../../customize/presentation/customize_sheets.dart' show PlaylistCover;
import '../../customize/presentation/track_text.dart';
import '../../playlists/domain/playlist.dart';
import '../../playlists/playlists_provider.dart';
import '../../playlists/presentation/playlist_screens.dart';
import '../../selection/track_selection.dart';
import '../../settings/data/settings_store.dart';
import '../../settings/domain/app_settings.dart';
import '../../settings/domain/setting_search.dart' show normalizeForSearch;
import '../../account/presentation/account_screens.dart' show YtConnectCard;
import 'local_library_screen.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Biblioteca (0.9, «una sola lista»): arriba el buscador, después tus playlists y, debajo, tu
/// música (Canciones, Descargadas y, si se eligieron, Artistas, Álbumes y Carpetas). Sin pestañas
/// que se muevan: cada entrada abre su pantalla. Qué se ve lo elige el usuario.
class LibraryHome extends ConsumerStatefulWidget {
  const LibraryHome({super.key});

  @override
  ConsumerState<LibraryHome> createState() => _LibraryHomeState();
}

class _LibraryHomeState extends ConsumerState<LibraryHome> {
  String _query = '';
  final _selection = TrackSelection();

  @override
  void initState() {
    super.initState();
    _selection.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _selection
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  /// Descargadas y, con la música del dispositivo, las locales.
  List<Track> _allSongs() {
    final downloaded = ref.watch(downloadsProvider.select((d) => d.completed)).values.toList()
      ..sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    return [for (final d in downloaded) d.toTrack(), ...?ref.watch(localTracksProvider).value];
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final songs = _allSongs();
    final results = _query.isEmpty
        ? const <Track>[]
        : [
            for (final t in songs)
              if (trackMatches(t, _query)) t,
          ];
    final playlistResults = _query.isEmpty
        ? const <Playlist>[]
        : [
            for (final p in ref.watch(playlistsProvider))
              if (normalizeForSearch(p.name).contains(_query)) p,
          ];

    final list = ScrollToTopOnReselect(
      tab: ShellTab.library,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 180),
        children: [
          Row(
            children: [
              Expanded(child: Text(tx.navLibrary, style: KijiText.title(size: 28))),
              IconButton(
                key: const Key('library-choose-entries'),
                tooltip: tx.queVerEnLaBiblioteca,
                icon: const Icon(Icons.tune_rounded),
                onPressed: () => showLibraryEntriesSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListSearchField(hint: tx.buscarEnTuBiblioteca, onChanged: (q) => setState(() => _query = q)),
          if (_query.isNotEmpty) ...[
            for (final p in playlistResults)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: PlaylistCover(playlist: p),
                title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(tx.nCanciones(p.tracks.length), style: TextStyle(color: KijiColors.muted)),
                onTap: () => PlaylistScreen.open(context, p.id),
              ),
            for (final (i, t) in results.indexed)
              _ResultTile(
                track: t,
                selecting: _selection.active,
                selected: _selection.contains(t.id),
                onTap: () => _selection.active
                    ? _selection.toggle(t.id, t)
                    : ref.read(playbackProvider.notifier).playQueue(results, startIndex: i),
                onLongPress: () => _selection.toggle(t.id, t),
              ),
            if (results.isEmpty && playlistResults.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tx.nadaEnTuBiblioteca,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: KijiColors.muted),
                ),
              ),
          ] else ...[
            if (settings.phoneMusic == 'ask') const PhoneMusicQuestion(),
            if (settings.libraryEntries.contains('playlists'))
              const Padding(padding: EdgeInsets.only(top: 8), child: PlaylistsView(compact: true)),
            const SizedBox(height: 16),
            Text(tx.tuMusica, style: KijiText.mono(size: 11)),
            const SizedBox(height: 8),
            _MusicCard(settings: settings, songCount: songs.length),
            // «Conecta tu YouTube Music (opcional)», al final: no tapa lo de arriba.
            const Padding(padding: EdgeInsets.only(top: 12), child: YtConnectCard()),
          ],
        ],
      ),
    );

    return Stack(
      children: [
        list,
        if (_selection.active)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: SelectionBar(selection: _selection, all: {for (final t in results) t.id: t}),
            ),
          ),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.track,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final Track track;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) => ListTile(
    key: Key('library-result-${track.id}'),
    contentPadding: EdgeInsets.zero,
    leading: selecting ? SelectionCheck(selected: selected) : TrackArtwork(track: track, size: 48, radius: 8),
    title: TrackTitleText(track, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: TrackArtistText(
      track,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: KijiColors.muted),
    ),
    onTap: onTap,
    onLongPress: onLongPress,
  );
}

/// Las entradas de «Tu música», cada una abre su pantalla.
class _MusicCard extends ConsumerWidget {
  const _MusicCard({required this.settings, required this.songCount});

  final AppSettings settings;
  final int songCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = settings.libraryEntries;
    final phone = settings.showsPhoneMusic;
    final downloads = ref.watch(downloadsProvider.select((d) => d.completed.length));
    Widget entry(LibraryTab tab, IconData icon, [String? subtitle]) => ListTile(
      key: Key('library-entry-${tab.name}'),
      leading: Icon(icon, color: KijiColors.cyan),
      title: Text(tab.label),
      subtitle: subtitle == null ? null : Text(subtitle, style: TextStyle(color: KijiColors.muted)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => LocalLibraryScreen.openSection(context, tab),
    );
    final tiles = [
      if (entries.contains('songs')) entry(LibraryTab.songs, Icons.music_note_rounded, tx.nCanciones(songCount)),
      if (entries.contains('downloads'))
        entry(LibraryTab.downloads, Icons.download_done_rounded, '${tx.nCanciones(downloads)} · ${tx.sinInternet}'),
      // Artistas, Álbumes y Carpetas salen de la música del dispositivo.
      if (phone && entries.contains('artists')) entry(LibraryTab.artists, Icons.person_outline_rounded),
      if (phone && entries.contains('albums')) entry(LibraryTab.albums, Icons.album_outlined),
      if (phone && entries.contains('folders')) entry(LibraryTab.folders, Icons.folder_outlined),
      // Las listas inteligentes (Más escuchadas, Recientes…), juntas en su pantalla.
      ListTile(
        key: const Key('library-entry-smart'),
        leading: Icon(Icons.auto_awesome_rounded, color: KijiColors.cyan),
        title: Text(tx.listasInteligentes),
        subtitle: Text(tx.calculadasEnTuTelefono, style: TextStyle(color: KijiColors.muted)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => SmartListsScreen.open(context),
      ),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Glass(
      blur: false,
      radius: KijiRadii.tile,
      child: Material(
        type: MaterialType.transparency,
        child: Column(children: tiles),
      ),
    );
  }
}

/// La primera vez: ¿mostrar la música del dispositivo? (también en Configuración).
class PhoneMusicQuestion extends ConsumerWidget {
  const PhoneMusicQuestion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> choose(String value) async {
      // La tarjeta se va al elegir: lo de Riverpod se toma antes (su `ref` deja de servir).
      final container = ProviderScope.containerOf(context, listen: false);
      await container.read(settingsProvider.notifier).update((s) => s.copyWith(phoneMusic: value));
      if (value != 'on') return;
      // «Sí»: el permiso se pide ahora (en Android; en la PC se elige la carpeta al abrir Canciones).
      final source = container.read(localLibrarySourceProvider);
      if (!source.usesFolders && !await source.hasAccess()) await source.requestAccess();
      container.invalidate(localTracksProvider);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Glass(
        key: const Key('phone-music-question'),
        blur: false,
        radius: KijiRadii.tile,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tx.musicaDelDispositivoPregunta, style: KijiText.title(size: 17)),
              const SizedBox(height: 6),
              Text(tx.musicaDelDispositivoPreguntaNota, style: TextStyle(color: KijiColors.muted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    key: const Key('phone-music-no'),
                    onPressed: () => choose('off'),
                    child: Text(tx.noSoloKiji),
                  ),
                  FilledButton(
                    key: const Key('phone-music-yes'),
                    onPressed: () => choose('on'),
                    child: Text(tx.siMostrarla),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «Qué ver en la Biblioteca»: un interruptor por entrada.
Future<void> showLibraryEntriesSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => const _EntriesSheet(),
);

class _EntriesSheet extends ConsumerWidget {
  const _EntriesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    String label(String name) => switch (name) {
      'playlists' => tx.playlists, // l10n-ignore
      'songs' => tx.canciones, // l10n-ignore
      'downloads' => tx.descargadas,
      'artists' => tx.artistas, // l10n-ignore
      'albums' => tx.albumes,
      _ => tx.carpetas,
    };
    const local = {'artists', 'albums', 'folders'}; // l10n-ignore
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text(tx.queVerEnLaBiblioteca, style: KijiText.title(size: 20)),
              subtitle: Text(tx.queVerEnLaBibliotecaNota),
            ),
            SwitchListTile(
              key: const Key('entries-phone-music'),
              title: Text(tx.musicaDelDispositivo),
              subtitle: Text(tx.musicaDelDispositivoNota),
              value: settings.showsPhoneMusic,
              onChanged: (on) => notifier.update((s) => s.copyWith(phoneMusic: on ? 'on' : 'off')),
            ),
            const Divider(),
            for (final name in AppSettings.libraryEntryNames)
              SwitchListTile(
                key: Key('entries-$name'),
                title: Text(label(name)),
                subtitle: local.contains(name) && !settings.showsPhoneMusic
                    ? Text(tx.necesitaMusicaDelDispositivo)
                    : null,
                value: settings.libraryEntries.contains(name),
                onChanged: local.contains(name) && !settings.showsPhoneMusic
                    ? null
                    : (on) => notifier.update(
                        (s) => s.copyWith(
                          libraryEntries: [
                            for (final n in AppSettings.libraryEntryNames)
                              if (n == name ? on : s.libraryEntries.contains(n)) n,
                          ],
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
