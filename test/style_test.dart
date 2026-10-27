import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/features/style/presentation/style_chooser_screen.dart';
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

  testWidgets('elegir un estilo lo guarda y deja anotado que ya se eligió', (tester) async {
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
      child: const MaterialApp(home: StyleChooserScreen()),
    ));
    await tester.pump();
    expect(find.text('¿Cómo quieres que se vea Kiji?'), findsOneWidget);
    expect(find.byType(StylePreview), findsNWidgets(3));
    expect(find.text('Continuar con Nocturne'), findsOneWidget);

    await tester.ensureVisible(find.text('Papel'));
    await tester.pump();
    await tester.tap(find.text('Papel'));
    await tester.pump();
    await tester.tap(find.text('Continuar con Papel'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(container.read(settingsProvider).style, 'paper');
    expect(container.read(settingsProvider).styleChosen, isTrue);
    expect(tester.takeException(), isNull, reason: 'sin desbordes a 360×560');
  });
}
