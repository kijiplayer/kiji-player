// Adaptado de Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0, que a su
// vez lo toma de NewPipe (GPL-3.0) y de BgUtils (LuanRT, MIT).
// Archivos originales: app/.../utils/potoken/PoTokenWebView.kt, PoTokenGenerator.kt,
// JavaScriptUtil.kt y app/src/main/assets/po_token.html.
//
// El "PO token" prueba que el pedido viene de un navegador real. Los clientes web
// de YouTube lo necesitan para bajar el audio entero (sin él, solo el primer
// minuto). Se genera en una WebView con BotGuard, el mismo programa que corre la
// web de YouTube, ligado al visitorData anónimo: no hay cuenta ni datos personales.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Genera PO tokens. Interfaz propia: donde no hay WebView,
/// [isSupported] es false y las formas web quedan sin token.
abstract class PoTokenProvider {
  bool get isSupported;

  /// Token ligado a [identifier] (el visitorData), o null si no se pudo.
  Future<String?> tokenFor(String identifier);
}

class NoPoTokens implements PoTokenProvider {
  const NoPoTokens();
  @override
  bool get isSupported => false;
  @override
  Future<String?> tokenFor(String identifier) async => null;
}

/// Desafío de BotGuard tal como lo usa la página.
@visibleForTesting
Map<String, dynamic> parseChallenge(String raw) {
  final scrambled = jsonDecode(raw) as List;
  final List data;
  if (scrambled.length > 1 && scrambled[1] is String) {
    data = jsonDecode(descrambleChallenge(scrambled[1] as String)) as List;
  } else {
    data = scrambled[0] as List;
  }
  String? firstString(Object? list) => list is List ? list.whereType<String>().firstOrNull : null;
  return {
    'messageId': data[0],
    'interpreterJavascript': firstString(data[1]),
    'interpreterUrl': firstString(data[2]),
    'interpreterHash': data[3],
    'program': data[4],
    'globalName': data[5],
  };
}

/// Base64 "de YouTube" (con - _ .) a bytes.
@visibleForTesting
Uint8List youtubeBase64Decode(String value) {
  var normalized = value.replaceAll('-', '+').replaceAll('_', '/').replaceAll('.', '=');
  while (normalized.length % 4 != 0) {
    normalized += '=';
  }
  return base64Decode(normalized);
}

/// El desafío viene "mezclado": base64 y cada byte corrido en 97.
@visibleForTesting
String descrambleChallenge(String scrambled) =>
    utf8.decode([for (final b in youtubeBase64Decode(scrambled)) (b + 97) & 0xff]);

/// Bytes a base64 "url-safe", como lo espera YouTube en `pot=`.
@visibleForTesting
String poTokenToBase64(List<int> bytes) => base64Encode(bytes).replaceAll('+', '-').replaceAll('/', '_');

const _requestKey = 'O43z0dpjhgX20SCx4KAo';
const _apiKey = 'AIzaSyDyT5W0Jh49F30Pqqtyfdf7pDLFKLJoAnw';
const _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

/// Página con el cliente de BotGuard (como `po_token.html` de Echo/NewPipe).
const _page = r'''<!DOCTYPE html><html><head><meta charset="utf-8"><script>
var kijiStringify = JSON.stringify.bind(JSON);
var kijiMinter = null;
function kijiRunBotGuard(challenge) {
  return new Promise(function (resolve, reject) {
    try {
      new Function(challenge.interpreterJavascript)();
      var vm = window[challenge.globalName];
      if (!vm || !vm.a) throw new Error('No se encontró la VM de BotGuard');
      var functions = null;
      vm.a(challenge.program, function (asyncSnapshot, shutdown, passEvent, checkCamera) {
        functions = { asyncSnapshot: asyncSnapshot };
      }, true, undefined, function () {}, [[], []]);
      var tries = 0;
      var timer = setInterval(function () {
        if (functions && functions.asyncSnapshot) {
          clearInterval(timer);
          var webPoSignalOutput = [];
          functions.asyncSnapshot(function (response) {
            window.kijiSignal = webPoSignalOutput;
            resolve(kijiStringify({ botguardResponse: response }));
          }, [undefined, undefined, webPoSignalOutput, undefined]);
        } else if (++tries > 2000) {
          clearInterval(timer);
          reject(new Error('BotGuard no respondió'));
        }
      }, 5);
    } catch (e) { reject(e); }
  });
}
async function kijiCreateMinter(integrityToken) {
  var getMinter = window.kijiSignal && window.kijiSignal[0];
  if (typeof getMinter !== 'function') throw new Error('BotGuard no entregó el generador');
  var minter = await getMinter(new Uint8Array(integrityToken));
  if (typeof minter !== 'function') throw new Error('El generador no es una función');
  kijiMinter = minter;
  return 'ok';
}
async function kijiMint(identifier) {
  if (!kijiMinter) throw new Error('Sin generador');
  var bytes = await kijiMinter(new TextEncoder().encode(identifier));
  if (!(bytes instanceof Uint8Array)) throw new Error('Token inválido');
  return Array.from(bytes).join(',');
}
</script></head><body></body></html>''';

class WebViewPoTokens implements PoTokenProvider {
  WebViewPoTokens({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(receiveTimeout: const Duration(seconds: 15)));

  final Dio _dio;
  HeadlessInAppWebView? _webView;
  DateTime? _expires;
  Future<InAppWebViewController?>? _starting;
  final Map<String, String> _tokens = {};
  Future<void> _queue = Future.value();

  @override
  bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows);

  @override
  Future<String?> tokenFor(String identifier) {
    final result = _queue.then((_) => _tokenFor(identifier));
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<String?> _tokenFor(String identifier) async {
    if (!isSupported) return null;
    final expires = _expires;
    if (expires != null && DateTime.now().isAfter(expires)) await _reset();
    final cached = _tokens[identifier];
    if (cached != null) return cached;
    try {
      final controller = await (_starting ??= _start()).timeout(const Duration(seconds: 20));
      if (controller == null) {
        _starting = null;
        return null;
      }
      final result = await controller.callAsyncJavaScript(
        functionBody: 'return await kijiMint(id);',
        arguments: {'id': identifier},
      );
      final value = result?.value;
      if (result?.error != null || value is! String) throw StateError('${result?.error ?? value}');
      final token = poTokenToBase64([for (final b in value.split(',')) int.parse(b)]);
      debugPrint('=== YTM potoken: token listo (${value.split(',').length} bytes, id ${identifier.length} caracteres) ===');
      return _tokens[identifier] = token;
    } catch (error) {
      debugPrint('=== YTM potoken: no se pudo generar: $error ===');
      await _reset();
      return null;
    }
  }

  Future<void> _reset() async {
    _tokens.clear();
    _expires = null;
    _starting = null;
    try {
      await _webView?.dispose();
    } catch (error) {
      debugPrint('=== YTM potoken: al cerrar la WebView: $error ===');
    }
    _webView = null;
  }

  Future<Response<String>> _post(String path, Object body) => _dio.post<String>(
        'https://www.youtube.com/api/jnn/v1/$path',
        data: jsonEncode(body),
        options: Options(responseType: ResponseType.plain, headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
          'Content-Type': 'application/json+protobuf',
          'x-goog-api-key': _apiKey,
          'x-user-agent': 'grpc-web-javascript/0.1',
        }),
      );

  Future<InAppWebViewController?> _start() async {
    final watch = Stopwatch()..start();
    final loaded = Completer<InAppWebViewController>();
    final webView = HeadlessInAppWebView(
      initialData: InAppWebViewInitialData(data: _page, baseUrl: WebUri('https://www.youtube.com/')),
      initialSettings: InAppWebViewSettings(javaScriptEnabled: true, userAgent: _userAgent),
      onLoadStop: (controller, _) {
        if (!loaded.isCompleted) loaded.complete(controller);
      },
      onConsoleMessage: (_, message) {
        if (message.messageLevel == ConsoleMessageLevel.ERROR) {
          debugPrint('=== YTM potoken: consola: ${message.message} ===');
        }
      },
    );
    _webView = webView;
    await webView.run();
    final controller = await loaded.future;

    final challenge = parseChallenge((await _post('Create', [_requestKey])).data!);
    if (challenge['interpreterJavascript'] == null) {
      debugPrint('=== YTM potoken: el desafío no trae el intérprete ===');
      return null;
    }
    final run = await controller.callAsyncJavaScript(
      functionBody: 'return await kijiRunBotGuard(challenge);',
      arguments: {'challenge': challenge},
    );
    if (run?.error != null || run?.value is! String) throw StateError('BotGuard: ${run?.error ?? run?.value}');
    final botguardResponse = (jsonDecode(run!.value as String) as Map)['botguardResponse'];

    final integrity = jsonDecode((await _post('GenerateIT', [_requestKey, botguardResponse])).data!) as List;
    final token = youtubeBase64Decode(integrity[0] as String);
    final ttl = integrity[1] as int;
    final minter = await controller.callAsyncJavaScript(
      functionBody: 'return await kijiCreateMinter(token);',
      arguments: {'token': token.toList()},
    );
    if (minter?.error != null) throw StateError('generador: ${minter!.error}');
    // Diez minutos de margen, como Echo.
    _expires = DateTime.now().add(Duration(seconds: ttl) - const Duration(minutes: 10));
    debugPrint('=== YTM potoken: BotGuard listo (${watch.elapsedMilliseconds} ms, dura ${ttl ~/ 60} min) ===');
    return controller;
  }
}
