import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Ícono a juego con el estilo (0.8.3), en Windows: el runner cambia el ícono de la ventana y de la
/// barra de tareas al momento. Solo con `-d windows` (no abre Kiji ni toca sus datos).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('kiji/icon');

  testWidgets('El runner pone cada ícono de estilo y vuelve al de siempre', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(await channel.invokeMethod<String>('current'), 'default');
    for (final variant in ['nocturne', 'aurora', 'ember', 'mint', 'ocean', 'graphite', 'paper']) {
      expect(await channel.invokeMethod<bool>('apply', variant), isTrue, reason: variant);
      expect(await channel.invokeMethod<String>('current'), variant);
    }
    // Un nombre raro (con rutas) no se carga.
    expect(await channel.invokeMethod<bool>('apply', '../../x'), isFalse);
    expect(await channel.invokeMethod<bool>('apply', 'default'), isTrue);
    expect(await channel.invokeMethod<String>('current'), 'default');
  });
}
