import 'package:flutter/material.dart';

import '../../../models/track.dart';

/// Una canción de YouTube guardada dentro de la app para escucharla sin
/// conexión. Los archivos viven en `<appSupportDir>/downloads/`; acá solo se
/// guardan nombres de archivo (no rutas completas), así el índice sigue
/// sirviendo si cambia la carpeta base (otra plataforma, copia de seguridad).
class DownloadedTrack {
  const DownloadedTrack({
    required this.videoId,
    required this.title,
    required this.artist,
    required this.coverColor,
    required this.fileName,
    required this.sizeBytes,
    required this.downloadedAt,
    this.album,
    this.thumbnailFileName,
    this.durationMs = 0,
  });

  final String videoId;
  final String title;
  final String artist;
  final Color coverColor;
  final String fileName;
  final int sizeBytes;
  final DateTime downloadedAt;
  final String? album;
  final String? thumbnailFileName;
  final int durationMs;

  /// Se convierte en una pista **de YouTube** (no local): el reproductor
  /// busca primero el archivo descargado por `videoId`. Así, si el usuario
  /// borra la descarga, la canción no desaparece de la cola: vuelve a sonar
  /// desde internet.
  Track toTrack() => Track(
        id: 'yt-$videoId',
        title: title,
        artist: artist,
        coverColor: coverColor,
        audioUrl: '',
        source: TrackSource.youtube,
        album: album,
        durationMs: durationMs,
        sizeBytes: sizeBytes,
      );

  DownloadedTrack copyWith({String? artist}) => DownloadedTrack(
        videoId: videoId,
        title: title,
        artist: artist ?? this.artist,
        coverColor: coverColor,
        fileName: fileName,
        sizeBytes: sizeBytes,
        downloadedAt: downloadedAt,
        album: album,
        thumbnailFileName: thumbnailFileName,
        durationMs: durationMs,
      );

  Map<String, dynamic> toJson() => {
        'videoId': videoId,
        'title': title,
        'artist': artist,
        'coverColor': coverColor.toARGB32(),
        'fileName': fileName,
        'sizeBytes': sizeBytes,
        'downloadedAt': downloadedAt.millisecondsSinceEpoch,
        if (album != null) 'album': album,
        if (thumbnailFileName != null) 'thumbnailFileName': thumbnailFileName,
        'durationMs': durationMs,
      };

  factory DownloadedTrack.fromJson(Map<String, dynamic> json) => DownloadedTrack(
        videoId: json['videoId'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String,
        coverColor: Color(json['coverColor'] as int),
        fileName: json['fileName'] as String,
        sizeBytes: json['sizeBytes'] as int,
        downloadedAt: DateTime.fromMillisecondsSinceEpoch(json['downloadedAt'] as int),
        album: json['album'] as String?,
        thumbnailFileName: json['thumbnailFileName'] as String?,
        durationMs: json['durationMs'] as int? ?? 0,
      );
}
