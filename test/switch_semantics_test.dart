// Los interruptores se leen con su nombre en TalkBack. SwitchListTile ya lo hace solo; un Switch
// suelto (por ejemplo, en el `trailing` de un ListTile) necesita MergeSemantics alrededor, o el
// lector dice solo «interruptor, activado» sin decir de qué.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Todo Switch suelto está dentro de un MergeSemantics', () {
    final bare = RegExp(r'\b(Switch(\.adaptive)?|CupertinoSwitch)\(');
    final problems = <String>[];
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (final (i, line) in lines.indexed) {
        if (!bare.hasMatch(line) || line.trimLeft().startsWith('//')) continue;
        // El MergeSemantics tiene que estar unas líneas más arriba (envolviendo la fila).
        final above = lines.sublist(i < 25 ? 0 : i - 25, i).join('\n');
        if (!above.contains('MergeSemantics(')) problems.add('${file.path}:${i + 1}');
      }
    }
    expect(problems, isEmpty, reason: 'Switch sin MergeSemantics: TalkBack no dice su nombre');
  });
}
