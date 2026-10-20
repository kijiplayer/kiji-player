// l10n-ignore-file: textos técnicos (no se muestran en la interfaz).
// Traducción en el dispositivo con Bergamot (Firefox Translations, MPL-2.0). La forma de
// armar los modelos y traducir sigue a Firefox: toolkit/components/translations/content/
// translations-engine.worker.js (alineación de memoria, configuración de Marian y pivote
// por inglés). El pegamento `bergamot-translator.js` es el de Firefox, sin modificar.
//
// La WebView no sale a internet: lee el motor y los modelos (ya guardados en el dispositivo)
// de un servidor propio de Kiji que solo escucha en 127.0.0.1 y con una ruta secreta.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;

import 'bergamot_models.dart';

const _page = r'''<!DOCTYPE html><html><head><meta charset="utf-8">
<script src="glue.js"></script>
<script>
var kijiBergamot = null;
var kijiService = null;
var kijiModels = {};
var ALIGN = { model: 256, lex: 64, vocab: 64, srcvocab: 64, trgvocab: 64 };
function kijiConfig(isInt8) {
  var c = { 'beam-size': '1', normalize: '1.0', 'word-penalty': '0', 'max-length-break': '128',
    'mini-batch-words': '1024', workspace: '128', 'max-length-factor': '2.0', 'skip-cost': 'true',
    'cpu-threads': '0', quiet: 'true', 'quiet-translation': 'true',
    'gemm-precision': isInt8 ? 'int8shiftAll' : 'int8shiftAlphaAll', alignment: 'soft' };
  var indent = '            ', r = '\n';
  for (var k in c) r += indent + k + ': ' + c[k] + '\n';
  return r + indent;
}
async function kijiEngine() {
  if (kijiService) return;
  var wasm = await (await fetch('engine.wasm')).arrayBuffer();
  kijiBergamot = await new Promise(function (resolve, reject) {
    var b = loadBergamot({ INITIAL_MEMORY: 41943040, wasmBinary: wasm, print: function () {},
      onAbort: function () { reject(new Error('No se pudo cargar el motor')); },
      onRuntimeInitialized: function () { Promise.resolve().then(function () { resolve(b); }); } });
  });
  kijiService = new kijiBergamot.BlockingService({ cacheSize: 0 });
}
async function kijiModel(pair, types, int8) {
  if (kijiModels[pair]) return kijiModels[pair];
  var mem = {};
  for (var i = 0; i < types.length; i++) {
    var t = types[i];
    var buffer = await (await fetch('models/' + pair + '/' + t + '.bin')).arrayBuffer();
    var aligned = new kijiBergamot.AlignedMemory(buffer.byteLength, ALIGN[t]);
    aligned.getByteArrayView().set(new Uint8Array(buffer));
    mem[t] = aligned;
  }
  var vocabs = new kijiBergamot.AlignedMemoryList();
  if (mem.vocab) { vocabs.push_back(mem.vocab); } else { vocabs.push_back(mem.srcvocab); vocabs.push_back(mem.trgvocab); }
  var parts = pair.split('-');
  kijiModels[pair] = new kijiBergamot.TranslationModel(parts[0], parts[1], kijiConfig(int8), mem.model, mem.lex || null, vocabs, null);
  return kijiModels[pair];
}
async function kijiTranslate(route, lines) {
  try {
    await kijiEngine();
    var models = [];
    for (var i = 0; i < route.length; i++) models.push(await kijiModel(route[i].pair, route[i].types, route[i].int8));
    var messages = new kijiBergamot.VectorString();
    var options = new kijiBergamot.VectorResponseOptions();
    for (var j = 0; j < lines.length; j++) {
      messages.push_back(lines[j]);
      options.push_back({ qualityScores: false, alignment: false, html: false });
    }
    var responses = models.length === 1
      ? kijiService.translate(models[0], messages, options)
      : kijiService.translateViaPivoting(models[0], models[1], messages, options);
    var out = [];
    for (var k = 0; k < responses.size(); k++) out.push(responses.get(k).getTranslatedText());
    messages.delete(); options.delete();
    return JSON.stringify({ lines: out });
  } catch (e) {
    return JSON.stringify({ error: String(e && e.message ? e.message : e) });
  }
}
</script></head><body></body></html>''';

/// Servidor mínimo para la WebView: solo 127.0.0.1 y una ruta secreta al azar.
class _LocalServer {
  _LocalServer(this._server, this.token, this._root, this._glue);

  final HttpServer _server;
  final String token;
  final Directory _root;
  final String _glue;

  String get base => 'http://127.0.0.1:${_server.port}/$token/';

  static Future<_LocalServer> start(Directory root, String glue) async {
    final random = Random.secure();
    final token = List.generate(24, (_) => random.nextInt(16).toRadixString(16)).join();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final local = _LocalServer(server, token, root, glue);
    server.listen(local._handle);
    return local;
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    response.headers.set('Cache-Control', 'no-store');
    try {
      final segments = request.uri.pathSegments;
      if (segments.isEmpty || segments.first != token) {
        response.statusCode = HttpStatus.forbidden;
        return;
      }
      final rest = segments.skip(1).toList();
      final path = rest.join('/');
      if (path == 'index.html') {
        response.headers.contentType = ContentType.html;
        response.write(_page);
      } else if (path == 'glue.js') {
        response.headers.contentType = ContentType('application', 'javascript', charset: 'utf-8');
        response.write(_glue);
      } else if (path == 'engine.wasm' ||
          (rest.length == 3 && rest[0] == 'models' && RegExp(r'^[a-zA-Z-]+$').hasMatch(rest[1]) &&
              RegExp(r'^(model|lex|vocab|srcvocab|trgvocab)\.bin$').hasMatch(rest[2]))) {
        final file = path == 'engine.wasm'
            ? File(p.join(_root.path, 'engine', 'engine.wasm'))
            : File(p.join(_root.path, rest[1], rest[2]));
        if (!await file.exists()) {
          response.statusCode = HttpStatus.notFound;
          return;
        }
        response.headers.contentType =
            path == 'engine.wasm' ? ContentType('application', 'wasm') : ContentType.binary;
        await response.addStream(file.openRead());
      } else {
        response.statusCode = HttpStatus.notFound;
      }
    } catch (error) {
      debugPrint('=== TRADUCIR: servidor local: $error ===');
      response.statusCode = HttpStatus.internalServerError;
    } finally {
      await response.close();
    }
  }

  Future<void> close() => _server.close(force: true);
}

/// Traduce con Bergamot dentro de una WebView sin ventana (Android, iOS,
/// macOS, Windows). Los modelos tienen que estar instalados (ver
/// [BergamotModels.install]).
class BergamotEngine {
  BergamotEngine(this.models);

  final BergamotModels models;
  _LocalServer? _server;
  HeadlessInAppWebView? _webView;
  InAppWebViewController? _controller;
  Future<InAppWebViewController>? _starting;
  Future<void> _queue = Future.value();

  bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows);

  Future<InAppWebViewController> _start() async {
    final glue = await rootBundle.loadString('assets/translation/bergamot-translator.js');
    final server = _server = await _LocalServer.start(await models.folder(), glue);
    final loaded = Completer<InAppWebViewController>();
    final webView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri('${server.base}index.html')),
      initialSettings: InAppWebViewSettings(javaScriptEnabled: true, cacheEnabled: false),
      onLoadStop: (controller, _) {
        if (!loaded.isCompleted) loaded.complete(controller);
      },
      onConsoleMessage: (_, message) {
        if (message.messageLevel == ConsoleMessageLevel.ERROR) {
          debugPrint('=== TRADUCIR: consola: ${message.message} ===');
        }
      },
    );
    _webView = webView;
    await webView.run();
    return _controller = await loaded.future.timeout(const Duration(seconds: 20));
  }

  /// Traduce [lines] por la ruta [route] (uno o dos pares, pivote por inglés).
  Future<List<String>> translate(List<LanguagePair> route, List<String> lines) {
    final result = _queue.then((_) => _translate(route, lines));
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<List<String>> _translate(List<LanguagePair> route, List<String> lines) async {
    if (route.isEmpty) return lines;
    final controller = _controller ?? await (_starting ??= _start());
    final payload = [
      for (final pair in route)
        {
          'pair': pairKey(pair),
          'types': await models.installedTypes(pair),
          'int8': (await models.filesFor(pair)).any((f) => f.name.endsWith('intgemm8.bin')),
        },
    ];
    final watch = Stopwatch()..start();
    final result = await controller.callAsyncJavaScript(
      functionBody: 'return await kijiTranslate(route, lines);',
      arguments: {'route': payload, 'lines': lines},
    );
    if (result?.error != null) throw StateError('${result!.error}');
    final decoded = jsonDecode('${result?.value}') as Map;
    if (decoded['error'] != null) throw StateError('${decoded['error']}');
    debugPrint('=== TRADUCIR: ${lines.length} líneas en ${watch.elapsedMilliseconds} ms ===');
    return [for (final line in decoded['lines'] as List) '$line'];
  }

  Future<void> close() async {
    await _webView?.dispose();
    await _server?.close();
    _webView = null;
    _controller = null;
    _starting = null;
    _server = null;
  }
}
