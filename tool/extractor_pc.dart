// Prueba del extractor DESDE UNA PC (IP de casa): `dart run tool/extractor_pc.dart`.
//
// Corre test_live/extractor_live_test.dart. Si falla, abre el issue "Prueba diaria del extractor"
// en el acto (o lo comenta si ya está abierto), con el `gh` de esta PC (hay que haber hecho
// `gh auth login`). Desde una PC no hay "bloqueo" que valga: si YouTube pide "no eres un bot" a
// una conexión de casa, también se lo pide a la gente que usa Kiji.
// Con `--sin-issue` solo muestra el resultado. Sin internet no abre nada.
// La Action diaria corre lo mismo desde GitHub, donde YouTube suele bloquear la IP.

import 'dart:convert';
import 'dart:io';

const _repo = 'kijiplayer/kiji-player';
const _title = 'Prueba diaria del extractor: YouTube no da el audio';

Future<void> main(List<String> args) async {
  if (!await _online()) {
    stdout.writeln('Sin conexión a YouTube Music: no se prueba ni se abre nada.');
    exit(2);
  }
  final test = await Process.start(
    'flutter',
    ['test', 'test_live/extractor_live_test.dart'],
    runInShell: true,
    mode: ProcessStartMode.inheritStdio,
  );
  await test.exitCode;

  final json = File('build/extractor_live.json');
  final summary = File('build/extractor_live.md');
  final result = json.existsSync() ? (jsonDecode(json.readAsStringSync()) as Map)['resultado'] : 'falla';
  stdout.writeln('\nResultado desde esta PC: $result');
  if (result == 'ok') return;
  if (args.contains('--sin-issue')) exit(1);

  final gh = _gh();
  final body = StringBuffer()
    ..writeln('La prueba del extractor **falló desde una PC** (conexión de casa, no un servidor) el '
        '${DateTime.now().toUtc().toIso8601String().substring(0, 10)}.')
    ..writeln()
    ..writeln(summary.existsSync() ? summary.readAsStringSync() : 'La prueba no llegó a escribir el resumen.')
    ..writeln()
    ..writeln('Qué hacer: [docs/EXTRACTOR.md](../blob/master/docs/EXTRACTOR.md) → "Diagnóstico paso a paso".');
  final bodyFile = File('build/extractor_issue.md')..writeAsStringSync(body.toString());

  final open = await Process.run(gh, [
    'issue', 'list', '-R', _repo, '--state', 'open', '--label', 'extractor', //
    '--search', 'in:title "$_title"', '--json', 'number', '--jq', '.[0].number',
  ]);
  if (open.exitCode != 0) _fail('No se pudo usar gh (¿hiciste `gh auth login`?): ${open.stderr}');
  final number = '${open.stdout}'.trim();
  final ProcessResult done;
  if (number.isNotEmpty) {
    done = await Process.run(gh, ['issue', 'comment', number, '-R', _repo, '--body-file', bodyFile.path]);
  } else {
    for (final (name, color, text) in [
      ('extractor', 'D93F0B', 'Extractor de YouTube'),
      ('error', 'B60205', 'Algo no funciona'),
    ]) {
      await Process.run(gh, ['label', 'create', name, '-R', _repo, '--color', color, '--description', text, '--force']);
    }
    done = await Process.run(gh, [
      'issue', 'create', '-R', _repo, '--title', _title, '--label', 'extractor', '--label', 'error', //
      '--body-file', bodyFile.path,
    ]);
  }
  if (done.exitCode != 0) _fail('gh no pudo abrir ni comentar el issue: ${done.stderr}');
  stdout.writeln(number.isNotEmpty ? 'Comentado en el issue #$number.' : 'Issue abierto: ${'${done.stdout}'.trim()}');
  exit(1);
}

/// Hay conexión con YouTube Music (si no, no es una falla del extractor).
Future<bool> _online() async {
  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    final request = await client.headUrl(Uri.parse('https://music.youtube.com/'));
    final response = await request.close();
    await response.drain<void>();
    client.close();
    return true;
  } catch (error) {
    stderr.writeln('Sin conexión: $error');
    return false;
  }
}

/// `gh` del PATH o el de la instalación de siempre en Windows.
String _gh() {
  const windows = r'C:\Program Files\GitHub CLI\gh.exe';
  if (Platform.isWindows && File(windows).existsSync()) return windows;
  return 'gh';
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
