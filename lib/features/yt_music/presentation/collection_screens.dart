import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/track.dart';
import '../../../providers/playback_provider.dart';
import '../../../theme/kiji_tokens.dart';
import '../../../widgets/nocturne/glass.dart';
import '../../downloads/presentation/download_button.dart';
import '../../playlists/presentation/playlist_screens.dart';
import '../../queue/presentation/track_actions.dart';
import '../../system_media/data/cover_art.dart';
import '../data/ytm_browse_parser.dart';
import '../data/ytm_client.dart';
import '../domain/yt_track_mapper.dart';
import '../../customize/presentation/track_text.dart';

/// Cliente compartido para las páginas de artista y álbum.
final ytMusicClientProvider = Provider<YtMusicClient>((ref) => YtMusicClient());

final artistPageProvider = FutureProvider.autoDispose.family<ArtistPage?, String>(
  (ref, browseId) => ref.watch(ytMusicClientProvider).artist(browseId),
);

final albumPageProvider = FutureProvider.autoDispose.family<AlbumPage?, String>(
  (ref, browseId) => ref.watch(ytMusicClientProvider).album(browseId),
);

/// Abre la página que corresponde a [collection].
Future<void> openCollection(BuildContext context, YtCollection collection) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => collection.kind == YtCollectionKind.artist
            ? ArtistScreen(browseId: collection.browseId, title: collection.title)
            : AlbumScreen(browseId: collection.browseId, title: collection.title),
      ),
    );

/// Fila de un artista o álbum en los resultados.
class CollectionTile extends StatelessWidget {
  const CollectionTile({super.key, required this.collection});

  final YtCollection collection;

  @override
  Widget build(BuildContext context) {
    final isArtist = collection.kind == YtCollectionKind.artist;
    final thumb = collection.thumbnailUrl;
    final image = thumb == null
        ? Icon(isArtist ? Icons.person_rounded : Icons.album_rounded, color: KijiColors.muted)
        : Image.network(largerThumbnailUrl(thumb), fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(Icons.music_note_rounded));
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(isArtist ? 28 : 8),
        child: SizedBox.square(dimension: 52, child: ColoredBox(color: KijiColors.surfaceHigh, child: image)),
      ),
      title: Text(collection.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        isArtist ? 'Artista' : (collection.subtitle.isEmpty ? 'Álbum' : collection.subtitle),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: KijiColors.muted),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => openCollection(context, collection),
    );
  }
}

class _SongsList extends ConsumerWidget {
  const _SongsList({required this.songs});

  final List<YtMusicSearchResult> songs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = [for (final s in songs) ytTrackFromResult(s, audioUrl: '')];
    return Column(
      children: [
        for (final (index, track) in tracks.indexed)
          GestureDetector(
            onSecondaryTap: () => showTrackActions(context, ref, track),
            child: ListTile(
              leading: _Art(track: track),
              title: TrackTitleText(track, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: TrackArtistText(track, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: DownloadButton(track: track),
              onTap: () => ref.read(playbackProvider.notifier).playQueue(tracks, startIndex: index),
              onLongPress: () => showTrackActions(context, ref, track),
            ),
          ),
      ],
    );
  }
}

class _Art extends StatelessWidget {
  const _Art({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final url = track.thumbnailUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(
        dimension: 44,
        child: url == null
            ? ColoredBox(color: track.coverColor)
            : Image.network(largerThumbnailUrl(url), fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(color: track.coverColor)),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.title, required this.subtitle, required this.thumbnailUrl, required this.tracks, this.round = false});

  final String title;
  final String subtitle;
  final String? thumbnailUrl;
  final List<Track> tracks;
  final bool round;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumb = thumbnailUrl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: GradientBorder(
        fill: KijiColors.surface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (thumb != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(round ? 48 : 16),
                  child: Image.network(largerThumbnailUrl(thumb), width: 96, height: 96, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(width: 96, height: 96)),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: KijiText.title(size: 22)),
                    if (subtitle.isNotEmpty)
                      Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: KijiColors.muted)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: tracks.isEmpty
                              ? null
                              : () => ref.read(playbackProvider.notifier).playQueue(tracks),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Reproducir'),
                        ),
                        OutlinedButton.icon(
                          onPressed: tracks.isEmpty ? null : () => showAddToPlaylistSheet(context, ref, tracks),
                          icon: const Icon(Icons.library_add_rounded),
                          label: const Text('A playlist'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _loadingOrError(AsyncValue<Object?> value, VoidCallback retry) => value.hasError
    ? Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No se pudo abrir. Revisa tu conexión.', style: TextStyle(color: KijiColors.muted)),
              const SizedBox(height: 12),
              FilledButton(onPressed: retry, child: const Text('Reintentar')),
            ],
          ),
        ),
      )
    : const Center(child: CircularProgressIndicator());

/// Página de un artista: sus canciones más escuchadas y sus álbumes.
class ArtistScreen extends ConsumerWidget {
  const ArtistScreen({super.key, required this.browseId, required this.title});

  final String browseId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(artistPageProvider(browseId));
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: page.value == null
          ? _loadingOrError(page, () => ref.invalidate(artistPageProvider(browseId)))
          : ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                _Header(
                  title: page.value!.name,
                  subtitle: 'Artista',
                  thumbnailUrl: page.value!.thumbnailUrl,
                  tracks: [for (final s in page.value!.songs) ytTrackFromResult(s, audioUrl: '')],
                  round: true,
                ),
                if (page.value!.songs.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text('CANCIONES', style: KijiText.mono(size: 11)),
                  ),
                  _SongsList(songs: page.value!.songs),
                ],
                if (page.value!.albums.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text('ÁLBUMES Y SINGLES', style: KijiText.mono(size: 11)),
                  ),
                  for (final album in page.value!.albums) CollectionTile(collection: album),
                ],
              ],
            ),
    );
  }
}

/// Página de un álbum: sus pistas.
class AlbumScreen extends ConsumerWidget {
  const AlbumScreen({super.key, required this.browseId, required this.title});

  final String browseId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(albumPageProvider(browseId));
    return Scaffold(
      appBar: AppBar(title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: page.value == null
          ? _loadingOrError(page, () => ref.invalidate(albumPageProvider(browseId)))
          : ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                _Header(
                  title: page.value!.title,
                  subtitle: [page.value!.artist, page.value!.subtitle].where((s) => s.isNotEmpty).join(' · '),
                  thumbnailUrl: page.value!.thumbnailUrl,
                  tracks: [for (final s in page.value!.tracks) ytTrackFromResult(s, audioUrl: '')],
                ),
                _SongsList(songs: page.value!.tracks),
              ],
            ),
    );
  }
}
