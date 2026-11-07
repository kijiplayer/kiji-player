import 'dart:math';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/equalizer/presentation/sound_screen.dart';
import '../../features/equalizer/data/equalizer_notifier.dart';
import '../../features/sleep_timer/presentation/timer_waveform.dart';
import '../../features/downloads/presentation/download_button.dart';
import '../../features/favorites/favorites.dart';
import '../../features/customize/presentation/track_style_sheet.dart';
import '../../features/lyrics/presentation/lyrics_fullscreen.dart';
import '../../features/style/presentation/custom_background.dart';
import '../../features/lyrics/presentation/lyrics_screen.dart';
import '../../features/lyrics/presentation/lyrics_views.dart' show ChromeAutoHide, HideWhenIdle;
import '../../features/settings/data/settings_store.dart';
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
import 'lyrics_swipe.dart';
import 'player_motion.dart';
import 'museum.dart';
import '../../widgets/nocturne/breathing_play_button.dart';
import '../../widgets/nocturne/micro_motion.dart';
import '../../widgets/nocturne/glass.dart';
import '../../widgets/nocturne/waveform_progress.dart' show waveformBars;
import '../../features/customize/presentation/track_text.dart';
import '../../features/playlists/presentation/playlist_screens.dart';
import '../../features/moments/presentation/moment_marks.dart';

import 'package:kiji_player/l10n/l10n.dart';
import 'package:kiji_player/widgets/nocturne/kiji_sheet.dart';

/// De dónde sale la canción, para "REPRODUCIENDO DESDE".
String playingFromLabel(Track track, {required bool downloaded}) {
  if (track.source == TrackSource.local) return tx.tuBiblioteca;
  if (downloaded) return tx.descargadas2;
  return 'YOUTUBE MUSIC'; // l10n-ignore
}

/// Reproductor a pantalla completa (Kiji Nocturne).
class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        settings: const RouteSettings(name: KijiRoutes.player),
        fullscreenDialog: true,
        // La carátula del mini-reproductor se expande hasta la del reproductor.
        transitionDuration: KijiMotion.emphasized,
        reverseTransitionDuration: KijiMotion.normal,
        pageBuilder: (context, animation, secondaryAnimation) => const PlayerScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (MediaQuery.disableAnimationsOf(context)) return child;
          // Grafito: sube con un resorte casi sin rebote (si rebotara, se vería el borde de abajo).
          final curve = CurvedAnimation(
            parent: animation,
            curve: KijiLook.museum ? KijiMotion.softSpring : KijiMotion.emphasizedCurve,
          );
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
    // Solo canción y play/pausa: la posición la dibuja _Progress por su cuenta.
    final playback = ref.watch(playbackProvider.select((s) => (track: s.track, isPlaying: s.isPlaying)));
    final track = playback.track;
    // Modos: pantalla completa (mientras está abierto) o compacto (se recuerda).
    final full = ref.watch(playerFullscreenProvider);
    final compact = !full && ref.watch(settingsProvider.select((s) => s.playerMode)) == 'compact';
    if (track == null) {
      return Scaffold(body: Center(child: Text(tx.eligeUnaCancion)));
    }
    final downloaded =
        track.youtubeVideoId != null &&
        ref.watch(downloadsProvider.select((d) => d.completed.containsKey(track.youtubeVideoId)));

    final screen = FullscreenGuard(
      provider: playerFullscreenProvider,
      child: ChromeAutoHide(
        enabled: full,
        child: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Un fondo propio (el de esta canción o el general) reemplaza al del estilo.
              if (ref.watch(hasCustomBackgroundProvider))
                const CustomBackground()
              else
                PlayerHalo(track: track, playing: playback.isPlaying),
              // Deslizar hacia arriba abre la letra, salvo que el gesto empiece en la zona de gestos
              // del sistema (salir de Kiji desde abajo no debe abrir la letra).
              LyricsSwipeDetector(
                onSwipeUp: () => LyricsScreen.open(context),
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Pantalla completa: la portada grande. Compacto: chica, al lado del título.
                      // Ventana ancha: todo en una columna centrada (la onda, el título y los controles no
                      // quedan de punta a punta).
                      final width = min(
                        constraints.maxWidth,
                        full ? KijiSizes.playerFullWidth : KijiSizes.playerMaxWidth,
                      );
                      final coverSize = full
                          ? min(640.0, min(width - 48, constraints.maxHeight * 0.58))
                          : compact
                          ? min(132.0, constraints.maxHeight * 0.24)
                          : min(KijiSizes.playerCover, min(width - 48, constraints.maxHeight * 0.38));
                      final cover = RepaintBoundary(
                        child: _Cover(track: track, size: coverSize, playing: playback.isPlaying),
                      );
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Center(
                          child: ConstrainedBox(
                            key: const Key('player-column'),
                            constraints: BoxConstraints(minHeight: constraints.maxHeight, maxWidth: width),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                HideWhenIdle(
                                  child: _TopBar(track: track, downloaded: downloaded),
                                ),
                                SizedBox(height: compact ? 8 : 16),
                                // Capas propias: la sombra grande de la carátula no se vuelve a
                                // rasterizar con cada avance de la posición.
                                if (compact)
                                  Row(
                                    children: [
                                      cover,
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _TitleRow(track: track, downloaded: downloaded, compact: true),
                                      ),
                                    ],
                                  )
                                else ...[
                                  cover,
                                  SizedBox(height: KijiLook.museum ? 36 : 24),
                                  _TitleRow(track: track, downloaded: downloaded),
                                ],
                                SizedBox(height: compact ? 12 : (KijiLook.museum ? 28 : 20)),
                                const RepaintBoundary(child: _Progress()),
                                SizedBox(height: compact ? 4 : (KijiLook.museum ? 20 : 12)),
                                PlaybackControlsRow(playSize: compact ? 60 : KijiSizes.playButton),
                                SizedBox(height: compact ? 8 : 20),
                                const HideWhenIdle(child: _BottomActions()),
                                SizedBox(height: compact ? 8 : 16),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return screen;
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
            tooltip: tx.minimizar,
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Column(
              children: [
                Text(tx.reproduciendoDesde, style: KijiText.mono(size: 10)),
                const SizedBox(height: 2),
                Text(
                  playingFromLabel(track, downloaded: downloaded),
                  style: KijiText.title(size: 13, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
          // Pantalla completa: salir (en la PC también con Esc).
          Consumer(
            builder: (context, ref, _) => ref.watch(playerFullscreenProvider)
                ? GlassIconButton(
                    key: const Key('player-fullscreen-exit'),
                    icon: Icons.fullscreen_exit_rounded,
                    tooltip: tx.salirDePantallaCompleta,
                    onPressed: () => ref.read(playerFullscreenProvider.notifier).state = false,
                  )
                : const SizedBox.shrink(),
          ),
          GlassIconButton(
            icon: Icons.more_horiz_rounded,
            tooltip: tx.masOpciones,
            onPressed: () => _showMenu(context, track),
          ),
        ],
      ),
    );
  }

  void _showMenu(BuildContext context, Track track) {
    final navigator = Navigator.of(context);
    showKijiSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (track.youtubeVideoId != null)
              ListTile(
                leading: const Icon(Icons.download_for_offline_outlined),
                title: Text(tx.escucharSinConexion),
                subtitle: Text(tx.descargarDentroDeKiji),
                trailing: DownloadButton(track: track),
              )
            else
              ListTile(
                leading: const Icon(Icons.phone_android_rounded),
                title: Text(tx.cancionGuardadaEnElDispositivo),
                subtitle: Text(tx.yaSuenaSinConexion),
              ),
            Consumer(
              builder: (context, ref, _) => ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: Text(tx.estiloDeEstaCancion),
                subtitle: Text(tx.estiloDeEstaCancionNota),
                onTap: () {
                  Navigator.pop(context);
                  showTrackStyleSheet(navigator.context, ref, track);
                },
              ),
            ),
            Consumer(
              builder: (context, ref, _) => SwitchListTile(
                secondary: const Icon(Icons.view_compact_alt_outlined),
                title: Text(tx.modoCompacto),
                subtitle: Text(tx.modoCompactoNota),
                value: ref.watch(settingsProvider.select((s) => s.playerMode)) == 'compact',
                onChanged: (on) => ref
                    .read(settingsProvider.notifier)
                    .update((s) => s.copyWith(playerMode: on ? 'compact' : 'normal')),
              ),
            ),
            Consumer(
              builder: (context, ref, _) => ListTile(
                key: const Key('player-fullscreen'),
                leading: const Icon(Icons.fullscreen_rounded),
                title: Text(tx.pantallaCompleta),
                subtitle: Text(tx.pantallaCompletaNota),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(playerFullscreenProvider.notifier).state = true;
                },
              ),
            ),
            if (track.youtubeVideoId != null)
              ListTile(
                leading: const Icon(Icons.health_and_safety_outlined),
                title: Text(tx.saludDelExtractor),
                subtitle: Text(tx.comoEstaFuncionandoYoutubeHoy2),
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
class _Cover extends ConsumerWidget {
  const _Cover({required this.track, required this.size, required this.playing});

  final Track track;
  final double size;
  final bool playing;

  /// En pausa la portada se aleja apenas (y vuelve al sonar): responde a la música sin moverse sola.
  static const pausedScale = 0.95;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radius = KijiLook.cover(KijiRadii.cover);
    final cover = CoverMotion(
      trackId: track.id,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          // El halo del color de la carátula es de Nocturne (Grafito y Papel no tienen brillos).
          boxShadow: KijiLook.nocturne
              ? [BoxShadow(color: track.coverColor.withValues(alpha: 0.45), blurRadius: 60, spreadRadius: 4)]
              : null,
        ),
        child: GradientBorder(
          radius: radius,
          child: Hero(
            tag: coverHeroTag(track),
            // Grafito: la portada vuela del mini-reproductor al reproductor (y vuelve) con un resorte.
            curve: KijiLook.museum ? KijiMotion.spring : Curves.fastOutSlowIn,
            child: TrackArtwork(track: track, size: size - 2, radius: radius - 1),
          ),
        ),
      ),
    );
    // Grafito 0.8: la portada sola, con su borde de vidrio. Sin la luz que respira, el brillo, el
    // reflejo ni la inclinación de la 0.7: menos efectos a la vez.
    // Con "reducir animaciones", la portada queda quieta del tamaño de siempre.
    if (reduceMotion(context, ref)) return cover;
    return AnimatedScale(
      key: const Key('player-cover-scale'),
      scale: playing ? 1 : pausedScale,
      duration: KijiMotion.normal,
      curve: KijiLook.museum ? KijiMotion.softSpring : Curves.easeOutCubic,
      child: cover,
    );
  }
}

class _TitleRow extends ConsumerWidget {
  const _TitleRow({required this.track, required this.downloaded, this.compact = false});

  final Track track;
  final bool downloaded;

  /// Al lado de la portada chica (modo compacto): el título más chico, para que entre.
  final bool compact;

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
              // Grafito: entran deslizándose, una línea después de la otra.
              MuseumLineIn(
                trackId: track.id,
                line: 0,
                child: TrackTitleText(
                  track,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  // Grafito: grande y fino.
                  style: KijiLook.museum
                      ? KijiText.title(size: compact ? 24 : 38, weight: FontWeight.w300)
                            .copyWith(letterSpacing: compact ? -0.5 : -1, height: 1.05)
                      : KijiText.title(size: compact ? 20 : 26),
                ),
              ),
              const SizedBox(height: 4),
              MuseumLineIn(
                trackId: track.id,
                line: 1,
                child: TrackArtistText(
                  track,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // Grafito: el artista como una etiqueta (versalitas espaciadas).
                  style: KijiLook.museum
                      ? TextStyle(
                          color: KijiColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.2,
                        )
                      : TextStyle(color: KijiColors.muted, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
        if (track.youtubeVideoId != null)
          downloaded
              ? Tooltip(
                  message: tx.descargadaSuenaSinConexion,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(Icons.download_done_rounded, color: KijiColors.cyan),
                  ),
                )
              : DownloadButton(track: track),
        // "Agregar a playlist" a un toque.
        IconButton(
          tooltip: tx.agregarAPlaylist,
          onPressed: () => showAddToPlaylistSheet(context, ref, [track]),
          icon: Icon(Icons.playlist_add_rounded, color: KijiLook.museum ? KijiColors.muted : KijiColors.text),
        ),
        IconButton(
          tooltip: liked ? tx.quitarDeMeGusta : tx.meGusta2,
          onPressed: () => ref.read(favoritesProvider.notifier).toggle(track),
          icon: LikeHeart(liked: liked),
        ),
      ],
    );
  }
}

class _Progress extends ConsumerWidget {
  const _Progress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider.select((s) => (position: s.position, duration: s.duration)));
    return Column(
      children: [
        // Con la luna del temporizador y "Marcar en la onda". Grafito: más baja y fina.
        KijiLook.museum ? const TimerWaveform(height: 26, barWidth: 2) : const TimerWaveform(),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatDuration(playback.position), style: KijiText.mono(size: 12)),
            Text(formatDuration(playback.duration), style: KijiText.mono(size: 12)),
          ],
        ),
        const MomentLoopChip(),
      ],
    );
  }
}

/// Aleatorio / anterior / PLAY / siguiente / repetir. Los activos, en cian.
/// [compact] para la barra del reproductor de la PC.
class PlaybackControlsRow extends ConsumerWidget {
  const PlaybackControlsRow({super.key, this.compact = false, this.playSize = KijiSizes.playButton});

  final bool compact;

  /// Tamaño del play con su anillo (el reproductor compacto lo achica).
  final double playSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(
      playbackProvider.select(
        (s) => (repeatMode: s.repeatMode, shuffleEnabled: s.shuffleEnabled, isPlaying: s.isPlaying),
      ),
    );
    final notifier = ref.read(playbackProvider.notifier);
    final iconSize = compact ? 24.0 : 30.0;

    final repeatIcon = switch (playback.repeatMode) {
      PlaybackRepeatMode.one => Icons.repeat_one_rounded,
      _ => Icons.repeat_rounded,
    };
    final repeatTooltip = switch (playback.repeatMode) {
      PlaybackRepeatMode.off => tx.repetirApagado,
      PlaybackRepeatMode.all => tx.repetirTodaLaCola,
      PlaybackRepeatMode.one => tx.repetirEstaCancion,
    };

    return Row(
      mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        PressScale(
          child: IconButton(
            tooltip: playback.shuffleEnabled ? tx.aleatorioActivado : tx.aleatorioApagado,
            onPressed: notifier.toggleShuffle,
            icon: PopSwitcher(
              child: Icon(
                Icons.shuffle_rounded,
                key: ValueKey(playback.shuffleEnabled),
                color: playback.shuffleEnabled ? KijiColors.cyan : KijiColors.muted,
              ),
            ),
            iconSize: iconSize * 0.85,
            visualDensity: VisualDensity.compact,
          ),
        ),
        PressScale(
          child: IconButton(
            tooltip: tx.anterior,
            onPressed: notifier.previousTrack,
            icon: const Icon(Icons.skip_previous_rounded),
            iconSize: iconSize * 1.2,
            color: KijiColors.text,
          ),
        ),
        if (compact)
          BreathingPlayButton(
            isPlaying: playback.isPlaying,
            onPressed: notifier.togglePlayPause,
            reduceMotion: reduceMotion(context, ref),
            size: 52,
          )
        else
          ProgressPlayButton(isPlaying: playback.isPlaying, onPressed: notifier.togglePlayPause, size: playSize),
        PressScale(
          child: IconButton(
            tooltip: tx.siguiente,
            onPressed: notifier.nextTrack,
            icon: const Icon(Icons.skip_next_rounded),
            iconSize: iconSize * 1.2,
            color: KijiColors.text,
          ),
        ),
        PressScale(
          child: IconButton(
            tooltip: repeatTooltip,
            onPressed: notifier.toggleRepeatMode,
            icon: PopSwitcher(
              child: Icon(
                repeatIcon,
                key: ValueKey(playback.repeatMode),
                color: playback.repeatMode == PlaybackRepeatMode.off ? KijiColors.muted : KijiColors.cyan,
              ),
            ),
            iconSize: iconSize * 0.85,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }
}

/// Barra de herramientas de abajo: Letra, Cola, Sonido, Temporizador y Momento en una sola fila.
/// De fábrica cada botón lleva su nombre debajo; con "Mostrar nombres de los botones" apagado quedan
/// solo los íconos (el nombre, en el tooltip, al mantener presionado y para los lectores de pantalla).
/// El temporizador activo muestra cuánto falta. Nocturne: una cápsula de vidrio; Grafito: sin
/// cápsula; Papel: una línea fina.
class _BottomActions extends ConsumerWidget {
  const _BottomActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(sleepTimerProvider);
    final soundOn = ref.watch(equalizerProvider.select((e) => e.settings.enabled));
    final labels = ref.watch(settingsProvider.select((s) => s.playerButtonLabels));
    // [short] es el nombre que se ve debajo; [name], el completo (tooltip y lectores de pantalla).
    Widget tool(IconData icon, String name, VoidCallback onTap, {bool active = false, String? short, String? value}) {
      final color = active ? KijiColors.cyan : KijiColors.muted;
      final Widget content;
      if (labels) {
        // Cada botón, del ancho de su nombre (como mínimo 60 px); si la fila no entra, se achica
        // entera (FittedBox de abajo), nunca se corta un nombre.
        content = Container(
          constraints: const BoxConstraints(minWidth: 60),
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 4),
              Text(
                value ?? short ?? name,
                maxLines: 1,
                softWrap: false,
                style: value != null
                    ? KijiText.mono(size: 11, color: KijiColors.cyan)
                    : TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      } else {
        content = SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: color),
                if (value != null) ...[
                  const SizedBox(width: 6),
                  Text(value, style: KijiText.mono(size: 12, color: KijiColors.cyan)),
                ],
              ],
            ),
          ),
        );
      }
      final button = InkResponse(onTap: onTap, radius: labels ? 34 : 26, child: content);
      return Semantics(
        button: true,
        label: name,
        excludeSemantics: true,
        // Con los nombres a la vista el tooltip sobra; sin ellos, aparece al pasar el mouse o al
        // mantener presionado.
        child: labels ? button : Tooltip(message: name, child: button),
      );
    }

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        tool(Icons.lyrics_outlined, tx.letra, () => LyricsScreen.open(context)),
        tool(Icons.queue_music_rounded, tx.cola, () => QueueScreen.open(context)),
        tool(Icons.graphic_eq_rounded, tx.sonido, () => SoundScreen.open(context), active: soundOn),
        tool(
          timer == null ? Icons.bedtime_outlined : Icons.bedtime_rounded,
          timer == null ? tx.temporizador : tx.temporizadorActivo(timer.mode.label),
          () => showSleepTimerSheet(context),
          active: timer != null,
          short: tx.temporizador,
          value: timer == null ? null : sleepTimerButtonLabel(timer),
        ),
        // Momentos: guardar este segundo. La lista se abre desde el aviso ("Ver") o desde
        // Biblioteca → Playlists → Momentos.
        tool(
          Icons.bookmark_add_outlined,
          tx.guardarEsteMomento,
          () => showNewMomentSheet(context, ref),
          short: tx.momento,
        ),
      ],
    );
    final decoration = switch (KijiLook.style) {
      KijiStyle.nocturne => BoxDecoration(
        color: KijiColors.glassFill,
        borderRadius: BorderRadius.circular(KijiRadii.pill),
        border: Border.all(color: KijiColors.glassBorder),
      ),
      KijiStyle.graphite => null,
      KijiStyle.paper => BoxDecoration(
        borderRadius: BorderRadius.circular(KijiRadii.pill),
        border: Border.all(color: KijiColors.glassBorder),
      ),
    };
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: DecoratedBox(
        decoration: decoration ?? const BoxDecoration(),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: row),
      ),
    );
  }
}

/// El play del reproductor, dentro de un anillo que se llena con la canción: el sello de Kiji en los
/// tres estilos. El anillo es **la misma onda de la barra de progreso, en círculo** (las mismas
/// barras de la canción, como marcas radiales): lo que ya sonó se pinta con el acento (Nocturne: su
/// degradado; Grafito: blanco; Papel: su rojo) y lo que falta, apagado. Es la acción principal y, de
/// paso, dice cuánto falta.
class ProgressPlayButton extends ConsumerWidget {
  const ProgressPlayButton({
    super.key,
    required this.isPlaying,
    required this.onPressed,
    this.size = KijiSizes.playButton,
  });

  final bool isPlaying;
  final VoidCallback onPressed;
  final double size;

  /// Marcas del anillo.
  static const ticks = 60;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(
      playbackProvider.select((p) => p.duration.inMilliseconds <= 0
          ? 0.0
          : (p.position.inMilliseconds / p.duration.inMilliseconds).clamp(0.0, 1.0)),
    );
    final seed = ref.watch(playbackProvider.select((p) => p.track?.id ?? ''));
    return SizedBox.square(
      dimension: size * 1.35,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              key: const Key('player-wave-ring'),
              size: Size.square(size * 1.35),
              painter: WaveRingPainter(
                bars: waveformBars(seed, ticks),
                progress: progress,
                rest: KijiColors.waveRest,
                colors: switch (KijiLook.style) {
                  KijiStyle.nocturne => [KijiColors.violet, KijiColors.cyan, KijiColors.violet],
                  KijiStyle.graphite => [KijiColors.text, KijiColors.text],
                  KijiStyle.paper => [KijiColors.like, KijiColors.like],
                },
                // Grafito: marcas más finas y cortas (más serio); Nocturne: las más marcadas.
                width: switch (KijiLook.style) {
                  KijiStyle.nocturne => 2.6,
                  KijiStyle.graphite => 1.6,
                  KijiStyle.paper => 2.0,
                },
                depth: KijiLook.museum ? 0.7 : 1,
                playSize: size,
              ),
            ),
          ),
          BreathingPlayButton(
            isPlaying: isPlaying,
            onPressed: onPressed,
            reduceMotion: reduceMotion(context, ref),
            size: size,
            breathingRing: false,
          ),
        ],
      ),
    );
  }
}

/// El anillo de onda alrededor del play: [bars] (0..1, las de la onda de la canción) como marcas
/// radiales que empiezan arriba y van en el sentido del reloj.
class WaveRingPainter extends CustomPainter {
  WaveRingPainter({
    required this.bars,
    required this.progress,
    required this.rest,
    required this.colors,
    required this.width,
    required this.playSize,
    this.depth = 1,
  });

  final List<double> bars;
  final double progress;
  final Color rest;
  final List<Color> colors;
  final double width;

  /// Diámetro del play (las marcas empiezan un poco por fuera).
  final double playSize;

  /// Cuánto se alargan las marcas altas (1 = lo de siempre).
  final double depth;

  /// Marcas que ya sonaron (las de antes de [progress]).
  static int playedCount(int total, double progress) => (total * progress.clamp(0.0, 1.0)).floor();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final inner = playSize * 0.58;
    final room = size.width / 2 - inner - width / 2;
    final played = playedCount(bars.length, progress);
    final shader = SweepGradient(
      endAngle: 2 * pi,
      colors: colors,
      // Empieza arriba, como las marcas.
      transform: const GradientRotation(-pi / 2),
    ).createShader(Offset.zero & size);
    final on = Paint()
      ..shader = shader
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    final off = Paint()
      ..color = rest
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < bars.length; i++) {
      final angle = -pi / 2 + 2 * pi * i / bars.length;
      final length = room * (0.3 + 0.7 * bars[i] * depth).clamp(0.2, 1.0);
      final dir = Offset(cos(angle), sin(angle));
      canvas.drawLine(center + dir * inner, center + dir * (inner + length), i < played ? on : off);
    }
  }

  @override
  bool shouldRepaint(WaveRingPainter old) =>
      playedCount(old.bars.length, old.progress) != playedCount(bars.length, progress) ||
      old.bars != bars ||
      old.rest != rest ||
      old.width != width ||
      old.depth != depth ||
      old.playSize != playSize ||
      !listEquals(old.colors, colors);
}
