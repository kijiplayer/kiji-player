// Cambiar de estilo es un fundido de la pantalla de antes a la nueva: nunca un cuadro negro (el velo
// del color de fondo se veía totalmente negro a mitad de la transición).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/app.dart';
import 'package:kiji_player/features/extractor/data/auto_tests.dart';
import 'package:kiji_player/features/recommendations/data/home_feed_provider.dart';
import 'package:kiji_player/features/recommendations/domain/home_feed.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/features/updates/update_checker.dart';
import 'package:kiji_player/features/yt_music/data/ytm_browse_parser.dart';
import 'package:kiji_player/providers/playback_provider.dart';

class _NoAutoTests extends ExtractorAutoTests {
  _NoAutoTests(super.ref);
  @override
  Future<void> start() async {}
}

/// Sin reproductor real (tiene un temporizador cada 10 s).
class _Idle extends PlaybackNotifier {
  @override
  PlaybackState build() => const PlaybackState(
    track: null,
    isPlaying: false,
    position: Duration.zero,
    duration: Duration.zero,
    shuffleEnabled: false,
    isInitialized: true,
    queue: [],
    currentIndex: 0,
    repeatMode: PlaybackRepeatMode.off,
  );
}

/// Ajustes en memoria (sin disco ni guardados diferidos).
class _Settings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings(style: 'graphite', styleChosen: true, personalized: true);
  @override
  Future<void> update(AppSettings Function(AppSettings) change) async => state = change(state);
}

class _NoUpdates extends UpdateNotifier {
  @override
  Future<void> checkIfDue() async {}
}

void main() {
  testWidgets('Cambiar de estilo: la pantalla de antes se desvanece (sin velo negro)', (tester) async {
    // Los atajos de teclado de la PC no existen en la prueba: se vuelven a registrar al cambiar ajustes.
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('dev.leanflutter.plugins/hotkey_manager'), (_) async => null);
    messenger.setMockStreamHandler(
      const EventChannel('dev.leanflutter.plugins/hotkey_manager_event'),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(_Settings.new),
        playbackProvider.overrideWith(_Idle.new),
        homeFeedProvider.overrideWith((ref) async => const HomeFeed()),
        moodsProvider.overrideWith((ref) async => const <YtMood>[]),
        updateProvider.overrideWith(_NoUpdates.new),
        extractorAutoTestsProvider.overrideWith(_NoAutoTests.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const KijiApp()));
    await tester.pump(const Duration(seconds: 1));

    await container.read(settingsProvider.notifier).update((s) => s.copyWith(style: 'paper'));
    await tester.pump();
    // A mitad del cambio: la foto de la pantalla de antes, no el color de fondo.
    expect(find.byKey(const Key('style-veil-shot')), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    // Terminado el fundido, la foto se suelta.
    expect(find.byKey(const Key('style-veil-shot')), findsNothing);
    expect(container.read(settingsProvider).style, 'paper');
    expect(AppSettings.styles, contains('paper'));
    // La app arranca temporizadores (precarga, guardados): se cierra y se dejan correr.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });
}
