import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../../models/track.dart';
import '../../yt_music/domain/subtitle_parser.dart';

const _unknownArtistMarkers = {'<unknown>', 'unknown', ''};

/// Convierte un [SongModel] leído del dispositivo en nuestro modelo [Track].
///
/// No usamos la carátula embebida aquí (eso requeriría leer bytes por
/// canción, que es costoso para listas largas). En su lugar generamos un
/// color determinístico a partir del título, igual que hace el resto de
/// la UI con `AlbumCover`.
Track localTrackFromSong(SongModel song) {
  final rawArtist = song.artist?.trim() ?? '';
  final artist = _unknownArtistMarkers.contains(rawArtist.toLowerCase())
      ? unknownArtist
      : rawArtist;

  return Track(
    id: 'local-${song.id}',
    title: song.title,
    artist: artist,
    coverColor: _colorFromSeed(song.title),
    audioUrl: song.data,
    source: TrackSource.local,
    album: song.album,
    durationMs: song.duration ?? 0,
    sizeBytes: song.size,
  );
}

Color _colorFromSeed(String seed) {
  final hash = seed.codeUnits.fold<int>(0, (acc, unit) => acc + unit);
  final hue = (hash * 37) % 360;
  return HSLColor.fromAHSL(1, hue.toDouble(), 0.55, 0.55).toColor();
}
