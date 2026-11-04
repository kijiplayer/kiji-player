import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../utils/json_file.dart';
import '../domain/equalizer_model.dart';
import 'equalizer_engine.dart';

class EqualizerState {
  const EqualizerState({
    this.settings = const EqualizerSettings(),
    this.output = AudioOutputKind.speaker,
    this.bands,
    this.supported = true,
    this.capabilities = const SoundCapabilities(),
  });

  final EqualizerSettings settings;

  /// Salida de audio activa ahora.
  final AudioOutputKind output;

  /// Bandas del dispositivo; `null` hasta que el reproductor cargó algo (Android).
  final EqBands? bands;
  final bool supported;

  /// Qué efectos hay aquí (lo que no hay, no se muestra).
  final SoundCapabilities capabilities;

  EqProfile get activeProfile => settings.profileFor(output);

  EqualizerState copyWith({
    EqualizerSettings? settings,
    AudioOutputKind? output,
    EqBands? bands,
    SoundCapabilities? capabilities,
  }) => EqualizerState(
    settings: settings ?? this.settings,
    output: output ?? this.output,
    bands: bands ?? this.bands,
    supported: supported,
    capabilities: capabilities ?? this.capabilities,
  );
}

/// "Sonido": ajustes en `<appSupportDir>/equalizer.json`. Aplica el perfil de la salida activa
/// (y lo cambia solo al conectar o desconectar auriculares), los bajos y la reverb. La velocidad
/// y el tono los aplica el reproductor ([EqualizerSettings.playbackRate]).
class EqualizerNotifier extends Notifier<EqualizerState> {
  EqualizerNotifier({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;
  JsonFile? _file;
  late SoundEngine _engine;
  final Completer<void> _loaded = Completer();

  /// Se completa cuando ya se leyó el archivo y la salida actual.
  Future<void> get loaded => _loaded.future;

  Future<JsonFile> _jsonFile() async =>
      _file ??= JsonFile(p.join((await _directory()).path, 'equalizer.json'), logTag: 'ECUALIZADOR');

  @override
  EqualizerState build() {
    _engine = ref.watch(equalizerEngineProvider);
    final monitor = ref.watch(audioOutputMonitorProvider);
    final subscription = monitor.changes.listen(
      _onOutputChanged,
      onError: (Object error) => debugPrint('=== ECUALIZADOR: error al seguir la salida: $error ==='),
    );
    ref.onDispose(subscription.cancel);
    unawaited(Future.microtask(() => _load(monitor)));
    unawaited(_waitForBands());
    unawaited(_readCapabilities());
    return EqualizerState(supported: _engine.isSupported);
  }

  Future<void> _load(AudioOutputMonitor monitor) async {
    try {
      final json = await (await _jsonFile()).read();
      if (json is Map<String, dynamic>) {
        state = state.copyWith(settings: EqualizerSettings.fromJson(json));
      }
    } catch (error) {
      debugPrint('=== ECUALIZADOR: no se pudieron leer los ajustes (queda apagado): $error ===');
    }
    state = state.copyWith(output: await monitor.current());
    if (!_loaded.isCompleted) _loaded.complete();
    await _apply();
  }

  Future<void> _waitForBands() async {
    try {
      final bands = await _engine.bands();
      if (bands != null) {
        state = state.copyWith(bands: bands);
        await _apply();
      }
    } catch (error) {
      debugPrint('=== ECUALIZADOR: no se pudieron leer las bandas: $error ===');
    }
  }

  Future<void> _readCapabilities() async {
    try {
      // Primero se espera: leer `state` antes (todavía en build) falla.
      final capabilities = await _engine.capabilities();
      state = state.copyWith(capabilities: capabilities);
      await _apply();
    } catch (error) {
      debugPrint('=== SONIDO: no se pudo saber qué efectos hay: $error ===');
    }
  }

  void _onOutputChanged(AudioOutputKind output) {
    if (output == state.output) return;
    debugPrint('=== ECUALIZADOR: salida ${state.output.name} -> ${output.name} ===');
    state = state.copyWith(output: output);
    unawaited(_apply());
  }

  Future<void>? _applyRun;
  bool _applyAgain = false;

  /// Lleva los efectos del sistema a lo elegido. Si llegan cambios mientras se aplica (un
  /// control que se arrastra), se juntan: al terminar se aplica una vez más, lo último. Quien
  /// espera, espera a que suene lo último que pidió.
  Future<void> _apply() {
    if (!_engine.isSupported) return Future.value();
    final running = _applyRun;
    if (running != null) {
      _applyAgain = true;
      return running;
    }
    return _applyRun = _applyLoop().whenComplete(() => _applyRun = null);
  }

  Future<void> _applyLoop() async {
    try {
      do {
        _applyAgain = false;
        final settings = state.settings;
        final bands = state.bands;
        final caps = state.capabilities;
        await _engine.apply(
          SoundMix(
            enabled: settings.enabled,
            gains: bands == null
                ? const []
                : state.activeProfile.gainsFor(bands.centers, min: bands.minDb, max: bands.maxDb),
            bass: caps.bass ? settings.bass : 0,
            reverb: caps.reverb ? settings.reverb : ReverbMode.off,
          ),
        );
      } while (_applyAgain);
    } catch (error) {
      debugPrint('=== ECUALIZADOR: no se pudo aplicar el perfil: $error ===');
    }
  }

  /// [persist]: false mientras se arrastra un control (se guarda al soltar).
  Future<void> _change(EqualizerSettings settings, {bool persist = true}) async {
    state = state.copyWith(settings: settings);
    await _apply();
    if (!persist) return;
    try {
      await (await _jsonFile()).write(settings.toJson());
    } catch (error) {
      debugPrint('=== ECUALIZADOR: no se pudieron guardar los ajustes: $error ===');
    }
  }

  /// Tocar un control enciende los efectos: si no, no se oiría el cambio.
  Future<void> _edit(EqualizerSettings settings, {bool persist = true}) =>
      _change(settings.copyWith(enabled: true), persist: persist);

  Future<void> setEnabled(bool enabled) => _change(state.settings.copyWith(enabled: enabled));

  /// Al activar "un perfil por dispositivo", cada salida arranca con el
  /// perfil general (nada cambia de golpe).
  Future<void> setPerDevice(bool perDevice) {
    final s = state.settings;
    final byOutput = perDevice
        ? {for (final kind in AudioOutputKind.values) kind: s.byOutput[kind] ?? s.general}
        : s.byOutput;
    return _change(s.copyWith(perDevice: perDevice, byOutput: byOutput));
  }

  /// Elige un preset de fábrica o uno propio para [output] (o para el perfil general).
  Future<void> selectPreset(AudioOutputKind output, String presetId) {
    final user = state.settings.userPresets.where((p) => p.profileId == presetId).firstOrNull;
    final profile = user == null
        ? EqProfile(presetId: presetId)
        : EqProfile(presetId: user.profileId, points: user.points, name: user.name);
    return _edit(state.settings.withProfile(output, profile));
  }

  /// Mueve una banda a mano: el perfil pasa a "Personalizado".
  Future<void> setBand(AudioOutputKind output, int index, double db, {bool persist = true}) async {
    final bands = state.bands;
    if (bands == null) return;
    final profile = state.settings.profileFor(output).withBand(bands.centers, index, db);
    await _edit(state.settings.withProfile(output, profile), persist: persist);
  }

  /// Guarda la curva que suena en [output] como preset propio y lo deja elegido.
  Future<void> saveUserPreset(AudioOutputKind output, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final s = state.settings;
    final bands = state.bands;
    final profile = s.profileFor(output);
    // La curva tal como suena en las bandas de este dispositivo.
    final points = bands == null
        ? profile.curve
        : {for (final (i, g) in profile.gainsFor(bands.centers).indexed) bands.centers[i].round(): g};
    final preset = EqUserPreset(id: '${DateTime.now().microsecondsSinceEpoch}', name: trimmed, points: points);
    final next = s.copyWith(userPresets: [...s.userPresets, preset]);
    await _edit(
      next.withProfile(output, EqProfile(presetId: preset.profileId, points: preset.points, name: preset.name)),
    );
  }

  Future<void> renameUserPreset(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final s = state.settings;
    final presets = [for (final p in s.userPresets) p.id == id ? p.copyWith(name: trimmed) : p];
    final profileId = '${EqProfile.userPrefix}$id';
    await _change(
      s
          .copyWith(userPresets: presets)
          .mapProfiles((profile) => profile.presetId == profileId
              ? EqProfile(presetId: profileId, points: profile.points, name: trimmed)
              : profile),
    );
  }

  /// Borra un preset propio. Los perfiles que lo usaban quedan como Personalizado con la misma
  /// curva: lo que suena no cambia.
  Future<void> deleteUserPreset(String id) async {
    final s = state.settings;
    final profileId = '${EqProfile.userPrefix}$id';
    await _change(
      s
          .copyWith(userPresets: [for (final p in s.userPresets) if (p.id != id) p])
          .mapProfiles((profile) => profile.presetId == profileId
              ? EqProfile(presetId: EqProfile.custom, points: profile.points)
              : profile),
    );
  }

  Future<void> setBass(double strength, {bool persist = true}) =>
      _edit(state.settings.copyWith(bass: strength.clamp(0, 1)), persist: persist);

  Future<void> setReverb(ReverbMode mode) => _edit(state.settings.copyWith(reverb: mode));

  Future<void> setSpeed(double speed, {bool persist = true}) => _edit(
    state.settings.copyWith(speed: double.parse(speed.clamp(minSpeed, maxSpeed).toStringAsFixed(2))),
    persist: persist,
  );

  Future<void> setSemitones(int semitones) =>
      _edit(state.settings.copyWith(semitones: semitones.clamp(-maxSemitones, maxSemitones)));

  Future<void> resetSpeedPitch() => _change(state.settings.copyWith(speed: 1, semitones: 0));

  Future<void> setKeepSpeedPitch(bool keep) => _change(state.settings.copyWith(keepSpeedPitch: keep));

  /// Empezó otra canción: sin "Mantener entre canciones", la velocidad y el tono vuelven a lo normal.
  Future<void> trackChanged() async {
    final s = state.settings;
    if (s.keepSpeedPitch || s.speedPitchNormal) return;
    debugPrint('=== SONIDO: otra canción; velocidad y tono vuelven a lo normal ===');
    await _change(s.copyWith(speed: 1, semitones: 0), persist: false);
  }

  /// La sesión de audio del reproductor (Android): ahí se enganchan los bajos y la reverb.
  void audioSessionChanged(int? id) => _engine.setAudioSession(id);
}

final equalizerProvider = NotifierProvider<EqualizerNotifier, EqualizerState>(EqualizerNotifier.new);
