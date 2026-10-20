import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/customize/presentation/customize_sheets.dart';
import '../../features/recommendations/data/home_feed_provider.dart';
import '../../features/recommendations/domain/home_feed.dart';
import '../../features/recommendations/presentation/home_sections.dart';
import '../../features/history/listening_history.dart';
import '../../features/playlists/domain/playlist.dart';
import '../../features/playlists/playlists_provider.dart';
import '../../features/playlists/presentation/playlist_screens.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../models/track.dart';
import '../../providers/downloads_provider.dart';
import '../../providers/playback_provider.dart';
import '../../providers/shell_provider.dart';
import '../../theme/kiji_tokens.dart';
import '../../widgets/album_cover.dart';
import '../../widgets/kiji_logo.dart';
import '../../widgets/nocturne/staggered.dart';
import '../../widgets/nocturne/glass.dart';
import '../../features/customize/presentation/track_text.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Saludo según la hora (5–12 mañana, 12–20 tarde, resto noche).
String greetingFor(DateTime now) {
  if (now.hour >= 5 && now.hour < 12) return tx.buenosDias;
  if (now.hour >= 12 && now.hour < 20) return tx.buenasTardes;
  return tx.buenasNoches;
}

/// Pestaña Inicio (§7): saludo, "Sigue donde quedaste", tus playlists,
/// escuchado recientemente y "Para ti", todo calculado en el teléfono.
class InicioTab extends ConsumerWidget {
  const InicioTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final history = ref.watch(listeningHistoryProvider);
    final recent = HistoryLogic.recent(history);
    final top = HistoryLogic.forYou(history, excludeId: playback.track?.id, limit: 6);
    final downloaded = [
      for (final d in [
        ...ref.watch(downloadsProvider).completed.values,
      ]..sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt)))
        d.toTrack(),
    ].take(15).toList();
    final isNew = history.isEmpty;

    // Orden de Inicio (Tarea Z5): nunca se ve vacío.
    return RefreshIndicator(
      onRefresh: () async {
        refreshHomeFeed(ref);
        if (isNew) ref.invalidate(moodsProvider);
        await ref.read(homeFeedProvider.future).catchError((Object _) => const HomeFeed());
      },
      child: StaggerScope(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 160),
          // Las secciones entran escalonadas (Tarea Z6).
          children: staggered([
            const _Greeting(),
            const SizedBox(height: 20),
            if (playback.track != null) ...[
              _ContinueCard(track: playback.track!, isPlaying: playback.isPlaying),
              const SizedBox(height: 28),
            ],
            // Tarea Z3: las playlists a la vista, arriba.
            const _PlaylistsRow(),
            const SizedBox(height: 28),
            if (isNew) ...[
              if (playback.track == null) ...[
                _EmptyHome(onSearch: () => ref.read(shellTabProvider.notifier).state = ShellTab.search),
                const SizedBox(height: 28),
              ],
              const StartHereSection(),
            ] else
              const RecommendationSections(),
            TrackShelf(title: tx.escuchadoRecientemente, tracks: recent),
            if (top.isNotEmpty) ...[
              SectionTitle(tx.tusMasEscuchadas, note: tx.calculadoEnTuTelefono),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.6,
                children: [
                  for (final (index, track) in top.indexed)
                    _ForYouTile(
                      track: track,
                      onTap: () => ref.read(playbackProvider.notifier).playQueue(top, startIndex: index),
                    ),
                ],
              ),
              const SizedBox(height: 28),
            ],
            TrackShelf(title: tx.descargadas, note: tx.sinInternet, tracks: downloaded),
          ]),
        ),
      ),
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
              Row(
                children: [
                  const KijiLogo(size: 22),
                  const SizedBox(width: 8),
                  Text(time, style: KijiText.mono(size: 13, color: KijiColors.cyan)),
                ],
              ),
              const SizedBox(height: 4),
              Text(greetingFor(_now), style: KijiText.title(size: 30)),
            ],
          ),
        ),
        GlassIconButton(
          icon: Icons.settings_outlined,
          tooltip: tx.settingsTitle,
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
                  Text(tx.sigueDondeQuedaste, style: KijiText.mono(size: 10)),
                  const SizedBox(height: 6),
                  TrackTitleText(track, maxLines: 1, overflow: TextOverflow.ellipsis, style: KijiText.title(size: 17)),
                  TrackArtistText(
                    track,
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
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: KijiColors.accentGradientDiagonal),
                child: InkWell(
                  onTap: () => ref.read(playbackProvider.notifier).togglePlayPause(),
                  child: Tooltip(
                    message: isPlaying ? tx.pausar : tx.reproducir,
                    child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: KijiColors.onAccent),
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
                child: TrackTitleText(
                  track,
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
          Text(tx.eligeUnaCancion, style: KijiText.title(size: 20)),
          const SizedBox(height: 6),
          Text(tx.loQueEscuchesApareceAquiTodo, style: const TextStyle(color: KijiColors.muted)),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: onSearch, icon: const Icon(Icons.search_rounded), label: Text(tx.buscarMusica)),
        ],
      ),
    );
  }
}

/// "Tus playlists" (Tarea Z3): carátulas grandes, las fijadas primero y
/// después las tocadas hace menos; al final, "+ Nueva".
class _PlaylistsRow extends ConsumerWidget {
  const _PlaylistsRow();

  static const _cover = 132.0;

  /// Alto de una línea de texto con [style], tal como se va a dibujar aquí.
  static double _lineHeight(BuildContext context, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: 'Ag', style: DefaultTextStyle.of(context).style.merge(style)), // l10n-ignore
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return painter.height;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(playlistsProvider);
    final playlists = PlaylistOps.pinnedFirst([...all]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tx.tusPlaylists2, style: KijiText.title(size: 18)),
        const SizedBox(height: 12),
        SizedBox(
          // Debajo de la portada van dos líneas de texto: se miden con la letra del teléfono
          // (con letra grande no se cortan).
          height: _cover + 8 + _lineHeight(context, const TextStyle(fontWeight: FontWeight.w600)) +
              _lineHeight(context, KijiText.mono(size: 11)) + 4,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: playlists.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              if (index == playlists.length) {
                return const _NewPlaylistCard(size: _cover);
              }
              final playlist = playlists[index];
              return GestureDetector(
                onTap: () => PlaylistScreen.open(context, playlist.id),
                child: SizedBox(
                  width: _cover,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          PlaylistCover(playlist: playlist, size: _cover, radius: KijiRadii.card),
                          if (playlist.pinned)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Icon(
                                Icons.push_pin_rounded,
                                size: 18,
                                color: KijiColors.cyan,
                                semanticLabel: tx.fijada,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        playlist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        tx.nCanciones(playlist.tracks.length),
                        style: KijiText.mono(size: 11),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NewPlaylistCard extends ConsumerWidget {
  const _NewPlaylistCard({required this.size});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        final name = await promptPlaylistName(context);
        if (name == null) return;
        final playlist = ref.read(playlistsProvider.notifier).create(name);
        if (context.mounted) await PlaylistScreen.open(context, playlist.id);
      },
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(KijiRadii.card),
                border: Border.all(color: KijiColors.glassBorder),
                color: KijiColors.glassFill,
              ),
              child: const Icon(Icons.add_rounded, size: 44, color: KijiColors.cyan),
            ),
            const SizedBox(height: 8),
            Text(
              tx.nueva2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
