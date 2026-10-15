import '../../../models/track.dart';

/// Foto de la reproducción que se guarda en disco para recuperarla al
/// reabrir la app: cola, índice, posición, repetir y aleatorio.
class PlaybackSnapshot {
  const PlaybackSnapshot({
    required this.queue,
    required this.currentIndex,
    required this.positionMs,
    required this.repeatMode,
    required this.shuffleEnabled,
  });

  static const _version = 1;

  final List<Track> queue;
  final int currentIndex;
  final int positionMs;

  /// Nombre del valor de `PlaybackRepeatMode` (`off`, `all`, `one`).
  final String repeatMode;
  final bool shuffleEnabled;

  Map<String, dynamic> toJson() => {
        'version': _version,
        'queue': [for (final track in queue) track.toJson()],
        'currentIndex': currentIndex,
        'positionMs': positionMs,
        'repeatMode': repeatMode,
        'shuffleEnabled': shuffleEnabled,
      };

  /// Lanza [FormatException] si el contenido no tiene sentido (versión
  /// desconocida, cola vacía o índice fuera de rango).
  factory PlaybackSnapshot.fromJson(Map<String, dynamic> json) {
    if (json['version'] != _version) {
      throw FormatException('Versión de guardado desconocida: ${json['version']}');
    }
    final queue = [
      for (final item in json['queue'] as List<dynamic>)
        Track.fromJson(item as Map<String, dynamic>),
    ];
    final index = json['currentIndex'] as int;
    if (queue.isEmpty || index < 0 || index >= queue.length) {
      throw const FormatException('Cola vacía o índice fuera de rango');
    }
    return PlaybackSnapshot(
      queue: queue,
      currentIndex: index,
      positionMs: json['positionMs'] as int? ?? 0,
      repeatMode: json['repeatMode'] as String? ?? 'off',
      shuffleEnabled: json['shuffleEnabled'] as bool? ?? false,
    );
  }
}
