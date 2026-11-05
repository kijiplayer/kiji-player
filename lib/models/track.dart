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
    this.sizeBytes,
    this.albumArtist,
    this.year,
    this.trackNumber,
    this.discNumber,
    this.genre,
    this.addedAtMs,
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

  /// Tamaño del archivo (locales y descargadas), si se conoce.
  final int? sizeBytes;

  /// Datos de los archivos de música (locales): artista del álbum, año, número de pista y de
  /// disco, género y cuándo se agregó (ms desde 1970: MediaStore en Android, la fecha del archivo
  /// en la PC).
  final String? albumArtist;
  final int? year;
  final int? trackNumber;
  final int? discNumber;
  final String? genre;
  final int? addedAtMs;

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
        if (sizeBytes != null) 'sizeBytes': sizeBytes,
        if (albumArtist != null) 'albumArtist': albumArtist,
        if (year != null) 'year': year,
        if (trackNumber != null) 'trackNumber': trackNumber,
        if (discNumber != null) 'discNumber': discNumber,
        if (genre != null) 'genre': genre,
        if (addedAtMs != null) 'addedAtMs': addedAtMs,
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
      sizeBytes: json['sizeBytes'] as int?,
      albumArtist: json['albumArtist'] as String?,
      year: json['year'] as int?,
      trackNumber: json['trackNumber'] as int?,
      discNumber: json['discNumber'] as int?,
      genre: json['genre'] as String?,
      addedAtMs: json['addedAtMs'] as int?,
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
    int? sizeBytes,
    String? albumArtist,
    int? year,
    int? trackNumber,
    int? discNumber,
    String? genre,
    int? addedAtMs,
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
      sizeBytes: sizeBytes ?? this.sizeBytes,
      albumArtist: albumArtist ?? this.albumArtist,
      year: year ?? this.year,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      genre: genre ?? this.genre,
      addedAtMs: addedAtMs ?? this.addedAtMs,
    );
  }
}
