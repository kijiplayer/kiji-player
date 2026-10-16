import 'package:flutter/foundation.dart';

import '../../../models/track.dart';
import '../domain/system_media_controls.dart';
import 'audio_service_controls.dart';

/// Elige los controles del sistema según la plataforma.
Future<SystemMediaControls> createSystemMediaControls() async {
  final supported = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);
  if (!supported) {
    // Windows (SMTC) y Linux (MPRIS): pendientes para la Tarea X.
    return const NoSystemMediaControls();
  }
  try {
    return await AudioServiceControls.init();
  } catch (error) {
    debugPrint('=== CONTROLES: no se pudo iniciar audio_service: $error ===');
    return const NoSystemMediaControls();
  }
}

/// Plataformas sin controles del sistema todavía (y los tests).
class NoSystemMediaControls implements SystemMediaControls {
  const NoSystemMediaControls();

  @override
  void attach(MediaCommands commands) {}

  @override
  Future<void> showTrack(Track track, {Duration? duration}) async {}

  @override
  void updatePlayback({
    required bool playing,
    required MediaProcessing processing,
    required Duration position,
    required Duration bufferedPosition,
  }) {}
}
