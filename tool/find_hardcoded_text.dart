// Busca textos para la persona usuaria que quedaron fijos en el código (en vez de estar en los
// archivos ARB de lib/l10n). Lo usa test/l10n_test.dart; también se corre a mano:
//   dart run tool/find_hardcoded_text.dart
// Ignora: el registro (debugPrint), comentarios, claves JSON, rutas, URLs, expresiones regulares y
// las líneas marcadas con `// l10n-ignore` (textos que no son de la interfaz, como el pedido a Gemini).

import 'dart:io';

/// Un texto fijo encontrado.
class HardcodedText {
  HardcodedText(this.file, this.line, this.text);
  final String file;
  final int line;
  final String text;
  @override
  String toString() => '$file:$line  $text';
}

final _literal = RegExp(r"""(?<![A-Za-z0-9_$])(r?)('(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*")""");
final _identifierLike = RegExp(r'^[A-Za-z0-9_.:/\-#@%+=<>|\[\]{}()*,?!~&^$\\ ]*$');
final _hasLetter = RegExp(r'[A-Za-zÁÉÍÓÚáéíóúñÑüÜ]');
final _word = RegExp(r'[A-Za-zÁÉÍÓÚáéíóúñÑüÜ]{2,}');

/// Archivos generados o que no son de interfaz.
bool _skipFile(String path) {
  final p = path.replaceAll(r'\', '/');
  return p.contains('/l10n/') || p.endsWith('.g.dart') || p.contains('/dev_tools/');
}

List<HardcodedText> findHardcodedText(String root) {
  final found = <HardcodedText>[];
  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart') || _skipFile(entity.path)) continue;
    final lines = entity.readAsLinesSync();
    var inLog = 0;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('//') || trimmed.startsWith('import ') || trimmed.startsWith('export ')) continue;
      if (trimmed.startsWith('part ') || line.contains('l10n-ignore')) continue;
      // El registro: debugPrint puede ocupar varias líneas.
      if (line.contains('debugPrint(') || line.contains('print(') || line.contains('=== ')) {
        inLog = ')'.allMatches(line).length >= '('.allMatches(line).length ? 0 : 1;
        continue;
      }
      if (inLog > 0) {
        if (line.trimRight().endsWith(');')) inLog = 0;
        continue;
      }
      if (line.contains('RegExp(') || line.contains('Uri.parse(')) continue;
      final code = line.split(RegExp(r'\s//\s')).first;
      for (final m in _literal.allMatches(code)) {
        if (m.group(1) == 'r') continue;
        final raw = m.group(2)!;
        final text = raw.substring(1, raw.length - 1);
        final plain = text.replaceAll(RegExp(r'\$\{[^}]*\}|\$[A-Za-z_][A-Za-z0-9_]*'), ' ');
        if (!_hasLetter.hasMatch(plain) || !_word.hasMatch(plain)) continue;
        if (plain.contains('://') || plain.startsWith('/') || plain.startsWith('package:')) continue;
        // Claves JSON, identificadores, nombres de archivo y de canales: sin espacios ni tildes.
        final looksLikeKey = !plain.contains(' ') && !RegExp(r'[ÁÉÍÓÚáéíóúñÑ¿¡]').hasMatch(plain) &&
            (plain == plain.toLowerCase() || RegExp(r'^[a-z]+[A-Z]').hasMatch(plain) || plain.contains('_') ||
                plain.contains('.') || plain.contains('/') || plain == plain.toUpperCase());
        if (looksLikeKey && _identifierLike.hasMatch(plain)) continue;
        found.add(HardcodedText(entity.path.replaceAll(r'\', '/'), i + 1, text));
      }
    }
  }
  return found;
}

void main(List<String> args) {
  final found = findHardcodedText(args.isEmpty ? 'lib' : args.first);
  for (final f in found) {
    stdout.writeln(f);
  }
  stdout.writeln('${found.length} textos fijos');
}
