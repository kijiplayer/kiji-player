// Mezcla real, solo PC: dos tonos de prueba como canciones locales; con la mezcla en
// 5 s, al acercarse el final la "cola" sigue sonando mientras la segunda ya está cargada.
// SOLO EN PC: flutter test integration_test/crossfade_test.dart -d windows
// (los tonos de prueba se generan con ffmpeg).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/system_media/data/system_media_controls_factory.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/playback_provider.dart';
import 'package:kiji_player/providers/system_media_provider.dart';

Track _tone(String name) => Track(
      id: 'local-$name',
      title: 'Tono $name',
      artist: 'Prueba',
      coverColor: const Color(0xFF7C5CFF),
      audioUrl: 'test_assets/tonos/tono_$name.mp3',
      source: TrackSource.local,
      durationMs: 20000,
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  JustAudioMediaKit.ensureInitialized(windows: true, linux: true);

  testWidgets('la cola y la siguiente suenan a la vez', (tester) async {
    final dir = Directory.systemTemp.createTempSync('kiji_mezcla');
    final container = ProviderContainer(overrides: [
      settingsProvider.overrideWith(() => SettingsNotifier(directory: () async => dir)),
      systemMediaControlsProvider.overrideWithValue(const NoSystemMediaControls()),
    ]);
    addTearDown(container.dispose);
    await container.read(settingsProvider.notifier).loaded;
    await container.read(settingsProvider.notifier).update((s) => s.copyWith(crossfadeSeconds: 5, rememberQueue: false));
    final notifier = container.read(playbackProvider.notifier);
    await tester.runAsync(() async {
      await notifier.playQueue([_tone('a'), _tone('b')]);
      await notifier.changeVolume(-1); // en silencio
      await Future<void>.delayed(const Duration(seconds: 1));
      await notifier.seekTo(const Duration(seconds: 11));
      var overlap = false;
      for (var i = 0; i < 60; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final s = container.read(playbackProvider);
        if (notifier.debugTailPlaying && s.track?.id == 'local-b' && s.isPlaying) overlap = true;
      }
      debugPrint('=== MEZCLA PC: suenan las dos a la vez = $overlap; '
          'cola sonando al final = ${notifier.debugTailPlaying}; '
          'canción actual = ${container.read(playbackProvider).track?.title} ===');
      expect(overlap, isTrue);
      expect(notifier.debugTailPlaying, isFalse, reason: 'la cola se cierra al terminar la mezcla');
      expect(container.read(playbackProvider).track?.id, 'local-b');
      await notifier.pause();
    });
  }, timeout: const Timeout(Duration(minutes: 3)));
}
