import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/lyrics/data/lrclib_client.dart';
import 'package:kiji_player/features/lyrics/data/lyrics_repository.dart';
import 'package:kiji_player/features/lyrics/data/lyrics_sources.dart';
import 'package:kiji_player/features/lyrics/domain/lyrics.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';

/// Fuente falsa: devuelve lo que se le dice y anota si la llamaron.
class _Fake implements LyricsFetcher {
  _Fake(this.source, {this.lyrics, this.offline = false});
  @override
  final LyricsSource source;
  final Lyrics? lyrics;
  final bool offline;
  int calls = 0;
  @override
  Future<Lyrics?> fetch(LyricsRequest request) async {
    calls++;
    if (offline) throw LyricsUnavailableException('${source.label} no respondió');
    return lyrics;
  }
}

LyricsRequest _req({String id = 'yt-abcdefghijk', String title = 'Tema', String artist = 'Artista'}) =>
    (id: id, title: title, artist: artist, album: null, durationMs: 200000, localPath: null);

void main() {
  group('formatos', () {
    test('LRC con marcas por palabra y coro de fondo', () {
      final lines = parseLrc('[00:01.00]<00:01.00>Hola <00:01.50>mundo\n[00:03.20]{bg}Coro');
      expect(lines.map((l) => l.text), ['Hola mundo', 'Coro']);
      expect(lines.first.time, const Duration(seconds: 1));
    });

    test('texto: sincronizada, simple, o nada', () {
      expect(lyricsFromText('[00:01.00]Uno', LyricsSource.kugou)!.isSynced, isTrue);
      expect(lyricsFromText('Una letra\nsin tiempos', LyricsSource.youtubeMusic)!.plain, startsWith('Una letra'));
      expect(lyricsFromText('   ', LyricsSource.kugou), isNull);
      expect(lyricsFromText('[00:01.00]\n[00:02.00]', LyricsSource.kugou), isNull, reason: 'solo marcas');
    });

    test('TTML de Better Lyrics', () {
      const ttml = '<tt xmlns:ttm="http://www.w3.org/ns/ttml#metadata"><body><div>'
          '<p begin="1.5s" end="3s"><span begin="1.5s">The</span> <span>sun</span> is warm today</p>'
          '<p begin="00:01:02.250">We walk <span ttm:role="x-bg">(coro)</span>along the river &amp; sing</p>'
          '</div></body></tt>';
      final lines = parseTtml(ttml);
      expect(lines.map((l) => l.text), ['The sun is warm today', 'We walk along the river & sing']);
      expect(lines[1].time, const Duration(minutes: 1, seconds: 2, milliseconds: 250));
    });

    test('KuGou: se sacan los créditos del principio y del final', () {
      const raw = '[00:00.00]Autor - Canción de prueba\n[00:01.00]作词：Autor Inventado\n'
          '[00:05.00]The sun is warm today\n[00:07.00]We walk along the river\n[03:00.00]制作：Estudio';
      expect(KuGouFetcher.normalizeKuGou(raw), '[00:05.00]The sun is warm today\n[00:07.00]We walk along the river');
    });

    test('subtítulos de YouTube: la pista en el idioma del canto, a LRC', () {
      final tracks = <Map>[
        {'languageCode': 'de-DE'},
        {'languageCode': 'en', 'kind': 'asr'},
        {'languageCode': 'en-GB'},
      ];
      expect(YouTubeSubtitlesFetcher.pickCaptionTrack(tracks)!['languageCode'], 'en-GB');
      expect(YouTubeSubtitlesFetcher.pickCaptionTrack([{'languageCode': 'es', 'kind': 'asr'}])!['kind'], 'asr');
      final json3 = jsonEncode({
        'events': [
          {'tStartMs': 18800},
          {
            'tStartMs': 27000,
            'segs': [
              {'utf8': '♪ We walk '},
              {'utf8': 'along the river ♪'},
            ],
          },
        ],
      });
      expect(YouTubeSubtitlesFetcher.captionsToLrc(json3), '[00:27.000]We walk along the river');
    });
  });

  group('varias fuentes, en orden', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('kiji_z4_'));
    tearDown(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('si una no la tiene o no responde, prueba la siguiente; respeta las apagadas', () async {
      final none = _Fake(LyricsSource.lrclib);
      final down = _Fake(LyricsSource.youlyplus, offline: true);
      final off = _Fake(LyricsSource.unison, lyrics: const Lyrics(plain: 'no', source: LyricsSource.unison));
      final found = _Fake(LyricsSource.kugou, lyrics: lyricsFromText('[00:01.00]Sí', LyricsSource.kugou));
      final after = _Fake(LyricsSource.youtubeMusic, lyrics: const Lyrics(plain: 'tarde', source: LyricsSource.youtubeMusic));
      final repo = LyricsRepository(fetchers: [none, down, off, found, after], baseDirectory: () async => dir);
      final lyrics = await repo.get(_req(), disabled: {LyricsSource.unison});
      expect(lyrics.source, LyricsSource.kugou);
      expect([none.calls, down.calls, off.calls, found.calls, after.calls], [1, 1, 0, 1, 0]);
    });

    test('sin conexión en todas: avisa y no guarda "no hay"', () async {
      final a = _Fake(LyricsSource.lrclib, offline: true);
      final repo = LyricsRepository(fetchers: [a], baseDirectory: () async => dir);
      await expectLater(repo.get(_req()), throwsA(isA<LyricsUnavailableException>()));
      await expectLater(repo.get(_req()), throwsA(isA<LyricsUnavailableException>()));
      expect(a.calls, 2, reason: 'no quedó guardado como "no encontrada"');
    });

    test('buscar a mano, importar un .lrc y desfase por canción', () async {
      final kugou = _Fake(LyricsSource.kugou, lyrics: lyricsFromText('[00:02.00]Encontrada', LyricsSource.kugou));
      final repo = LyricsRepository(fetchers: [kugou], baseDirectory: () async => dir);
      final found = await repo.search(_req(title: 'Otro título'));
      expect(found.synced.single.text, 'Encontrada');
      expect((await repo.get(_req())).synced.single.text, 'Encontrada', reason: 'quedó para la canción');

      await repo.setOffset('yt-abcdefghijk', const Duration(milliseconds: 1500));
      expect(await repo.offset('yt-abcdefghijk'), const Duration(milliseconds: 1500));

      final imported = await repo.importText('yt-abcdefghijk', '[ar:Yo]\n[00:03.50]Mía');
      expect(imported.source, LyricsSource.imported);
      expect(await repo.offset('yt-abcdefghijk'), Duration.zero, reason: 'letra nueva, desfase en 0');
      // Texto sin marcas de tiempo: se guarda como letra simple (esperando a que termine).
      await repo.importText('x', 'nada de nada [sin] marcas');
      await expectLater(repo.importText('x', '   '), throwsA(isA<FormatException>()));
    });
  });

  test('las fuentes apagadas se guardan en los ajustes', () {
    final s = const AppSettings().copyWith(disabledLyricsSources: {LyricsSource.kugou, LyricsSource.paxsenix});
    final back = AppSettings.fromJson(s.toJson());
    expect(back.disabledLyricsSources, {LyricsSource.kugou, LyricsSource.paxsenix});
    expect(AppSettings.fromJson({'disabledLyricsSources': ['no-existe']}).disabledLyricsSources, isEmpty);
    expect(LyricsSource.online.first, LyricsSource.lrclib, reason: 'después de la del archivo, LRCLIB');
  });
}
