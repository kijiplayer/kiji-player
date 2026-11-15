import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/equalizer/data/equalizer_engine.dart';
import 'package:kiji_player/features/equalizer/data/equalizer_notifier.dart';
import 'package:kiji_player/features/equalizer/domain/equalizer_model.dart';

/// 0.8.2: si Android no puede crear el ecualizador (el sistema se quedó sin efectos), la música
/// tiene que sonar igual. Antes el ecualizador iba en el AudioPipeline de just_audio y cada carga
/// fallaba con `getNumberOfBands()` sobre null hasta reiniciar la app.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('kiji/sound');
  final calls = <MethodCall>[];

  void nativeAnswers(Object? Function(MethodCall call) answer) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return answer(call);
    });
  }

  setUp(calls.clear);
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

  const mix = SoundMix(enabled: true, gains: [3, 0, -2, 0, 4], bass: 0.5, reverb: ReverbMode.room);

  test('Sin ecualizador (Android no lo pudo crear): avisa una vez, no tira error y aplica lo demás', () async {
    nativeAnswers((call) => switch (call.method) {
      'bands' => null,
      'apply' => {'eq': false, 'bass': true, 'reverb': true},
      _ => null,
    });
    final engine = AndroidSoundEngine();
    final seen = <bool>[];
    final sub = engine.availability.listen(seen.add);
    engine.setAudioSession(42);
    await engine.apply(mix);
    await engine.apply(mix);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(seen, [false], reason: 'un solo aviso, no uno por canción');
    final apply = calls.lastWhere((c) => c.method == 'apply');
    expect(apply.arguments['session'], 42);
    expect(apply.arguments['gains'], [3, 0, -2, 0, 4]);
    await sub.cancel();
    await engine.dispose();
  });

  test('El canal nativo falla del todo: ni apply ni la sesión tiran error', () async {
    nativeAnswers((call) => throw PlatformException(code: 'NullPointerException', message: 'Equalizer null'));
    final engine = AndroidSoundEngine();
    engine.setAudioSession(7);
    await expectLater(engine.apply(mix), completes);
    engine.setAudioSession(8);
    await expectLater(engine.apply(mix), completes);
    await expectLater(engine.capabilities(), completion(isA<SoundCapabilities>()));
    await engine.dispose();
  });

  test('Un solo juego de efectos: al perder la sesión se sueltan; con bandas, el ecualizador vuelve', () async {
    var eqOk = false;
    nativeAnswers((call) => switch (call.method) {
      'bands' => eqOk ? {'centers': [60.0, 230.0, 910.0, 3600.0, 14000.0], 'minDb': -15.0, 'maxDb': 15.0} : null,
      'apply' => {'eq': eqOk, 'bass': true, 'reverb': true},
      _ => null,
    });
    final engine = AndroidSoundEngine();
    final seen = <bool>[];
    final sub = engine.availability.listen(seen.add);
    engine.setAudioSession(1);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    engine.setAudioSession(null);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(calls.where((c) => c.method == 'release'), hasLength(1));
    // Otra sesión: Android ya tiene efectos libres.
    eqOk = true;
    engine.setAudioSession(2);
    final bands = await engine.bands().timeout(const Duration(seconds: 2));
    expect(bands!.centers, hasLength(5));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(seen, [false, true]);
    await sub.cancel();
    await engine.dispose();
  });

  test('Sonido marca "no disponible" sin romper los ajustes', () async {
    final engine = _UnavailableEngine();
    addTearDown(engine.controller.close);
    final dir = Directory.systemTemp.createTempSync('kiji_eq_na_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final c = ProviderContainer(overrides: [
      equalizerEngineProvider.overrideWithValue(engine),
      audioOutputMonitorProvider.overrideWithValue(const FixedOutputMonitor()),
      equalizerProvider.overrideWith(() => EqualizerNotifier(directory: () async => dir)),
    ]);
    addTearDown(c.dispose);
    c.read(equalizerProvider);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    engine.controller.add(false);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.read(equalizerProvider).equalizerUnavailable, isTrue);
    engine.controller.add(true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.read(equalizerProvider).equalizerUnavailable, isFalse);
  });

  test('El reproductor principal no lleva efectos en el AudioPipeline (la carga no depende de ellos)', () {
    final source = File('lib/providers/playback_provider.dart').readAsStringSync();
    expect(source.contains('AudioPipeline('), isFalse);
    expect(source.contains('androidAudioEffects'), isFalse);
  });
}

class _UnavailableEngine extends SoundEngine {
  final controller = StreamController<bool>.broadcast();
  @override
  bool get isSupported => true;
  @override
  Future<EqBands?> bands() => Completer<EqBands?>().future;
  @override
  Future<SoundCapabilities> capabilities() async => const SoundCapabilities();
  @override
  Future<void> apply(SoundMix mix) async {}
  @override
  Stream<bool> get availability => controller.stream;
}
