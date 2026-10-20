import '../../../models/track.dart';
import '../../../utils/duration_formatter.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Un "Momento" (propio de Kiji): un segundo exacto de una canción ("aquí empieza el solo") o un
/// tramo ("de 1:12 a 1:40, la parte que me gusta").
class Moment {
  const Moment({required this.id, required this.track, required this.position, required this.createdAt, this.end});

  final String id;
  final Track track;

  /// El segundo del punto, o el principio del tramo.
  final Duration position;

  /// El final del tramo; null si es un punto.
  final Duration? end;
  final DateTime createdAt;

  bool get isInterval => end != null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'track': track.toJson(),
    'positionMs': position.inMilliseconds,
    if (end != null) 'endMs': end!.inMilliseconds,
    'createdAt': createdAt.toIso8601String(),
  };

  static Moment? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final track = json['track'];
    final ms = json['positionMs'];
    if (track is! Map<String, dynamic> || ms is! int || json['id'] is! String) return null;
    return Moment(
      id: json['id'] as String,
      track: Track.fromJson(track),
      position: Duration(milliseconds: ms),
      end: json['endMs'] is int && (json['endMs'] as int) > ms ? Duration(milliseconds: json['endMs'] as int) : null,
      createdAt: DateTime.tryParse('${json['createdAt']}') ?? DateTime.now(),
    );
  }
}

/// Texto para compartir un Momento. Con canción de YouTube va el enlace que
/// arranca en ese segundo; con un archivo propio, solo el texto.
String momentShareText(Moment moment) {
  final at = formatDuration(moment.position);
  final end = moment.end;
  final base = end == null
      ? tx.momentoDesde(moment.track.title, moment.track.artist, at)
      : tx.deDeA(moment.track.title, moment.track.artist, at, formatDuration(end));
  final id = moment.track.youtubeVideoId;
  if (id == null) return base;
  return '$base\nhttps://youtu.be/$id?t=${moment.position.inSeconds}';
}
