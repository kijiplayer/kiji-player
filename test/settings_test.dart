import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/features/settings/domain/setting_search.dart';
import 'package:kiji_player/features/settings/presentation/credits_screen.dart';
import 'package:kiji_player/features/settings/presentation/settings_screen.dart';
import 'package:kiji_player/providers/appearance_provider.dart';
import 'package:kiji_player/providers/playback_provider.dart';

class _EmptyPlayback extends PlaybackNotifier {
  @override
  PlaybackState build() => PlaybackState.initial();
}

void main() {
  group('AppSettings', () {
    test('Valores de fábrica', () {
      const s = AppSettings();
      expect(s.rememberQueue, isTrue);
      expect(s.reduceMotion, isFalse);
      expect(s.streamCacheLimitBytes, AppSettings.defaultCacheLimit);
      expect(s.hideShortAudios, isFalse);
    });

    test('Se guarda y se lee igual', () {
      const s = AppSettings(
        rememberQueue: false,
        reduceMotion: true,
        streamCacheLimitBytes: 1024 * 1024 * 1024,
        hideShortAudios: true,
      );
      final r = AppSettings.fromJson(s.toJson());
      expect(r.rememberQueue, isFalse);
      expect(r.reduceMotion, isTrue);
      expect(r.streamCacheLimitBytes, 1024 * 1024 * 1024);
      expect(r.hideShortAudios, isTrue);
    });

    test('Datos raros o de otra versión vuelven a los de fábrica', () {
      final r = AppSettings.fromJson({
        'rememberQueue': 'sí',
        'reduceMotion': 1,
        'streamCacheLimitBytes': 12345,
        'opcionDelFuturo': true,
      });
      expect(r.rememberQueue, isTrue);
      expect(r.reduceMotion, isFalse);
      expect(r.streamCacheLimitBytes, AppSettings.defaultCacheLimit);
    });

    test('Ocultar audios cortos: solo si está activado y se conoce la duración', () {
      expect(const AppSettings().hides(5000), isFalse);
      const on = AppSettings(hideShortAudios: true);
      expect(on.hides(5000), isTrue);
      expect(on.hides(45000), isFalse);
      expect(on.hides(0), isFalse, reason: 'duración desconocida: no se oculta');
    });
  });

  test('Las opciones se respetan al reabrir la app', () async {
    final dir = await Directory.systemTemp.createTemp('kiji_ajustes_');
    addTearDown(() => dir.delete(recursive: true));

    final first = ProviderContainer(overrides: [
      settingsProvider.overrideWith(() => SettingsNotifier(directory: () async => dir)),
    ]);
    first.read(settingsProvider);
    await first.read(settingsProvider.notifier).loaded;
    await first.read(settingsProvider.notifier).update((s) => s.copyWith(reduceMotion: true, rememberQueue: false));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    first.dispose();

    final second = ProviderContainer(overrides: [
      settingsProvider.overrideWith(() => SettingsNotifier(directory: () async => dir)),
    ]);
    addTearDown(second.dispose);
    second.read(settingsProvider);
    final loaded = await second.read(settingsProvider.notifier).loaded;
    expect(loaded.reduceMotion, isTrue);
    expect(loaded.rememberQueue, isFalse);
    expect(second.read(reduceMotionSettingProvider), isTrue);
  });

  test('Un archivo de ajustes dañado no rompe nada', () async {
    final dir = await Directory.systemTemp.createTemp('kiji_ajustes_');
    addTearDown(() => dir.delete(recursive: true));
    await File(p.join(dir.path, 'settings.json')).writeAsString('{"reduceMotion": tr');

    final container = ProviderContainer(overrides: [
      settingsProvider.overrideWith(() => SettingsNotifier(directory: () async => dir)),
    ]);
    addTearDown(container.dispose);
    container.read(settingsProvider);
    final loaded = await container.read(settingsProvider.notifier).loaded;
    expect(loaded.reduceMotion, isFalse);
  });

  group('Buscador de opciones', () {
    test('Sin tildes ni mayúsculas', () {
      expect(normalizeForSearch('Reducir ANIMACIÓN'), 'reducir animacion');
      expect(settingMatches('animacion', title: 'Reducir animaciones'), isTrue);
      expect(settingMatches('CACHÉ', title: 'Vaciar la caché'), isTrue);
    });

    test('Todas las palabras tienen que aparecer (en título, texto, sección o claves)', () {
      expect(settingMatches('wifi datos', title: 'Descargar solo con WiFi', keywords: ['datos']), isTrue);
      expect(settingMatches('wifi tema', title: 'Descargar solo con WiFi'), isFalse);
      expect(settingMatches('privacidad', title: 'Salud', section: 'Privacidad'), isTrue);
      expect(settingMatches('   ', title: 'Algo'), isFalse);
    });
  });

  group('Créditos dentro de la app', () {
    test('Quita el formato de Markdown y no deja enlaces', () {
      expect(stripInlineMarkdown('[Echo Music](https://x.y) y **GPL**'), 'Echo Music y GPL');
      expect(stripInlineMarkdown('`lib/a.dart`'), 'lib/a.dart');
    });

    test('Lee el CREDITS.md real del proyecto', () {
      final blocks = parseCredits(File('CREDITS.md').readAsStringSync());
      expect(blocks.whereType<CreditsHeading>().first.text, 'Créditos');
      final rows = blocks.whereType<CreditsRow>().where((r) => !r.header).toList();
      expect(rows.any((r) => r.cells.first.contains('Echo Music')), isTrue);
      expect(rows.any((r) => r.cells.first.contains('Space Grotesk')), isTrue);
      expect(blocks.any((b) => b.text.contains('](')), isFalse, reason: 'sin enlaces crudos');
    });
  });

  testWidgets('Configuración: buscar "animacion" deja solo esa opción, y se puede activar', (tester) async {
    // En testWidgets el tiempo es simulado y el disco real no responde: sin
    // carpeta, las preferencias quedan en memoria (mismo camino que un error).
    Future<Directory> noDisk() async => throw const FileSystemException('sin disco en el test');
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        settingsProvider.overrideWith(() => SettingsNotifier(directory: noDisk)),
        playbackProvider.overrideWith(_EmptyPlayback.new),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pump();

    for (final section in ['REPRODUCTOR Y AUDIO', 'CONTENIDO', 'LETRAS']) {
      expect(find.text(section), findsOneWidget, reason: section);
    }

    await tester.enterText(find.byType(TextField), 'animacion');
    await tester.pump();
    expect(find.text('Reducir animaciones'), findsOneWidget);
    expect(find.text('Recordar la cola al cerrar'), findsNothing);
    expect(find.text('APARIENCIA'), findsOneWidget);
    expect(find.text('ALMACENAMIENTO'), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    final container = ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
    expect(container.read(settingsProvider).reduceMotion, isTrue);

    await tester.enterText(find.byType(TextField), 'xyz nada');
    await tester.pump();
    expect(find.text('No hay ninguna opción con ese nombre.'), findsOneWidget);
  });
}
