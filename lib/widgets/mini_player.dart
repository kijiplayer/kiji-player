import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/playback_provider.dart';
import '../screens/player/player_screen.dart';
import '../theme/kiji_tokens.dart';
import 'album_cover.dart';
import 'nocturne/glass.dart';

/// Mini-reproductor de vidrio (§7): radio 20, borde 1 px blanco 12 %, y una
/// línea de progreso degradada de 2 px abajo. Sin canción elegida, no ocupa
/// lugar.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final track = playback.track;
    if (track == null) return const SizedBox.shrink();

    return Glass(
      radius: KijiRadii.miniPlayer,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => PlayerScreen.open(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 6, 8),
                child: Row(
                  children: [
                    TrackArtwork(track: track, size: 44, radius: 12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: KijiColors.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => ref.read(playbackProvider.notifier).togglePlayPause(),
                      icon: Icon(
                        playback.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      ),
                      iconSize: 32,
                      color: Colors.white,
                      tooltip: playback.isPlaying ? 'Pausar' : 'Reproducir',
                    ),
                  ],
                ),
              ),
            ),
            // Línea de progreso degradada de 2 px.
            SizedBox(
              height: KijiSizes.progressLine,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: playback.progress.clamp(0.0, 1.0),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(gradient: KijiColors.accentGradient),
                    child: SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
