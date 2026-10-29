// Prueba larga de las WebView ocultas en Windows (solo en la PC):
//   flutter test integration_test/webview_largo_test.dart -d windows
// Simula lo que pasaba tras horas con Kiji abierta: una WebView que queda viva (la traducción),
// la ventana en la bandeja y el proceso de WebView2 de Kiji trabado. Crear otra WebView tiene que
// recuperarse sola (entorno nuevo en otra carpeta) sin errores sin dueño.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kiji_player/utils/webview_host.dart';
import 'package:window_manager/window_manager.dart';

/// Congela o descongela los procesos de WebView2 que usan [folder] (NtSuspendProcess / NtResumeProcess).
Future<int> _freeze(String folder, {required bool frozen}) async {
  final call = frozen ? 'NtSuspendProcess' : 'NtResumeProcess';
  final script = '''
Add-Type @"
using System; using System.Runtime.InteropServices;
public class K { [DllImport("ntdll.dll")] public static extern int $call(IntPtr h);
[DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(int a, bool i, int id);
[DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h); }
"@
\$n = 0
Get-CimInstance Win32_Process -Filter "Name='msedgewebview2.exe'" | Where-Object { \$_.CommandLine -like '*${folder.replaceAll("'", "''")}*' } | ForEach-Object {
  \$h = [K]::OpenProcess(0x0800, \$false, \$_.ProcessId); if (\$h -ne [IntPtr]::Zero) { [K]::$call(\$h) | Out-Null; [K]::CloseHandle(\$h) | Out-Null; \$n++ } }
\$n''';
  final result = await Process.run('powershell', ['-NoProfile', '-Command', script]);
  return int.tryParse('${result.stdout}'.trim()) ?? 0;
}

HeadlessInAppWebView _page(WebViewEnvironment? environment, Completer<void> loaded, String text) =>
    HeadlessInAppWebView(
      webViewEnvironment: environment,
      initialData: InAppWebViewInitialData(data: '<html><body>$text</body></html>'),
      onLoadStop: (_, _) {
        if (!loaded.isCompleted) loaded.complete();
      },
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tras "horas" (WebView viva, bandeja, proceso trabado) crear otra WebView se recupera sola', (
    tester,
  ) async {
    final uncaught = <Object>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) => uncaught.add(details.exception);
    addTearDown(() => FlutterError.onError = previous);

    await windowManager.ensureInitialized();
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('prueba larga'))));
    final base = Directory.systemTemp.createTempSync('kiji_webview_largo_');
    final host = WebViewHost(baseDirectory: () async => base);

    await tester.runAsync(() async {
      // 1. La "traducción" queda viva todo el tiempo.
      final keepLoaded = Completer<void>();
      final keep = await host.run('traducción', (env) => _page(env, keepLoaded, 'traducción'));
      await keepLoaded.future.timeout(const Duration(seconds: 20));
      final firstFolder = host.folder!;
      debugPrint('=== PRUEBA: traducción viva en ${firstFolder.split(r'\').last} ===');

      // 2. La ventana va a la bandeja.
      await windowManager.hide();
      await Future<void>.delayed(const Duration(seconds: 1));

      // 3. El proceso de WebView2 de Kiji queda trabado.
      final frozen = await _freeze(firstFolder, frozen: true);
      debugPrint('=== PRUEBA: procesos de WebView2 congelados: $frozen ===');
      expect(frozen, greaterThan(0), reason: 'tiene que haber un proceso de WebView2 de Kiji para congelar');

      // 4. Pedir el solver: se tiene que recuperar solo, en otra carpeta.
      final solverLoaded = Completer<void>();
      final solver = await host.run('solver', (env) => _page(env, solverLoaded, 'solver'));
      await solverLoaded.future.timeout(const Duration(seconds: 20));
      debugPrint('=== PRUEBA: solver creado; renovaciones: ${host.renewals}; carpeta ${host.folder!.split(r'\').last} ===');
      expect(host.renewals, greaterThanOrEqualTo(1));
      expect(host.folder, isNot(firstFolder));

      await _freeze(firstFolder, frozen: false);
      try {
        await keep.dispose();
      } catch (error) {
        debugPrint('=== PRUEBA: al cerrar la traducción vieja: $error ===');
      }
      await solver.dispose();

      // 5. Horas de uso: abrir y cerrar como cada 5 minutos, con la ventana oculta.
      for (var i = 1; i <= 24; i++) {
        final loaded = Completer<void>();
        final webView = await host.run(['solver', 'PO token', 'traducción'][i % 3], (env) => _page(env, loaded, '$i'));
        await loaded.future.timeout(const Duration(seconds: 20));
        await webView.dispose();
      }
      debugPrint('=== PRUEBA: 24 ciclos de abrir y cerrar con la ventana oculta: OK ===');
      await windowManager.show();
    });

    expect(uncaught, isEmpty, reason: 'nada de errores sin dueño');
    try {
      base.deleteSync(recursive: true);
    } catch (error) {
      debugPrint('=== PRUEBA: carpeta temporal en uso todavía: $error ===');
    }
  }, timeout: const Timeout(Duration(minutes: 15)));
}
