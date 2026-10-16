import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/playback_provider.dart';
import '../../equalizer/data/equalizer_engine.dart';
import '../../equalizer/domain/equalizer_model.dart';
import '../../settings/data/settings_store.dart';
import '../domain/playback_rules.dart';

/// Volumen de la música del sistema (0 a 1), detrás de una interfaz
///: en Android sale de `MainActivity` por el canal
/// `kiji/volume`; en PC no hay (el silencio de Windows no pausa).
abstract class SystemVolumeMonitor {
  Stream<double> get volume;
}

class AndroidVolumeMonitor implements SystemVolumeMonitor {
  static const _channel = EventChannel('kiji/volume');

  @override
  Stream<double> get volume => _channel
      .receiveBroadcastStream()
      .map((value) => value is num ? value.toDouble() : 1.0)
      .distinct();
}

class NoVolumeMonitor implements SystemVolumeMonitor {
  const NoVolumeMonitor();
  @override
  Stream<double> get volume => const Stream.empty();
}

final systemVolumeMonitorProvider = Provider<SystemVolumeMonitor>(
  (ref) => !kIsWeb && Platform.isAndroid ? AndroidVolumeMonitor() : const NoVolumeMonitor(),
);

/// Lo que la automatización necesita del reproductor (para poder probarla
/// sin un reproductor real).
abstract class PlaybackControl {
  bool get isPlaying;
  Future<void> play();
  Future<void> pause();
}

class _NotifierControl implements PlaybackControl {
  _NotifierControl(this.ref);
  final Ref ref;
  @override
  bool get isPlaying => ref.read(playbackProvider).isPlaying;
  @override
  Future<void> play() => ref.read(playbackProvider.notifier).play();
  @override
  Future<void> pause() => ref.read(playbackProvider.notifier).pause();
}

final playbackControlProvider = Provider<PlaybackControl>(_NotifierControl.new);

/// "Pausar al silenciar" y "Retomar al reconectar el Bluetooth" (Tarea K).
/// Las dos vienen apagadas; solo escuchan el volumen y los dispositivos
/// mientras están activas.
class PlaybackAutomation {
  PlaybackAutomation(this.ref, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final Ref ref;
  final DateTime Function() _clock;
  final mute = MuteRule();
  final bluetooth = BluetoothResumeRule();
  StreamSubscription<double>? _volume;
  StreamSubscription<AudioOutputKind>? _outputs;
  AudioOutputKind? _lastOutput;

  /// Cuándo dejó de sonar por última vez (al desconectarse el Bluetooth,
  /// el reproductor se pausa casi al mismo tiempo que llega el aviso).
  DateTime? _stoppedAt;
  bool _wasPlaying = false;

  /// Pausas y play propios (no cuentan como "la persona tomó el control").
  bool _ownAction = false;

  void start() {
    ref.listen(settingsProvider.select((s) => (s.pauseOnMute, s.resumeOnBluetooth)), (_, next) {
      _sync(pauseOnMute: next.$1, resumeOnBluetooth: next.$2);
    }, fireImmediately: true);
    ref.onDispose(() {
      _volume?.cancel();
      _outputs?.cancel();
    });
  }

  /// La reproducción cambió (lo llama quien observa al reproductor).
  void onPlayingChanged(bool playing) {
    if (_wasPlaying && !playing) _stoppedAt = _clock();
    _wasPlaying = playing;
    if (_ownAction) {
      _ownAction = false;
      return;
    }
    if (playing) {
      mute.userTookControl();
      bluetooth.userTookControl();
    }
  }

  void _sync({required bool pauseOnMute, required bool resumeOnBluetooth}) {
    if (pauseOnMute && _volume == null) {
      _volume = ref.read(systemVolumeMonitorProvider).volume.listen(
            onVolume,
            onError: (Object e) => debugPrint('=== AUTOMATICO: no se pudo leer el volumen: $e ==='),
          );
    } else if (!pauseOnMute && _volume != null) {
      unawaited(_volume!.cancel());
      _volume = null;
      mute.userTookControl();
    }
    if (resumeOnBluetooth && _outputs == null) {
      final monitor = ref.read(audioOutputMonitorProvider);
      unawaited(monitor.current().then((kind) => _lastOutput ??= kind));
      _outputs = monitor.changes.listen(
        onOutput,
        onError: (Object e) => debugPrint('=== AUTOMATICO: no se pudo seguir la salida: $e ==='),
      );
    } else if (!resumeOnBluetooth && _outputs != null) {
      unawaited(_outputs!.cancel());
      _outputs = null;
      bluetooth.userTookControl();
    }
  }

  PlaybackControl get _control => ref.read(playbackControlProvider);

  @visibleForTesting
  void onVolume(double volume) {
    switch (mute.onVolume(volume, isPlaying: _control.isPlaying)) {
      case MuteAction.pause:
        debugPrint('=== AUTOMATICO: volumen en cero, pausa ===');
        _ownAction = true;
        unawaited(_control.pause());
      case MuteAction.resume:
        debugPrint('=== AUTOMATICO: volvió el volumen, sigue ===');
        _ownAction = true;
        unawaited(_control.play());
      case MuteAction.none:
        break;
    }
  }

  @visibleForTesting
  void onOutput(AudioOutputKind output) {
    final previous = _lastOutput;
    _lastOutput = output;
    final now = _clock();
    if (previous == AudioOutputKind.bluetooth && output != AudioOutputKind.bluetooth) {
      final stoppedRecently = _stoppedAt != null && now.difference(_stoppedAt!) < const Duration(seconds: 3);
      bluetooth.onDisconnected(wasPlaying: _control.isPlaying || stoppedRecently, now: now);
    } else if (output == AudioOutputKind.bluetooth && previous != AudioOutputKind.bluetooth) {
      if (bluetooth.onConnected(isPlaying: _control.isPlaying, now: now)) {
        debugPrint('=== AUTOMATICO: volvió el Bluetooth, sigue ===');
        _ownAction = true;
        unawaited(_control.play());
      }
    }
  }
}

final playbackAutomationProvider = Provider<PlaybackAutomation>((ref) {
  final automation = PlaybackAutomation(ref)..start();
  ref.listen(playbackProvider.select((s) => s.isPlaying), (_, playing) => automation.onPlayingChanged(playing));
  return automation;
});
