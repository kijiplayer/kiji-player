// Prueba cada fuente de letras contra el servicio real (Tarea Z4). A mano:
//   flutter test test_live/lyrics_sources_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/lyrics/data/lyrics_repository.dart';
import 'package:kiji_player/features/lyrics/data/lyrics_sources.dart';

void main() {
  test('cada fuente', () async {
    final songs = <LyricsRequest>[
      (id: 'yt-BSTsnWoslP4', title: 'Bohemian Rhapsody', artist: 'Queen', album: 'A Night at the Opera', durationMs: 354000, localPath: null),
      (id: 'yt-4D7u5KF7SP8', title: 'Get Lucky', artist: 'Daft Punk', album: 'Random Access Memories', durationMs: 369000, localPath: null),
    ];
    for (final fetcher in defaultLyricsFetchers()) {
      final parts = <String>[];
      for (final song in songs) {
        final watch = Stopwatch()..start();
        try {
          final l = await fetcher.fetch(song).timeout(const Duration(seconds: 25));
          parts.add(l == null
              ? 'no está'
              : l.isSynced
                  ? '${l.synced.length} líneas sinc. («${l.synced.firstWhere((x) => x.text.isNotEmpty).text}»)'
                  : 'texto (${l.plain!.length} car.)');
        } catch (e) {
          parts.add('ERROR $e');
        }
        parts.last += ' ${watch.elapsedMilliseconds}ms';
      }
      // ignore: avoid_print
      print('FUENTE ${fetcher.source.label}: ${parts.join(' | ')}');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
