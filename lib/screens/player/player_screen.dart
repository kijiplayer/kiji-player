import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/sleep_timer/presentation/timer_waveform.dart';
import '../../features/downloads/presentation/download_button.dart';
import '../../features/favorites/favorites.dart';
import '../../features/lyrics/presentation/lyrics_screen.dart';
import '../../features/sleep_timer/presentation/sleep_timer_sheet.dart';
import '../../features/sleep_timer/sleep_timer_provider.dart';
import '../../features/queue/presentation/queue_screen.dart';
import '../../features/yt_music/presentation/extractor_health_screen.dart';
import '../../models/track.dart';
import '../../providers/appearance_provider.dart';
import '../../providers/downloads_provider.dart';
import '../../providers/playback_provider.dart';
import '../../theme/kiji_tokens.dart';
import '../../utils/duration_formatter.dart';
import '../../widgets/album_cover.dart';
import '../../widgets/global_mini_player.dart';
import '../../widgets/mini_player.dart' show coverHeroTag;
import '../../features/moments/presentation/moments_screen.dart';
import 'player_motion.dart';
import '../../widgets/nocturne/breathing_play_button.dart';
import '../../widgets/nocturne/glass.dart';
import '../../features/customize/presentation/track_text.dart';
import '../../features/playlists/presentation/playlist_screens.dart';

/// De dónde sale la canción, para "REPRODUCIENDO DESDE".
String playingFromLabel(Track track, {required bool downloaded}) {
  if (track.source == TrackSource.local) return 'TU BIBLIOTECA';
  if (downloaded) return 'DESCARGADAS';
  return 'YOUTUBE MUSIC';
}

/// Reproductor a pantalla completa (Kiji Nocturne, §7).
class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        settings: const RouteSettings(name: KijiRoutes.player),
        fullscreenDialog: true,
        // La carátula del mini-reproductor se expande hasta la del reproductor (Tarea Z6).
        transitionDuration: KijiMotion.emphasized,
        reverseTransitionDuration: KijiMotion.normal,
        pageBuilder: (context, animation, secondaryAnimation) => const PlayerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (MediaQuery.disableAnimationsOf(context)) return child;
          final curve = CurvedAnimation(parent: animation, curve: KijiMotion.emphasizedCurve);
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(curve),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final track = playback.track;
    if (track == null) {
      return const Scaffold(body: Center(child: Text('Elige una canción')));
    }
    final downloaded =
        track.youtubeVideoId != null && ref.watch(downloadsProvider).completed.containsKey(track.youtubeVideoId);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          PlayerHalo(track: track, playing: playback.isPlaying),
          // Deslizar hacia arriba en cualquier parte del reproductor abre la letra.
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) < -350) LyricsScreen.open(context);
            },
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final coverSize = min(
                    KijiSizes.playerCover,
                    min(constraints.maxWidth - 48, constraints.maxHeight * 0.38),
                  );
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _TopBar(track: track, downloaded: downloaded),
                          const SizedBox(height: 16),
                          _Cover(track: track, size: coverSize),
                          const SizedBox(height: 24),
                          _TitleRow(track: track, downloaded: downloaded),
                          const SizedBox(height: 20),
                          _Progress(playback: playback, seed: track.id),
                          const SizedBox(height: 12),
                          const PlaybackControlsRow(),
                          const SizedBox(height: 20),
                          const _BottomActions(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.track, required this.downloaded});

  final Track track;
  final bool downloaded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          GlassIconButton(
            icon: Icons.keyboard_arrow_down_rounded,
            tooltip: 'Minimizar',
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Column(
              children: [
                Text('REPRODUCIENDO DESDE', style: KijiText.mono(size: 10)),
                const SizedBox(height: 2),
                Text(
                  playingFromLabel(track, downloaded: downloaded),
                  style: KijiText.title(size: 13, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
          GlassIconButton(
            icon: Icons.more_horiz_rounded,
            tooltip: 'Más opciones',
            onPressed: () => _showMenu(context, track),
          ),
        ],
      ),
    );
  }

  void _showMenu(BuildContext context, Track track) {
    final navigator = Navigator.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (track.youtubeVideoId != null)
              ListTile(
                leading: const Icon(Icons.download_for_offline_outlined),
                title: const Text('Escuchar sin conexión'),
                subtitle: const Text('Descargar dentro de Kiji'),
                trailing: DownloadButton(track: track),
              )
            else
              const ListTile(
                leading: Icon(Icons.phone_android_rounded),
                title: Text('Canción guardada en el dispositivo'),
                subtitle: Text('Ya suena sin conexión'),
              ),
            if (track.youtubeVideoId != null)
              ListTile(
                leading: const Icon(Icons.health_and_safety_outlined),
                title: const Text('Salud del Extractor'),
                subtitle: const Text('Cómo está funcionando YouTube hoy'),
                onTap: () {
                  Navigator.pop(context);
                  navigator.push(MaterialPageRoute<void>(builder: (_) => const ExtractorHealthScreen()));
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Carátula de 320 px, radio 28, borde degradado de 1 px y halo de su color.
class _Cover extends StatelessWidget {
  const _Cover({required this.track, required this.size});

  final Track track;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CoverMotion(
      trackId: track.id,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KijiRadii.cover),
          boxShadow: [BoxShadow(color: track.coverColor.withValues(alpha: 0.45), blurRadius: 60, spreadRadius: 4)],
        ),
        child: GradientBorder(
          radius: KijiRadii.cover,
          child: Hero(
            tag: coverHeroTag(track),
            child: TrackArtwork(track: track, size: size - 2, radius: KijiRadii.cover - 1),
          ),
        ),
      ),
    );
  }
}

class _TitleRow extends ConsumerWidget {
  const _TitleRow({required this.track, required this.downloaded});

  final Track track;
  final bool downloaded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = ref.watch(favoritesProvider).containsKey(track.id);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TrackTitleText(track, maxLines: 2, overflow: TextOverflow.ellipsis, style: KijiText.title(size: 26)),
              const SizedBox(height: 4),
              TrackArtistText(
                track,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: KijiColors.muted, fontSize: 16),
              ),
            ],
          ),
        ),
        if (track.youtubeVideoId != null)
          downloaded
              ? const Tooltip(
                  message: 'Descargada: suena sin conexión',
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.download_done_rounded, color: KijiColors.cyan),
                  ),
                )
              : DownloadButton(track: track),
        // "Agregar a playlist" a un toque (Tarea Z3).
        IconButton(
          tooltip: 'Agregar a playlist',
          onPressed: () => showAddToPlaylistSheet(context, ref, [track]),
          icon: const Icon(Icons.playlist_add_rounded, color: Colors.white),
        ),
        IconButton(
          tooltip: liked ? 'Quitar de me gusta' : 'Me gusta',
          onPressed: () => ref.read(favoritesProvider.notifier).toggle(track),
          icon: Icon(
            liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: liked ? KijiColors.violet : Colors.white,
          ),
        ),
      ],
    );
  }
}

class _Progress extends ConsumerWidget {
  const _Progress({required this.playback, required this.seed});

  final PlaybackState playback;
  final String seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Con la luna del temporizador y "Marcar en la onda" (Tarea Z2).
        const TimerWaveform(),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatDuration(playback.position), style: KijiText.mono(size: 12)),
            Text(formatDuration(playback.duration), style: KijiText.mono(size: 12)),
          ],
        ),
      ],
    );
  }
}

/// Aleatorio / anterior / PLAY / siguiente / repetir. Los activos, en cian.
/// [compact] para la barra del reproductor de la PC.
class PlaybackControlsRow extends ConsumerWidget {
  const PlaybackControlsRow({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final notifier = ref.read(playbackProvider.notifier);
    final iconSize = compact ? 24.0 : 30.0;

    final repeatIcon = switch (playback.repeatMode) {
      PlaybackRepeatMode.one => Icons.repeat_one_rounded,
      _ => Icons.repeat_rounded,
    };
    final repeatTooltip = switch (playback.repeatMode) {
      PlaybackRepeatMode.off => 'Repetir: apagado',
      PlaybackRepeatMode.all => 'Repetir: toda la cola',
      PlaybackRepeatMode.one => 'Repetir: esta canción',
    };

    return Row(
      mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        IconButton(
          tooltip: playback.shuffleEnabled ? 'Aleatorio: activado' : 'Aleatorio: apagado',
          onPressed: notifier.toggleShuffle,
          icon: const Icon(Icons.shuffle_rounded),
          iconSize: iconSize * 0.85,
          color: playback.shuffleEnabled ? KijiColors.cyan : KijiColors.muted,
        ),
        IconButton(
          tooltip: 'Anterior',
          onPressed: notifier.previousTrack,
          icon: const Icon(Icons.skip_previous_rounded),
          iconSize: iconSize * 1.2,
          color: Colors.white,
        ),
        BreathingPlayButton(
          isPlaying: playback.isPlaying,
          onPressed: notifier.togglePlayPause,
          reduceMotion: reduceMotion(context, ref),
          size: compact ? 52 : KijiSizes.playButton,
        ),
        IconButton(
          tooltip: 'Siguiente',
          onPressed: notifier.nextTrack,
          icon: const Icon(Icons.skip_next_rounded),
          iconSize: iconSize * 1.2,
          color: Colors.white,
        ),
        IconButton(
          tooltip: repeatTooltip,
          onPressed: notifier.toggleRepeatMode,
          icon: Icon(repeatIcon),
          iconSize: iconSize * 0.85,
          color: playback.repeatMode == PlaybackRepeatMode.off ? KijiColors.muted : KijiColors.cyan,
        ),
      ],
    );
  }
}

/// Botones de vidrio de abajo: Letra, Cola y Temporizador.
class _BottomActions extends ConsumerWidget {
  const _BottomActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(sleepTimerProvider);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        GlassIconButton(
          icon: Icons.lyrics_outlined,
          label: 'Letra',
          tooltip: 'Letra',
          onPressed: () => LyricsScreen.open(context),
        ),
        GlassIconButton(
          icon: Icons.queue_music_rounded,
          label: 'Cola',
          tooltip: 'Cola',
          onPressed: () => QueueScreen.open(context),
        ),
        GlassIconButton(
          icon: timer == null ? Icons.bedtime_outlined : Icons.bedtime_rounded,
          // Activo: muestra cuánto falta, en cian.
          label: sleepTimerButtonLabel(timer),
          tooltip: timer == null ? 'Temporizador' : 'Temporizador activo: ${timer.mode.label}',
          active: timer != null,
          onPressed: () => showSleepTimerSheet(context),
        ),
        // Momentos (Tarea Z6): guardar este segundo. La lista se abre desde el
        // aviso ("Ver") o desde Biblioteca → Playlists → Momentos.
        GlassIconButton(
          icon: Icons.bookmark_add_outlined,
          label: 'Momento',
          tooltip: 'Guardar este momento',
          onPressed: () => saveCurrentMoment(context, ref),
        ),
      ],
    );
  }
}
