import 'package:flutter/material.dart';

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
  /// Para YouTube puede venir vacía (pista restaurada del guardado): se
  /// resuelve de nuevo con el `videoId` antes de reproducir.
  final String audioUrl;
  final TrackSource source;
  final String? thumbnailUrl;
  final String? album;
  final int durationMs;

  /// `videoId` de YouTube (sale de `id = 'yt-<videoId>'`), o null si la
  /// pista no es de YouTube.
  String? get youtubeVideoId =>
      source == TrackSource.youtube && id.startsWith('yt-') ? id.substring(3) : null;

  /// Para YouTube no se guarda la URL de audio: vence en unas horas.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'coverColor': coverColor.toARGB32(),
        'source': source.name,
        if (source == TrackSource.local) 'audioUrl': audioUrl,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (album != null) 'album': album,
        'durationMs': durationMs,
      };

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      coverColor: Color(json['coverColor'] as int),
      audioUrl: json['audioUrl'] as String? ?? '',
      source: TrackSource.values.byName(json['source'] as String),
      thumbnailUrl: json['thumbnailUrl'] as String?,
      album: json['album'] as String?,
      durationMs: json['durationMs'] as int? ?? 0,
    );
  }

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
