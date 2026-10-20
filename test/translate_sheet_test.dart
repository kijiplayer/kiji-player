import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/translation/presentation/translate_sheet.dart';
import 'package:kiji_player/features/translation/presentation/translated_lyrics.dart';
import 'package:kiji_player/l10n/l10n.dart';

void main() {
  late Directory dir;
  late ProviderContainer container;

  setUp(() {
    setKijiLocale(const Locale('es'));
    dir = Directory.systemTemp.createTempSync('kiji_traducir');
    container = ProviderContainer(overrides: [
      settingsProvider.overrideWith(() => SettingsNotifier(directory: () async => dir)),
    ]);
  });
  tearDown(() => container.dispose());

  Future<void> open(WidgetTester tester) async {
    await tester.runAsync(() => container.read(settingsProvider.notifier).loaded);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => showTranslateSheet(context, ref),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('Dos opciones claras y la IA marcada como Beta', (tester) async {
    await open(tester);
    expect(find.text('Traducción en el teléfono'), findsOneWidget);
    expect(find.text('Traducción con IA'), findsOneWidget);
    expect(find.text('BETA'), findsOneWidget);
    expect(find.text('Ajustes de traducción'), findsOneWidget);
  });

  testWidgets('"En el teléfono": un toque elige y traduce', (tester) async {
    await open(tester);
    await tester.tap(find.text('Traducción en el teléfono'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).useGemini, isFalse);
    expect(container.read(lyricsTranslationOnProvider), isTrue);
  });

  testWidgets('"Con IA" lista: un toque elige la IA y traduce', (tester) async {
    await tester.runAsync(() => container
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(geminiEnabled: true, geminiModel: 'gemini-test')));
    await open(tester);
    await tester.tap(find.text('Traducción con IA'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).useGemini, isTrue);
    expect(container.read(lyricsTranslationOnProvider), isTrue);
  });

  test('La IA solo está lista activada y con un modelo elegido', () {
    final s = container.read(settingsProvider);
    expect(geminiReady(s), isFalse);
    expect(geminiReady(s.copyWith(geminiEnabled: true)), isFalse);
    expect(geminiReady(s.copyWith(geminiEnabled: true, geminiModel: 'm')), isTrue);
  });
}
