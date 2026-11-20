// "Reproduciendo desde" dice de dónde empezó a sonar la canción, aunque se descargue sola a mitad.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/l10n/l10n.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/playback_provider.dart';
import 'package:kiji_player/screens/player/player_screen.dart';

const _yt = Track(
  id: 'yt-aaaaaaaaaaa',
  title: 'Canción Inventada',
  artist: 'Artista Inventado',
  coverColor: Color(0xFF7C5CFF),
  audioUrl: '',
  source: TrackSource.youtube,
);

void main() {
  setUp(() => setKijiLocale(const Locale('en')));
  tearDown(() => setKijiLocale(const Locale('es')));

  test('Empezó por YouTube y se descargó a mitad: sigue diciendo YouTube Music', () {
    expect(playingFromLabel(_yt, downloaded: true, origin: AudioOrigin.stream), 'YOUTUBE MUSIC');
    expect(playingFromLabel(_yt, downloaded: true, origin: AudioOrigin.cache), 'YOUTUBE MUSIC');
  });

  test('Empezó desde la descarga: Descargadas', () {
    expect(playingFromLabel(_yt, downloaded: true, origin: AudioOrigin.download), tx.descargadas2);
  });

  test('Sin origen anotado (todavía cargando): como antes', () {
    expect(playingFromLabel(_yt, downloaded: true), tx.descargadas2);
    expect(playingFromLabel(_yt, downloaded: false), 'YOUTUBE MUSIC');
  });
}
