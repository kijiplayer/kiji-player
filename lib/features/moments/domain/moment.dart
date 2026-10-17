import '../../../models/track.dart';
import '../../../utils/duration_formatter.dart';

/// Un "Momento" (Tarea Z6, propio de Kiji): un segundo exacto de una canción
/// que el usuario quiso guardar ("acá empieza el solo").
class Moment {
  const Moment({required this.id, required this.track, required this.position, required this.createdAt});

  final String id;
  final Track track;
  final Duration position;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'track': track.toJson(),
        'positionMs': position.inMilliseconds,
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
      createdAt: DateTime.tryParse('${json['createdAt']}') ?? DateTime.now(),
    );
  }
}

/// Texto para compartir un Momento. Con canción de YouTube va el enlace que
/// arranca en ese segundo; con un archivo propio, solo el texto.
String momentShareText(Moment moment) {
  final at = formatDuration(moment.position);
  final base = '«${moment.track.title}» de ${moment.track.artist}, desde el $at';
  final id = moment.track.youtubeVideoId;
  if (id == null) return base;
  return '$base\nhttps://youtu.be/$id?t=${moment.position.inSeconds}';
}
