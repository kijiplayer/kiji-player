// Saltar las partes sin música (SponsorBlock, 0.9): solo se manda un prefijo del hash, se usan
// solo los tramos del video que suena, y cada tramo se salta una vez (Deshacer lo respeta).
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/features/sponsorblock/sponsorblock.dart';

void main() {
  const id = 'abcdEFGHijk'; // ID inventado

  test('Se manda solo un prefijo de 4 caracteres del SHA-256, nunca el ID', () {
    final prefix = hashPrefixFor(id);
    expect(prefix, hasLength(4));
    expect(prefix, sha256.convert(utf8.encode(id)).toString().substring(0, 4));
    expect(prefix, isNot(contains(id)));
  });

  test('De la respuesta, solo los tramos de este video y de las categorías conocidas', () {
    final json = [
      {
        'videoID': 'otroVideo00',
        'segments': [
          {'category': 'intro', 'segment': [0, 10], 'actionType': 'skip'},
        ],
      },
      {
        'videoID': id,
        'segments': [
          {'category': 'outro', 'segment': [200.5, 230], 'actionType': 'skip'},
          {'category': 'music_offtopic', 'segment': [0, 12.25], 'actionType': 'skip'},
          {'category': 'poi_highlight', 'segment': [50, 50], 'actionType': 'poi'},
          {'category': 'intro', 'segment': [80, 90], 'actionType': 'mute'},
        ],
      },
    ];
    final segments = parseSkipSegments(json, id);
    expect(segments, [
      const SkipSegment(start: Duration.zero, end: Duration(milliseconds: 12250), category: SkipCategory.musicOfftopic),
      const SkipSegment(start: Duration(milliseconds: 200500), end: Duration(seconds: 230), category: SkipCategory.outro),
    ]);
    expect(parseSkipSegments(json, 'noEsta0000'), isEmpty);
    expect(parseSkipSegments('respuesta rara', id), isEmpty);
  });

  test('Salta una vez por tramo; lo deshecho no se vuelve a saltar; casi al final, no salta', () {
    const intro = SkipSegment(start: Duration.zero, end: Duration(seconds: 15), category: SkipCategory.intro);
    final done = <SkipSegment>{};
    expect(segmentToSkip([intro], const Duration(seconds: 2), done), intro);
    done.add(intro); // saltado (o deshecho)
    expect(segmentToSkip([intro], const Duration(seconds: 3), done), isNull);
    expect(segmentToSkip([intro], const Duration(milliseconds: 14500), <SkipSegment>{}), isNull, reason: 'queda <1 s');
    expect(segmentToSkip([intro], const Duration(seconds: 20), <SkipSegment>{}), isNull);
  });

  test('Apagado de fábrica, con categorías de música elegidas para cuando se prenda', () {
    const s = AppSettings();
    expect(s.sponsorBlock, isFalse);
    expect(s.sponsorBlockCategories, defaultSkipCategories);
    final back = AppSettings.fromJson(s.copyWith(sponsorBlock: true, sponsorBlockCategories: ['intro']).toJson());
    expect(back.sponsorBlock, isTrue);
    expect(back.sponsorBlockCategories, ['intro']);
  });
}
