// Scrobbling a ListenBrainz (0.9): cuándo cuenta una escucha, qué se manda (nada más que eso) y
// que se manda una sola vez por reproducción, contando solo lo que de verdad sonó.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/scrobble/listenbrainz.dart';
import 'package:kiji_player/features/scrobble/scrobble_provider.dart';
import 'package:kiji_player/models/track.dart';

const _track = Track(
  id: 'local-7',
  title: 'Glass Harbor',
  artist: 'The Velvet Tides',
  album: 'Canciones Inventadas',
  coverColor: Color(0xFF7C5CFF),
  audioUrl: '/musica/inventada.mp3',
  source: TrackSource.local,
  durationMs: 200000, // 3:20
);

void main() {
  test('La mitad o 4 minutos, lo que llegue primero; menos de 30 s, nunca', () {
    expect(shouldScrobble(played: const Duration(seconds: 99), length: const Duration(seconds: 200)), isFalse);
    expect(shouldScrobble(played: const Duration(seconds: 100), length: const Duration(seconds: 200)), isTrue);
    expect(shouldScrobble(played: const Duration(minutes: 4), length: const Duration(minutes: 20)), isTrue);
    expect(shouldScrobble(played: const Duration(seconds: 25), length: const Duration(seconds: 25)), isFalse);
  });

  test('Se manda solo artista, título, álbum, duración y la hora (nada del archivo ni del usuario)', () {
    final payload = listenPayload(_track, DateTime.utc(2026, 11, 26, 20));
    expect(payload['listened_at'], DateTime.utc(2026, 11, 26, 20).millisecondsSinceEpoch ~/ 1000);
    final meta = payload['track_metadata']! as Map;
    expect(meta['artist_name'], 'The Velvet Tides');
    expect(meta['track_name'], 'Glass Harbor');
    expect(meta['release_name'], 'Canciones Inventadas');
    expect(payload.toString(), isNot(contains('/musica/')), reason: 'la ruta del archivo no sale');
  });

  test('Cuenta lo que sonó (no los saltos) y manda una sola vez', () {
    final tracker = ScrobbleTracker()..start(_track, DateTime(2026, 11, 26));
    var position = Duration.zero;
    ({Track track, DateTime startedAt})? sent;
    // Un salto de 90 s no cuenta.
    tracker.tick(position, playing: true);
    position += const Duration(seconds: 90);
    expect(tracker.tick(position, playing: true), isNull);
    // Sonando de a 1 s: a los 100 s escuchados (la mitad de 200), se manda.
    for (var i = 0; i < 99; i++) {
      position += const Duration(seconds: 1);
      expect(tracker.tick(position, playing: true), isNull, reason: 'todavía no: $i s');
    }
    position += const Duration(seconds: 1);
    sent = tracker.tick(position, playing: true);
    expect(sent?.track.id, _track.id);
    position += const Duration(seconds: 1);
    expect(tracker.tick(position, playing: true), isNull, reason: 'una sola vez');
  });

  test('En pausa no cuenta', () {
    final tracker = ScrobbleTracker()..start(_track, DateTime(2026, 11, 26));
    var position = Duration.zero;
    tracker.tick(position, playing: false);
    for (var i = 0; i < 150; i++) {
      position += const Duration(seconds: 1);
      expect(tracker.tick(position, playing: false), isNull);
    }
  });
}
