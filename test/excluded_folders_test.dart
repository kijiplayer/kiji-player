import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/local_library/domain/local_exclusions.dart';
import 'package:kiji_player/features/local_library/presentation/excluded_folders_screen.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';

Future<Directory> _noDisk() async => throw const FileSystemException('sin disco en el test');

void main() {
  testWidgets('Carpetas excluidas: quitar, agregar por nombre y volver a las de fábrica', (tester) async {
    final container = ProviderContainer(overrides: [settingsProvider.overrideWith(() => SettingsNotifier(directory: _noDisk))]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MaterialApp(home: ExcludedFoldersScreen())),
    );
    await tester.pump();
    expect(find.text('Telegram'), findsOneWidget);
    expect(find.byKey(const Key('excluded-defaults')), findsNothing, reason: 'ya son las de fábrica');

    // Quitar Telegram.
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('excluded-Telegram')), matching: find.byType(IconButton)));
    await tester.pump();
    expect(container.read(settingsProvider).localExclusions.folders, isNot(contains('Telegram')));

    // Agregar una por nombre.
    await tester.scrollUntilVisible(find.byKey(const Key('excluded-add-name')), 100);
    await tester.tap(find.byKey(const Key('excluded-add-name')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('excluded-name')), 'Podcasts');
    await tester.tap(find.byKey(const Key('excluded-name-ok')));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).localExclusions.excludes('/m/Podcasts/episodio.mp3'), isTrue);

    // Volver a las de fábrica.
    await tester.scrollUntilVisible(find.byKey(const Key('excluded-defaults')), 100);
    await tester.tap(find.byKey(const Key('excluded-defaults')));
    await tester.pump();
    expect(container.read(settingsProvider).localExclusions.folders, LocalExclusions.defaultFolders);
  });

  test('Audios sin etiquetas en Descargas o Documentos no son música (grabaciones, TikTok, voces)', () {
    // Como los que aparecían en la Biblioteca: en Download/, sin artista.
    expect(LocalExclusions.isUntaggedLooseAudio('/storage/emulated/0/Download/ElevenLabs_2026-10-19.mp3', '<unknown>'), isTrue);
    expect(LocalExclusions.isUntaggedLooseAudio('/storage/emulated/0/Download/TikDownloader_123.mp3', null), isTrue);
    expect(LocalExclusions.isUntaggedLooseAudio('/storage/emulated/0/Documents/descarga.m4a', ''), isTrue);
    // Música bajada con su artista: sí es música.
    expect(LocalExclusions.isUntaggedLooseAudio('/storage/emulated/0/Download/Daft Punk - One More Time.mp3', 'Daft Punk'), isFalse);
    // Sin artista pero en la carpeta de música: se respeta (puede ser música propia).
    expect(LocalExclusions.isUntaggedLooseAudio('/storage/emulated/0/Music/maqueta.mp3', '<unknown>'), isFalse);
  });
}
