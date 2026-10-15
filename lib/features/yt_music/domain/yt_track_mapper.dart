import 'package:flutter/material.dart';

import '../../../models/track.dart';
import '../data/ytm_client.dart';

/// Convierte un [YtMusicSearchResult] (más la URL de audio ya resuelta)
/// en nuestro modelo [Track], listo para pasarle al `playbackProvider`.
Track ytTrackFromResult(YtMusicSearchResult result, {required String audioUrl}) {
  return Track(
    id: 'yt-${result.videoId}',
    title: result.title,
    artist: result.artist,
    coverColor: _colorFromSeed(result.title),
    audioUrl: audioUrl,
    source: TrackSource.youtube,
    thumbnailUrl: result.thumbnailUrl,
    album: result.album,
  );
}

Color _colorFromSeed(String seed) {
  final hash = seed.codeUnits.fold<int>(0, (acc, unit) => acc + unit);
  final hue = (hash * 37) % 360;
  return HSLColor.fromAHSL(1, hue.toDouble(), 0.55, 0.55).toColor();
}
