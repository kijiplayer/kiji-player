import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/widgets/nocturne/kiji_sheet.dart';

Widget _app() => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => showKijiSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: ListView(
              shrinkWrap: true,
              children: [for (var i = 0; i < 40; i++) ListTile(title: Text('Fila $i'))],
            ),
          ),
        ),
        child: const Text('abrir'),
      ),
    ),
  ),
);

void main() {
  testWidgets('Con la lista arriba, deslizar hacia abajo desde la mitad cierra la hoja', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Fila 3'), findsOneWidget);

    await tester.drag(find.text('Fila 3'), const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(find.text('Fila 3'), findsNothing);
  });

  testWidgets('Hacia arriba la lista se desplaza igual y la hoja no se cierra', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Fila 3'), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Fila 0'), findsNothing); // se desplazó
    expect(find.byType(ListView), findsOneWidget); // sigue abierta

    // Con la lista desplazada, bajar primero vuelve la lista arriba (no cierra).
    await tester.drag(find.byType(ListView), const Offset(0, 150));
    await tester.pumpAndSettle();
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('Un tirón corto deja la hoja abierta en su lugar', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.timedDrag(find.text('Fila 3'), const Offset(0, 60), const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('Fila 3'), findsOneWidget);
  });
}
