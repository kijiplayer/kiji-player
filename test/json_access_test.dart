import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/yt_music/domain/subtitle_parser.dart';
import 'package:kiji_player/utils/json_access.dart';

void main() {
  group('jsonAt', () {
    final json = {
      'a': {
        'b': [
          {'c': 'hola'},
        ],
      },
      'texto': 'no es un mapa',
    };

    test('recorre mapas y listas', () {
      expect(jsonAt(json, const ['a', 'b', 0, 'c']), 'hola');
      expect(jsonStringAt(json, const ['a', 'b', 0, 'c']), 'hola');
      expect(jsonListAt(json, const ['a', 'b']), hasLength(1));
    });

    test('forma inesperada: null en vez de error', () {
      expect(jsonAt(json, const ['texto', 'runs']), isNull);
      expect(jsonAt(json, const ['a', 'b', 5, 'c']), isNull);
      expect(jsonAt(json, const ['a', 'b', 'c']), isNull);
      expect(jsonAt(null, const ['a']), isNull);
      expect(jsonListAt(json, const ['texto']), isNull);
      expect(jsonStringAt(json, const ['a']), isNull);
    });
  });

  group('parseSubtitleRuns con datos raros de YouTube', () {
    test('runs que no son mapas o sin texto no rompen ni agregan "null"', () {
      final parsed = parseSubtitleRuns([
        {'text': 'Canción'},
        {'text': ' • '},
        'algo raro',
        {'sin': 'texto'},
        {'text': 'Mira Solenne'},
        {
          'text': ' • ',
          'navigationEndpoint': 'no es un mapa',
        },
        {'text': '3:48'},
      ]);
      expect(parsed.artist, 'Mira Solenne');
      expect(parsed.durationMs, 228000);
    });
  });
}
