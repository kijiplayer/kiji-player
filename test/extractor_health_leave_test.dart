import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/extractor/data/path_health.dart';
import 'package:kiji_player/features/extractor/data/ytdlp_engine.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/yt_music/presentation/extractor_health_screen.dart';

/// yt-dlp que tarda en instalarse hasta que la prueba lo diga.
class _SlowYtDlp extends YtDlpEngine {
  final done = Completer<void>();

  @override
  Future<bool> installed() async => false;

  @override
  Future<void> install({void Function(int done, int total)? onProgress}) => done.future;
}

void main() {
  testWidgets('Salir de Salud del Extractor mientras baja yt-dlp no rompe y queda aceptado', (tester) async {
    if (!YtDlpEngine.platformSupported) return;
    tester.view.physicalSize = const Size(500, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final dir = Directory.systemTemp.createTempSync('kiji_salir');
    final engine = _SlowYtDlp();
    final container = ProviderContainer(overrides: [
      settingsProvider.overrideWith(() => SettingsNotifier(directory: () async => dir)),
      ytDlpEngineProvider.overrideWithValue(engine),
    ]);
    addTearDown(container.dispose);
    await tester.runAsync(() => container.read(settingsProvider.notifier).loaded);

    final health = PathHealth(directory: () async => dir.path);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => ExtractorHealthScreen(health: health)),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byIcon(Icons.download_rounded));
    await tester.tap(find.byIcon(Icons.download_rounded));
    await tester.pump();
    // El usuario se va antes de que termine la descarga.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      engine.done.complete();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(container.read(settingsProvider).ytDlpAccepted, isTrue);
  });
}
