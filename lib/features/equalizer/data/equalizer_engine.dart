// audio_session marca la lista de dispositivos como "experimental": la usamos
// solo aquí, detrás de [AudioOutputMonitor], para poder cambiarla sin tocar el resto.
// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import '../domain/equalizer_model.dart';

/// Android: el ecualizador, BassBoost y PresetReverb del sistema, por un canal propio
/// (`SoundEffects.kt`), enganchados a la sesión de audio del reproductor. Lo que el teléfono no
/// tenga no se muestra.
///
/// 0.8.2: el ecualizador ya no va en el `AudioPipeline` de just_audio. Ahí se creaba al cargar
/// cada canción y, si Android no podía crearlo (límite de efectos del sistema), la carga fallaba
/// (`getNumberOfBands()` sobre null) y ninguna canción sonaba hasta reiniciar la app. Ahora un
/// efecto que no se crea no toca la carga: la música suena igual, sin ecualizador.
class AndroidSoundEngine extends SoundEngine {
  AndroidSoundEngine({MethodChannel? channel}) : _channel = channel ?? const MethodChannel('kiji/sound');

  final MethodChannel _channel;
  int? _session;
  SoundMix? _last;
  final _bands = Completer<EqBands>();
  bool _readingBands = false;
  bool? _available;
  final _availability = StreamController<bool>.broadcast();

  @override
  bool get isSupported => true;

  /// Las bandas del ecualizador del teléfono: llegan cuando el reproductor tiene sesión y Android
  /// pudo crear el ecualizador (si no, se vuelve a intentar con la próxima sesión).
  @override
  Future<EqBands?> bands() => _bands.future;

  @override
  Stream<bool> get availability => _availability.stream;

  void _setAvailable(bool ok) {
    if (_available == ok) return;
    _available = ok;
    debugPrint(ok ? '=== SONIDO: ecualizador disponible ===' : '=== SONIDO: el ecualizador no está disponible ahora; la música suena sin él ===');
    _availability.add(ok);
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
    if (id == null || id == 0) {
      unawaited(_release());
      return;
    }
    unawaited(_readBands());
    final last = _last;
    if (last != null) unawaited(_applyNative(last));
  }

  Future<void> _readBands() async {
    final session = _session;
    if (_bands.isCompleted || _readingBands || session == null || session == 0) return;
    _readingBands = true;
    try {
      final found = await _channel.invokeMapMethod<String, Object?>('bands', {'session': session});
      if (found == null) {
        _setAvailable(false);
        return;
      }
      final centers = [for (final c in (found['centers'] as List? ?? const [])) (c as num).toDouble()];
      if (centers.isEmpty) {
        _setAvailable(false);
        return;
      }
      _bands.complete(EqBands(
        centers: centers,
        minDb: (found['minDb'] as num? ?? -15).toDouble(),
        maxDb: (found['maxDb'] as num? ?? 15).toDouble(),
      ));
      _setAvailable(true);
    } catch (error) {
      debugPrint('=== SONIDO: no se pudieron leer las bandas del ecualizador: $error ===');
      _setAvailable(false);
    } finally {
      _readingBands = false;
    }
  }

  Future<void> _release() async {
    try {
      await _channel.invokeMethod<void>('release');
    } catch (error) {
      debugPrint('=== SONIDO: no se pudieron soltar los efectos: $error ===');
    }
  }

  @override
  Future<void> apply(SoundMix mix) async {
    _last = mix;
    await _applyNative(mix);
  }

  Future<void> _applyNative(SoundMix mix) async {
    final session = _session;
    if (session == null || session == 0) return; // se aplica cuando el reproductor tenga sesión
    try {
      final result = await _channel.invokeMapMethod<String, bool>('apply', {
        'session': session,
        'enabled': mix.enabled,
        'gains': mix.gains,
        'bass': mix.bass,
        'reverb': mix.reverb.index,
      });
      final eq = result?['eq'];
      if (eq == false) _setAvailable(false);
      if (eq == true && !_bands.isCompleted) unawaited(_readBands());
      if (eq == true && _bands.isCompleted) _setAvailable(true);
    } catch (error) {
      debugPrint('=== SONIDO: no se pudieron aplicar los efectos: $error ===');
    }
  }

  @override
  Future<void> dispose() async {
    await _release();
    await _availability.close();
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

final equalizerEngineProvider = Provider<SoundEngine>((ref) {
  if (!kIsWeb && Platform.isAndroid) {
    final engine = AndroidSoundEngine();
    ref.onDispose(engine.dispose);
    return engine;
  }
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
