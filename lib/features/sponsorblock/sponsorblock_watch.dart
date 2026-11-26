import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/playback_provider.dart';
import '../../widgets/global_mini_player.dart' show kijiNavigatorKey;
import '../../widgets/top_notice.dart';
import '../settings/data/settings_store.dart';
import 'sponsorblock.dart';

import 'package:kiji_player/l10n/l10n.dart';

final sponsorBlockClientProvider = Provider<SponsorBlockClient>((ref) => SponsorBlockClient());

/// Engancha «Saltar las partes sin música» al reproductor (se llama una vez, desde la app). Solo
/// con el ajuste prendido y con canciones de YouTube. Cada tramo se salta una vez por canción; con
/// «Deshacer» vuelve al principio del tramo y ya no se salta.
void watchSponsorBlock(WidgetRef ref) {
  String? current;
  var segments = const <SkipSegment>[];
  final done = <SkipSegment>{};

  Future<void> load(String? videoId) async {
    current = videoId;
    segments = const [];
    done.clear();
    final settings = ref.read(settingsProvider);
    if (videoId == null || !settings.sponsorBlock || settings.sponsorBlockCategories.isEmpty) return;
    final found = await ref.read(sponsorBlockClientProvider).segmentsFor(videoId, settings.sponsorBlockCategories);
    if (current == videoId) segments = found;
  }

  ref.listenManual(playbackProvider.select((p) => p.track?.youtubeVideoId), (_, id) => load(id), fireImmediately: true);
  // Prenderlo (o cambiar las categorías) con una canción sonando: se buscan sus tramos.
  ref.listenManual(
    settingsProvider.select((s) => (s.sponsorBlock, s.sponsorBlockCategories.join(','))),
    (_, _) => load(ref.read(playbackProvider).track?.youtubeVideoId),
  );

  ref.listenManual(playbackProvider.select((p) => p.position), (_, position) {
    if (segments.isEmpty || !ref.read(settingsProvider).sponsorBlock) return;
    final segment = segmentToSkip(segments, position, done);
    if (segment == null) return;
    done.add(segment);
    final playback = ref.read(playbackProvider.notifier);
    playback.seekTo(segment.end);
    final context = kijiNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    showTopNotice(
      context,
      message: tx.saltadoCategoria(segment.category.label),
      actionLabel: tx.deshacer,
      onAction: (_) => playback.seekTo(segment.start),
    );
  });
}
