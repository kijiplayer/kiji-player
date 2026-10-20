import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/utils/file_exists_cache.dart';

void main() {
  test('Lo que existe se recuerda: no se vuelve a preguntar al disco', () {
    var asked = 0;
    final cache = FileExistsCache(exists: (_) {
      asked++;
      return true;
    });
    for (var i = 0; i < 50; i++) {
      expect(cache.exists('a.png'), isTrue);
    }
    expect(asked, 1);
  });

  test('Lo que falta se vuelve a mirar pasado un rato (por si se bajó después)', () {
    var now = DateTime(2026, 10, 20, 12);
    var onDisk = false;
    var asked = 0;
    final cache = FileExistsCache(
      recheckMissingAfter: const Duration(seconds: 20),
      clock: () => now,
      exists: (_) {
        asked++;
        return onDisk;
      },
    );
    expect(cache.exists('b.png'), isFalse);
    onDisk = true;
    now = now.add(const Duration(seconds: 5));
    expect(cache.exists('b.png'), isFalse, reason: 'todavía dentro de los 20 s');
    expect(asked, 1);
    now = now.add(const Duration(seconds: 20));
    expect(cache.exists('b.png'), isTrue);
    expect(asked, 2);
  });

  test('No crece sin límite', () {
    final cache = FileExistsCache(maxEntries: 10, exists: (_) => true);
    for (var i = 0; i < 100; i++) {
      cache.exists('$i.png');
    }
    expect(cache.exists('99.png'), isTrue);
  });
}
