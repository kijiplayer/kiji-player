import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/loudness/data/loudness_analyzer.dart';
import 'package:kiji_player/features/lyrics/presentation/lyrics_views.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/playback_provider.dart';

const _track = Track(
  id: 'yt-inventada',
  title: 'Paper Lanterns',
  artist: 'Mira Solenne',
  coverColor: Color(0xFF5577AA),
  audioUrl: '',
  source: TrackSource.youtube,
);

class _Playback extends PlaybackNotifier {
  @override
  PlaybackState build() => const PlaybackState(
    track: _track,
    isPlaying: true,
    position: Duration(seconds: 30),
    duration: Duration(minutes: 3),
    shuffleEnabled: false,
    isInitialized: true,
    queue: [_track],
    currentIndex: 0,
    repeatMode: PlaybackRepeatMode.off,
  );
}

Widget _app(Widget child, Directory dir) => ProviderScope(
  overrides: [
    playbackProvider.overrideWith(_Playback.new),
    // Sin datos de volumen (como una canción por streaming): la portada queda quieta.
    loudnessProvider.overrideWith((ref, id) async => null),
    settingsProvider.overrideWith(() => SettingsNotifier(directory: () async => dir)),
  ],
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('kiji_vistas_'));
  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException catch (error) {
      debugPrint('=== TEST: no se pudo borrar la carpeta temporal: $error ===');
    }
  });

  test('el botón pasa por las tres vistas y vuelve a Completo; las desconocidas vuelven a Completo', () {
    expect(nextLyricsPanel('full'), 'simple');
    expect(nextLyricsPanel('simple'), 'showcase');
    expect(nextLyricsPanel('showcase'), 'full');
    expect(AppSettings.fromJson({'lyricsPanel': 'raro'}).lyricsPanel, 'full');
    final back = AppSettings.fromJson(
      const AppSettings().copyWith(lyricsPanel: 'showcase', showcaseMark: true, lyricsLayout: 'double').toJson(),
    );
    expect([back.lyricsPanel, back.showcaseMark, back.lyricsLayout], ['showcase', true, 'double']);
    expect(const AppSettings().showcaseMark, isFalse, reason: 'la marca Kiji viene apagada');
  });

  testWidgets('Escaparate: los botones se esconden a los 3 s y vuelven al tocar', (tester) async {
    await tester.pumpWidget(
      _app(
        ChromeAutoHide(
          enabled: true,
          child: Column(
            children: [
              const HideWhenIdle(child: Text('barra de arriba')),
              Expanded(child: Container(color: Colors.black)),
            ],
          ),
        ),
        dir,
      ),
    );
    double opacity() => tester
        .widget<AnimatedOpacity>(find.ancestor(of: find.text('barra de arriba'), matching: find.byType(AnimatedOpacity)))
        .opacity;
    expect(opacity(), 1);
    await tester.pump(const Duration(seconds: 2));
    expect(opacity(), 1, reason: 'antes de los 3 s sigue a la vista');
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
    expect(opacity(), 0);
    await tester.tapAt(const Offset(200, 400));
    await tester.pump();
    expect(opacity(), 1, reason: 'vuelve al tocar la pantalla');
  });

  for (final (name, size) in [
    ('teléfono', const Size(390, 780)),
    ('horizontal', const Size(330, 380)), // la columna derecha del teléfono girado
    ('PC', const Size(440, 860)),
  ]) {
    testWidgets('Escaparate y Simple entran sin desbordes ($name)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(const LyricsShowcase(track: _track, line: 'The sun is warm today'), dir),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(find.text('Paper Lanterns'), findsOneWidget);
      expect(find.text('The sun is warm today'), findsOneWidget);

      await tester.pumpWidget(_app(const LyricsSimplePanel(track: _track), dir));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(find.byType(Slider), findsNWidgets(2), reason: 'progreso y volumen');

      await tester.pumpWidget(_app(const LyricsSimplePanel(track: _track, compact: true), dir));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  }
}
