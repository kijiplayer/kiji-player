// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/equalizer/data/equalizer_engine.dart';
import 'package:kiji_player/features/equalizer/data/equalizer_notifier.dart';
import 'package:kiji_player/features/equalizer/domain/equalizer_model.dart';
import 'package:kiji_player/features/equalizer/presentation/equalizer_screen.dart';

/// Ecualizador falso: anota lo que se le pide.
class _FakeEngine implements EqualizerEngine {
  static const centers = [60.0, 230.0, 910.0, 3600.0, 14000.0];
  bool enabled = false;
  List<double>? gains;

  @override
  bool get isSupported => true;
  @override
  Future<EqBands?> bands() async => const EqBands(centers: centers, minDb: -15, maxDb: 15);
  @override
  Future<void> setEnabled(bool value) async => enabled = value;
  @override
  Future<void> setGains(List<double> value) async => gains = value;
}

class _FakeMonitor extends AudioOutputMonitor {
  _FakeMonitor(this.output);
  AudioOutputKind output;
  final controller = StreamController<AudioOutputKind>.broadcast();

  void plug(AudioOutputKind kind) {
    output = kind;
    controller.add(kind);
  }

  @override
  Future<AudioOutputKind> current() async => output;
  @override
  Stream<AudioOutputKind> get changes => controller.stream;
}

// Deja correr los microtasks y futures pendientes (carga y aplicación).
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 50));

/// Espera a que se cumpla [done] (con la PC cargada, una espera fija puede quedarse corta).
Future<void> _until(bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!done() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  group('curva y presets', () {
    test('gainAt interpola en escala logarítmica y se queda en los extremos', () {
      const points = {100: 0.0, 1000: 10.0};
      expect(gainAt(points, 100), 0);
      expect(gainAt(points, 1000), 10);
      // 316 Hz está a mitad de camino entre 100 y 1000 en escala logarítmica.
      expect(gainAt(points, 316.2278), closeTo(5, 0.01));
      expect(gainAt(points, 20), 0);
      expect(gainAt(points, 20000), 10);
      expect(gainAt(const {}, 500), 0);
    });

    test('un preset se adapta a las bandas del teléfono y respeta su rango', () {
      const profile = EqProfile(presetId: 'bass');
      expect(profile.gainsFor([60, 230, 910, 3600, 14000]), [6, 4, 0, 0, 0]);
      // Un teléfono con 10 bandas recibe la curva interpolada.
      final ten = profile.gainsFor([31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]);
      expect(ten.first, 6);
      expect(ten[3], inInclusiveRange(0, 4));
      expect(ten.last, 0);
      // Un rango chico (±3 dB) recorta.
      expect(profile.gainsFor([60], min: -3, max: 3), [3]);
    });

    test('mover una banda pasa a Personalizado sin tocar las demás', () {
      const centers = [60.0, 230.0, 910.0, 3600.0, 14000.0];
      final edited = const EqProfile(presetId: 'rock').withBand(centers, 2, 6);
      expect(edited.presetId, EqProfile.custom);
      expect(edited.label, 'Personalizado');
      expect(edited.gainsFor(centers), [5, 3, 6, 3, 5]);
    });

    test('los ajustes se guardan y se leen igual; un archivo raro vuelve a lo de fábrica', () {
      final settings = const EqualizerSettings(enabled: true, perDevice: true).copyWith(byOutput: {
        AudioOutputKind.headphones: const EqProfile(presetId: 'bass'),
        AudioOutputKind.bluetooth: const EqProfile(presetId: EqProfile.custom, points: {60: 2, 14000: -1}),
      });
      final back = EqualizerSettings.fromJson(settings.toJson());
      expect(back.enabled, isTrue);
      expect(back.perDevice, isTrue);
      expect(back.profileFor(AudioOutputKind.headphones).presetId, 'bass');
      expect(back.profileFor(AudioOutputKind.bluetooth).points, {60: 2, 14000: -1});
      expect(back.profileFor(AudioOutputKind.speaker).presetId, 'flat');

      final weird = EqualizerSettings.fromJson({
        'enabled': 'sí',
        'general': {'preset': 'no-existe'},
        'byOutput': {'bluetooth': 7},
      });
      expect(weird.enabled, isFalse);
      expect(weird.general.presetId, 'flat');
      expect(const EqualizerSettings().enabled, isFalse, reason: 'apagado de fábrica');
    });

    test('la salida se deduce de los dispositivos conectados', () {
      expect(outputKindFrom([AudioDeviceType.builtInSpeaker]), AudioOutputKind.speaker);
      expect(outputKindFrom([AudioDeviceType.builtInSpeaker, AudioDeviceType.bluetoothA2dp]),
          AudioOutputKind.bluetooth);
      expect(outputKindFrom([AudioDeviceType.wiredHeadphones]), AudioOutputKind.headphones);
      // El cable gana sobre el Bluetooth, como en Android.
      expect(outputKindFrom([AudioDeviceType.bluetoothA2dp, AudioDeviceType.wiredHeadset]),
          AudioOutputKind.headphones);
    });
  });

  group('EqualizerNotifier', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('kiji_eq_'));
    tearDown(() async {
      await _settle();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    ProviderContainer container(_FakeEngine engine, _FakeMonitor monitor) {
      final c = ProviderContainer(overrides: [
        equalizerEngineProvider.overrideWithValue(engine),
        audioOutputMonitorProvider.overrideWithValue(monitor),
        equalizerProvider.overrideWith(() => EqualizerNotifier(directory: () async => dir)),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('apagado de fábrica: no cambia el sonido', () async {
      final engine = _FakeEngine();
      final c = container(engine, _FakeMonitor(AudioOutputKind.speaker));
      c.read(equalizerProvider);
      await _settle();
      expect(engine.enabled, isFalse);
      expect(engine.gains, [0, 0, 0, 0, 0]);
    });

    test('perfil por dispositivo: cambia solo al conectar los auriculares y se recuerda', () async {
      final engine = _FakeEngine();
      final monitor = _FakeMonitor(AudioOutputKind.speaker);
      final c = container(engine, monitor);
      final eq = c.read(equalizerProvider.notifier);
      c.read(equalizerProvider);
      await _settle();

      await eq.setEnabled(true);
      await eq.selectPreset(AudioOutputKind.speaker, 'vocal');
      expect(engine.enabled, isTrue);
      expect(engine.gains, [-2, -1, 3, 4, 1]);

      // Al activar el perfil por dispositivo, cada salida arranca igual que
      // el general: el sonido no cambia de golpe.
      await eq.setPerDevice(true);
      expect(engine.gains, [-2, -1, 3, 4, 1]);
      await eq.selectPreset(AudioOutputKind.headphones, 'bass');
      expect(engine.gains, [-2, -1, 3, 4, 1], reason: 'suena el parlante, no los auriculares');

      monitor.plug(AudioOutputKind.headphones);
      await _until(() => c.read(equalizerProvider).output == AudioOutputKind.headphones && engine.gains?.first == 6);
      expect(c.read(equalizerProvider).output, AudioOutputKind.headphones);
      expect(engine.gains, [6, 4, 0, 0, 0]);

      monitor.plug(AudioOutputKind.speaker);
      await _until(() => engine.gains?.first == -2);
      expect(engine.gains, [-2, -1, 3, 4, 1]);

      // Otra sesión lee lo mismo del disco.
      final engine2 = _FakeEngine();
      final c2 = container(engine2, _FakeMonitor(AudioOutputKind.headphones));
      c2.read(equalizerProvider);
      await c2.read(equalizerProvider.notifier).loaded;
      await _until(() => engine2.gains?.first == 6);
      expect(c2.read(equalizerProvider).settings.perDevice, isTrue);
      expect(engine2.enabled, isTrue);
      expect(engine2.gains, [6, 4, 0, 0, 0]);
    });

    test('mover una banda guarda un perfil personalizado', () async {
      final engine = _FakeEngine();
      final c = container(engine, _FakeMonitor(AudioOutputKind.speaker));
      c.read(equalizerProvider);
      await _settle();
      await c.read(equalizerProvider.notifier).setBand(AudioOutputKind.speaker, 4, -4.5);
      final state = c.read(equalizerProvider);
      expect(state.activeProfile.presetId, EqProfile.custom);
      expect(engine.gains, [0, 0, 0, 0, -4.5]);
    });
  });

  testWidgets('la pantalla elige un preset y muestra las bandas', (tester) async {
    Future<Directory> noDisk() async => throw const FileSystemException('sin disco en el test');
    final engine = _FakeEngine();
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        equalizerEngineProvider.overrideWithValue(engine),
        audioOutputMonitorProvider.overrideWithValue(const FixedOutputMonitor()),
        equalizerProvider.overrideWith(() => EqualizerNotifier(directory: noDisk)),
      ],
      child: const MaterialApp(home: EqualizerScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Apagado: el sonido no cambia.'), findsOneWidget);
    expect(find.text('14k'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(5));

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rock'));
    await tester.pumpAndSettle();
    expect(find.text('Encendido: Rock'), findsOneWidget);
    expect(engine.enabled, isTrue);
    expect(engine.gains, [5, 3, -1, 3, 5]);
    expect(find.text('+5.0'), findsNWidgets(2));
  });
}
