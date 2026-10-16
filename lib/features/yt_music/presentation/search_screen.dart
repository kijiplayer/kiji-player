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
import '../../downloads/presentation/download_button.dart';
import '../../queue/presentation/track_actions.dart';
import '../data/ytm_browse_parser.dart';
import '../data/ytm_client.dart';
import 'collection_screens.dart';
import '../domain/yt_track_mapper.dart';

/// Qué se busca (chips del mockup, §7).
enum SearchKind {
  songs('Canciones'),
  artists('Artistas'),
  albums('Álbumes'),
  myFiles('Mis archivos');

  const SearchKind(this.label);
  final String label;
}

/// Filtra [tracks] por título, artista o álbum (sin distinguir mayúsculas).
List<Track> filterMyFiles(List<Track> tracks, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  return tracks
      .where((t) =>
          t.title.toLowerCase().contains(q) ||
          t.artist.toLowerCase().contains(q) ||
          (t.album?.toLowerCase().contains(q) ?? false))
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
  SearchKind _kind = SearchKind.songs;

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

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = const [];
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
    if (_kind == SearchKind.artists || _kind == SearchKind.albums) {
      try {
        final kind = _kind == SearchKind.artists ? YtCollectionKind.artist : YtCollectionKind.album;
        final collections = await _client.searchCollections(query, kind);
        if (!mounted) return;
        setState(() {
          _collections = collections;
          _loading = false;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _error = 'No se pudo buscar. Revisá tu conexión a Internet.';
          _loading = false;
        });
        debugPrint('=== ERROR AL BUSCAR ${_kind.label.toUpperCase()} "$query": $error ===');
      }
      return;
    }

    try {
      final results = await _client.search(query, songsOnly: true);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo buscar. Revisá tu conexión a Internet.';
        _loading = false;
      });
      debugPrint('=== ERROR AL BUSCAR "$query" ===\n$error');
    }
  }

  Future<void> _play(YtMusicSearchResult result) async {
    setState(() => _resolvingVideoId = result.videoId);

    try {
      // El reproductor resuelve el audio (descarga, caché o YouTube) y, si
      // falla, avisa en palabras simples (Modo de Gracia).
      await ref.read(playbackProvider.notifier).playTrack(ytTrackFromResult(result, audioUrl: ''));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo reproducir esta canción.')),
        );
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
          // Campo con borde degradado (§7). Ctrl K lo enfoca desde cualquier lado.
          child: GradientBorder(
            radius: KijiRadii.pill,
            fill: KijiColors.surface,
            child: TextField(
              controller: _controller,
              focusNode: ref.watch(searchFocusProvider),
              onChanged: _onChanged,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Buscar canciones, artistas...',
                hintStyle: TextStyle(color: AppColors.onSurfaceMuted),
                prefixIcon: Icon(Icons.search_rounded, color: KijiColors.muted),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
                    selectedColor: KijiColors.violet,
                    labelStyle: TextStyle(
                      color: _kind == kind ? Colors.white : KijiColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                    side: const BorderSide(color: KijiColors.glassBorder),
                    shape: const StadiumBorder(),
                    onSelected: (_) {
                      setState(() => _kind = kind);
                      _search(_controller.text);
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: switch (_kind) {
            SearchKind.songs => _buildBody(),
            SearchKind.myFiles => _buildMyFiles(),
            SearchKind.artists || SearchKind.albums => _buildCollections(),
          },
        ),
      ],
    );
  }

  /// Artistas o álbumes de YouTube Music (anónimo).
  Widget _buildCollections() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: AppColors.onSurfaceMuted)));
    }
    if (_controller.text.trim().isEmpty) {
      return Center(
        child: Text('Buscá ${_kind.label.toLowerCase()}', style: const TextStyle(color: AppColors.onSurfaceMuted)),
      );
    }
    if (_collections.isEmpty) {
      return const Center(child: Text('Sin resultados', style: TextStyle(color: AppColors.onSurfaceMuted)));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 180),
      itemCount: _collections.length,
      itemBuilder: (context, index) => CollectionTile(collection: _collections[index]),
    );
  }

  /// Canciones locales y descargadas que coinciden, sin internet.
  Widget _buildMyFiles() {
    final query = _controller.text;
    final local = ref.watch(localTracksProvider).value ?? const <Track>[];
    final downloaded = [for (final d in ref.watch(downloadsProvider).completed.values) d.toTrack()];
    final results = filterMyFiles([...downloaded, ...local], query);

    if (query.trim().isEmpty) {
      return const Center(
        child: Text('Buscá entre tu música guardada y tus descargas',
            style: TextStyle(color: AppColors.onSurfaceMuted)),
      );
    }
    if (results.isEmpty) {
      return const Center(
        child: Text('No hay coincidencias en tus archivos',
            style: TextStyle(color: AppColors.onSurfaceMuted)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 180),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final track = results[index];
        return ListTile(
          leading: TrackArtwork(track: track, size: 44, radius: 8),
          title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => ref.read(playbackProvider.notifier).playQueue(results, startIndex: index),
          onLongPress: () => showTrackActions(context, ref, track),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: AppColors.onSurfaceMuted)),
      );
    }
    if (_controller.text.trim().isEmpty) {
      return const Center(
        child: Text(
          'Busca música, videos o podcasts',
          style: TextStyle(color: AppColors.onSurfaceMuted),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text('Sin resultados', style: TextStyle(color: AppColors.onSurfaceMuted)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 180),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox.shrink(),
      itemBuilder: (context, index) {
        final result = _results[index];
        final isResolving = _resolvingVideoId == result.videoId;

        final track = ytTrackFromResult(result, audioUrl: '');

        // Mantener apretado (celular) o clic derecho (PC): "Reproducir a
        // continuación" / "Agregar a la cola".
        return GestureDetector(
          onSecondaryTap: () => showTrackActions(context, ref, track),
          child: ListTile(
            leading: _Thumbnail(url: result.thumbnailUrl),
            title: Text(result.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(result.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: isResolving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : DownloadButton(track: track),
            onTap: isResolving ? null : () => _play(result),
            onLongPress: () => showTrackActions(context, ref, track),
          ),
        );
      },
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
            ? Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _FallbackThumb(),
              )
            : const _FallbackThumb(),
      ),
    );
  }
}

class _FallbackThumb extends StatelessWidget {
  const _FallbackThumb();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceContainer,
      child: const Icon(Icons.music_note_rounded, color: Colors.white70, size: 20),
    );
  }
}
