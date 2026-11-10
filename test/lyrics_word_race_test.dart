import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/lyrics/data/lrclib_client.dart';
import 'package:kiji_player/features/lyrics/data/lyrics_repository.dart';
import 'package:kiji_player/features/lyrics/data/lyrics_sources.dart';
import 'package:kiji_player/features/lyrics/domain/lyrics.dart';

// Letras inventadas (nunca letras reales).
const _byLine = Lyrics(
  synced: [LyricLine(Duration(seconds: 1), 'Una línea inventada'), LyricLine(Duration(seconds: 60), 'Otra')],
  source: LyricsSource.lrclib,
);
const _byWord = Lyrics(
  synced: [
    LyricLine(
      Duration(seconds: 1),
      'Una línea inventada',
      words: [LyricWord(Duration(seconds: 1), 'Una '), LyricWord(Duration(milliseconds: 1500), 'línea')],
    ),
    LyricLine(Duration(seconds: 60), 'Otra'),
  ],
  source: LyricsSource.youlyplus,
);

class _Fake implements LyricsFetcher {
  _Fake(this.source, {this.lyrics, this.delay = Duration.zero, this.fails = false});

  @override
  final LyricsSource source;
  final Lyrics? lyrics;
  final Duration delay;
  final bool fails;
  int calls = 0;

  @override
  Future<Lyrics?> fetch(LyricsRequest request) async {
    calls++;
    await Future<void>.delayed(delay);
    if (fails) throw const LyricsUnavailableException('403');
    return lyrics;
  }
}

const LyricsRequest _request = (
  id: 'yt-inventada',
  title: 'Canción inventada',
  artist: 'Grupo Inventado',
  album: null,
  durationMs: 180000,
  localPath: null,
);

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('kiji_karaoke_'));
  tearDown(() => dir.deleteSync(recursive: true));

  LyricsRepository repo(List<LyricsFetcher> fetchers, {DateTime Function()? clock}) =>
      LyricsRepository(fetchers: fetchers, baseDirectory: () async => dir, clock: clock);

  test('Si una fuente con palabras responde a tiempo, gana sobre la de línea (aunque LRCLIB va primero)', () async {
    final words = _Fake(LyricsSource.youlyplus, lyrics: _byWord, delay: const Duration(milliseconds: 300));
    final lyrics = await repo([_Fake(LyricsSource.lrclib, lyrics: _byLine), words]).get(_request);
    expect(lyrics.hasWordTiming, isTrue);
    expect(lyrics.source, LyricsSource.youlyplus);
  });

  test('Si las de palabras tardan más de 2 s, queda la de línea', () async {
    final slow = _Fake(LyricsSource.youlyplus, lyrics: _byWord, delay: const Duration(seconds: 4));
    final watch = Stopwatch()..start();
    final lyrics = await repo([_Fake(LyricsSource.lrclib, lyrics: _byLine), slow]).get(_request);
    expect(lyrics.source, LyricsSource.lrclib);
    expect(watch.elapsed, lessThan(const Duration(milliseconds: 3500)), reason: 'no espera de más');
  });

  test('Una fuente que da 403 queda en pausa: no se le vuelve a preguntar enseguida, sin avisos', () async {
    var now = DateTime(2026, 11, 10, 12);
    final broken = _Fake(LyricsSource.paxsenix, fails: true);
    final r = repo([_Fake(LyricsSource.lrclib, lyrics: _byLine), broken], clock: () => now);
    expect((await r.search(_request)).source, LyricsSource.lrclib);
    expect(broken.calls, 1);
    await r.search(_request);
    expect(broken.calls, 1, reason: 'en pausa');
    now = now.add(LyricsRepository.failureCooldown + const Duration(minutes: 1));
    await r.search(_request);
    expect(broken.calls, 2, reason: 'pasada la pausa se vuelve a probar');
  });
}
