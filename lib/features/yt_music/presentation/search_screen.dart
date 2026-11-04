import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/track.dart';
import '../../../providers/downloads_provider.dart';
import '../../../providers/local_library_provider.dart';
import '../../../providers/playback_provider.dart';
import '../../../providers/shell_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/kiji_tokens.dart';
import '../../../widgets/album_cover.dart';
import '../../../widgets/nocturne/glass.dart';
import '../../../widgets/nocturne/staggered.dart';
import '../../downloads/presentation/download_button.dart';
import '../../queue/presentation/track_actions.dart';
import '../data/ytm_browse_parser.dart';
import '../data/ytm_client.dart';
import 'collection_screens.dart';
import '../domain/yt_track_mapper.dart';
import '../../customize/presentation/track_text.dart';
import '../../history/listening_history.dart';
import '../../recommendations/data/home_feed_provider.dart';
import '../../recommendations/data/search_history.dart';
import '../../recommendations/presentation/home_sections.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Qué se busca.
enum SearchKind {
  all,
  songs,
  artists,
  albums,
  playlists,
  myFiles;

  String get label => switch (this) {
    SearchKind.all => tx.todo,
    SearchKind.songs => tx.canciones,
    SearchKind.artists => tx.artistas,
    SearchKind.albums => tx.albumes,
    SearchKind.playlists => tx.playlists,
    SearchKind.myFiles => tx.misArchivos,
  };
}

/// Pestaña Todo: el resultado principal y unos pocos de cada tipo, en este orden.
class SearchOverview {
  const SearchOverview({
    this.top,
    this.songs = const [],
    this.artists = const [],
    this.albums = const [],
    this.playlists = const [],
  });

  /// Arma la vista sin repetir el resultado principal en su sección.
  factory SearchOverview.from({
    YtTopResult? top,
    List<YtMusicSearchResult> songs = const [],
    List<YtCollection> artists = const [],
    List<YtCollection> albums = const [],
    List<YtCollection> playlists = const [],
    int songsShown = 4,
    int othersShown = 3,
  }) {
    final topSong = top?.song?.videoId;
    final topCollection = top?.collection?.browseId;
    List<YtCollection> pick(List<YtCollection> list) =>
        list.where((c) => c.browseId != topCollection).take(othersShown).toList();
    return SearchOverview(
      top: top,
      songs: songs.where((s) => s.videoId != topSong).take(songsShown).toList(),
      artists: pick(artists),
      albums: pick(albums),
      playlists: pick(playlists),
    );
  }

  final YtTopResult? top;
  final List<YtMusicSearchResult> songs;
  final List<YtCollection> artists;
  final List<YtCollection> albums;
  final List<YtCollection> playlists;

  bool get isEmpty => top == null && songs.isEmpty && artists.isEmpty && albums.isEmpty && playlists.isEmpty;
}

/// Filtra [tracks] por título, artista o álbum (sin distinguir mayúsculas).
List<Track> filterMyFiles(List<Track> tracks, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  return tracks
      .where(
        (t) =>
            t.title.toLowerCase().contains(q) ||
            t.artist.toLowerCase().contains(q) ||
            (t.album?.toLowerCase().contains(q) ?? false),
      )
      .toList();
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _client = YtMusicClient();
  final _controller = TextEditingController();
  Timer? _debounce;

  List<YtMusicSearchResult> _results = const [];
  List<YtCollection> _collections = const [];
  bool _loading = false;
  String? _error;
  String? _resolvingVideoId;
  SearchKind _kind = SearchKind.all;
  SearchOverview _overview = const SearchOverview();

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(query));
    setState(() {}); // refresca el mensaje vacío/placeholder al instante
  }

  /// Marca de YouTube Music para la página siguiente (null: no hay más).
  String? _continuation;
  bool _loadingMore = false;

  /// Sube con cada búsqueda nueva: lo que llegue de una búsqueda vieja se descarta.
  int _generation = 0;

  YtCollectionKind get _collectionKind => switch (_kind) {
    SearchKind.artists => YtCollectionKind.artist,
    SearchKind.playlists => YtCollectionKind.playlist,
    _ => YtCollectionKind.album,
  };

  /// Pestaña Todo: todo a la vez; si una parte falla, se muestra el resto.
  Future<SearchOverview> _loadOverview(String query) async {
    var failures = 0;
    Future<T?> part<T>(String what, Future<T> future) async {
      try {
        return await future;
      } catch (error) {
        failures++;
        debugPrint('=== BÚSQUEDA: Todo sin $what: $error ===');
        return null;
      }
    }

    final top = part('resultado principal', _client.searchTop(query)); // l10n-ignore (registro)
    final songs = part('canciones', _client.searchSongsPage(query)); // l10n-ignore (registro)
    final artists = part('artistas', _client.searchCollectionsPage(query, YtCollectionKind.artist)); // l10n-ignore (registro)
    final albums = part('álbumes', _client.searchCollectionsPage(query, YtCollectionKind.album)); // l10n-ignore (registro)
    final playlists = part('playlists', _client.searchCollectionsPage(query, YtCollectionKind.playlist)); // l10n-ignore (registro)
    final overview = SearchOverview.from(
      top: await top,
      songs: (await songs)?.items ?? const [],
      artists: (await artists)?.items ?? const [],
      albums: (await albums)?.items ?? const [],
      playlists: (await playlists)?.items ?? const [],
    );
    if (overview.isEmpty && failures == 5) throw StateError('falló toda la búsqueda');
    return overview;
  }

  Future<void> _search(String query) async {
    final generation = ++_generation;
    _continuation = null;
    _loadingMore = false;
    if (query.trim().isEmpty) {
      setState(() {
        _results = const [];
        _collections = const [];
        _overview = const SearchOverview();
        _error = null;
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    if (_kind == SearchKind.myFiles) {
      // Mis archivos se filtra en pantalla, sin internet.
      setState(() => _loading = false);
      return;
    }
    try {
      if (_kind == SearchKind.all) {
        final overview = await _loadOverview(query);
        if (!mounted || generation != _generation) return;
        setState(() {
          _overview = overview;
          _loading = false;
        });
      } else if (_kind == SearchKind.songs) {
        final page = await _client.searchSongsPage(query);
        if (!mounted || generation != _generation) return;
        setState(() {
          _results = page.items;
          _continuation = page.continuation;
          _loading = false;
        });
      } else {
        final page = await _client.searchCollectionsPage(query, _collectionKind);
        if (!mounted || generation != _generation) return;
        setState(() {
          _collections = page.items;
          _continuation = page.continuation;
          _loading = false;
        });
      }
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = tx.noSePudoBuscarRevisaTu;
        _loading = false;
      });
      debugPrint('=== BÚSQUEDA: error al buscar ${_kind.name} "$query": $error ===');
    }
  }

  /// Trae la página siguiente de la pestaña actual (al llegar cerca del final).
  Future<void> _loadMore() async {
    final token = _continuation;
    if (token == null || _loadingMore || _loading || _kind == SearchKind.myFiles || _kind == SearchKind.all) return;
    final generation = _generation;
    setState(() => _loadingMore = true);
    try {
      if (_kind == SearchKind.songs) {
        final page = await _client.searchSongsPage(_controller.text, continuation: token);
        if (!mounted || generation != _generation) return;
        final seen = {for (final r in _results) r.videoId};
        setState(() {
          _results = [..._results, ...page.items.where((r) => seen.add(r.videoId))];
          _continuation = page.items.isEmpty ? null : page.continuation;
        });
      } else {
        final page = await _client.searchCollectionsPage(_controller.text, _collectionKind, continuation: token);
        if (!mounted || generation != _generation) return;
        final seen = {for (final c in _collections) c.browseId};
        setState(() {
          _collections = [..._collections, ...page.items.where((c) => seen.add(c.browseId))];
          _continuation = page.items.isEmpty ? null : page.continuation;
        });
      }
    } catch (error) {
      // Sin aviso: lo ya cargado queda, y al volver a bajar se reintenta.
      debugPrint('=== BÚSQUEDA: no se pudo traer más resultados: $error ===');
    } finally {
      if (mounted && generation == _generation) setState(() => _loadingMore = false);
    }
  }

  /// Envuelve una lista de resultados: cerca del final pide la página siguiente.
  Widget _withMore(Widget list) => NotificationListener<ScrollNotification>(
    onNotification: (notification) {
      if (notification.metrics.axis == Axis.vertical && notification.metrics.extentAfter < 600) _loadMore();
      return false;
    },
    child: list,
  );

  /// Al pie de la lista, mientras llega la página siguiente.
  Widget get _moreIndicator => const Padding(
    padding: EdgeInsets.symmetric(vertical: 16),
    child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
  );

  /// Guarda la búsqueda en "Recientes" (solo al confirmarla: Enter o tocar
  /// un resultado; no cada letra).
  void _remember(String query) => ref.read(searchHistoryProvider.notifier).add(query);

  void _searchFor(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    _remember(query);
    _search(query);
  }

  /// Antes de escribir: búsquedas recientes y sugerencias.
  Widget _buildBeforeTyping() {
    final recent = ref.watch(searchHistoryProvider);
    final isNew = ref.watch(listeningHistoryProvider).isEmpty;
    final feed = isNew ? null : ref.watch(homeFeedProvider).value;
    final suggestions = feed == null ? const <Track>[] : (feed.discover.isNotEmpty ? feed.discover : feed.mix);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 180),
      children: [
        if (recent.isNotEmpty) ...[
          Row(
            children: [
              Expanded(child: Text(tx.recientes, style: KijiText.mono(size: 11))),
              TextButton(onPressed: () => ref.read(searchHistoryProvider.notifier).clear(), child: Text(tx.borrar)),
            ],
          ),
          for (final query in recent.take(8))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.history_rounded, color: KijiColors.muted),
              title: Text(query, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                tooltip: tx.quitar,
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => ref.read(searchHistoryProvider.notifier).remove(query),
              ),
              onTap: () => _searchFor(query),
            ),
          const SizedBox(height: 16),
        ],
        if (suggestions.isNotEmpty)
          TrackShelf(title: tx.tePuedeGustar, note: tx.segunLoQueEscuchas, tracks: suggestions),
        isNew
            ? const StartHereSection()
            : StartHereSection(title: tx.exploraPorEstilo, note: tx.generosYAnimosDeYoutubeMusic),
      ],
    );
  }

  Future<void> _play(YtMusicSearchResult result) async {
    _remember(_controller.text);
    setState(() => _resolvingVideoId = result.videoId);

    try {
      // El reproductor resuelve el audio (descarga, caché o YouTube) y, si
      // falla, avisa en palabras simples (Modo de Gracia).
      await ref.read(playbackProvider.notifier).playTrack(ytTrackFromResult(result, audioUrl: ''));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tx.noSePudoReproducirEstaCancion)));
      }
      debugPrint('=== ERROR AL REPRODUCIR RESULTADO DE BÚSQUEDA ===\n$error');
    } finally {
      if (mounted) setState(() => _resolvingVideoId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          // Campo con borde degradado. Ctrl K lo enfoca desde cualquier lado.
          child: GradientBorder(
            radius: KijiRadii.pill,
            fill: KijiColors.surface,
            child: TextField(
              controller: _controller,
              focusNode: ref.watch(searchFocusProvider),
              onChanged: _onChanged,
              onSubmitted: (query) {
                _remember(query);
                _debounce?.cancel();
                _search(query);
              },
              textInputAction: TextInputAction.search,
              style: TextStyle(color: KijiColors.text),
              decoration: InputDecoration(
                hintText: tx.buscarCancionesArtistas,
                hintStyle: TextStyle(color: AppColors.onSurfaceMuted),
                prefixIcon: Icon(Icons.search_rounded, color: KijiColors.muted),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final kind in SearchKind.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(kind.label),
                    selected: _kind == kind,
                    showCheckmark: false,
                    // Colores de lo elegido: los del tema (KijiSelected).
                    shape: const StadiumBorder(),
                    onSelected: (_) => _switchTo(kind),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: switch (_kind) {
            SearchKind.all => _buildOverview(),
            SearchKind.songs => _buildBody(),
            SearchKind.myFiles => _buildMyFiles(),
            SearchKind.artists || SearchKind.albums || SearchKind.playlists => _buildCollections(),
          },
        ),
      ],
    );
  }

  /// Artistas o álbumes de YouTube Music (anónimo).
  Widget _buildCollections() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Text(_error!, style: TextStyle(color: AppColors.onSurfaceMuted)),
      );
    }
    if (_controller.text.trim().isEmpty) return _buildBeforeTyping();
    if (_collections.isEmpty) {
      return Center(
        child: Text(tx.sinResultados, style: TextStyle(color: AppColors.onSurfaceMuted)),
      );
    }
    return _withMore(
      ListView.builder(
        padding: const EdgeInsets.only(bottom: 180),
        itemCount: _collections.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) =>
            index == _collections.length ? _moreIndicator : CollectionTile(collection: _collections[index]),
      ),
    );
  }

  /// Canciones locales y descargadas que coinciden, sin internet.
  Widget _buildMyFiles() {
    final query = _controller.text;
    final local = ref.watch(localTracksProvider).value ?? const <Track>[];
    final downloaded = [for (final d in ref.watch(downloadsProvider.select((d) => d.completed)).values) d.toTrack()];
    final results = filterMyFiles([...downloaded, ...local], query);

    if (query.trim().isEmpty) {
      return Center(
        child: Text(tx.buscaEntreTuMusicaGuardadaY, style: TextStyle(color: AppColors.onSurfaceMuted)),
      );
    }
    if (results.isEmpty) {
      return Center(
        child: Text(tx.noHayCoincidenciasEnTusArchivos, style: TextStyle(color: AppColors.onSurfaceMuted)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 180),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final track = results[index];
        return ListTile(
          leading: TrackArtwork(track: track, size: 44, radius: 8),
          title: TrackTitleText(track, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: TrackArtistText(track, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => ref.read(playbackProvider.notifier).playQueue(results, startIndex: index),
          onLongPress: () => showTrackActions(context, ref, track),
        );
      },
    );
  }

  void _switchTo(SearchKind kind) {
    setState(() => _kind = kind);
    _search(_controller.text);
  }

  /// Una canción de los resultados. Mantener presionado (celular) o clic
  /// derecho (PC): "Reproducir a continuación" / "Agregar a la cola".
  Widget _songTile(YtMusicSearchResult result) {
    final isResolving = _resolvingVideoId == result.videoId;
    final track = ytTrackFromResult(result, audioUrl: '');
    return GestureDetector(
      onSecondaryTap: () => showTrackActions(context, ref, track),
      child: ListTile(
        leading: _Thumbnail(url: result.thumbnailUrl),
        title: Text(result.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(result.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: isResolving
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : DownloadButton(track: track),
        onTap: isResolving ? null : () => _play(result),
        onLongPress: () => showTrackActions(context, ref, track),
      ),
    );
  }

  /// Título de una sección de la pestaña Todo, con "Ver todo" si tiene pestaña propia.
  Widget _sectionHeader(String title, {SearchKind? more}) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
    child: Row(
      children: [
        Expanded(child: Text(title.toUpperCase(), style: KijiText.mono(size: 11))),
        if (more != null) TextButton(onPressed: () => _switchTo(more), child: Text(tx.verTodo)),
      ],
    ),
  );

  /// Pestaña Todo: primero lo más exacto, después canciones, artistas, álbumes y playlists.
  Widget _buildOverview() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Text(_error!, style: TextStyle(color: AppColors.onSurfaceMuted)),
      );
    }
    if (_controller.text.trim().isEmpty) return _buildBeforeTyping();
    final o = _overview;
    if (o.isEmpty) {
      return Center(
        child: Text(tx.sinResultados, style: TextStyle(color: AppColors.onSurfaceMuted)),
      );
    }
    final top = o.top;
    final children = <Widget>[
      if (top != null) ...[
        _sectionHeader(tx.resultadoPrincipal),
        if (top.song != null) _songTile(top.song!) else CollectionTile(collection: top.collection!),
      ],
      if (o.songs.isNotEmpty) ...[
        _sectionHeader(tx.canciones, more: SearchKind.songs),
        for (final song in o.songs) _songTile(song),
      ],
      for (final (title, kind, list) in [
        (tx.artistas, SearchKind.artists, o.artists),
        (tx.albumes, SearchKind.albums, o.albums),
        (tx.playlists, SearchKind.playlists, o.playlists),
      ])
        if (list.isNotEmpty) ...[
          _sectionHeader(title, more: kind),
          for (final collection in list) CollectionTile(collection: collection),
        ],
    ];
    return StaggerScope(
      generation: o,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 180),
        itemCount: children.length,
        itemBuilder: (context, index) => StaggeredEntrance(index: index, child: children[index]),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: TextStyle(color: AppColors.onSurfaceMuted)),
      );
    }
    if (_controller.text.trim().isEmpty) return _buildBeforeTyping();
    if (_results.isEmpty) {
      return Center(
        child: Text(tx.sinResultados, style: TextStyle(color: AppColors.onSurfaceMuted)),
      );
    }

    // Los resultados entran escalonados; otra búsqueda vuelve a escalonar.
    return StaggerScope(
      generation: _results,
      child: _withMore(
        ListView.separated(
          padding: const EdgeInsets.only(bottom: 180),
          itemCount: _results.length + (_loadingMore ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox.shrink(),
          itemBuilder: (context, index) {
            if (index == _results.length) return _moreIndicator;
            return StaggeredEntrance(index: index, child: _songTile(_results[index]));
          },
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 44,
        height: 44,
        child: url != null
            ? Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const _FallbackThumb())
            : const _FallbackThumb(),
      ),
    );
  }
}

class _FallbackThumb extends StatelessWidget {
  const _FallbackThumb();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceContainer,
      child: const Icon(Icons.music_note_rounded, color: Colors.white70, size: 20),
    );
  }
}
