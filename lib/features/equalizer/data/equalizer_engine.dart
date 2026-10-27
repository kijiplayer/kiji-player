// audio_session marca la lista de dispositivos como "experimental": la usamos
// solo aquí, detrás de [AudioOutputMonitor], para poder cambiarla sin tocar el resto.
// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../domain/equalizer_model.dart';

/// Las bandas reales del teléfono.
class EqBands {
  const EqBands({required this.centers, required this.minDb, required this.maxDb});
  final List<double> centers;
  final double minDb;
  final double maxDb;
}

/// El ecualizador del sistema, detrás de una interfaz: en
/// Android es el `AndroidEqualizer` de just_audio; en PC todavía no hay.
abstract class EqualizerEngine {
  bool get isSupported;

  /// Se completa cuando el reproductor ya cargó algo (antes, Android no
  /// informa las bandas). `null` si no hay ecualizador.
  Future<EqBands?> bands();

  Future<void> setEnabled(bool enabled);
  Future<void> setGains(List<double> gains);
}

class AndroidEqualizerEngine implements EqualizerEngine {
  AndroidEqualizerEngine(this.effect);
  final AndroidEqualizer effect;

  @override
  bool get isSupported => true;

  @override
  Future<EqBands?> bands() async {
    final parameters = await effect.parameters;
    return EqBands(
      centers: [for (final band in parameters.bands) band.centerFrequency],
      minDb: parameters.minDecibels,
      maxDb: parameters.maxDecibels,
    );
  }

  @override
  Future<void> setEnabled(bool enabled) => effect.setEnabled(enabled);

  @override
  Future<void> setGains(List<double> gains) async {
    final parameters = await effect.parameters;
    for (var i = 0; i < parameters.bands.length && i < gains.length; i++) {
      await parameters.bands[i].setGain(gains[i]);
    }
  }
}

class UnsupportedEqualizerEngine implements EqualizerEngine {
  const UnsupportedEqualizerEngine();
  @override
  bool get isSupported => false;
  @override
  Future<EqBands?> bands() async => null;
  @override
  Future<void> setEnabled(bool enabled) async {}
  @override
  Future<void> setGains(List<double> gains) async {}
}

/// El efecto que se conecta al reproductor (solo Android). Uno solo por app:
/// just_audio no deja usar el mismo efecto en dos reproductores.
final androidEqualizerProvider = Provider<AndroidEqualizer?>(
  (ref) => !kIsWeb && Platform.isAndroid ? AndroidEqualizer() : null,
);

final equalizerEngineProvider = Provider<EqualizerEngine>((ref) {
  final effect = ref.watch(androidEqualizerProvider);
  return effect == null ? const UnsupportedEqualizerEngine() : AndroidEqualizerEngine(effect);
});

/// Qué salida de audio está activa, a partir de los dispositivos conectados.
/// El cable gana sobre el Bluetooth (Android también lo prioriza así).
AudioOutputKind outputKindFrom(Iterable<AudioDeviceType> outputs) {
  const wired = {
    AudioDeviceType.wiredHeadset,
    AudioDeviceType.wiredHeadphones,
    AudioDeviceType.usbAudio,
    AudioDeviceType.lineAnalog,
  };
  const bluetooth = {
    AudioDeviceType.bluetoothA2dp,
    AudioDeviceType.bluetoothSco,
    AudioDeviceType.bluetoothLe,
    AudioDeviceType.hearingAid,
  };
  if (outputs.any(wired.contains)) return AudioOutputKind.headphones;
  if (outputs.any(bluetooth.contains)) return AudioOutputKind.bluetooth;
  return AudioOutputKind.speaker;
}

/// Salida de audio actual y sus cambios.
abstract class AudioOutputMonitor {
  const AudioOutputMonitor();
  Future<AudioOutputKind> current();
  Stream<AudioOutputKind> get changes;

  /// Android avisa que el audio va a salir por el parlante (se desconectó el Bluetooth o los audífonos).
  Stream<void> get becomingNoisy => const Stream.empty();

  /// Otra app tomó o devolvió el audio (llamada, alarma, asistente…).
  Stream<AudioInterruptionEvent> get interruptions => const Stream.empty();
}

class AudioSessionOutputMonitor extends AudioOutputMonitor {
  @override
  Future<AudioOutputKind> current() async {
    try {
      final session = await AudioSession.instance;
      final devices = await session.getDevices(includeInputs: false);
      return outputKindFrom(devices.map((device) => device.type));
    } catch (error) {
      debugPrint('=== ECUALIZADOR: no se pudo leer la salida de audio: $error ===');
      return AudioOutputKind.speaker;
    }
  }

  @override
  Stream<AudioOutputKind> get changes async* {
    final session = await AudioSession.instance;
    await for (final _ in session.devicesChangedEventStream) {
      yield await current();
    }
  }

  @override
  Stream<void> get becomingNoisy async* {
    yield* (await AudioSession.instance).becomingNoisyEventStream;
  }

  @override
  Stream<AudioInterruptionEvent> get interruptions async* {
    yield* (await AudioSession.instance).interruptionEventStream;
  }
}

class FixedOutputMonitor extends AudioOutputMonitor {
  const FixedOutputMonitor([this.kind = AudioOutputKind.speaker]);
  final AudioOutputKind kind;
  @override
  Future<AudioOutputKind> current() async => kind;
  @override
  Stream<AudioOutputKind> get changes => const Stream.empty();
}

final audioOutputMonitorProvider = Provider<AudioOutputMonitor>(
  (ref) => !kIsWeb && Platform.isAndroid ? AudioSessionOutputMonitor() : const FixedOutputMonitor(),
);
