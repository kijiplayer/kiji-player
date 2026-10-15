import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/track.dart';
import '../../../providers/downloads_provider.dart';
import '../../../providers/playback_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/duration_formatter.dart';
import '../../../utils/byte_formatter.dart';
import '../../downloads/presentation/downloads_screen.dart';
import '../data/local_library_service.dart';
import '../domain/local_track_mapper.dart';

enum _LibraryStatus { loading, denied, empty, ready, error }

class LocalLibraryScreen extends StatefulWidget {
  const LocalLibraryScreen({super.key});

  @override
  State<LocalLibraryScreen> createState() => _LocalLibraryScreenState();
}

class _LocalLibraryScreenState extends State<LocalLibraryScreen> {
  final _service = LocalLibraryService();
  _LibraryStatus _status = _LibraryStatus.loading;
  List<Track> _tracks = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = _LibraryStatus.loading);

    final alreadyGranted = await _service.hasPermission();
    final granted = alreadyGranted || await _service.requestPermission();

    if (!granted) {
      if (mounted) setState(() => _status = _LibraryStatus.denied);
      return;
    }

    try {
      final songs = await _service.fetchSongs();
      final tracks = songs
          .where((song) => song.isMusic ?? true)
          .map(localTrackFromSong)
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _tracks = tracks;
        _status = tracks.isEmpty ? _LibraryStatus.empty : _LibraryStatus.ready;
      });
    } catch (_) {
      if (mounted) setState(() => _status = _LibraryStatus.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Las descargas se ven aunque no haya permiso ni música local.
        const _DownloadsEntry(),
        const Divider(height: 1, color: Color(0xFF1F1F26)),
        Expanded(child: _buildLocal()),
      ],
    );
  }

  Widget _buildLocal() {
    return RefreshIndicator(
      onRefresh: _load,
      child: switch (_status) {
        _LibraryStatus.loading => const _CenteredMessage(
            child: CircularProgressIndicator(),
          ),
        _LibraryStatus.denied => _CenteredMessage(
            child: _InfoCard(
              icon: Icons.lock_outline_rounded,
              message: 'Kiji necesita permiso para leer tu música local.',
              actionLabel: 'Conceder permiso',
              onAction: _load,
            ),
          ),
        _LibraryStatus.error => _CenteredMessage(
            child: _InfoCard(
              icon: Icons.error_outline_rounded,
              message: 'No se pudo leer la biblioteca local.',
              actionLabel: 'Reintentar',
              onAction: _load,
            ),
          ),
        _LibraryStatus.empty => const _CenteredMessage(
            child: _InfoCard(
              icon: Icons.music_off_rounded,
              message: 'No se encontró música en este dispositivo.',
            ),
          ),
        _LibraryStatus.ready => _SongList(tracks: _tracks),
      },
    );
  }
}

class _DownloadsEntry extends ConsumerWidget {
  const _DownloadsEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadsProvider);
    final count = downloads.completed.length;
    final active = downloads.active.length;

    return ListTile(
      leading: const Icon(Icons.download_for_offline_rounded, color: AppColors.seed),
      title: const Text('Descargadas'),
      subtitle: Text(
        count == 0 && active == 0
            ? 'Para escuchar sin conexión'
            : '$count ${count == 1 ? 'canción' : 'canciones'} · ${formatBytes(downloads.usedBytes)}'
                '${active > 0 ? ' · $active descargando' : ''}',
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => DownloadsScreen.open(context),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Envuelto en ListView para que RefreshIndicator (pull-to-refresh)
    // funcione incluso cuando el contenido no llena la pantalla.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 360,
          child: Center(child: child),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppColors.onSurfaceMuted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
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

class _SongList extends ConsumerWidget {
  const _SongList({required this.tracks});

  final List<Track> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: tracks.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFF1F1F26)),
      itemBuilder: (context, index) {
        final track = tracks[index];
        return ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: track.coverColor,
            ),
            child: const Icon(Icons.music_note_rounded, color: Colors.white70, size: 20),
          ),
          title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Text(
            formatDuration(Duration(milliseconds: track.durationMs)),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
          ),
          onTap: () => ref
              .read(playbackProvider.notifier)
              .playQueue(tracks, startIndex: index),
        );
      },
    );
  }
}
