import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/utils/startup_log.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Una fase que se traba no traba la app: se corta por tiempo y sigue', () async {
    final result = await StartupLog.guard('fase lenta', () => Future<int>.delayed(const Duration(seconds: 5), () => 1),
        limit: const Duration(milliseconds: 50));
    expect(result, isNull);
  });

  test('Una fase que falla se registra y la app sigue', () async {
    final result = await StartupLog.guard<int>('fase rota', () async => throw StateError('falso'));
    expect(result, isNull);
  });

  test('Una fase normal devuelve su resultado', () async {
    expect(await StartupLog.guard('fase normal', () async => 42), 42);
  });
}
