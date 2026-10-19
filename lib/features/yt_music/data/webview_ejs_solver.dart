// Adaptado de Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivos originales: app/.../utils/sabr/EjsNTransformSolver.kt y
// app/.../utils/cipher/CipherWebView.kt (el solver de yt-dlp/ejs dentro de una
// WebView: meriyah + astring + yt.solver.core.js, y luego llamar a `n` y `sig`).
// Los .js de assets/solver/ son de yt-dlp/ejs 0.8.0 (Unlicense; yt.solver.lib.js incluye
// meriyah, ISC, y astring, MIT), copiados sin modificar.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/js_challenge_solver.dart';

/// Código del Web Worker: el solver de yt-dlp y las funciones propias. El
/// reproductor de YouTube se ejecuta aquí adentro, aislado de la página (al
/// ejecutarse en la página, la dejaba vacía y se perdía todo lo preparado).
/// yt-dlp también lo corre sin página (Deno, Node).
const _workerBridge = r'''
var meriyah = lib.meriyah;
var astring = lib.astring;
''';

const _workerFunctions = r'''
var kijiPost = self.postMessage.bind(self);
var kijiSolvers = null;
var kijiPreparedCode = null;
function kijiError(e) {
  return { error: String(e && e.message ? e.message : e) + (e && e.stack ? '\n' + e.stack : '') };
}
function kijiUse(code) {
  var result = { n: null, sig: null };
  (new Function('_result', code))(result);
  kijiSolvers = result;
  return { n: typeof result.n === 'function', sig: typeof result.sig === 'function' };
}
function kijiPrepare(player) {
  var output = jsc({ type: 'player', player: player, requests: [], output_preprocessed: true });
  if (output.type === 'error') return { error: String(output.error) };
  kijiPreparedCode = output.preprocessed_player;
  return kijiUse(output.preprocessed_player);
}
function kijiTakeCode() { var c = kijiPreparedCode; kijiPreparedCode = null; return { code: c }; }
function kijiSolve(kind, values) {
  var answers = {};
  var fn = kijiSolvers && kijiSolvers[kind];
  if (typeof fn !== 'function') return { error: 'no hay función de ' + kind + ' preparada' };
  var failure = null;
  for (var i = 0; i < values.length; i++) {
    try { answers[values[i]] = String(fn(values[i])); } catch (e) { failure = kijiError(e).error; }
  }
  return { answers: answers, error: failure };
}
var kijiFunctions = { kijiUse: kijiUse, kijiPrepare: kijiPrepare, kijiTakeCode: kijiTakeCode, kijiSolve: kijiSolve };
self.onmessage = function (event) {
  var result;
  try { result = kijiFunctions[event.data.fn].apply(null, event.data.args); } catch (e) { result = kijiError(e); }
  try { kijiPost({ id: event.data.id, result: result }); }
  catch (e) { kijiPost({ id: event.data.id, result: kijiError(e) }); }
};
''';

/// Página: crea el worker y le pasa los pedidos. Las respuestas vuelven a
/// Dart como texto JSON.
const _pageScript = r'''
var kijiStringify = JSON.stringify.bind(JSON);
var kijiWorker = new Worker(URL.createObjectURL(
  new Blob([document.getElementById('kiji-worker').textContent], { type: 'text/javascript' })));
var kijiPending = {};
var kijiNext = 0;
kijiWorker.onmessage = function (event) {
  var resolve = kijiPending[event.data.id];
  delete kijiPending[event.data.id];
  if (resolve) resolve(event.data.result);
};
kijiWorker.onerror = function (event) {
  for (var id in kijiPending) kijiPending[id]({ error: 'worker: ' + event.message });
  kijiPending = {};
};
function kijiAsk(fn, args) {
  return new Promise(function (resolve) {
    var id = ++kijiNext;
    kijiPending[id] = resolve;
    kijiWorker.postMessage({ id: id, fn: fn, args: args });
  }).then(function (result) { return kijiStringify(result); });
}
''';

class WebViewEjsSolver implements JsChallengeSolver {
  WebViewEjsSolver({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;
  HeadlessInAppWebView? _webView;
  InAppWebViewController? _controller;
  Completer<InAppWebViewController>? _starting;
  String? _preparedHash;
  Future<void> _queue = Future.value();

  /// Llama a una función del puente y decodifica su respuesta (texto JSON).
  static Future<Map<String, dynamic>> _call(
    InAppWebViewController controller,
    String function,
    List<Object?> args,
  ) async {
    final result = await controller.callAsyncJavaScript(
      functionBody: 'return await kijiAsk(fn, args);',
      arguments: {'fn': function, 'args': args},
    );
    if (result?.error != null) throw StateError('$function: ${result!.error}');
    final raw = result?.value;
    if (raw is! String) throw StateError('$function: respuesta inesperada ($raw)');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) throw StateError('$function: respuesta inesperada');
    return decoded;
  }

  @override
  bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows);

  @override
  Future<ChallengeAnswers> solve({
    required String playerHash,
    required Future<String> Function() playerJs,
    List<String> n = const [],
    List<String> sig = const [],
  }) {
    // De a un pedido por vez: la WebView es una sola.
    final result = _queue.then((_) => _solve(playerHash, playerJs, n, sig));
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<ChallengeAnswers> _solve(
    String hash,
    Future<String> Function() playerJs,
    List<String> n,
    List<String> sig,
  ) async {
    if (!isSupported) return const ChallengeAnswers(error: 'En este dispositivo no hay WebView para descifrar');
    try {
      final controller = await _start();
      if (_preparedHash != hash) await _prepare(controller, hash, playerJs);
      Future<Map<String, String>> ask(String kind, List<String> values) async {
        if (values.isEmpty) return const {};
        final value = await _call(controller, 'kijiSolve', [kind, values]);
        if (value['error'] != null) debugPrint('=== YTM solver: $kind: ${value['error']} ===');
        final answers = value['answers'];
        if (answers is! Map) throw StateError('$kind: ${value['error']}');
        return answers.map((k, v) => MapEntry('$k', '$v'));
      }

      final answers = ChallengeAnswers(n: await ask('n', n), sig: await ask('sig', sig));
      final missing = (n.length - answers.n.length) + (sig.length - answers.sig.length);
      return missing == 0
          ? answers
          : ChallengeAnswers(n: answers.n, sig: answers.sig, error: 'El solver no resolvió $missing valores');
    } catch (error) {
      debugPrint('=== YTM solver: falló: $error ===');
      _preparedHash = null;
      return ChallengeAnswers(error: 'El solver falló: ${'$error'.split('\n').first}');
    }
  }

  Future<InAppWebViewController> _start() async {
    final ready = _controller;
    if (ready != null) return ready;
    final starting = _starting;
    if (starting != null) return starting.future;
    final completer = _starting = Completer<InAppWebViewController>();
    try {
      final scripts = [
        for (final file in ['yt.solver.lib.js', 'yt.solver.core.js'])
          await rootBundle.loadString('assets/solver/$file'),
      ];
      // Los scripts van dentro de etiquetas <script>: se evita que un
      // "</script>" del texto corte la página.
      String tag(String code) => '<script>${code.replaceAll('</script', r'<\/script')}</script>';
      // yt.solver.lib.js deja meriyah y astring dentro de "lib"; el núcleo
      // los espera como variables globales. Todo eso va al worker.
      final worker = [scripts[0], _workerBridge, scripts[1], _workerFunctions].join('\n');
      final html = '<!DOCTYPE html><html><head><meta charset="utf-8">'
          '<script type="text/plain" id="kiji-worker">${worker.replaceAll('</script', r'<\/script')}</script>'
          '${tag(_pageScript)}</head><body></body></html>';
      final webView = HeadlessInAppWebView(
        initialData: InAppWebViewInitialData(data: html, baseUrl: WebUri('https://kiji.invalid/')),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          cacheEnabled: false,
          useShouldOverrideUrlLoading: true,
        ),
        // La página del solver no navega nunca: el código del reproductor
        // de YouTube podría intentarlo y se perdería todo lo preparado.
        shouldOverrideUrlLoading: (_, action) async {
          final first = !completer.isCompleted;
          debugPrint('=== YTM solver: navegación ${first ? 'inicial' : 'BLOQUEADA'}: ${action.request.url} ===');
          return first ? NavigationActionPolicy.ALLOW : NavigationActionPolicy.CANCEL;
        },
        onLoadStart: (_, url) => debugPrint('=== YTM solver: carga $url ==='),
        onLoadStop: (controller, _) {
          if (!completer.isCompleted) completer.complete(controller);
        },
        onConsoleMessage: (_, message) {
          if (message.messageLevel == ConsoleMessageLevel.ERROR) {
            debugPrint('=== YTM solver: consola: ${message.message} ===');
          }
        },
      );
      _webView = webView;
      await webView.run();
      final controller = await completer.future.timeout(const Duration(seconds: 20));
      _controller = controller;
      debugPrint('=== YTM solver: WebView lista ===');
      return controller;
    } catch (error) {
      _starting = null;
      await _webView?.dispose();
      _webView = null;
      if (!completer.isCompleted) completer.completeError(error);
      rethrow;
    }
  }

  /// Prepara el reproductor [hash]: usa el preprocesado guardado en disco o
  /// lo genera con el solver (lo pesado, 1–5 s) y lo guarda.
  Future<void> _prepare(InAppWebViewController controller, String hash, Future<String> Function() playerJs) async {
    final watch = Stopwatch()..start();
    File? cache;
    try {
      final folder = Directory(p.join((await _directory()).path, 'player_js'));
      await folder.create(recursive: true);
      cache = File(p.join(folder.path, '$hash.ejs.js'));
      if (await cache.exists()) {
        final value = await _call(controller, 'kijiUse', [await cache.readAsString()]);
        if (value['n'] == true) {
          _preparedHash = hash;
          debugPrint('=== YTM solver: $hash listo desde el disco (${watch.elapsedMilliseconds} ms) ===');
          return;
        }
        debugPrint('=== YTM solver: el preprocesado guardado no sirvió (${value['error']}) ===');
      }
    } catch (error) {
      debugPrint('=== YTM solver: sin caché del preprocesado: $error ===');
      cache = null;
    }

    final value = await _call(controller, 'kijiPrepare', [await playerJs()]);
    if (value['error'] != null) throw StateError('preparar: ${value['error']}');
    if (value['n'] != true) throw StateError('el solver no encontró la función de "n" (sig: ${value['sig']})');
    _preparedHash = hash;
    debugPrint('=== YTM solver: $hash preparado (n: ${value['n']}, sig: ${value['sig']}, '
        '${watch.elapsedMilliseconds} ms) ===');
    final code = cache == null ? null : (await _call(controller, 'kijiTakeCode', const []))['code'];
    if (cache != null && code is String) {
      try {
        await cache.writeAsString(code);
        for (final old in cache.parent.listSync().whereType<File>()) {
          if (old.path.endsWith('.ejs.js') && old.path != cache.path) await old.delete();
        }
      } catch (error) {
        debugPrint('=== YTM solver: no se pudo guardar el preprocesado: $error ===');
      }
    }
  }
}
