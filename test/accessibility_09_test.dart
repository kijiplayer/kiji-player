// Accesibilidad de lo nuevo de la 0.9 (sin teléfono: las pautas automáticas de Flutter, las
// mismas que revisa el Accessibility Scanner de Android): cada botón con nombre para TalkBack y
// de 48 px como mínimo para tocar. Datos inventados.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/quotes/quote_card.dart';
import 'package:kiji_player/features/quotes/quotes.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/share_cards/now_playing_card.dart';
import 'package:kiji_player/features/updates/whats_new_screen.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/theme/app_theme.dart';

const _track = Track(
  id: 'yt-inventado01',
  title: 'Glass Harbor',
  artist: 'The Velvet Tides',
  coverColor: Color(0xFF7C5CFF),
  audioUrl: '',
  source: TrackSource.youtube,
);

Future<Directory> _noDisk() async => throw const FileSystemException('sin disco en el test');

Widget _app(Widget home) => ProviderScope(
  overrides: [settingsProvider.overrideWith(() => SettingsNotifier(directory: _noDisk))],
  child: MaterialApp(theme: AppTheme.darkWith(), home: home),
);

Future<void> _check(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
}

void main() {
  testWidgets('«Qué hay de nuevo»: «Empezar» con nombre y de 48 px', (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const WhatsNewScreen()));
    // La aurora se mueve siempre: se espera a que entren las tarjetas, sin «settle».
    await tester.pump(const Duration(seconds: 2));
    await _check(tester);
    handle.dispose();
  });

  testWidgets('Tarjetas para compartir: estilos, formatos y «Compartir» con nombre y de 48 px', (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(Builder(
      builder: (context) => Scaffold(
        body: Center(child: TextButton(onPressed: () => showShareCardScreen(context, _track), child: const Text('abrir'))),
      ),
    )));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await _check(tester);
    handle.dispose();
  });

  testWidgets('Frase del día: «Compartir la frase» con nombre y de 48 px', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        settingsProvider.overrideWith(() => SettingsNotifier(directory: _noDisk)),
        currentQuoteProvider.overrideWithValue(
          const Quote(id: 'inventada', author: 'Autora Inventada', source: 'Libro Inventado', es: 'Una frase inventada.', en: 'A made-up quote.'),
        ),
      ],
      child: MaterialApp(theme: AppTheme.darkWith(), home: const Scaffold(body: SingleChildScrollView(child: DailyQuoteCard()))),
    ));
    await tester.pump();
    expect(find.byTooltip('Compartir la frase'), findsOneWidget);
    await _check(tester);
    handle.dispose();
  });
}
