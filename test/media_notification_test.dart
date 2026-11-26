// Notificación y sesión de medios de Android (0.8.6): los botones anterior / play-pausa /
// siguiente tienen que estar siempre, en la vista compacta, la expandida y la pantalla de bloqueo.

import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/system_media/data/audio_service_controls.dart';
import 'package:kiji_player/features/system_media/domain/system_media_controls.dart';

void main() {
  const requiredActions = {
    MediaAction.play,
    MediaAction.pause,
    MediaAction.playPause,
    MediaAction.skipToNext,
    MediaAction.skipToPrevious,
    MediaAction.seek,
    MediaAction.stop,
  };

  for (final playing in [true, false]) {
    for (final processing in MediaProcessing.values) {
      test('3 controles y todas las acciones (playing: $playing, ${processing.name})', () {
        final state = kijiPlaybackState(
          playing: playing,
          processing: processing,
          position: Duration.zero,
          bufferedPosition: Duration.zero,
        );
        expect(state.controls.map((c) => c.action).toList(), [
          MediaAction.skipToPrevious,
          playing ? MediaAction.pause : MediaAction.play,
          MediaAction.skipToNext,
        ]);
        expect(state.androidCompactActionIndices, [0, 1, 2]);
        expect(state.systemActions, containsAll(requiredActions));
        expect(state.playing, playing);
      });
    }
  }

  test('la reducción de recursos conserva los íconos de los botones', () {
    final keep = File('android/app/src/main/res/raw/keep.xml').readAsStringSync();
    expect(keep, contains('@drawable/audio_service_*'));
    expect(keep, contains('@drawable/ic_stat_kiji'));
  });
}
