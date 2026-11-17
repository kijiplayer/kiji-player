import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/translation/data/translation_service.dart';
import 'package:kiji_player/features/translation/presentation/translated_lyrics.dart';
import 'package:kiji_player/l10n/l10n.dart';

/// Cuenta qué canciones se pidieron traducir (todas ya traducidas: no toca disco ni WebView).
class _CountingService extends TranslationService {
  _CountingService(Directory dir) : super(directory: () async => dir);
  final asked = <String>[];

  @override
  Future<List<String?>?> cached(String trackId, List<String> lines, String engineName, String target) async {
    asked.add(trackId);
    return [for (final line in lines) 'tr-$trackId-$line'];
  }
}

void main() {
  late Directory dir;
  late _CountingService service;
  late ProviderContainer container;

  setUp(() {
    setKijiLocale(const Locale('es'));
    dir = Directory.systemTemp.createTempSync('kiji_traducir_espera');
    service = _CountingService(dir);
    container = ProviderContainer(overrides: [
      settingsProvider.overrideWith(() => SettingsNotifier(directory: () async => dir)),
      translationServiceProvider.overrideWithValue(service),
    ]);
  });
  tearDown(() => container.dispose());

  Widget lyrics(String id) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: TranslatedLyrics(
          trackId: id,
          lines: const ['uno', 'dos'],
          builder: (translations) => Text(translations?.join('|') ?? 'sin traducir'),
        ),
      ),
    ),
  );

  testWidgets('al pasar canciones rápido solo se traduce la última', (tester) async {
    await tester.runAsync(() => container.read(settingsProvider.notifier).loaded);
    await tester.pumpWidget(lyrics('a'));
    await tester.pump();
    expect(service.asked, ['a']);

    for (final id in ['b', 'c', 'd', 'e']) {
      await tester.pumpWidget(lyrics(id));
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(service.asked, ['a'], reason: 'todavía pasando canciones');

    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump();
    expect(service.asked, ['a', 'e']);
    expect(find.text('tr-e-uno|tr-e-dos'), findsOneWidget);
  });
}
