import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_js/flutter_js.dart';

/// Representa una función ya extraída del reproductor de YouTube, lista
/// para ejecutarse: su nombre y el código JS mínimo necesario para
/// definirla (incluyendo cualquier objeto ayudante del que dependa).
class _ExtractedFunction {
  const _ExtractedFunction(this.name, this.code);
  final String name;
  final String code;
}

/// Descarga el script del reproductor de YouTube (`base.js`) para el video
/// que se quiera reproducir, y ejecuta SOLO los fragmentos de JavaScript
/// necesarios (no el archivo completo — es de varios MB y hace que el
/// motor embebido se caiga) dentro de un motor JS real (QuickJS, vía
/// `flutter_js`) para descifrar la firma de audio y el parámetro "n"
/// (anti-throttling).
///
/// NOTA HONESTA: esta es la parte más frágil de todo el proyecto. YouTube
/// cambia el nombre de las funciones y la forma exacta del código cada
/// tanto. En vez de reimplementar el algoritmo de descifrado a mano en
/// Dart (que se rompería con cada cambio), extraemos y ejecutamos el
/// JavaScript original de YouTube tal cual — solo necesitamos ubicar el
/// fragmento correcto dentro del archivo, no reescribir su lógica.
class YtCipherSolver {
  YtCipherSolver(this._dio);

  final Dio _dio;
  JavascriptRuntime? _runtime;

  String? _cachedJsUrl;
  String? _decipherFunctionName;
  String? _nFunctionName;
  int? _signatureTimestamp;

  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  Future<void> _ensureReady(String videoId) async {
    if (_runtime != null) return;

    debugPrint('=== YTM cipher: pidiendo la página de "$videoId" para ubicar el reproductor ===');

    final watchResponse = await _dio.get<String>(
      'https://www.youtube.com/watch',
      queryParameters: {'v': videoId, 'hl': 'en'},
      options: Options(
        responseType: ResponseType.plain,
        headers: {'User-Agent': _userAgent},
      ),
    );

    final html = watchResponse.data ?? '';

    final jsUrlMatch = RegExp(r'"jsUrl":"([^"]+)"').firstMatch(html);
    if (jsUrlMatch == null) {
      debugPrint('=== YTM cipher: no se encontró "jsUrl" en la página ===');
      throw StateError('No se pudo ubicar el script del reproductor de YouTube.');
    }

    final jsUrl = jsUrlMatch.group(1)!;
    debugPrint('=== YTM cipher: jsUrl = $jsUrl ===');

    if (jsUrl == _cachedJsUrl && _runtime != null) {
      debugPrint('=== YTM cipher: reutilizando reproductor ya cargado ===');
      return;
    }

    final fullJsUrl = jsUrl.startsWith('http') ? jsUrl : 'https://www.youtube.com$jsUrl';

    debugPrint('=== YTM cipher: descargando base.js ===');
    final playerJsResponse = await _dio.get<String>(
      fullJsUrl,
      options: Options(responseType: ResponseType.plain),
    );
    final playerJs = playerJsResponse.data ?? '';
    debugPrint('=== YTM cipher: base.js descargado (${playerJs.length} chars) ===');

    _signatureTimestamp = _findSignatureTimestamp(playerJs);
    debugPrint('=== YTM cipher: signatureTimestamp = $_signatureTimestamp ===');

    final decipher = _extractDecipherFunction(playerJs);
    final nFunc = _extractNFunction(playerJs);

    if (decipher == null) {
      debugPrint('=== YTM cipher: NO se pudo extraer la función de firma. Contexto para diagnóstico: ===');
      _dumpContextAround(playerJs, 'splice(a,0,c)', label: 'splice(a,0,c)');
      _dumpContextAround(playerJs, '=function(a){a=a.split("")', label: 'split("")');
    }
    if (nFunc == null) {
      debugPrint('=== YTM cipher: NO se pudo extraer la función de "n". Contexto para diagnóstico: ===');
      _dumpContextAround(playerJs, '.get("n")', label: '.get("n")');
    }

    final runtime = getJavascriptRuntime();

    // Solo cargamos los fragmentos pequeños que sí necesitamos, NO el
    // archivo completo (eso es lo que hacía crashear al motor antes).
    if (decipher != null) {
      final evalResult = runtime.evaluate(decipher.code);
      if (evalResult.isError) {
        debugPrint('=== YTM cipher: ERROR al cargar función de firma: ${evalResult.stringResult} ===');
      } else {
        debugPrint('=== YTM cipher: función de firma "${decipher.name}" cargada OK ===');
        _decipherFunctionName = decipher.name;
      }
    }

    if (nFunc != null) {
      final evalResult = runtime.evaluate(nFunc.code);
      if (evalResult.isError) {
        debugPrint('=== YTM cipher: ERROR al cargar función de "n": ${evalResult.stringResult} ===');
      } else {
        debugPrint('=== YTM cipher: función de "n" "${nFunc.name}" cargada OK ===');
        _nFunctionName = nFunc.name;
      }
    }

    _runtime = runtime;
    _cachedJsUrl = jsUrl;
  }

  /// Imprime ~300 caracteres alrededor de la primera aparición de [anchor]
  /// dentro de [source], para poder ver a mano cómo luce el código real
  /// cuando nuestros patrones no lo detectan solos.
  void _dumpContextAround(String source, String anchor, {required String label}) {
    final index = source.indexOf(anchor);
    if (index == -1) {
      debugPrint('=== YTM cipher: ancla "$label" ni siquiera aparece en el archivo ===');
      return;
    }
    final start = (index - 150).clamp(0, source.length);
    final end = (index + 150).clamp(0, source.length);
    debugPrint('=== YTM cipher: contexto alrededor de "$label" ===');
    debugPrint(source.substring(start, end));
  }

  /// Extrae un bloque balanceado de llaves `{...}` empezando en el índice
  /// donde está la primera "{" (inclusive). Respeta strings para no
  /// contar llaves que estén dentro de texto entre comillas.
  String? _extractBalancedBraces(String source, int openBraceIndex) {
    if (openBraceIndex < 0 || openBraceIndex >= source.length || source[openBraceIndex] != '{') {
      return null;
    }
    var depth = 0;
    var inString = false;
    String stringChar = '';
    var escaped = false;

    for (var i = openBraceIndex; i < source.length; i++) {
      final char = source[i];

      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char == r'\') {
          escaped = true;
        } else if (char == stringChar) {
          inString = false;
        }
        continue;
      }

      if (char == '"' || char == "'" || char == '`') {
        inString = true;
        stringChar = char;
        continue;
      }

      if (char == '{') depth++;
      if (char == '}') {
        depth--;
        if (depth == 0) {
          return source.substring(openBraceIndex, i + 1);
        }
      }
    }
    return null;
  }

  /// Ubica y extrae SOLO la función de descifrado de firma (más su objeto
  /// ayudante, si usa uno), como un fragmento pequeño de JS listo para
  /// ejecutar — no el archivo entero.
  _ExtractedFunction? _extractDecipherFunction(String playerJs) {
    final namePatterns = <RegExp>[
      RegExp(r'([a-zA-Z0-9$]{2,4})=function\(a\)\{a=a\.split\(""\)'),
      RegExp(r'\bc&&\(c=([a-zA-Z0-9$]{2,4})\(decodeURIComponent\(c\)\)'),
      RegExp(r'\.sig\|\|([a-zA-Z0-9$]{2,4})\('),
    ];

    for (final pattern in namePatterns) {
      final match = pattern.firstMatch(playerJs);
      if (match == null) continue;
      final name = match.group(1)!;

      final declMatch = RegExp('${RegExp.escape(name)}=function\\(a\\)').firstMatch(playerJs);
      if (declMatch == null) continue;

      final braceIndex = playerJs.indexOf('{', declMatch.end);
      final body = _extractBalancedBraces(playerJs, braceIndex);
      if (body == null) continue;

      var helperCode = '';
      final helperMatch = RegExp(r'([a-zA-Z0-9$]{2,})\.[a-zA-Z0-9$]{2}\(a,\d+\)').firstMatch(body);
      if (helperMatch != null) {
        final helperName = helperMatch.group(1)!;
        final helperDecl = RegExp('var ${RegExp.escape(helperName)}=\\{').firstMatch(playerJs);
        if (helperDecl != null) {
          final helperBraceIndex = playerJs.indexOf('{', helperDecl.start);
          final helperBody = _extractBalancedBraces(playerJs, helperBraceIndex);
          if (helperBody != null) {
            helperCode = 'var $helperName=$helperBody;\n';
          }
        }
      }

      return _ExtractedFunction(name, '$helperCode function $name(a)$body');
    }
    return null;
  }

  /// Igual que arriba, pero para la función que transforma el parámetro
  /// "n" (protección anti-throttling de YouTube).
  _ExtractedFunction? _extractNFunction(String playerJs) {
    final namePatterns = <RegExp>[
      RegExp(r'\.get\("n"\)\)&&\(b=([a-zA-Z0-9$]{2,4})(?:\[\d+\])?\('),
      RegExp(r'&&\(b=([a-zA-Z0-9$]{2,4})\(b\),c\.set\("n",b\)'),
    ];

    for (final pattern in namePatterns) {
      final match = pattern.firstMatch(playerJs);
      if (match == null) continue;
      final name = match.group(1)!;

      final declMatch = RegExp('${RegExp.escape(name)}=function\\(a\\)').firstMatch(playerJs);
      if (declMatch == null) continue;

      final braceIndex = playerJs.indexOf('{', declMatch.end);
      final body = _extractBalancedBraces(playerJs, braceIndex);
      if (body == null) continue;

      return _ExtractedFunction(name, 'function $name(a)$body');
    }
    return null;
  }

  int? _findSignatureTimestamp(String playerJs) {
    final patterns = <RegExp>[
      RegExp(r'signatureTimestamp["\s:=]+(\d{5,})'),
      RegExp(r'\bsts["\s:=]+(\d{5,})'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(playerJs);
      if (match != null) return int.tryParse(match.group(1)!);
    }
    return null;
  }

  Future<int?> getSignatureTimestamp(String videoId) async {
    try {
      await _ensureReady(videoId);
    } catch (error) {
      debugPrint('=== YTM cipher: no se pudo obtener signatureTimestamp: $error ===');
      return null;
    }
    return _signatureTimestamp;
  }

  Future<String?> decipherSignature(String videoId, String cipheredSignature) async {
    await _ensureReady(videoId);

    final functionName = _decipherFunctionName;
    final runtime = _runtime;
    if (functionName == null || runtime == null) {
      debugPrint('=== YTM cipher: no hay función de firma disponible, aborto ===');
      return null;
    }

    final escaped = cipheredSignature.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    final result = runtime.evaluate('$functionName("$escaped")');

    if (result.isError) {
      debugPrint('=== YTM cipher: ERROR al descifrar firma: ${result.stringResult} ===');
      return null;
    }

    return result.stringResult;
  }

  Future<String> transformN(String videoId, String nValue) async {
    await _ensureReady(videoId);

    final functionName = _nFunctionName;
    final runtime = _runtime;
    if (functionName == null || runtime == null) {
      debugPrint('=== YTM cipher: no hay función de "n" disponible, uso el valor original ===');
      return nValue;
    }

    final escaped = nValue.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    final result = runtime.evaluate('$functionName("$escaped")');

    if (result.isError || result.stringResult.isEmpty) {
      debugPrint('=== YTM cipher: ERROR al transformar "n": ${result.stringResult} ===');
      return nValue;
    }

    return result.stringResult;
  }
}
