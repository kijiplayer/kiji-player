import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/downloads/data/storage_info_impl.dart';

void main() {
  group('Salida de df -Pk (macOS)', () {
    test('Toma la columna "Available" en bloques de 1024', () {
      const out = '''
Filesystem   1024-blocks      Used Available Capacity  Mounted on
/dev/disk3s1   971350180 512345678 459004502    53%    /System/Volumes/Data
''';
      expect(parseDfAvailableBytes(out), 459004502 * 1024);
    });

    test('Salida rara: null', () {
      expect(parseDfAvailableBytes(''), isNull);
      expect(parseDfAvailableBytes('Filesystem 1024-blocks Used Available'), isNull);
      expect(parseDfAvailableBytes('a b\nx y z'), isNull);
    });
  });

  test('Linux: statvfs da lo mismo que df (±5 %)', () async {
    final dir = Directory.systemTemp.path;
    final free = await LinuxStorageInfo().freeBytes(dir);
    final df = parseDfAvailableBytes('${(await Process.run('df', ['-Pk', dir])).stdout}');
    expect(free, isNotNull);
    expect(free, greaterThan(0));
    expect(df, isNotNull);
    expect((free! - df!).abs(), lessThanOrEqualTo(df * 0.05 + 1024 * 1024));
  }, skip: !Platform.isLinux ? 'solo en Linux (lo corre el CI)' : false);
}
