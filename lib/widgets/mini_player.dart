import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/track.dart';
import '../providers/playback_provider.dart';
import '../screens/player/player_screen.dart';
import '../theme/kiji_tokens.dart';
import 'album_cover.dart';
import 'global_mini_player.dart';
import 'nocturne/glass.dart';
import '../features/customize/presentation/track_text.dart';
import '../features/playlists/presentation/playlist_screens.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Mini-reproductor de vidrio (§7): radio 20, borde 1 px blanco 12 %, y una
/// línea de progreso degradada de 2 px abajo. Sin canción elegida, no ocupa
/// lugar.
/// Etiqueta de la carátula que se expande del mini-reproductor al reproductor.
String coverHeroTag(Track track) => 'kiji-cover-${track.id}';

/// Alto del mini-reproductor (botones de 48 + márgenes 18 + línea 2).
const miniPlayerHeight = 68.0;

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key, this.useAppNavigator = false});

  /// true en el mini-reproductor global, que vive afuera del Navigator.
  final bool useAppNavigator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final track = playback.track;
    if (track == null) return const SizedBox.shrink();
    BuildContext nav() => useAppNavigator ? (kijiNavigatorKey.currentContext ?? context) : context;

    return Glass(
      radius: KijiRadii.miniPlayer,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => PlayerScreen.open(nav()),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 6, 8),
                child: Row(
                  children: [
                    // Solo el de Inicio (adentro del Navigator) puede volar al reproductor.
                    if (useAppNavigator)
                      TrackArtwork(track: track, size: 44, radius: 12)
                    else
                      Hero(
                        tag: coverHeroTag(track),
                        child: TrackArtwork(track: track, size: 44, radius: 12),
                      ),
                    const SizedBox(width: 12),
                    // El mini-reproductor tiene alto fijo: con letra muy grande, el título y el artista
                    // crecen hasta un límite (en el reproductor completo se ven enteros).
                    Expanded(
                      child: MediaQuery.withClampedTextScaling(
                        maxScaleFactor: 1.1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TrackTitleText(
                              track,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            TrackArtistText(
                              track,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: KijiColors.muted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // "Agregar a playlist" a un toque (Tarea Z3).
                    IconButton(
                      onPressed: () => showAddToPlaylistSheet(nav(), ref, [track]),
                      icon: const Icon(Icons.playlist_add_rounded),
                      color: Colors.white,
                      tooltip: tx.agregarAPlaylist,
                    ),
                    IconButton(
                      onPressed: () => ref.read(playbackProvider.notifier).togglePlayPause(),
                      icon: Icon(playback.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                      iconSize: 32,
                      color: Colors.white,
                      tooltip: playback.isPlaying ? tx.pausar : tx.reproducir,
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
