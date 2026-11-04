import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/lyrics/data/screen_mode_impl.dart';
import 'package:kiji_player/features/lyrics/domain/lyrics.dart';
import 'package:kiji_player/features/lyrics/domain/screen_mode.dart';
import 'package:kiji_player/features/lyrics/presentation/lyrics_fullscreen.dart';
import 'package:kiji_player/features/lyrics/lyrics_provider.dart';
import 'package:kiji_player/features/lyrics/presentation/lyrics_screen.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/playback_provider.dart';

/// Letra inventada, con líneas cortas y una muy larga (para ver que no se corte).
final _lines = [
  for (var i = 0; i < 30; i++)
    LyricLine(
      Duration(seconds: 4 * i),
      i == 5 ? 'Una línea inventada muy larga que tiene que partirse en varias sin cortarse nunca de costado' : 'Línea inventada número $i',
    ),
];

class _Playback extends PlaybackNotifier {
  @override
  PlaybackState build() => const PlaybackState(
    track: Track(
      id: 'yt-inventada',
      title: 'Un título inventado bastante largo para probar el panel',
      artist: 'Grupo Inventado',
      coverColor: Color(0xFF3A6EA5),
      audioUrl: '',
      source: TrackSource.youtube,
    ),
    isPlaying: false,
    position: Duration(seconds: 21),
    duration: Duration(minutes: 3),
    shuffleEnabled: false,
    isInitialized: true,
    queue: [],
    currentIndex: 0,
    repeatMode: PlaybackRepeatMode.off,
  );
}

class _Mode implements ScreenMode {
  @override
  Future<void> setFullScreen(bool on) async {}
}

Future<Directory> _noDisk() async => throw const FileSystemException('sin disco en el test');

const sizes = <Size>[
  Size(600, 400), Size(800, 600), Size(1024, 640), Size(1280, 720),
  Size(1366, 768), Size(1920, 1080), Size(2560, 1440), Size(900, 1400), Size(412, 915), Size(915, 412),
];

void main() {
  for (final panel in ['full', 'simple', 'showcase', 'fullscreen']) {
    for (final size in sizes) {
      testWidgets('La letra entra sin cortes: vista $panel en ${size.width.toInt()}×${size.height.toInt()}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final errors = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (details) {
          errors.add(details.exceptionAsString().split('\n').first);
          if (const bool.fromEnvironment('DETALLE')) FlutterError.dumpErrorToConsole(details);
        };
        addTearDown(() => FlutterError.onError = previous);

        final container = ProviderContainer(overrides: [
          playbackProvider.overrideWith(_Playback.new),
          settingsProvider.overrideWith(() => SettingsNotifier(directory: _noDisk)),
          lyricsProvider.overrideWith((ref, request) async => Lyrics(synced: _lines, source: LyricsSource.lrclib)),
          screenModeProvider.overrideWithValue(_Mode()),
        ]);
        addTearDown(container.dispose);
        if (panel == 'fullscreen') {
          container.read(lyricsFullscreenProvider.notifier).state = true;
        } else {
          await container.read(settingsProvider.notifier).update((s) => s.copyWith(lyricsPanel: panel));
        }
        await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LyricsScreen()),
        ));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        FlutterError.onError = previous;
        expect(errors, isEmpty, reason: 'vista $panel en $size');
        // La línea que suena se ve entera dentro de la ventana.
        final current = find.bySemanticsLabel(RegExp('Línea inventada número 5|Una línea inventada'));
        if (panel != 'showcase' || size.width >= 560) {
          for (final element in current.evaluate()) {
            final rect = tester.getRect(find.byWidget(element.widget));
            expect(rect.left, greaterThanOrEqualTo(-1), reason: 'no se corta a la izquierda ($panel, $size)');
            expect(rect.right, lessThanOrEqualTo(size.width + 1), reason: 'no se corta a la derecha ($panel, $size)');
          }
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
