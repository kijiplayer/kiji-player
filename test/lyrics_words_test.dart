import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/lyrics/data/lyrics_sources.dart';
import 'package:kiji_player/features/lyrics/domain/lyrics.dart';

// Letras inventadas para las pruebas (nunca letras reales).

Duration _ms(int ms) => Duration(milliseconds: ms);

void main() {
  test('LRC con marcas por palabra: texto limpio y el tiempo de cada palabra', () {
    final lines = parseLrc('[00:10.00]<00:10.00>Hola <00:10.50>mundo <00:11.20>inventado<00:12.00>\n[00:13.00]Sin marcas');
    expect(lines.first.text, 'Hola mundo inventado');
    expect(lines.first.words.map((w) => w.text), ['Hola ', 'mundo ', 'inventado']);
    expect(lines.first.words.map((w) => w.start), [_ms(10000), _ms(10500), _ms(11200)]);
    expect(lines.first.words.last.end, _ms(12000), reason: 'la marca final cierra la última palabra');
    expect(lines.last.hasWords, isFalse, reason: 'sin marcas: por línea, como siempre');
  });

  test('El desfase [offset] también corre las palabras', () {
    final line = parseLrc('[offset:+500]\n[00:10.00]<00:10.00>Uno <00:11.00>dos').single;
    expect(line.time, _ms(9500));
    expect(line.words.map((w) => w.start), [_ms(9500), _ms(10500)]);
  });

  test('TTML con sílabas: los espacios entre <span> quedan en la palabra de antes', () {
    const ttml = '<tt><body><div>'
        '<p begin="1.0s" end="3.0s"><span begin="1.0s" end="1.4s">Can</span><span begin="1.4s" end="1.8s">ción</span> '
        '<span begin="2.0s" end="2.8s">nueva</span><span ttm:role="x-bg"><span begin="2.1s">(coro)</span></span></p>'
        '<p begin="4.0s">Línea sin sílabas</p>'
        '</div></body></tt>';
    final lines = parseTtml(ttml);
    expect(lines.first.text, 'Canción nueva', reason: 'sin el coro de fondo');
    expect(lines.first.words.map((w) => w.text), ['Can', 'ción ', 'nueva']);
    expect(lines.first.words.map((w) => (w.start, w.end)), [
      (_ms(1000), _ms(1400)),
      (_ms(1400), _ms(1800)),
      (_ms(2000), _ms(2800)),
    ]);
    expect(lines.last.hasWords, isFalse);
  });

  test('YouLyPlus: sílabas con tiempo y duración, sin las del coro de fondo', () {
    final lyrics = YouLyPlusFetcher.itemsToLyrics([
      {
        'time': 5000,
        'syllabus': [
          {'time': 5000, 'duration': 300, 'text': 'Pa'},
          {'time': 5300, 'duration': 400, 'text': 'la '},
          {'time': 5700, 'duration': 500, 'text': 'bra'},
          {'time': 5900, 'duration': 500, 'text': 'eco', 'isBackground': true},
        ],
      },
      {'time': 8000, 'text': 'Otra línea'},
    ], LyricsSource.youlyplus)!;
    final first = lyrics.synced.first;
    expect(first.text, 'Pala bra');
    expect(first.words.map((w) => w.text), ['Pa', 'la ', 'bra']);
    expect(first.words.last.end, _ms(6200));
    expect(lyrics.synced.last.text, 'Otra línea');
    expect(lyrics.synced.last.hasWords, isFalse);
  });

  test('Tiempos que no tienen sentido no se usan: la línea queda por línea', () {
    // Desordenadas.
    expect(sanitizeWords([LyricWord(_ms(9000), 'b'), LyricWord(_ms(5000), 'a')], _ms(5000)), isEmpty);
    // Muy lejos de la línea.
    expect(sanitizeWords([LyricWord(_ms(500000), 'a')], _ms(5000)), isEmpty);
    // Termina antes de empezar.
    expect(sanitizeWords([LyricWord(_ms(6000), 'a', _ms(5500))], _ms(5000)), isEmpty);
    // Bien.
    expect(sanitizeWords([LyricWord(_ms(5000), 'a '), LyricWord(_ms(5400), 'b')], _ms(5000)), hasLength(2));
  });

  test('Las palabras se guardan en la caché y se leen igual', () {
    final lyrics = Lyrics(synced: parseLrc('[00:01.00]<00:01.00>Uno <00:01.50>dos<00:02.00>'), source: LyricsSource.lrclib);
    final back = Lyrics.fromJson(lyrics.toJson());
    expect(back.synced.single.words.map((w) => (w.start, w.text, w.end)),
        lyrics.synced.single.words.map((w) => (w.start, w.text, w.end)));
    // Una caché vieja (sin palabras) se sigue leyendo.
    final old = Lyrics.fromJson({
      'synced': [
        {'ms': 1000, 'text': 'Vieja'},
      ],
    });
    expect(old.synced.single.hasWords, isFalse);
  });

  group('Cuánto de la línea ya sonó (karaoke)', () {
    test('con tiempos por palabra: sigue cada palabra, no un reparto parejo', () {
      final line = parseLrc('[00:10.00]<00:10.00>Hola <00:11.00>mundo<00:13.00>').single;
      expect(sungCharacters(line, _ms(9000)), 0);
      expect(sungCharacters(line, _ms(10500)), closeTo(2, 0.01), reason: 'mitad de "Hola"');
      expect(sungCharacters(line, _ms(11000)), 5, reason: '"Hola " entera');
      expect(sungCharacters(line, _ms(12000)), closeTo(7.5, 0.01), reason: 'mitad de "mundo" (2 s)');
      expect(sungCharacters(line, _ms(14000)), line.text.length);
    });

    test('sin tiempos por palabra: se llena parejo hasta la línea siguiente', () {
      const line = LyricLine(Duration(seconds: 10), 'Diez letra');
      expect(sungCharacters(line, _ms(11000), next: _ms(12000)), closeTo(5, 0.01));
      expect(sungCharacters(line, _ms(13000), next: _ms(12000)), 10);
      // Una pausa larga hasta la siguiente: tope de 3 s para una línea corta.
      expect(sungCharacters(line, _ms(11500), next: _ms(40000)), closeTo(5, 0.01));
      expect(sungCharacters(const LyricLine(Duration.zero, ''), _ms(5000)), 0);
    });
  });
}
