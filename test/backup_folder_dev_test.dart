import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/backup/data/backup_folder.dart';

void main() {
  test('Kiji guarda en Documentos/Kiji (Kiji Dev usa Documentos/Kiji Dev)', () {
    // Las pruebas corren sin --flavor dev: es Kiji normal.
    expect(backupFolderName, 'Kiji');
  });

  test('Una carpeta en la que se puede escribir pasa la revisión', () async {
    final dir = Directory.systemTemp.createTempSync('kiji_copias');
    addTearDown(() => dir.deleteSync(recursive: true));
    expect(await checkWritable(Directory('${dir.path}/Kiji Dev')), isNull);
  });
}
