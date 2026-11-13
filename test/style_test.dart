import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/features/style/presentation/personalize_screen.dart';
import 'package:kiji_player/features/style/presentation/style_parts.dart';
import 'package:kiji_player/theme/kiji_tokens.dart';

/// Contraste de WCAG 2 entre dos colores opacos.
double contrast(Color a, Color b) {
  double channel(double c) => c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
  double luminance(Color c) => 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  final (l1, l2) = (luminance(a), luminance(b));
  return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05);
}

void main() {
  test('texto con contraste de 4.5:1 como mínimo en los tres estilos', () {
    for (final style in KijiStyle.values) {
      final p = KijiPalette.forStyle(style);
      final pairs = {
        'texto/fondo': (p.text, p.background),
        'texto/superficie': (p.text, p.surface),
        'secundario/fondo': (p.muted, p.background),
        'secundario/superficie': (p.muted, p.surface),
        'sobre el acento': (p.onAccent, p.violet),
        'me gusta/fondo': (p.like ?? p.violet, p.background),
      };
      for (final MapEntry(key: name, value: (fg, bg)) in pairs.entries) {
        expect(contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: '${style.name}: $name');
      }
    }
  });

  test('Grafito: el texto se lee sobre la portada de fondo y sobre el vidrio, aunque la portada sea blanca', () {
    const p = KijiPalette.graphite;
    // Pinta [top] encima de [bottom] (los dos pueden ser translúcidos; el resultado es opaco).
    Color over(Color bottom, Color top) => Color.alphaBlend(top, bottom);
    Color white(double opacity) => Colors.white.withValues(alpha: opacity);

    // Peor caso del fondo del reproductor: la portada blanca (oscurecida).
    final cover = white(KijiMuseum.backdropBrightness * KijiMuseum.backdropOpacity);
    final backdrop = over(p.background, cover);
    final button = over(backdrop, p.glassFill);
    // Mini-reproductor, barra y hojas: sobre cualquier cosa (también una portada blanca).
    final pane = over(Colors.white, KijiMuseum.pane);
    final pairs = {
      'texto/fondo de portada': (p.text, backdrop),
      'secundario/fondo de portada': (p.muted, backdrop),
      'texto/botón de vidrio': (p.text, button),
      'texto/panel': (p.text, pane),
      'secundario/panel': (p.muted, pane),
      'texto/vidrio sobre el fondo': (p.text, over(p.background, p.glassFill)),
      'secundario/vidrio sobre el fondo': (p.muted, over(p.background, p.glassFill)),
    };
    for (final MapEntry(key: name, value: (fg, bg)) in pairs.entries) {
      expect(contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: name);
    }
  });

  test('la onda de Grafito y Papel es monocroma, con los grises pedidos', () {
    expect(KijiPalette.graphite.violet, const Color(0xFFF2F2F2));
    expect(KijiPalette.graphite.cyan, const Color(0xFFF2F2F2));
    expect(KijiPalette.graphite.waveRest, const Color(0x2EFFFFFF), reason: 'blanco 18 %');
    expect(KijiPalette.paper.violet, const Color(0xFF1B1B1A));
    expect(KijiPalette.paper.cyan, const Color(0xFF1B1B1A));
    expect(KijiPalette.paper.waveRest, const Color(0xFFCFCAC0));
    expect(KijiPalette.graphite.glassBorder, const Color(0x1AFFFFFF), reason: 'blanco 10 %');
  });

  test('Grafito y Papel tienen los colores pedidos', () {
    expect(KijiPalette.graphite.background, const Color(0xFF0F0F10));
    expect(KijiPalette.graphite.violet, KijiPalette.graphite.text, reason: 'el acento es el blanco');
    expect(KijiPalette.paper.background, const Color(0xFFF3F1EC));
    expect(KijiPalette.paper.like, const Color(0xFFB4462B));
    expect(KijiPalette.paper.isLight, isTrue);
    expect(KijiPalette.forStyle(KijiStyle.nocturne), KijiPalette.nocturne);
  });

  test('el estilo se guarda; uno desconocido vuelve a Nocturne', () {
    const d = AppSettings();
    expect([d.style, d.styleChosen], ['nocturne', false]);
    final back = AppSettings.fromJson(d.copyWith(style: 'paper', styleChosen: true).toJson());
    expect([back.style, back.styleChosen], ['paper', true]);
    expect(AppSettings.fromJson({'style': 'neon'}).style, 'nocturne');
    expect(KijiStyle.parse('graphite'), KijiStyle.graphite);
    expect(KijiStyle.parse(null), KijiStyle.nocturne);
  });

  testWidgets('Personaliza Kiji: 4 pasos con vista previa en vivo, "Saltar" y queda anotado', (tester) async {
    final dir = Directory.systemTemp.createTempSync('kiji_style_');
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException catch (error) {
        // El ajuste se puede estar terminando de escribir: es una carpeta temporal.
        debugPrint('=== TEST: no se pudo borrar la carpeta temporal: $error ===');
      }
    });
    final container = ProviderContainer(overrides: [
      settingsProvider.overrideWith(() => SettingsNotifier(directory: () async => dir)),
    ]);
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(360, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => PersonalizeScreen.open(context, ref),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Paso 1 de 4'), findsOneWidget);
    expect(find.text('¿Cómo quieres que se vea Kiji?'), findsOneWidget);
    // La vista previa en vivo y una miniatura por estilo.
    expect(find.byType(StylePreview), findsNWidgets(4));

    await tester.ensureVisible(find.text('Papel'));
    await tester.tap(find.text('Papel'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(container.read(settingsProvider).style, 'paper', reason: 'se aplica en el momento');

    await tester.tap(find.byKey(const Key('personalize-next')));
    await tester.pumpAndSettle();
    expect(find.text('Paso 2 de 4'), findsOneWidget);
    await tester.tap(find.byKey(const Key('personalize-next')));
    await tester.pumpAndSettle();
    expect(find.text('Paso 3 de 4'), findsOneWidget);
    await tester.tap(find.text('Newsreader'));
    await tester.pump();
    expect(container.read(settingsProvider).font, 'newsreader');
    expect(tester.takeException(), isNull, reason: 'sin desbordes a 360×560');

    // "Saltar" cierra en cualquier paso y deja anotado que ya se vio.
    await tester.tap(find.byKey(const Key('personalize-skip')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('abrir'), findsOneWidget);
    expect(container.read(settingsProvider).personalized, isTrue);
    expect(container.read(settingsProvider).styleChosen, isTrue);
  });
}
