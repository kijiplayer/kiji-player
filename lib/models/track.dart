import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Origen de una pista: descargada/leída del dispositivo o transmitida
/// desde YouTube Music (streaming/anónimo).
enum TrackSource { local, youtube }

class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.coverColor,
    required this.audioUrl,
    required this.source,
    this.thumbnailUrl,
    this.album,
    this.durationMs = 0,
  });

  /// Identificador único: `local-<mediaStoreId>` o `yt-<videoId>`.
  final String id;
  final String title;
  final String artist;
  final Color coverColor;

  /// URL remota (streaming) o ruta de archivo local, según [source].
  final String audioUrl;
  final TrackSource source;
  final String? thumbnailUrl;
  final String? album;
  final int durationMs;

  static const demo = Track(
    id: 'demo-sintel',
    title: 'Midnight Echoes',
    artist: 'Luna Nova',
    coverColor: AppColors.seed,
    audioUrl:
        'https://storage.googleapis.com/media-session/sintel/sintel_carl.mp3',
    source: TrackSource.youtube,
  );

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    Color? coverColor,
    String? audioUrl,
    TrackSource? source,
    String? thumbnailUrl,
    String? album,
    int? durationMs,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      coverColor: coverColor ?? this.coverColor,
      audioUrl: audioUrl ?? this.audioUrl,
      source: source ?? this.source,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      album: album ?? this.album,
      durationMs: durationMs ?? this.durationMs,
    );
  }
}
