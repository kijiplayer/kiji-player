import '../../../models/track.dart';

/// Estado de carga que se informa al sistema (notificación, pantalla de
/// bloqueo, auriculares).
enum MediaProcessing { idle, loading, buffering, ready, completed }

/// Lo que el sistema le puede pedir a Kiji: los botones de la notificación,
/// de la pantalla de bloqueo y de los auriculares.
class MediaCommands {
  const MediaCommands({
    required this.play,
    required this.pause,
    required this.next,
    required this.previous,
    required this.seek,
    required this.stop,
  });

  final Future<void> Function() play;
  final Future<void> Function() pause;
  final Future<void> Function() next;
  final Future<void> Function() previous;
  final Future<void> Function(Duration position) seek;

  /// El usuario descartó la notificación: se pausa, no se cierra la app.
  final Future<void> Function() stop;
}

/// Controles multimedia del sistema operativo.
///
/// Es una interfaz porque cada plataforma los resuelve
/// distinto: Android/iOS/macOS con `audio_service`, Windows con SMTC (nativo) y en Linux todavía
/// no hay. Ver `data/`.
abstract interface class SystemMediaControls {
  /// Conecta los botones del sistema con el reproductor.
  void attach(MediaCommands commands);

  /// Muestra [track] en la notificación / pantalla de bloqueo.
  Future<void> showTrack(Track track, {Duration? duration});

  void updatePlayback({
    required bool playing,
    required MediaProcessing processing,
    required Duration position,
    required Duration bufferedPosition,
  });
}
