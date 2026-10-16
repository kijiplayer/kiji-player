import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/history/listening_history.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../models/track.dart';
import '../../providers/playback_provider.dart';
import '../../providers/shell_provider.dart';
import '../../theme/kiji_tokens.dart';
import '../../widgets/album_cover.dart';
import '../../widgets/nocturne/glass.dart';

/// Saludo según la hora (5–12 mañana, 12–20 tarde, resto noche).
String greetingFor(DateTime now) {
  if (now.hour >= 5 && now.hour < 12) return 'Buenos días';
  if (now.hour >= 12 && now.hour < 20) return 'Buenas tardes';
  return 'Buenas noches';
}

/// Pestaña Inicio (§7): saludo, "Seguí donde quedaste", escuchado
/// recientemente y "Para vos", todo calculado en el teléfono.
class InicioTab extends ConsumerWidget {
  const InicioTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final history = ref.watch(listeningHistoryProvider);
    final recent = HistoryLogic.recent(history);
    final forYou = HistoryLogic.forYou(history, excludeId: playback.track?.id);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 160),
      children: [
        const _Greeting(),
        const SizedBox(height: 20),
        if (playback.track != null) ...[
          _ContinueCard(track: playback.track!, isPlaying: playback.isPlaying),
          const SizedBox(height: 28),
        ],
        if (recent.isEmpty && playback.track == null)
          _EmptyHome(onSearch: () => ref.read(shellTabProvider.notifier).state = ShellTab.search),
        if (recent.isNotEmpty) ...[
          Text('Escuchado recientemente', style: KijiText.title(size: 18)),
          const SizedBox(height: 12),
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recent.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) => _RecentCard(
                track: recent[index],
                onTap: () => ref.read(playbackProvider.notifier).playQueue(recent, startIndex: index),
              ),
            ),
          ),
          const SizedBox(height: 28),
        ],
        if (forYou.isNotEmpty) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('Para vos', style: KijiText.title(size: 18)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '· calculado en tu teléfono',
                  style: KijiText.mono(size: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.6,
            children: [
              for (final (index, track) in forYou.indexed)
                _ForYouTile(
                  track: track,
                  onTap: () => ref.read(playbackProvider.notifier).playQueue(forYou, startIndex: index),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Greeting extends StatefulWidget {
  const _Greeting();

  @override
  State<_Greeting> createState() => _GreetingState();
}

class _GreetingState extends State<_Greeting> {
  late DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // La hora se actualiza sola (una vez por minuto alcanza).
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final time = '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(time, style: KijiText.mono(size: 13, color: KijiColors.cyan)),
              const SizedBox(height: 4),
              Text(greetingFor(_now), style: KijiText.title(size: 30)),
            ],
          ),
        ),
        GlassIconButton(
          icon: Icons.settings_outlined,
          tooltip: 'Configuración',
          onPressed: () => SettingsScreen.open(context),
        ),
      ],
    );
  }
}

class _ContinueCard extends ConsumerWidget {
  const _ContinueCard({required this.track, required this.isPlaying});

  final Track track;
  final bool isPlaying;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GradientBorder(
      radius: KijiRadii.card,
      fill: KijiColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            TrackArtwork(track: track, size: 64, radius: 14),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SEGUÍ DONDE QUEDASTE', style: KijiText.mono(size: 10)),
                  const SizedBox(height: 6),
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KijiText.title(size: 17),
                  ),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: KijiColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Material(
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              color: Colors.transparent,
              child: Ink(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: KijiColors.accentGradientDiagonal,
                ),
                child: InkWell(
                  onTap: () => ref.read(playbackProvider.notifier).togglePlayPause(),
                  child: Tooltip(
                    message: isPlaying ? 'Pausar' : 'Reproducir',
                    child: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: KijiColors.onAccent,
                    ),
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

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.track, required this.onTap});

  final Track track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: InkWell(
        borderRadius: BorderRadius.circular(KijiRadii.tile),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrackArtwork(track: track, size: 140, radius: 16),
            const SizedBox(height: 8),
            Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: KijiColors.muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ForYouTile extends StatelessWidget {
  const _ForYouTile({required this.track, required this.onTap});

  final Track track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: KijiRadii.tile,
      blur: false,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Row(
            children: [
              TrackArtwork(track: track, size: 56, radius: KijiRadii.tile),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  track.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Glass(
      blur: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Elige una canción', style: KijiText.title(size: 20)),
          const SizedBox(height: 6),
          const Text(
            'Lo que escuches aparece acá. Todo se calcula en tu teléfono; nada sale de él.',
            style: TextStyle(color: KijiColors.muted),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onSearch,
            icon: const Icon(Icons.search_rounded),
            label: const Text('Buscar música'),
          ),
        ],
      ),
    );
  }
}
