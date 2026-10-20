import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/track.dart';
import '../../../providers/playback_provider.dart';
import '../../../theme/kiji_tokens.dart';
import '../../../widgets/album_cover.dart';
import '../../customize/presentation/track_text.dart';
import '../../playlists/playlists_provider.dart';
import '../../queue/presentation/track_actions.dart';
import '../../yt_music/data/ytm_browse_parser.dart';
import '../data/home_feed_provider.dart';

import 'package:kiji_player/l10n/l10n.dart';

void _playAll(WidgetRef ref, List<Track> tracks, {int index = 0, bool shuffle = false}) {
  if (tracks.isEmpty) return;
  final notifier = ref.read(playbackProvider.notifier);
  if (shuffle && !ref.read(playbackProvider).shuffleEnabled) notifier.toggleShuffle();
  notifier.playQueue(tracks, startIndex: shuffle ? Random().nextInt(tracks.length) : index);
}

/// Título de una sección de Inicio, con un "Reproducir todo" opcional.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.note, this.onPlayAll});

  final String title;

  /// Aclaración chica al lado ("· calculado en tu teléfono").
  final String? note;
  final VoidCallback? onPlayAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // La nota va debajo, para que el título no se parta en dos líneas.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: KijiText.title(size: 18), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (note != null) Text(note!, style: KijiText.mono(size: 11), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (onPlayAll != null) ...[
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: tx.reproducirTodo,
              onPressed: onPlayAll,
              icon: const Icon(Icons.play_arrow_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

/// Fila horizontal de canciones con carátula grande.
class TrackShelf extends ConsumerWidget {
  const TrackShelf({super.key, required this.title, required this.tracks, this.note, this.playAll = true});

  final String title;
  final String? note;
  final List<Track> tracks;
  final bool playAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tracks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(title, note: note, onPlayAll: playAll ? () => _playAll(ref, tracks) : null),
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tracks.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, i) => TrackCard(
                track: tracks[i],
                onTap: () => _playAll(ref, tracks, index: i),
                onLongPress: () => showTrackActions(context, ref, tracks[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TrackCard extends StatelessWidget {
  const TrackCard({super.key, required this.track, required this.onTap, this.onLongPress});

  final Track track;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: InkWell(
        borderRadius: BorderRadius.circular(KijiRadii.tile),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrackArtwork(track: track, size: 140, radius: 16),
            const SizedBox(height: 8),
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
    );
  }
}

/// "Porque escuchaste X", "Mezcla para ti" y "Descubre" (Tarea Z5).
class RecommendationSections extends ConsumerWidget {
  const RecommendationSections({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(homeFeedProvider);
    return feed.when(
      loading: () => Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Row(
          children: [
            const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Text(tx.buscandoMusicaParaTi, style: const TextStyle(color: KijiColors.muted)),
          ],
        ),
      ),
      error: (error, _) => const SizedBox.shrink(),
      data: (feed) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (feed.becauseOf != null)
            TrackShelf(title: tx.porqueEscuchaste(feed.becauseOf!.title), tracks: feed.because),
          TrackShelf(title: tx.mezclaParaTi, note: tx.tusFavoritasNuevas, tracks: feed.mix),
          TrackShelf(title: tx.descubre, note: tx.relacionadasDeYoutubeMusic, tracks: feed.discover),
        ],
      ),
    );
  }
}

/// "Para empezar" (usuario nuevo): géneros y estados de ánimo de YouTube Music.
class StartHereSection extends ConsumerWidget {
  const StartHereSection({super.key, this._title, this._note});

  final String? _title;
  final String? _note;
  String get title => _title ?? tx.paraEmpezar;
  String get note => _note ?? tx.eligeUnEstilo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moods = ref.watch(moodsProvider);
    return moods.when(
      loading: () => const Padding(padding: EdgeInsets.only(bottom: 28), child: LinearProgressIndicator()),
      error: (error, _) => Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Text(tx.sinConexionLosGenerosAparecenCuando, style: const TextStyle(color: KijiColors.muted)),
      ),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        Widget chips(Iterable<YtMood> items) =>
            Wrap(spacing: 8, runSpacing: 8, children: [for (final mood in items) MoodChip(mood: mood)]);
        return Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(title, note: note),
              Text(tx.estadosDeAnimo, style: KijiText.mono(size: 11)),
              const SizedBox(height: 8),
              chips(list.where((m) => !m.isGenre)),
              const SizedBox(height: 16),
              Text(tx.generos, style: KijiText.mono(size: 11)),
              const SizedBox(height: 8),
              chips(list.where((m) => m.isGenre)),
            ],
          ),
        );
      },
    );
  }
}

class MoodChip extends StatelessWidget {
  const MoodChip({super.key, required this.mood});

  final YtMood mood;

  @override
  Widget build(BuildContext context) {
    final stripe = mood.color == null ? KijiColors.violet : Color(mood.color!);
    return ActionChip(
      avatar: CircleAvatar(backgroundColor: stripe, radius: 6),
      label: Text(mood.title),
      onPressed: () => MoodScreen.open(context, mood),
    );
  }
}

/// Playlists de un género o estado de ánimo.
class MoodScreen extends ConsumerWidget {
  const MoodScreen({super.key, required this.mood});

  final YtMood mood;

  static Future<void> open(BuildContext context, YtMood mood) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MoodScreen(mood: mood)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelves = ref.watch(moodCategoryProvider(mood.params));
    return Scaffold(
      appBar: AppBar(title: Text(mood.title)),
      body: shelves.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(tx.noSePudoCargarRevisaTu)),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            for (final shelf in list) ...[
              SectionTitle(shelf.title),
              SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: shelf.playlists.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, i) => _PlaylistCard(card: shelf.playlists[i]),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({required this.card});

  final YtPlaylistCard card;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: InkWell(
        borderRadius: BorderRadius.circular(KijiRadii.tile),
        onTap: () => YtPlaylistScreen.open(context, card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox.square(
                dimension: 140,
                child: card.thumbnailUrl == null
                    ? const ColoredBox(color: KijiColors.surfaceHigh, child: Icon(Icons.queue_music_rounded))
                    : Image.network(
                        card.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const ColoredBox(color: KijiColors.surfaceHigh, child: Icon(Icons.queue_music_rounded)),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              card.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una playlist de YouTube Music: escucharla o guardarla como playlist de Kiji.
class YtPlaylistScreen extends ConsumerWidget {
  const YtPlaylistScreen({super.key, required this.card});

  final YtPlaylistCard card;

  static Future<void> open(BuildContext context, YtPlaylistCard card) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => YtPlaylistScreen(card: card)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(ytPlaylistTracksProvider(card.playlistId));
    return Scaffold(
      appBar: AppBar(title: Text(card.title)),
      body: tracks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(tx.noSePudoCargarRevisaTu)),
        data: (list) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: list.isEmpty ? null : () => _playAll(ref, list),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(tx.reproducir),
                  ),
                  OutlinedButton.icon(
                    onPressed: list.isEmpty ? null : () => _playAll(ref, list, shuffle: true),
                    icon: const Icon(Icons.shuffle_rounded),
                    label: Text(tx.aleatorio),
                  ),
                  OutlinedButton.icon(
                    onPressed: list.isEmpty
                        ? null
                        : () {
                            final created = ref.read(playlistsProvider.notifier).create(card.title, tracks: list);
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text(tx.seGuardoEnTusPlaylists(created.name))));
                          },
                    icon: const Icon(Icons.library_add_rounded),
                    label: Text(tx.guardarEnKiji),
                  ),
                ],
              ),
            ),
            for (final (i, track) in list.indexed)
              ListTile(
                leading: TrackArtwork(track: track, size: 44, radius: 8),
                title: TrackTitleText(track, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: TrackArtistText(track, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => _playAll(ref, list, index: i),
                onLongPress: () => showTrackActions(context, ref, track),
              ),
          ],
        ),
      ),
    );
  }
}
