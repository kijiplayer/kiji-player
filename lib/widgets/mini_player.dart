import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/playback_provider.dart';
import '../screens/player/player_screen.dart';
import '../theme/app_colors.dart';
import 'album_cover.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  static const _height = 68.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final theme = Theme.of(context);

    return Material(
      color: AppColors.surfaceContainer,
      child: Container(
        height: _height,
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF2A2A32)),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => PlayerScreen.open(context),
                child: Row(
                  children: [
                    AlbumCover(color: playback.track.coverColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playback.track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            playback.track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.onSurfaceMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              onPressed: () =>
                  ref.read(playbackProvider.notifier).togglePlayPause(),
              icon: Icon(
                playback.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
              iconSize: 32,
              color: AppColors.seed,
              tooltip: playback.isPlaying ? 'Pausar' : 'Reproducir',
            ),
          ],
        ),
      ),
    );
  }
}
