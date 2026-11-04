// audio_session marca la lista de dispositivos como "experimental": la usamos
// solo aquí, detrás de [AudioOutputMonitor], para poder cambiarla sin tocar el resto.
// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import '../domain/equalizer_model.dart';

/// Android: el ecualizador del sistema (`AndroidEqualizer` de just_audio, con las bandas que dé
/// el teléfono) y, por un canal propio, BassBoost y PresetReverb sobre la misma sesión de audio
/// (`SoundEffects.kt`). Lo que el teléfono no tenga no se muestra.
class AndroidSoundEngine extends SoundEngine {
  AndroidSoundEngine(this.effect, {MethodChannel? channel}) : _channel = channel ?? const MethodChannel('kiji/sound');

  final AndroidEqualizer effect;
  final MethodChannel _channel;
  int? _session;
  SoundMix? _last;

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
  Future<SoundCapabilities> capabilities() async {
    try {
      final found = await _channel.invokeMapMethod<String, bool>('capabilities') ?? const {};
      return SoundCapabilities(bass: found['bass'] ?? false, reverb: found['reverb'] ?? false);
    } catch (error) {
      debugPrint('=== SONIDO: no se pudo saber qué efectos tiene el teléfono: $error ===');
      return const SoundCapabilities();
    }
  }

  @override
  void setAudioSession(int? id) {
    if (id == _session) return;
    _session = id;
    final last = _last;
    if (last != null) unawaited(_applyNative(last));
  }

  @override
  Future<void> apply(SoundMix mix) async {
    _last = mix;
    await effect.setEnabled(mix.enabled);
    final parameters = await effect.parameters;
    for (var i = 0; i < parameters.bands.length && i < mix.gains.length; i++) {
      await parameters.bands[i].setGain(mix.gains[i]);
    }
    await _applyNative(mix);
  }

  Future<void> _applyNative(SoundMix mix) async {
    final session = _session;
    if (session == null) return; // se aplica cuando el reproductor tenga sesión
    try {
      await _channel.invokeMethod<void>('apply', {
        'session': session,
        'enabled': mix.enabled,
        'bass': mix.bass,
        'reverb': mix.reverb.index,
      });
    } catch (error) {
      debugPrint('=== SONIDO: no se pudieron aplicar bajos/reverb: $error ===');
    }
  }
}

/// La cadena de filtros de mpv para [mix] (null: sin filtros, el audio sale tal cual). Una
/// `equalizer` (pico de una octava) por banda que no esté en 0, y el refuerzo de bajos como una
/// más, ancha, en 70 Hz. En la libavfilter de Windows no hay otros filtros de audio (ni reverb).
String? mpvEffects(SoundMix mix, List<double> centers) {
  if (!mix.enabled) return null;
  String db(double value) => value.toStringAsFixed(1);
  final filters = [
    for (var i = 0; i < centers.length && i < mix.gains.length; i++)
      if (mix.gains[i] != 0) 'equalizer=f=${centers[i].round()}:t=o:w=1:g=${db(mix.gains[i])}',
    if (mix.bass > 0) 'equalizer=f=70:t=o:w=2:g=${db(mix.bass * maxBassDb)}',
  ];
  return filters.isEmpty ? null : filters.join(',');
}

/// Refuerzo de bajos al máximo, en dB (PC).
const maxBassDb = 10.0;

/// PC (Windows y Linux): filtros de mpv por el plugin local just_audio_media_kit, en todos los
/// reproductores (también el de la mezcla). 10 bandas y bajos; sin reverb.
class MpvSoundEngine extends SoundEngine {
  MpvSoundEngine({Future<void> Function(String? effects)? setEffects})
    : _setEffects = setEffects ?? JustAudioMediaKit.setAudioEffects;

  final Future<void> Function(String? effects) _setEffects;

  static const _bands = EqBands(centers: tenBands, minDb: -12, maxDb: 12);

  @override
  bool get isSupported => true;

  @override
  Future<EqBands?> bands() async => _bands;

  @override
  Future<SoundCapabilities> capabilities() async => const SoundCapabilities(bass: true);

  @override
  Future<void> apply(SoundMix mix) => _setEffects(mpvEffects(mix, _bands.centers));
}

class UnsupportedSoundEngine extends SoundEngine {
  UnsupportedSoundEngine();
  @override
  bool get isSupported => false;
  @override
  Future<EqBands?> bands() async => null;
  @override
  Future<SoundCapabilities> capabilities() async => const SoundCapabilities();
  @override
  Future<void> apply(SoundMix mix) async {}
}

/// El efecto que se conecta al reproductor (solo Android). Uno solo por app:
/// just_audio no deja usar el mismo efecto en dos reproductores.
final androidEqualizerProvider = Provider<AndroidEqualizer?>(
  (ref) => !kIsWeb && Platform.isAndroid ? AndroidEqualizer() : null,
);

final equalizerEngineProvider = Provider<SoundEngine>((ref) {
  final effect = ref.watch(androidEqualizerProvider);
  if (effect != null) return AndroidSoundEngine(effect);
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) return MpvSoundEngine();
  return UnsupportedSoundEngine();
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
