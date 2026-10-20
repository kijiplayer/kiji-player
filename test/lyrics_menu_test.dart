import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/lyrics/presentation/lyrics_menu_sheet.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';

class _FakeSettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}

void main() {
  testWidgets('⋯ de la letra: grupos con íconos grandes, cierra al tocar y cambia el tamaño', (tester) async {
    var translated = 0;
    final container = ProviderContainer(overrides: [settingsProvider.overrideWith(_FakeSettings.new)]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showLyricsMenuSheet(
                  context,
                  groups: [
                    LyricsMenuGroup('Leer', [
                      LyricsMenuAction(icon: Icons.translate_rounded, label: 'Traducir', onTap: () => translated++),
                    ]),
                    const LyricsMenuGroup('Vacío', []),
                    LyricsMenuGroup('Fuente', [
                      LyricsMenuAction(icon: Icons.library_books_outlined, label: 'Elegir fuente', onTap: () {}),
                    ]),
                  ],
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('LEER'), findsOneWidget);
    expect(find.text('FUENTE'), findsOneWidget);
    expect(find.text('VACÍO'), findsNothing); // un grupo sin acciones no se muestra
    // Íconos grandes (28 px).
    expect(tester.widget<Icon>(find.byIcon(Icons.translate_rounded)).size, 28);

    // Tamaño de las letras: se guarda al tocar.
    await tester.tap(find.text('Grande'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).lyricsSize, 'large');

    await tester.tap(find.text('Traducir'));
    await tester.pumpAndSettle();
    expect(translated, 1);
    expect(find.text('LEER'), findsNothing); // la hoja se cerró
  });

  test('Tamaño de las letras', () {
    expect(lyricsScaleFor('small'), lessThan(1));
    expect(lyricsScaleFor('normal'), 1);
    expect(lyricsScaleFor('large'), greaterThan(1));
    expect(lyricsScaleFor('raro'), 1);
  });
}
