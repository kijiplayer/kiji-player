import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/equalizer/data/equalizer_engine.dart';
import 'package:kiji_player/features/equalizer/data/equalizer_notifier.dart';
import 'package:kiji_player/features/equalizer/domain/equalizer_model.dart';
import 'package:kiji_player/features/equalizer/presentation/sound_screen.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/theme/kiji_tokens.dart';

/// Motor falso: 10 bandas como en la PC, con lo que se le diga que hay.
class _Engine extends SoundEngine {
  _Engine(this.caps);
  final SoundCapabilities caps;
  SoundMix? last;

  @override
  bool get isSupported => true;
  @override
  Future<EqBands?> bands() async => const EqBands(centers: tenBands, minDb: -12, maxDb: 12);
  @override
  Future<SoundCapabilities> capabilities() async => caps;
  @override
  Future<void> apply(SoundMix mix) async => last = mix;
}

Future<Directory> _noDisk() async => throw const FileSystemException('sin disco en el test');

Future<ProviderContainer> _pump(WidgetTester tester, _Engine engine) async {
  tester.view.physicalSize = const Size(480, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      equalizerEngineProvider.overrideWithValue(engine),
      audioOutputMonitorProvider.overrideWithValue(const FixedOutputMonitor()),
      equalizerProvider.overrideWith(() => EqualizerNotifier(directory: _noDisk)),
      settingsProvider.overrideWith(() => SettingsNotifier(directory: _noDisk)),
    ],
    child: const MaterialApp(home: SoundScreen(perDeviceAvailable: false)),
  ));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(SoundScreen)));
}

void main() {
  testWidgets('Sonido: Efectos, 10 bandas, presets, bajos, velocidad y tono, reverb y mezcla', (tester) async {
    final engine = _Engine(const SoundCapabilities(bass: true, reverb: true));
    final c = await _pump(tester, engine);

    expect(find.text('Apagados: la música suena tal cual.'), findsOneWidget);
    expect(find.text('ECUALIZADOR · 10 BANDAS'), findsOneWidget);
    expect(find.text('16k'), findsOneWidget);
    for (final name in ['Normal', 'Bajos', 'Voz', 'Rock', 'Electrónica', 'Acústico', 'Noche']) {
      expect(find.widgetWithText(ChoiceChip, name), findsOneWidget, reason: name);
    }
    expect(find.text('REFUERZO DE BAJOS'), findsOneWidget);
    expect(find.text('REVERB'), findsOneWidget);
    expect(find.text('MEZCLA ENTRE CANCIONES'), findsOneWidget);

    // Tocar un preset enciende los efectos (si no, no se oiría).
    await tester.tap(find.widgetWithText(ChoiceChip, 'Rock'));
    await tester.pumpAndSettle();
    expect(find.text('Encendidos: Rock'), findsOneWidget);
    expect(engine.last?.enabled, isTrue);
    expect(engine.last?.gains, const EqProfile(presetId: 'rock').gainsFor(tenBands));

    // Reverb en un toque.
    await tester.tap(find.text('Estadio'));
    await tester.pumpAndSettle();
    expect(engine.last?.reverb, ReverbMode.stadium);

    // Tono +2 y volver a lo normal.
    await tester.tap(find.text('Volver a lo normal'));
    await tester.pumpAndSettle();
    expect(c.read(equalizerProvider).settings.speedPitchNormal, isTrue, reason: 'ya estaba normal: no hace nada');
    await c.read(equalizerProvider.notifier).setSemitones(2);
    await tester.pumpAndSettle();
    expect(find.text('2 semitonos'), findsOneWidget);
    await tester.tap(find.text('Volver a lo normal'));
    await tester.pumpAndSettle();
    expect(c.read(equalizerProvider).settings.semitones, 0);

    // Apagar "Efectos" apaga todo.
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(engine.last?.enabled, isFalse);
    expect(find.text('Apagados: la música suena tal cual.'), findsOneWidget);
  });

  testWidgets('Lo que el dispositivo no tiene no se muestra (la PC no tiene reverb)', (tester) async {
    await _pump(tester, _Engine(const SoundCapabilities(bass: true)));
    expect(find.text('REVERB'), findsNothing);
    expect(find.text('Estadio'), findsNothing);
    expect(find.text('REFUERZO DE BAJOS'), findsOneWidget);
    expect(find.text('Un perfil por dispositivo'), findsNothing, reason: 'en la PC no se sabe qué salida suena');
  });

  testWidgets('Guardar un preset propio desde la pantalla', (tester) async {
    final engine = _Engine(const SoundCapabilities());
    final c = await _pump(tester, engine);
    await tester.tap(find.text('Guardar como preset'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Para correr');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, 'Para correr'), findsOneWidget);
    expect(c.read(equalizerProvider).settings.userPresets.single.name, 'Para correr');
  });

  testWidgets('Se dibuja en los tres estilos', (tester) async {
    addTearDown(() {
      KijiLook.style = KijiStyle.nocturne;
      KijiColors.palette = KijiPalette.nocturne;
    });
    for (final style in KijiStyle.values) {
      KijiLook.style = style;
      KijiColors.palette = KijiPalette.forStyle(style);
      await _pump(tester, _Engine(const SoundCapabilities(bass: true, reverb: true)));
      expect(tester.takeException(), isNull, reason: style.name);
      expect(find.text('Sonido'), findsOneWidget, reason: style.name);
    }
  });
}
