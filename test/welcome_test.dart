import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/welcome/data/welcome_store.dart';
import 'package:kiji_player/features/welcome/presentation/welcome_screen.dart';
import 'package:kiji_player/l10n/l10n.dart';
import 'package:kiji_player/theme/app_theme.dart';

/// En memoria, para las pruebas de la pantalla: con el disco de verdad, la escritura solo avanza
/// con el reloj real y mezclarlo con el de la prueba fallaba a veces con la PC cargada. Lo de
/// guardar en disco se prueba arriba, con el de verdad.
class _MemoryStore extends WelcomeStore {
  bool seen = false;
  @override
  Future<bool> shouldShow() async => !seen;
  @override
  Future<void> markSeen() async => seen = true;
}

void main() {
  late Directory dir;
  late WelcomeStore store;
  late _MemoryStore screenStore;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kiji_bienvenida');
    store = WelcomeStore(directory: () async => dir);
    screenStore = _MemoryStore();
  });
  tearDown(() async {
    setKijiLocale(const Locale('es'));
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  group('Se muestra sola una única vez, y solo a quien recién instala', () {
    test('Kiji recién instalado: se muestra', () async {
      expect(await store.shouldShow(), isTrue);
    });

    test('Después de verla (Empezar o Saltar), no vuelve a aparecer', () async {
      await store.markSeen();
      expect(await store.shouldShow(), isFalse);
    });

    for (final file in ['settings.json', 'history.json', 'playlists.json', 'favorites.json', 'downloads/index.json']) {
      test('Con datos de antes ($file): nunca se muestra', () async {
        final f = File('${dir.path}/$file');
        await f.parent.create(recursive: true);
        await f.writeAsString('{}');
        expect(await store.shouldShow(), isFalse);
      });
    }
  });

  Widget app() => ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkWith(reduceMotion: false),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => WelcomeScreen(store: screenStore, playSound: false)),
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  testWidgets('Cinco pantallas, "Saltar" en todas y "Empezar" al final (y queda anotado)', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('abrir'));
    await settle(tester);

    final pages = ['Hola', 'Qué es Kiji', 'La historia', 'A tu gusto', 'Kiji no recopila nada'];
    for (var i = 0; i < pages.length; i++) {
      expect(find.text('Saltar'), findsOneWidget, reason: 'pantalla ${i + 1}');
      if (i > 0) expect(find.text(pages[i]), findsOneWidget);
      // La historia va sin etiqueta de borrador.
      if (i == 2) expect(find.textContaining('BORRADOR'), findsNothing);
      if (i < pages.length - 1) {
        await tester.tap(find.text('Siguiente'));
        await settle(tester);
      }
    }
    await tester.tap(find.text('Empezar'));
    await settle(tester);
    expect(find.text('abrir'), findsOneWidget);
    expect(screenStore.seen, isTrue, reason: 'queda anotado');
  });

  testWidgets('"Saltar" cierra desde la primera pantalla', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('abrir'));
    await settle(tester);
    await tester.tap(find.text('Saltar'));
    await settle(tester);
    expect(find.text('abrir'), findsOneWidget);
    expect(screenStore.seen, isTrue, reason: 'queda anotado');
  });

  for (final (language, scale) in [('es', 1.0), ('en', 1.0), ('en', 1.6), ('es', 1.6)]) {
    testWidgets('En "$language" con letra x$scale, ninguna pantalla se corta (celular de 360 dp)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2000);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      setKijiLocale(Locale(language));

      await tester.pumpWidget(app());
      await tester.tap(find.text('abrir'));
      await settle(tester);
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text(tx.bienvenidaSiguiente));
        await settle(tester);
      }
      expect(find.text(tx.bienvenidaEmpezar), findsOneWidget);
    });
  }
}
