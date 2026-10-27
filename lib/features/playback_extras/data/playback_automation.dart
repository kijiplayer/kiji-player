import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
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
  Stream<double> get volume =>
      _channel.receiveBroadcastStream().map((value) => value is num ? value.toDouble() : 1.0).distinct();
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

  /// Hay una canción cargada (para "Retomar al conectar el Bluetooth").
  bool get hasTrack;
  Future<void> play();

  /// [reason] queda en el registro. Con [keepAliveFor], Kiji sigue en primer plano ese
  /// tiempo para poder seguir sola (si no, Android la congela a los pocos segundos).
  Future<void> pause({required String reason, Duration? keepAliveFor});
}

class _NotifierControl implements PlaybackControl {
  _NotifierControl(this.ref);
  final Ref ref;
  @override
  bool get isPlaying => ref.read(playbackProvider).isPlaying;
  @override
  bool get hasTrack => ref.read(playbackProvider).track != null;
  @override
  Future<void> play() => ref.read(playbackProvider.notifier).play();
  @override
  Future<void> pause({required String reason, Duration? keepAliveFor}) =>
      ref.read(playbackProvider.notifier).pause(reason: reason, keepAliveFor: keepAliveFor);
}

final playbackControlProvider = Provider<PlaybackControl>(_NotifierControl.new);

/// Pausas y retomas automáticas: "Pausar al silenciar" (apagado de fábrica),
/// "Retomar al conectar el Bluetooth" (prendido de fábrica), el corte de la
/// salida (pausa y sigue sola si vuelve en 15 s) y las interrupciones de otras
/// apps. El volumen solo se escucha con su opción activa.
class PlaybackAutomation {
  PlaybackAutomation(this.ref);

  final Ref ref;
  final mute = MuteRule();
  final bluetooth = BluetoothResumeRule();
  final outputLoss = OutputLossRule();
  StreamSubscription<double>? _volume;
  final _system = <StreamSubscription<Object?>>[];
  AudioOutputKind? _lastOutput;
  bool _resumeOnBluetooth = false;
  bool _pausedByInterruption = false;

  /// Pausas y play propios (no cuentan como "la persona tomó el control").
  bool _ownAction = false;

  void start() {
    final monitor = ref.read(audioOutputMonitorProvider);
    unawaited(monitor.current().then((kind) => _lastOutput ??= kind));
    void onError(Object e) => debugPrint('=== AUTOMATICO: no se pudo seguir la salida de audio: $e ===');
    _system
      ..add(monitor.changes.listen(onOutput, onError: onError))
      ..add(monitor.becomingNoisy.listen((_) => onBecomingNoisy(), onError: onError))
      ..add(monitor.interruptions.listen(onInterruption, onError: onError));
    ref.listen(settingsProvider.select((s) => (s.pauseOnMute, s.resumeOnBluetooth)), (_, next) {
      _sync(pauseOnMute: next.$1);
      _resumeOnBluetooth = next.$2;
    }, fireImmediately: true);
    ref.onDispose(() {
      _volume?.cancel();
      for (final s in _system) {
        s.cancel();
      }
    });
  }

  /// La reproducción cambió (lo llama quien observa al reproductor).
  void onPlayingChanged(bool playing) {
    if (_ownAction) {
      _ownAction = false;
      return;
    }
    outputLoss.userTookControl();
    _pausedByInterruption = false;
    if (playing) {
      mute.userTookControl();
    }
  }

  void _sync({required bool pauseOnMute}) {
    if (pauseOnMute && _volume == null) {
      _volume = ref
          .read(systemVolumeMonitorProvider)
          .volume
          .listen(onVolume, onError: (Object e) => debugPrint('=== AUTOMATICO: no se pudo leer el volumen: $e ==='));
    } else if (!pauseOnMute && _volume != null) {
      unawaited(_volume!.cancel());
      _volume = null;
      mute.userTookControl();
    }
  }

  PlaybackControl get _control => ref.read(playbackControlProvider);

  void _pause(String reason, {Duration? keepAliveFor}) {
    _ownAction = true;
    unawaited(_control.pause(reason: reason, keepAliveFor: keepAliveFor));
  }

  void _play(String why) {
    debugPrint('=== AUTOMATICO: $why ===');
    _ownAction = true;
    unawaited(_control.play());
  }

  @visibleForTesting
  void onVolume(double volume) {
    switch (mute.onVolume(volume, isPlaying: _control.isPlaying)) {
      case MuteAction.pause:
        _pause('volumen en cero (Pausar al silenciar)'); // l10n-ignore
      case MuteAction.resume:
        _play('volvió el volumen, sigue'); // l10n-ignore
      case MuteAction.none:
        break;
    }
  }

  @visibleForTesting
  void onBecomingNoisy() => _outputLost('se desconectó el Bluetooth o los audífonos'); // l10n-ignore

  void _outputLost(String reason) {
    if (outputLoss.onLost(isPlaying: _control.isPlaying)) {
      _pause(reason, keepAliveFor: outputLoss.window);
    }
  }

  @visibleForTesting
  void onOutput(AudioOutputKind output) {
    final previous = _lastOutput;
    _lastOutput = output;
    if (output == previous) return;
    if (output == AudioOutputKind.speaker) {
      // A veces Android pasa al parlante sin avisar "becoming noisy": tampoco ahí suena por el parlante.
      _outputLost('la salida pasó al parlante'); // l10n-ignore
      return;
    }
    if (outputLoss.onBack()) {
      _play('volvió la salida en menos de ${outputLoss.window.inSeconds} s, sigue'); // l10n-ignore
      return;
    }
    if (output == AudioOutputKind.bluetooth &&
        _resumeOnBluetooth &&
        bluetooth.onConnected(isPlaying: _control.isPlaying, hasTrack: _control.hasTrack)) {
      _play('volvió el Bluetooth, sigue'); // l10n-ignore
    }
  }

  /// Como hacía just_audio por dentro, pero con el motivo en el registro.
  @visibleForTesting
  void onInterruption(AudioInterruptionEvent event) {
    // Al "bajar el volumen" se encarga Android solo.
    if (event.type == AudioInterruptionType.duck) return;
    if (event.begin) {
      if (_control.isPlaying) {
        _pausedByInterruption = true;
        _pause('otra app tomó el audio (llamada, alarma, asistente…)'); // l10n-ignore
      }
      return;
    }
    if (_pausedByInterruption && event.type == AudioInterruptionType.pause && !_control.isPlaying) {
      _play('la otra app devolvió el audio, sigue'); // l10n-ignore
    }
    _pausedByInterruption = false;
  }
}

final playbackAutomationProvider = Provider<PlaybackAutomation>((ref) {
  final automation = PlaybackAutomation(ref)..start();
  ref.listen(playbackProvider.select((s) => s.isPlaying), (_, playing) => automation.onPlayingChanged(playing));
  return automation;
});
