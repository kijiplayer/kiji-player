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
  });

  final EqualizerSettings settings;

  /// Salida de audio activa ahora.
  final AudioOutputKind output;

  /// Bandas del teléfono; `null` hasta que el reproductor cargó algo.
  final EqBands? bands;
  final bool supported;

  EqProfile get activeProfile => settings.profileFor(output);

  EqualizerState copyWith({EqualizerSettings? settings, AudioOutputKind? output, EqBands? bands}) => EqualizerState(
    settings: settings ?? this.settings,
    output: output ?? this.output,
    bands: bands ?? this.bands,
    supported: supported,
  );
}

/// Ajustes en `<appSupportDir>/equalizer.json`. Aplica el perfil de la salida
/// activa y lo cambia solo cuando se conectan o desconectan auriculares.
class EqualizerNotifier extends Notifier<EqualizerState> {
  EqualizerNotifier({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;
  JsonFile? _file;
  late EqualizerEngine _engine;
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

  void _onOutputChanged(AudioOutputKind output) {
    if (output == state.output) return;
    debugPrint('=== ECUALIZADOR: salida ${state.output.name} -> ${output.name} ===');
    state = state.copyWith(output: output);
    unawaited(_apply());
  }

  /// Lleva el ecualizador del sistema al perfil activo.
  Future<void> _apply() async {
    if (!_engine.isSupported) return;
    try {
      final settings = state.settings;
      await _engine.setEnabled(settings.enabled);
      final bands = state.bands;
      if (bands == null) return; // se aplica cuando lleguen las bandas
      await _engine.setGains(state.activeProfile.gainsFor(bands.centers, min: bands.minDb, max: bands.maxDb));
    } catch (error) {
      debugPrint('=== ECUALIZADOR: no se pudo aplicar el perfil: $error ===');
    }
  }

  Future<void> _change(EqualizerSettings settings) async {
    state = state.copyWith(settings: settings);
    await _apply();
    try {
      await (await _jsonFile()).write(settings.toJson());
    } catch (error) {
      debugPrint('=== ECUALIZADOR: no se pudieron guardar los ajustes: $error ===');
    }
  }

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

  /// Elige un preset para [output] (o para el perfil general).
  Future<void> selectPreset(AudioOutputKind output, String presetId) =>
      _change(state.settings.withProfile(output, EqProfile(presetId: presetId)));

  /// Mueve una banda a mano: el perfil pasa a "Personalizado".
  Future<void> setBand(AudioOutputKind output, int index, double db) async {
    final bands = state.bands;
    if (bands == null) return;
    final profile = state.settings.profileFor(output).withBand(bands.centers, index, db);
    await _change(state.settings.withProfile(output, profile));
  }
}

final equalizerProvider = NotifierProvider<EqualizerNotifier, EqualizerState>(EqualizerNotifier.new);
