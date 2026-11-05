import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/customize/data/track_overrides.dart';
import 'package:kiji_player/features/customize/presentation/track_style_sheet.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/playback_provider.dart';

const _song = Track(
  id: 'yt-inventada',
  title: 'Canción inventada',
  artist: 'Grupo Inventado',
  coverColor: Color(0xFF3A6EA5),
  audioUrl: '',
  source: TrackSource.youtube,
);

class _Playback extends PlaybackNotifier {
  _Playback(this.track);
  final Track? track;
  @override
  PlaybackState build() => PlaybackState(
    track: track,
    isPlaying: false,
    position: Duration.zero,
    duration: const Duration(minutes: 3),
    shuffleEnabled: false,
    isInitialized: true,
    queue: const [],
    currentIndex: 0,
    repeatMode: PlaybackRepeatMode.off,
  );
}

Future<Directory> _noDisk() async => throw const FileSystemException('sin disco en el test');

void main() {
  test('El estilo de una canción se guarda y se lee; nunca una ruta de archivo', () {
    const style = TrackOverride(title: 'Otro', accent: 0xFFFF9800, backgroundFile: 'cancion-x.png', lyricsPanel: 'simple');
    final back = TrackOverride.fromJson(style.toJson());
    expect((back.title, back.accent, back.backgroundFile, back.backgroundKind, back.lyricsPanel),
        ('Otro', 0xFFFF9800, 'cancion-x.png', 'image', 'simple'));
    expect(TrackOverride.fromJson({'backgroundFile': r'..\otra\carpeta.png'}).backgroundFile, isNull);
    expect(TrackOverride.fromJson({'lyricsPanel': 'raro'}).lyricsPanel, isNull);
    // "Volver al estilo general" deja el título, el artista y la foto propios.
    expect(style.withoutStyle.title, 'Otro');
    expect(style.withoutStyle.hasStyle, isFalse);
  });

  test('El estilo manda solo mientras suena esa canción', () async {
    final c = ProviderContainer(overrides: [
      playbackProvider.overrideWith(() => _Playback(_song)),
      trackOverridesProvider.overrideWith(() => TrackOverridesNotifier(directory: _noDisk)),
    ]);
    addTearDown(c.dispose);
    expect(c.read(currentTrackStyleProvider), isNull);
    c.read(trackOverridesProvider.notifier).setStyle(_song.id, (s) => s.copyWith(accent: 0xFFE53935));
    expect(c.read(currentTrackStyleProvider)?.accent, 0xFFE53935);
    c.read(trackOverridesProvider.notifier).setStyle('yt-otra', (s) => s.copyWith(accent: 0xFF2EE6A6));
    expect(c.read(currentTrackStyleProvider)?.accent, 0xFFE53935, reason: 'la de otra canción no cuenta');
    c.read(trackOverridesProvider.notifier).clearStyle(_song.id);
    expect(c.read(currentTrackStyleProvider), isNull);
  });

  testWidgets('La hoja: elegir un color y volver al estilo general', (tester) async {
    tester.view.physicalSize = const Size(420, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = ProviderContainer(overrides: [
      playbackProvider.overrideWith(() => _Playback(_song)),
      trackOverridesProvider.overrideWith(() => TrackOverridesNotifier(directory: _noDisk)),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: Scaffold(body: TrackStyleSheet(track: _song))),
    ));
    await tester.tap(find.byTooltip('#FF9800'));
    await tester.pump();
    expect(c.read(trackOverridesProvider)[_song.id]?.accent, 0xFFFF9800);
    await tester.tap(find.text('Simple'));
    await tester.pump();
    expect(c.read(trackOverridesProvider)[_song.id]?.lyricsPanel, 'simple');
    await tester.tap(find.byKey(const Key('track-style-reset')));
    await tester.pump();
    expect(c.read(trackOverridesProvider)[_song.id]?.hasStyle ?? false, isFalse);
  });
}
