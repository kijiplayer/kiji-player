import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/updates/whats_new_screen.dart';
import 'package:kiji_player/theme/app_theme.dart';
import 'package:kiji_player/theme/kiji_tokens.dart';

Future<Directory> _noDisk() async => throw const FileSystemException('sin disco en el test');

void main() {
  tearDown(() {
    KijiLook.style = KijiStyle.nocturne;
    KijiColors.palette = KijiPalette.nocturne;
  });

  test('las novedades de la 0.7: lo de la PC solo en la PC', () {
    final phone = whatsNewItems(desktop: false);
    final pc = whatsNewItems(desktop: true);
    expect(phone, hasLength(7));
    expect(pc, hasLength(8));
    expect(pc.last.title, 'En la PC');
    expect([for (final i in phone) i.title], contains('Tres estilos'));
    expect([for (final i in phone) i.title], contains('Tus más escuchadas'));
  });

  for (final style in KijiStyle.values) {
    for (final (name, size, scale) in [
      ('teléfono con letra grande', const Size(360, 640), 1.6),
      ('PC', const Size(1400, 900), 1.0),
    ]) {
      testWidgets('se ve sin desbordes y "Empezar" la cierra (${style.name}, $name)', (tester) async {
        KijiLook.style = style;
        KijiColors.palette = KijiPalette.forStyle(style);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [settingsProvider.overrideWith(() => SettingsNotifier(directory: _noDisk))],
            child: MaterialApp(
              theme: AppTheme.darkWith(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: TextButton(onPressed: () => WhatsNewScreen.open(context), child: const Text('abrir')),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('abrir'));
        // En Nocturne la aurora de fondo se mueve siempre: se avanza un tiempo fijo, no "hasta que quede quieta".
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
        expect(find.text('Qué hay de nuevo'), findsOneWidget);
        expect(find.text('Tres estilos'), findsOneWidget);
        await tester.tap(find.byKey(const Key('whats-new-start')));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(WhatsNewScreen), findsNothing);
      });
    }
  }

  testWidgets('con "Reducir animaciones" las tarjetas aparecen quietas, sin esperar', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith(() => SettingsNotifier(directory: _noDisk))],
        child: const MaterialApp(
          home: MediaQuery(data: MediaQueryData(size: Size(400, 800), disableAnimations: true), child: WhatsNewScreen()),
        ),
      ),
    );
    await tester.pump();
    // Sin un solo cuadro de animación, todas las tarjetas ya están del todo visibles.
    final opacities = tester.widgetList<Opacity>(find.byType(Opacity)).map((o) => o.opacity);
    expect(opacities.every((o) => o == 1), isTrue);
    expect(find.text('Tres estilos'), findsOneWidget);
  });
}
