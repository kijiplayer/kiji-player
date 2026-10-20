// Busca textos para la persona usuaria que quedaron fijos en el código (en vez de estar en los
// archivos ARB de lib/l10n). Lo usa test/l10n_test.dart; también se corre a mano:
//   dart run tool/find_hardcoded_text.dart
// Ignora: el registro (debugPrint), comentarios, claves JSON, rutas, URLs, expresiones regulares,
// las líneas marcadas con `// l10n-ignore` y los archivos marcados con `// l10n-ignore-file`
// (textos que no son de la interfaz, como los clientes de YouTube o el pedido a Gemini).

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

/// Un literal de texto del código, con las interpolaciones cambiadas por `{}`.
class _Literal {
  _Literal(this.offset, this.end, this.text, this.raw, this.calls);
  final int offset;
  final int end;
  final String text;
  final bool raw;

  /// Las funciones dentro de cuyos paréntesis está (debugPrint, RegExp…).
  final List<String> calls;
}

final _hasLetter = RegExp(r'[A-Za-zÁÉÍÓÚáéíóúñÑüÜ]');

/// Palabras de interfaz que, sueltas, parecen claves (minúsculas, sin tilde) pero son texto para
/// la persona usuaria. Y conectores que unen partes de una frase ("a y b").
const _uiWords = {
  'canciones', 'playlist', 'playlists', 'minutos', 'segundos', 'horas', 'artistas', 'descargadas',
  'songs', 'minutes', 'seconds', 'hours', 'artists', 'likes',
};
const _connectors = {'y', 'o', 'de', 'del', 'and', 'or', 'of'};
final _word = RegExp(r'[A-Za-zÁÉÍÓÚáéíóúñÑüÜ]{2,}');
final _identifierLike = RegExp(r'^[A-Za-z0-9_.:/\-#@%+=<>|\[\]{}()*,?!~&^$\\ ;"]*$');
const _technicalCalls = {
  'debugPrint', 'print', 'RegExp', 'Uri.parse', 'Uri.https', 'Uri.http', 'log', '_log', 'AppLog.add',
  'Exception', 'StateError', 'ArgumentError', 'UnsupportedError', 'select', 'execute', 'runJavaScript',
  'runJavaScriptReturningResult', 'callAsyncJavaScript', 'evaluateJavascript', 'Key', 'ValueKey', 'ObjectKey',
  'PageStorageKey', 'Hero', 'heroTag', 'getString', 'setString', 'containsKey', 'remove', 'MethodChannel',
  'EventChannel', 'invokeMethod', '_any', 'File', 'Directory', 'assert', 'tryParse', 'parse', 'jsonDecode',
  'contains', 'read', 'lengthOf',
};

/// Archivos generados o que no son de interfaz.
bool _skipFile(String path) {
  final p = path.replaceAll(r'\', '/');
  return p.contains('/l10n/') || p.endsWith('.g.dart') || p.contains('/dev_tools/');
}

List<HardcodedText> findHardcodedText(String root) {
  final found = <HardcodedText>[];
  final files = Directory(root).listSync(recursive: true).whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    if (!file.path.endsWith('.dart') || _skipFile(file.path)) continue;
    final src = file.readAsStringSync().replaceAll('\r\n', '\n');
    final lines = src.split('\n');
    if (lines.take(15).any((l) => l.contains('l10n-ignore-file'))) continue;
    for (final lit in _scan(src)) {
      if (lit.raw) continue;
      final lineNo = '\n'.allMatches(src.substring(0, lit.offset)).length;
      final line = lines[lineNo];
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('import ') || trimmed.startsWith('export ') || trimmed.startsWith('part ')) continue;
      if (line.contains('l10n-ignore') || line.contains('=== ')) continue;
      if (lit.calls.any((c) => _technicalCalls.contains(c) || _technicalCalls.contains(c.split('.').last))) continue;
      final text = lit.text;
      final plain = text.replaceAll('{}', ' ');
      final word = plain.trim().toLowerCase();
      final after0 = src.substring(lit.end).trimLeft();
      final before0 = src.substring(0, lit.offset).trimRight();
      // Como dato: clave de un mapa (`'x':`, `json['x']`, `key: 'x'`) o etiqueta en mayúsculas.
      final asData = after0.startsWith(':') ||
          before0.endsWith('[') ||
          RegExp(r'(key|logTag):$').hasMatch(before0) ||
          (plain.trim() == plain.trim().toUpperCase() && plain.trim() != word);
      // Palabras de interfaz y conectores sueltos: siempre texto para la persona usuaria.
      if (!asData && (_uiWords.contains(word) || (_connectors.contains(word) && plain != word))) {
        found.add(HardcodedText(file.path.replaceAll(r'\', '/'), lineNo + 1, text));
        continue;
      }
      if (!_hasLetter.hasMatch(plain) || !_word.hasMatch(plain)) continue;
      if (plain.contains('://') || plain.startsWith('/') || plain.startsWith('package:')) continue;
      // Claves de mapas (cabeceras HTTP, campos JSON): 'User-Agent': …
      // (No confundir con la rama de un ternario: `a ? 'Sí' : 'No'`.)
      final after = src.substring(lit.end).trimLeft();
      final before = src.substring(0, lit.offset).trimRight();
      final keyPosition = before.endsWith('{') || before.endsWith(',');
      if (keyPosition && after.startsWith(':') && !plain.trim().contains(' ')) continue;
      // Comparaciones con datos: == 'MUSIC_VIDEO_TYPE_ATV', case 'x':
      if ((before.endsWith('==') || before.endsWith('!=') || before.endsWith('case')) && !plain.contains(' ')) continue;
      // Claves, identificadores, nombres de archivo: sin espacios ni tildes.
      final bare = text.replaceAll('{}', '');
      final looksLikeKey = !bare.contains(' ') &&
          !RegExp(r'[ÁÉÍÓÚáéíóúñÑ¿¡]').hasMatch(bare) &&
          (bare == bare.toLowerCase() ||
              RegExp(r'^[a-z]+[A-Z]').hasMatch(bare) ||
              bare.contains('_') ||
              bare.contains('.') ||
              bare.contains('/') ||
              bare == bare.toUpperCase());
      if (looksLikeKey && _identifierLike.hasMatch(bare)) continue;
      found.add(HardcodedText(file.path.replaceAll(r'\', '/'), lineNo + 1, text));
    }
  }
  return found;
}

/// Un lexer chico de Dart: devuelve los literales de texto de [src], también los que están
/// dentro de interpolaciones (`'${n == 1 ? 'canción' : 'canciones'}'`).
List<_Literal> _scan(String src) {
  final out = <_Literal>[];
  final calls = <String>[];

  String previousWord(int at) {
    var j = at - 1;
    while (j >= 0 && (src[j] == ' ' || src[j] == '\n')) {
      j--;
    }
    final end = j + 1;
    while (j >= 0 && RegExp(r'[A-Za-z0-9_.]').hasMatch(src[j])) {
      j--;
    }
    return src.substring(j + 1, end);
  }

  late int Function(int, bool) code;

  int string(int start) {
    var j = start;
    final raw = src[j] == 'r';
    if (raw) j++;
    final quote = src.startsWith("'''", j) || src.startsWith('"""', j) ? src.substring(j, j + 3) : src[j];
    j += quote.length;
    final text = StringBuffer();
    while (j < src.length) {
      if (src.startsWith(quote, j)) {
        j += quote.length;
        out.add(_Literal(start, j, text.toString(), raw, List.of(calls)));
        return j;
      }
      final ch = src[j];
      if (!raw && ch == r'\') {
        text.write(src.substring(j, (j + 2).clamp(0, src.length)));
        j += 2;
        continue;
      }
      if (!raw && ch == r'$' && j + 1 < src.length) {
        if (src[j + 1] == '{') {
          text.write('{}');
          j = code(j + 2, true);
          continue;
        }
        final m = RegExp(r'[A-Za-z_][A-Za-z0-9_]*').matchAsPrefix(src, j + 1);
        if (m != null) {
          text.write('{}');
          j = m.end;
          continue;
        }
      }
      if (quote.length == 1 && ch == '\n') return j; // Literal roto: se corta acá.
      text.write(ch);
      j++;
    }
    return j;
  }

  code = (int start, bool interpolation) {
    var j = start;
    var depth = 0;
    final base = calls.length;
    while (j < src.length) {
      final ch = src[j];
      if (src.startsWith('//', j)) {
        final nl = src.indexOf('\n', j);
        j = nl < 0 ? src.length : nl;
        continue;
      }
      if (src.startsWith('/*', j)) {
        final close = src.indexOf('*/', j + 2);
        j = close < 0 ? src.length : close + 2;
        continue;
      }
      final startsRaw = ch == 'r' &&
          j + 1 < src.length &&
          (src[j + 1] == "'" || src[j + 1] == '"') &&
          (j == 0 || !RegExp(r'[A-Za-z0-9_$]').hasMatch(src[j - 1]));
      if (ch == "'" || ch == '"' || startsRaw) {
        j = string(j);
        continue;
      }
      if (ch == '(') {
        calls.add(previousWord(j));
      } else if (ch == ')') {
        if (calls.length > base) calls.removeLast();
      } else if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        if (depth == 0 && interpolation) {
          calls.length = base;
          return j + 1;
        }
        depth--;
      }
      j++;
    }
    return j;
  };

  code(0, false);
  return out;
}

void main(List<String> args) {
  final found = findHardcodedText(args.isEmpty ? 'lib' : args.first);
  for (final f in found) {
    stdout.writeln(f);
  }
  stdout.writeln('${found.length} textos fijos');
}
