// Tocar la pestaña que ya está abierta sube al principio (como en todas las apps); tocar otra
// pestaña solo cambia de pestaña.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/providers/shell_provider.dart';
import 'package:kiji_player/widgets/scroll_to_top_on_reselect.dart';

void main() {
  Future<WidgetRef> pump(WidgetTester tester) async {
    late WidgetRef saved;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                saved = ref;
                return ScrollToTopOnReselect(
                  tab: ShellTab.home,
                  builder: (context, controller) => ListView.builder(
                    controller: controller,
                    itemCount: 200,
                    itemBuilder: (_, i) => SizedBox(height: 60, child: Text('fila $i')),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    return saved;
  }

  double offset(WidgetTester tester) => tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;

  testWidgets('En Inicio, tocar «Inicio» otra vez sube al principio', (tester) async {
    final ref = await pump(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(offset(tester), greaterThan(1000));
    selectShellTab(ref, ShellTab.home);
    await tester.pumpAndSettle();
    expect(offset(tester), 0);
  });

  testWidgets('Tocar otra pestaña cambia de pestaña y no mueve la lista', (tester) async {
    final ref = await pump(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    final before = offset(tester);
    selectShellTab(ref, ShellTab.search);
    await tester.pumpAndSettle();
    expect(ref.read(shellTabProvider), ShellTab.search);
    expect(offset(tester), before);
  });
}
