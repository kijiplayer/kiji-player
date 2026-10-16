import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/system_media/data/cover_art.dart';

void main() {
  test('La portada de la pantalla de bloqueo pide la miniatura grande', () {
    expect(
      largerThumbnailUrl('https://lh3.googleusercontent.com/abc=w60-h60-l90-rj'),
      'https://lh3.googleusercontent.com/abc=w544-h544-l90-rj',
    );
    // Las de i.ytimg.com no tienen tamaño en la URL: quedan igual.
    expect(
      largerThumbnailUrl('https://i.ytimg.com/vi/abc/hqdefault.jpg'),
      'https://i.ytimg.com/vi/abc/hqdefault.jpg',
    );
  });
}
