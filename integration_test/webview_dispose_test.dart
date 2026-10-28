// Solo PC (Windows): crear y cerrar varias veces una WebView sin ventana, como hacen el solver y el
// PO token. En flutter_inappwebview_windows 0.7.0-beta.3, cerrarla podía cerrar Kiji
// (violación de acceso en FlutterDesktopMessengerSetCallback).
//   flutter test integration_test/webview_dispose_test.dart -d windows
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Abrir y cerrar una WebView sin ventana 6 veces no cierra la app', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    for (var i = 0; i < 6; i++) {
      final loaded = Completer<void>();
      final webView = HeadlessInAppWebView(
        initialData: InAppWebViewInitialData(data: '<html><body>Kiji $i</body></html>'),
        onLoadStop: (_, _) {
          if (!loaded.isCompleted) loaded.complete();
        },
      );
      await tester.runAsync(() async {
        await webView.run();
        await loaded.future.timeout(const Duration(seconds: 30));
        final result = await webView.webViewController?.evaluateJavascript(source: '1 + 1');
        expect('$result', '2');
        await webView.dispose();
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      debugPrint('=== PRUEBA: WebView $i abierta y cerrada ===');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('Dos WebView cerradas a la vez (solver y PO token) y una con JavaScript en curso', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    for (var i = 0; i < 4; i++) {
      Future<HeadlessInAppWebView> open(String name) async {
        final loaded = Completer<void>();
        final webView = HeadlessInAppWebView(
          initialData: InAppWebViewInitialData(data: '<html><body>$name</body></html>'),
          onLoadStop: (_, _) {
            if (!loaded.isCompleted) loaded.complete();
          },
        );
        await webView.run();
        await loaded.future.timeout(const Duration(seconds: 30));
        return webView;
      }

      await tester.runAsync(() async {
        final a = await open('solver');
        final b = await open('potoken');
        // Una espera larga en JavaScript que queda sin terminar al cerrar.
        unawaited(
          a.webViewController
                  ?.callAsyncJavaScript(functionBody: 'await new Promise(r => setTimeout(r, 5000)); return 1;')
                  .then((_) {}, onError: (Object e) => debugPrint('=== PRUEBA: JS cortado: $e ===')) ??
              Future.value(),
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await Future.wait([a.dispose(), b.dispose()]);
        await Future<void>.delayed(const Duration(seconds: 3));
      });
      debugPrint('=== PRUEBA: par $i cerrado ===');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
