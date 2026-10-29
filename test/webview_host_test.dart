import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/utils/webview_host.dart';

/// Una "WebView" de mentira: solo cuenta si se arrancó y si se soltó.
class _Fake {
  _Fake(this.n);
  final int n;
  bool stopped = false;
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('kiji_webview_'));
  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException catch (error) {
      // ignore: avoid_print
      print('=== TEST: no se pudo borrar la carpeta temporal: $error ===');
    }
  });

  final cannotCreate = PlatformException(code: '0', message: 'Cannot create the HeadlessInAppWebView instance!');

  test('si no se puede crear, renueva y reintenta: la tercera anda', () async {
    var tries = 0;
    final made = <_Fake>[];
    final host = WebViewHost(
      baseDirectory: () async => dir,
      useEnvironment: false,
      start: (w) async {
        tries++;
        if (tries < 3) throw cannotCreate;
      },
      stop: (w) async => (w as _Fake).stopped = true,
    );
    final webView = await host.run('solver', (_) {
      final fake = _Fake(made.length);
      made.add(fake);
      return fake;
    });
    expect(webView.n, 2);
    expect(host.renewals, 2);
    expect([for (final f in made) f.stopped], [true, true, false], reason: 'las que fallaron se sueltan');
  });

  test('si nunca se puede, lanza un error propio (que cada parte maneja), no el del plugin', () async {
    final host = WebViewHost(
      baseDirectory: () async => dir,
      useEnvironment: false,
      start: (_) async => throw cannotCreate,
      stop: (_) async {},
    );
    await expectLater(
      host.run('traducción', (_) => _Fake(0)),
      throwsA(isA<WebViewUnavailable>().having((e) => e.who, 'who', 'traducción')),
    );
    expect(host.renewals, WebViewHost.attempts);
  });

  test('en Windows: cada renovación usa una carpeta nueva, y al empezar se borran las viejas', () async {
    final root = Directory('${dir.path}/webview2');
    for (final old in ['0', '3', '7']) {
      Directory('${root.path}/$old').createSync(recursive: true);
    }
    final folders = <String>[];
    var tries = 0;
    final host = WebViewHost(
      baseDirectory: () async => dir,
      useEnvironment: true,
      // El entorno real necesita el plugin: acá se anota la carpeta y se sigue sin él.
      createEnvironment: (folder) async {
        folders.add(folder.split(RegExp(r'[\\/]')).last);
        throw StateError('sin plugin en la prueba');
      },
      start: (_) async {
        tries++;
        if (tries == 1) throw cannotCreate;
      },
      stop: (_) async {},
    );
    await host.run('PO token', (_) => _Fake(0));
    expect(folders, ['0', '1'], reason: 'el primer intento en la 0; el reintento, en una carpeta nueva');
    expect(Directory('${root.path}/3').existsSync(), isFalse, reason: 'las de otras sesiones se borran');
    expect(Directory('${root.path}/7').existsSync(), isFalse);
  });

  test('varios pedidos a la vez después de una falla no dejan errores sin dueño', () async {
    final uncaught = <Object>[];
    final done = Completer<void>();
    runZonedGuarded(() async {
      var tries = 0;
      final host = WebViewHost(
        baseDirectory: () async => dir,
        useEnvironment: false,
        start: (_) async {
          tries++;
          if (tries.isOdd) throw cannotCreate;
        },
        stop: (_) async {},
      );
      // Cada pedido maneja su resultado, como en la app: o una WebView o WebViewUnavailable.
      final results = await Future.wait([
        for (var i = 0; i < 4; i++)
          host.run('solver', (_) => _Fake(i)).then<Object>((w) => w, onError: (Object e) => e),
      ]);
      expect(results.every((r) => r is _Fake || r is WebViewUnavailable), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      done.complete();
    }, (error, _) {
      uncaught.add(error);
      if (!done.isCompleted) done.complete();
    });
    await done.future;
    expect(uncaught, isEmpty);
  });
}
