import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/playback_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/duration_formatter.dart';
import '../../widgets/album_cover.dart';

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        fullscreenDialog: true,
        pageBuilder: (context, animation, secondaryAnimation) => const PlayerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curve),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final coverColor = playback.track.coverColor;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _PlayerBackground(coverColor: coverColor),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _PlayerAppBar(onClose: () => Navigator.of(context).pop()),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final coverSize = min(
                          constraints.maxWidth * 0.72,
                          constraints.maxHeight * 0.62,
                        );

                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AlbumCover(
                              color: coverColor,
                              size: coverSize,
                              borderRadius: 16,
                              iconSize: coverSize * 0.28,
                            ),
                            const SizedBox(height: 32),
                            Text(
                              playback.track.title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              playback.track.artist,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppColors.onSurfaceMuted,
                                  ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  _ProgressSection(
                    progress: playback.progress,
                    position: playback.position,
                    duration: playback.duration,
                    accentColor: coverColor,
                    onSeek: ref.read(playbackProvider.notifier).seekToProgress,
                  ),
                  const SizedBox(height: 32),
                  _PlaybackControls(
                    isPlaying: playback.isPlaying,
                    shuffleEnabled: playback.shuffleEnabled,
                    repeatMode: playback.repeatMode,
                    accentColor: coverColor,
                    onShuffle: ref.read(playbackProvider.notifier).toggleShuffle,
                    onPrevious: ref.read(playbackProvider.notifier).previousTrack,
                    onPlayPause: ref.read(playbackProvider.notifier).togglePlayPause,
                    onNext: ref.read(playbackProvider.notifier).nextTrack,
                    onRepeat: ref.read(playbackProvider.notifier).toggleRepeatMode,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerBackground extends StatelessWidget {
  const _PlayerBackground({required this.coverColor});

  final Color coverColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.35),
              radius: 1.1,
              colors: [
                coverColor.withValues(alpha: 0.55),
                coverColor.withValues(alpha: 0.18),
                AppColors.background,
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  AppColors.background.withValues(alpha: 0.92),
                  AppColors.background,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlayerAppBar extends StatelessWidget {
  const _PlayerAppBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            iconSize: 32,
            color: Colors.white,
            tooltip: 'Minimizar',
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_horiz_rounded),
            color: AppColors.onSurfaceMuted,
            tooltip: 'Más opciones',
          ),
        ],
      ),
    );
  }
}

class _ProgressSection extends StatefulWidget {
  const _ProgressSection({
    required this.progress,
    required this.position,
    required this.duration,
    required this.accentColor,
    required this.onSeek,
  });

  final double progress;
  final Duration position;
  final Duration duration;
  final Color accentColor;
  final ValueChanged<double> onSeek;

  @override
  State<_ProgressSection> createState() => _ProgressSectionState();
}

class _ProgressSectionState extends State<_ProgressSection> {
  double? _dragProgress;

  @override
  Widget build(BuildContext context) {
    final progress = (_dragProgress ?? widget.progress).clamp(0.0, 1.0);
    final displayedPosition = _dragProgress == null
        ? widget.position
        : Duration(
            milliseconds: (widget.duration.inMilliseconds * progress).round(),
          );

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: widget.accentColor,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
            thumbColor: Colors.white,
            overlayColor: widget.accentColor.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: progress,
            onChangeStart: widget.duration.inMilliseconds > 0
                ? (_) => setState(() => _dragProgress = widget.progress)
                : null,
            onChanged: widget.duration.inMilliseconds > 0
                ? (value) => setState(() => _dragProgress = value)
                : null,
            onChangeEnd: widget.duration.inMilliseconds > 0
                ? (value) {
                    widget.onSeek(value);
                    setState(() => _dragProgress = null);
                  }
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatDuration(displayedPosition),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
              ),
              Text(
                formatDuration(widget.duration),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlaybackControls extends StatelessWidget {
  const _PlaybackControls({
    required this.isPlaying,
    required this.shuffleEnabled,
    required this.repeatMode,
    required this.accentColor,
    required this.onShuffle,
    required this.onPrevious,
    required this.onPlayPause,
    required this.onNext,
    required this.onRepeat,
  });

  final bool isPlaying;
  final bool shuffleEnabled;
  final PlaybackRepeatMode repeatMode;
  final Color accentColor;
  final VoidCallback onShuffle;
  final VoidCallback onPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onRepeat;

  @override
  Widget build(BuildContext context) {
    final repeatActive = repeatMode != PlaybackRepeatMode.off;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          onPressed: onShuffle,
          icon: Icon(
            Icons.shuffle_rounded,
            color: shuffleEnabled ? accentColor : AppColors.onSurfaceMuted,
          ),
          iconSize: 28,
          tooltip: 'Aleatorio',
        ),
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.skip_previous_rounded),
          iconSize: 36,
          color: Colors.white,
          tooltip: 'Anterior',
        ),
        _PlayPauseButton(
          isPlaying: isPlaying,
          accentColor: accentColor,
          onPressed: onPlayPause,
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.skip_next_rounded),
          iconSize: 36,
          color: Colors.white,
          tooltip: 'Siguiente',
        ),
        IconButton(
          onPressed: onRepeat,
          icon: Icon(
            repeatMode == PlaybackRepeatMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
            color: repeatActive ? accentColor : AppColors.onSurfaceMuted,
          ),
          iconSize: 28,
          tooltip: switch (repeatMode) {
            PlaybackRepeatMode.off => 'Repetir (desactivado)',
            PlaybackRepeatMode.all => 'Repetir cola',
            PlaybackRepeatMode.one => 'Repetir una canción',
          },
        ),
      ],
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.isPlaying,
    required this.accentColor,
    required this.onPressed,
  });

  final bool isPlaying;
  final Color accentColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accentColor,
      shape: const CircleBorder(),
      elevation: 8,
      shadowColor: accentColor.withValues(alpha: 0.45),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 72,
          height: 72,
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 40,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
