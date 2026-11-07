import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/lyrics/data/lyrics_repository.dart';
import 'package:kiji_player/features/lyrics/data/lyrics_sources.dart';
import 'package:kiji_player/features/lyrics/domain/lyrics.dart';

// Letras inventadas (nunca letras reales).

class _Fake implements LyricsFetcher {
  _Fake(this.source, this.lyrics);
  @override
  final LyricsSource source;
  final Lyrics? lyrics;
  int calls = 0;
  @override
  Future<Lyrics?> fetch(LyricsRequest request) async {
    calls++;
    return lyrics;
  }
}

LyricsRequest _request(int seconds) => (
  id: 'yt-inventado',
  title: 'Canción inventada',
  artist: 'Grupo Inventado',
  album: null,
  durationMs: seconds * 1000,
  localPath: null,
);

/// Una letra inventada con líneas cada [every] segundos desde [from].
Lyrics _synced(LyricsSource source, {int from = 10, int lines = 10, int every = 10}) => Lyrics(
  synced: [for (var i = 0; i < lines; i++) LyricLine(Duration(seconds: from + i * every), 'Línea inventada $i')],
  source: source,
);

void main() {
  group('¿La letra encaja con la canción?', () {
    test('encaja: empieza temprano y la última línea es antes del final', () {
      expect(syncMatches(_synced(LyricsSource.lrclib), const Duration(seconds: 120)), isTrue);
      expect(syncMatches(_synced(LyricsSource.lrclib), Duration.zero), isTrue, reason: 'sin duración no se puede saber');
      expect(syncMatches(const Lyrics(plain: 'Texto'), const Duration(seconds: 5)), isTrue);
    });

    test('no encaja: la última línea pasa el final (otra versión, más larga)', () {
      // Líneas hasta los 100 s en una canción de 60 s.
      expect(syncMatches(_synced(LyricsSource.lrclib), const Duration(seconds: 60)), isFalse);
      // Con el margen de 3 s sí.
      expect(syncMatches(_synced(LyricsSource.lrclib), const Duration(seconds: 98)), isTrue);
    });

    test('no encaja: corrida (empieza pasado el 60 %) o desordenada; una intro larga sí encaja', () {
      expect(syncMatches(_synced(LyricsSource.lrclib, from: 120, lines: 2), const Duration(seconds: 180)), isFalse);
      expect(syncMatches(_synced(LyricsSource.lrclib, from: 90, lines: 2), const Duration(seconds: 180)), isTrue,
          reason: 'empieza a la mitad: puede ser una intro larga');
      const messy = Lyrics(synced: [
        LyricLine(Duration(seconds: 20), 'b'),
        LyricLine(Duration(seconds: 10), 'a'),
      ]);
      expect(syncMatches(messy, const Duration(seconds: 120)), isFalse);
    });
  });

  group('Al buscar', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('kiji_sincronia_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('si la primera no encaja, se usa la siguiente que sí', () async {
      final longer = _Fake(LyricsSource.lrclib, _synced(LyricsSource.lrclib, every: 20)); // hasta los 190 s
      final good = _Fake(LyricsSource.youlyplus, _synced(LyricsSource.youlyplus));
      final repository = LyricsRepository(fetchers: [longer, good], baseDirectory: () async => dir);
      final lyrics = await repository.get(_request(120));
      expect(lyrics.source, LyricsSource.youlyplus);
      expect(lyrics.isSynced, isTrue);
    });

    test('si ninguna sincronizada encaja, se muestra la letra sin sincronizar (sin avisos)', () async {
      final repository = LyricsRepository(
        fetchers: [_Fake(LyricsSource.lrclib, _synced(LyricsSource.lrclib, every: 20))],
        baseDirectory: () async => dir,
      );
      final lyrics = await repository.get(_request(60));
      expect(lyrics.isSynced, isFalse);
      expect(lyrics.plain, startsWith('Línea inventada 0\nLínea inventada 1'));
      expect(lyrics.source, LyricsSource.lrclib);
    });

    test('la elegida a mano se respeta aunque no encaje', () async {
      final repository = LyricsRepository(fetchers: [_Fake(LyricsSource.kugou, null)], baseDirectory: () async => dir);
      await repository.choose('yt-inventado', _synced(LyricsSource.lrclib, every: 20));
      final lyrics = await repository.get(_request(60));
      expect(lyrics.isSynced, isTrue);
    });
  });
}
