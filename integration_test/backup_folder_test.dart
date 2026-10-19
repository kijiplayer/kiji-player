// Carpeta de las copias en la PC (Tarea U). SOLO EN PC:
//   flutter test integration_test/backup_folder_test.dart -d windows
// NUNCA en el celular real (en el teléfono borraría los datos de la app).
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kiji_player/features/backup/data/backup_folder.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Documentos/Kiji existe y se puede escribir', (tester) async {
    final folder = await defaultBackupFolder();
    debugPrint('=== COPIA PC: ${folder.path}');
    expect(folder.path.replaceAll(r'\', '/'), endsWith('Documents/Kiji'));
    expect(await checkWritable(folder), isNull);
  });
}
