import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/lyrics/data/screen_mode_impl.dart';
import 'package:kiji_player/features/lyrics/domain/lyrics.dart';
import 'package:kiji_player/features/lyrics/domain/screen_mode.dart';
import 'package:kiji_player/features/lyrics/lyrics_provider.dart';
import 'package:kiji_player/features/lyrics/presentation/lyrics_fullscreen.dart';
import 'package:kiji_player/features/lyrics/presentation/lyrics_screen.dart';
import 'package:kiji_player/features/lyrics/presentation/lyrics_side_panel.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/playback_provider.dart';

// Letra inventada (nunca letras reales).

class _Mode implements ScreenMode {
  final calls = <bool>[];
  @override
  Future<void> setFullScreen(bool on) async => calls.add(on);
}

class _Playback extends PlaybackNotifier {
  @override
  PlaybackState build() => const PlaybackState(
    track: Track(
      id: 'yt-inventada',
      title: 'Inventada',
      artist: 'Grupo Inventado',
      coverColor: Color(0xFF3A6EA5),
      audioUrl: '',
      source: TrackSource.youtube,
    ),
    isPlaying: false,
    position: Duration(seconds: 3),
    duration: Duration(minutes: 3),
    shuffleEnabled: false,
    isInitialized: true,
    queue: [],
    currentIndex: 0,
    repeatMode: PlaybackRepeatMode.off,
  );
}

Future<Directory> _noDisk() async => throw const FileSystemException('sin disco en el test');

void main() {
  testWidgets('Pantalla completa: solo la letra, Esc sale y al cerrar la letra la ventana vuelve a lo normal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final mode = _Mode();
    final container = ProviderContainer(overrides: [
      playbackProvider.overrideWith(_Playback.new),
      settingsProvider.overrideWith(() => SettingsNotifier(directory: _noDisk)),
      screenModeProvider.overrideWithValue(mode),
      lyricsProvider.overrideWith(
        (ref, request) async => Lyrics(
          synced: [for (var i = 0; i < 8; i++) LyricLine(Duration(seconds: 2 * i), 'Línea inventada $i')],
          source: LyricsSource.lrclib,
        ),
      ),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(onPressed: () => LyricsScreen.open(context), child: const Text('abrir')),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.byType(LyricsSidePanel), findsOneWidget, reason: 'en la PC, la letra con su panel');

    await tester.tap(find.byKey(const Key('lyrics-fullscreen')));
    await tester.pumpAndSettle();
    expect(mode.calls, [true]);
    expect(find.byType(LyricsSidePanel), findsNothing, reason: 'a pantalla completa, solo la letra');
    expect(find.byTooltip('Salir de pantalla completa'), findsOneWidget);

    // Las barras se esconden solas sin tocar nada.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    final header = tester.widget<AnimatedOpacity>(
      find.ancestor(of: find.byKey(const Key('lyrics-fullscreen')), matching: find.byType(AnimatedOpacity)).first,
    );
    expect(header.opacity, 0);

    // Esc sale.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(mode.calls, [true, false]);
    expect(find.byType(LyricsSidePanel), findsOneWidget);

    // Otra vez a pantalla completa y se cierra la letra: la ventana vuelve a lo normal.
    await tester.tap(find.byKey(const Key('lyrics-fullscreen')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cerrar la letra'));
    await tester.pumpAndSettle();
    expect(mode.calls, [true, false, true, false]);
    expect(container.read(lyricsFullscreenProvider), isFalse);
  });
}
