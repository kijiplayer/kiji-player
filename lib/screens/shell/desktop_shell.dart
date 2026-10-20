import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/sleep_timer/presentation/timer_waveform.dart';
import '../../features/lyrics/presentation/lyrics_screen.dart';
import '../../features/playlists/playlists_provider.dart';
import '../../features/playlists/presentation/playlist_screens.dart';
import '../../features/queue/presentation/queue_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/sleep_timer/presentation/sleep_timer_sheet.dart';
import '../../features/sleep_timer/sleep_timer_provider.dart';
import '../../features/extractor/data/path_health.dart';
import '../../features/yt_music/presentation/extractor_health_screen.dart';
import '../../providers/playback_provider.dart';
import '../../providers/shell_provider.dart';
import '../../theme/kiji_tokens.dart';
import '../../utils/duration_formatter.dart';
import '../../widgets/album_cover.dart';
import '../../widgets/nocturne/glass.dart';
import '../home/home_screen.dart';
import '../player/player_screen.dart';
import 'pill_nav_bar.dart';
import '../../features/customize/presentation/track_text.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// "A continuación" visible en la PC (el botón Cola de la barra lo oculta).
final queuePanelVisibleProvider = StateProvider<bool>((ref) => true);

/// Diseño de PC, desde 1000 px de ancho: barra lateral, contenido al
/// centro con buscador (Ctrl K), panel "A continuación" y barra del
/// reproductor abajo.
class DesktopShell extends ConsumerWidget {
  const DesktopShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showQueue = ref.watch(queuePanelVisibleProvider);
    final hasTrack = ref.watch(playbackProvider.select((p) => p.track != null));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(width: 240, child: _Sidebar()),
                  const VerticalDivider(width: 1, color: KijiColors.glassBorder),
                  const Expanded(
                    child: Column(
                      children: [
                        _SearchBarHint(),
                        Expanded(child: ShellTabContent()),
                      ],
                    ),
                  ),
                  if (showQueue) ...[
                    const VerticalDivider(width: 1, color: KijiColors.glassBorder),
                    const SizedBox(width: 320, child: _QueuePanel()),
                  ],
                ],
              ),
            ),
            if (hasTrack) const _PlayerBar(),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(shellTabProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 24),
            child: GradientText('Kiji', style: KijiText.title(size: 32)), // l10n-ignore
          ),
          for (final destination in ShellDestination.all)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _SidebarItem(
                destination: destination,
                selected: destination.tab == current,
                onTap: () => ref.read(shellTabProvider.notifier).state = destination.tab,
              ),
            ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(tx.tusListas, style: KijiText.mono(size: 11)),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                final playlists = ref.watch(playlistsProvider);
                if (playlists.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      tx.tusPlaylistsVanAAparecerAqui,
                      style: const TextStyle(color: KijiColors.muted, fontSize: 13),
                    ),
                  );
                }
                return ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final playlist in playlists)
                      ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KijiRadii.tile)),
                        leading: const Icon(Icons.queue_music_rounded, size: 20, color: KijiColors.violet),
                        title: Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => PlaylistScreen.open(context, playlist.id),
                      ),
                  ],
                );
              },
            ),
          ),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KijiRadii.tile)),
            leading: const Icon(Icons.settings_outlined, color: KijiColors.muted),
            title: Text(tx.settingsTitle),
            onTap: () => SettingsScreen.open(context),
          ),
          const SizedBox(height: 8),
          const _HealthBox(),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.destination, required this.selected, required this.onTap});

  final ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(KijiRadii.tile),
      child: Ink(
        decoration: BoxDecoration(
          gradient: selected ? KijiColors.accentGradient : null,
          borderRadius: BorderRadius.circular(KijiRadii.tile),
        ),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KijiRadii.tile)),
          selected: selected,
          leading: Icon(destination.icon, color: selected ? KijiColors.onAccent : KijiColors.muted),
          title: Text(
            destination.labelOf(context),
            style: TextStyle(
              color: selected ? KijiColors.onAccent : Colors.white,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

/// Cajita "Salud del Extractor" al pie de la barra lateral.
class _HealthBox extends StatelessWidget {
  const _HealthBox();

  @override
  Widget build(BuildContext context) {
    final health = PathHealth.instance;
    return ListenableBuilder(
      listenable: health,
      builder: (context, _) {
        final working = health.all.entries.where((e) => e.value.working).map((e) => e.key);
        final anyUsed = health.all.isNotEmpty;
        final summary = working.isNotEmpty
            ? tx.youtubeFuncionaNFormas(working.length)
            : anyUsed
            ? tx.youtubeConProblemas
            : tx.sinUsarTodavia;
        return Glass(
          blur: false,
          radius: KijiRadii.tile,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => ExtractorHealthScreen.open(context),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 10,
                      color: working.isNotEmpty
                          ? Colors.greenAccent
                          : (anyUsed ? Colors.orangeAccent : KijiColors.muted),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tx.saludDelExtractor2, style: KijiText.mono(size: 9)),
                          const SizedBox(height: 2),
                          Text(summary, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Buscador de arriba: un toque (o Ctrl K) lleva a la pestaña Buscar.
class _SearchBarHint extends ConsumerWidget {
  const _SearchBarHint();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(shellTabProvider) == ShellTab.search) return const SizedBox(height: 12);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: GradientBorder(
        radius: KijiRadii.pill,
        fill: KijiColors.surface,
        child: InkWell(
          onTap: () {
            ref.read(shellTabProvider.notifier).state = ShellTab.search;
            WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(searchFocusProvider).requestFocus());
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: KijiColors.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(tx.buscarCancionesArtistas2, style: const TextStyle(color: KijiColors.muted)),
                ),
                Text('Ctrl K', style: KijiText.mono(size: 11)), // l10n-ignore
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QueuePanel extends StatelessWidget {
  const _QueuePanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(tx.aContinuacion, style: KijiText.title(size: 18)),
        ),
        const Expanded(child: QueueList(padding: EdgeInsets.only(bottom: 16))),
      ],
    );
  }
}

/// Barra del reproductor de la PC: carátula y título, controles con la onda,
/// volumen, Letra y Cola.
class _PlayerBar extends ConsumerWidget {
  const _PlayerBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final track = playback.track!;
    final notifier = ref.read(playbackProvider.notifier);
    final showQueue = ref.watch(queuePanelVisibleProvider);

    return Container(
      decoration: const BoxDecoration(
        color: KijiColors.surface,
        border: Border(top: BorderSide(color: KijiColors.glassBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 280,
            child: InkWell(
              borderRadius: BorderRadius.circular(KijiRadii.tile),
              onTap: () => PlayerScreen.open(context),
              child: Row(
                children: [
                  TrackArtwork(track: track, size: 52, radius: KijiRadii.tile),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TrackTitleText(
                          track,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TrackArtistText(
                          track,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: KijiColors.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PlaybackControlsRow(compact: true),
                Row(
                  children: [
                    Text(formatDuration(playback.position), style: KijiText.mono(size: 11)),
                    const SizedBox(width: 10),
                    const Expanded(child: TimerWaveform(height: 28, barWidth: 2)),
                    const SizedBox(width: 10),
                    Text(formatDuration(playback.duration), style: KijiText.mono(size: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const Icon(Icons.volume_up_rounded, color: KijiColors.muted, size: 20),
          SizedBox(
            width: 120,
            child: Slider(
              value: playback.volume,
              onChanged: (value) => notifier.changeVolume(value - playback.volume),
              semanticFormatterCallback: (value) => tx.volumen((value * 100).round()),
            ),
          ),
          IconButton(
            tooltip: tx.letra,
            onPressed: () => LyricsScreen.open(context),
            icon: const Icon(Icons.lyrics_outlined),
            color: KijiColors.muted,
          ),
          IconButton(
            tooltip: ref.watch(sleepTimerProvider) == null ? tx.temporizador : tx.temporizadorActivo2,
            onPressed: () => showSleepTimerSheet(context),
            icon: const Icon(Icons.bedtime_outlined),
            color: ref.watch(sleepTimerProvider) == null ? KijiColors.muted : KijiColors.cyan,
          ),
          IconButton(
            tooltip: showQueue ? tx.ocultarLaCola : tx.mostrarLaCola,
            onPressed: () => ref.read(queuePanelVisibleProvider.notifier).state = !showQueue,
            icon: const Icon(Icons.queue_music_rounded),
            color: showQueue ? KijiColors.cyan : KijiColors.muted,
          ),
        ],
      ),
    );
  }
}
