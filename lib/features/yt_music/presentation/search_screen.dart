import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/playback_provider.dart';
import '../../../theme/app_colors.dart';
import '../data/ytm_client.dart';
import '../domain/yt_track_mapper.dart';

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
  bool _loading = false;
  String? _error;
  String? _resolvingVideoId;

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

    try {
      final results = await _client.search(query);
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
      final audioUrl = await _client.getAudioStreamUrl(result.videoId);

      if (audioUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo obtener el audio de esta canción (formato protegido). Probá con otra.',
              ),
            ),
          );
        }
        return;
      }

      final track = ytTrackFromResult(result, audioUrl: audioUrl);
      await ref.read(playbackProvider.notifier).playTrack(track);
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
          child: TextField(
            controller: _controller,
            onChanged: _onChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar canciones, artistas...',
              hintStyle: const TextStyle(color: AppColors.onSurfaceMuted),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
              filled: true,
              fillColor: AppColors.surfaceContainer,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(child: _buildBody()),
      ],
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
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFF1F1F26)),
      itemBuilder: (context, index) {
        final result = _results[index];
        final isResolving = _resolvingVideoId == result.videoId;

        return ListTile(
          leading: _Thumbnail(url: result.thumbnailUrl),
          title: Text(result.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(result.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: isResolving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: isResolving ? null : () => _play(result),
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
