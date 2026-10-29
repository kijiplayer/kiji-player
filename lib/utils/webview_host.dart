// l10n-ignore-file: mensajes del registro y de errores internos (no se muestran en la interfaz).
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// No se pudo crear una WebView ni después de renovar el entorno. Quien la pidió lo maneja sin
/// avisos técnicos (el solver y el PO token prueban otro camino; la traducción avisa con amabilidad).
class WebViewUnavailable implements Exception {
  const WebViewUnavailable(this.who, this.cause);

  final String who;
  final Object? cause;

  @override
  String toString() => 'No se pudo crear la WebView de $who: $cause';
}

/// Crea las WebView ocultas de Kiji (solver, PO token y traducción).
///
/// En Windows todas comparten un entorno de WebView2 propio de Kiji, con su carpeta de datos dentro
/// de la de Kiji y siempre las mismas opciones (antes, cada una creaba un entorno nuevo con la
/// carpeta y las opciones por defecto). Si una no se puede crear (pasaba tras horas con Kiji
/// abierta: "Cannot create the HeadlessInAppWebView instance!"), se descarta ese entorno, se crea
/// otro en una carpeta nueva —arranca un proceso de WebView2 nuevo, por si el anterior quedó
/// trabado— y se reintenta, sin reiniciar Kiji. En Android no hay entorno: solo se reintenta.
class WebViewHost {
  WebViewHost({
    Future<Directory> Function()? baseDirectory,
    bool? useEnvironment,
    @visibleForTesting Future<WebViewEnvironment> Function(String folder)? createEnvironment,
    @visibleForTesting Future<void> Function(Object webView)? start,
    @visibleForTesting Future<void> Function(Object webView)? stop,
  }) : _baseDirectory = baseDirectory ?? getApplicationSupportDirectory,
       _useEnvironment = useEnvironment ?? (!kIsWeb && Platform.isWindows),
       _newEnvironment = createEnvironment ?? _defaultEnvironment,
       _start = start ?? ((webView) => (webView as HeadlessInAppWebView).run()),
       _stop = stop ?? ((webView) => (webView as HeadlessInAppWebView).dispose());

  static Future<WebViewEnvironment> _defaultEnvironment(String folder) =>
      WebViewEnvironment.create(settings: WebViewEnvironmentSettings(userDataFolder: folder));

  static final instance = WebViewHost();

  static const attempts = 3;
  static const createTimeout = Duration(seconds: 20);

  final Future<Directory> Function() _baseDirectory;
  final bool _useEnvironment;
  final Future<WebViewEnvironment> Function(String folder) _newEnvironment;
  final Future<void> Function(Object webView) _start;
  final Future<void> Function(Object webView) _stop;

  /// La carpeta de datos del entorno actual (null sin entorno propio).
  String? folder;

  WebViewEnvironment? _environment;
  Future<WebViewEnvironment?>? _creating;

  /// Número de la carpeta de datos actual (`webview2/<n>`); sube con cada renovación.
  int generation = 0;
  bool _cleaned = false;

  /// Cuántas veces se renovó el entorno en esta sesión (para el registro y las pruebas).
  int renewals = 0;

  Future<WebViewEnvironment?> _currentEnvironment() {
    if (!_useEnvironment) return Future.value();
    final ready = _environment;
    if (ready != null) return Future.value(ready);
    return _creating ??= _createEnvironment().whenComplete(() => _creating = null);
  }

  Future<WebViewEnvironment?> _createEnvironment() async {
    try {
      final root = Directory(p.join((await _baseDirectory()).path, 'webview2'));
      if (!_cleaned) {
        _cleaned = true;
        await _cleanOldFolders(root);
      }
      final folder = Directory(p.join(root.path, '$generation'));
      await folder.create(recursive: true);
      final environment = await _newEnvironment(folder.path);
      this.folder = folder.path;
      debugPrint('=== WEBVIEW: entorno listo (carpeta ${p.basename(folder.path)}) ===');
      return _environment = environment;
    } catch (error) {
      // Sin entorno propio se usa el de siempre (el del plugin): mejor eso que nada.
      debugPrint('=== WEBVIEW: no se pudo crear el entorno ($error); se usa el de siempre ===');
      return null;
    }
  }

  /// Carpetas de renovaciones de sesiones anteriores (las que no estén en uso).
  Future<void> _cleanOldFolders(Directory root) async {
    if (!await root.exists()) return;
    await for (final entity in root.list()) {
      if (entity is! Directory || p.basename(entity.path) == '0') continue;
      try {
        await entity.delete(recursive: true);
      } catch (error) {
        debugPrint('=== WEBVIEW: no se pudo borrar ${p.basename(entity.path)}: $error ===');
      }
    }
  }

  /// Descarta el entorno actual: el próximo pedido crea otro, en una carpeta nueva.
  Future<void> renew(String why) async {
    final old = _environment;
    _environment = null;
    if (_useEnvironment) generation++;
    renewals++;
    debugPrint('=== WEBVIEW: se renueva el entorno ($why) ===');
    if (old == null) return;
    try {
      await old.dispose();
    } catch (error) {
      debugPrint('=== WEBVIEW: al soltar el entorno viejo: $error ===');
    }
  }

  /// Crea y arranca una WebView oculta para [who]. [build] la arma con el entorno que le toca
  /// (null fuera de Windows). Si no se puede crear, renueva el entorno y reintenta; si después de
  /// [attempts] intentos no hay forma, lanza [WebViewUnavailable].
  Future<W> run<W extends Object>(String who, W Function(WebViewEnvironment? env) build) async {
    Object? lastError;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      final environment = await _currentEnvironment();
      final webView = build(environment);
      try {
        await _start(webView).timeout(createTimeout);
        if (attempt > 1) debugPrint('=== WEBVIEW: $who se creó al intento $attempt ===');
        return webView;
      } catch (error) {
        lastError = error;
        debugPrint('=== WEBVIEW: $who no se pudo crear (intento $attempt de $attempts): $error ===');
        try {
          await _stop(webView);
        } catch (disposeError) {
          debugPrint('=== WEBVIEW: al soltar la de $who: $disposeError ===');
        }
        await renew('no se pudo crear la de $who');
        if (attempt < attempts) await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
    throw WebViewUnavailable(who, lastError);
  }
}
