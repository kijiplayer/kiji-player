import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/reports/data/error_report.dart';
import 'package:kiji_player/features/reports/data/error_reporter.dart';
import 'package:kiji_player/features/reports/data/log_file.dart';
import 'package:kiji_player/features/reports/data/log_scrubber.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/utils/app_log.dart';

void main() {
  group('Sin datos personales', () {
    test('Correos, claves, tokens, IPs, URLs de audio y usuarios en rutas se ocultan', () {
      const raw = 'usuario ana.perez@example.com clave AIzaSyA1234567890abcdefghijklmnopqrstu '
          'url https://rr3---sn-abc.googlevideo.com/videoplayback?ip=181.1.2.3&sig=XYZ&pot=abc '
          'ruta C:\\Users\\Ana\\Music\\canción.mp3 y /storage/emulated/0/Music/x.mp3 '
          'player?key=secreto&n=abc token=zzz desde 192.168.0.10 '
          'cookie larga eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9eyJzdWIiOiIxMjM0NTY3ODkwIn0';
      final clean = scrubPersonalData(raw);
      for (final secret in [
        'ana.perez@example.com', 'AIzaSy', 'googlevideo.com/videoplayback', '181.1.2.3', 'XYZ',
        'Users\\Ana', '/storage/emulated', 'secreto', '192.168.0.10', 'eyJhbGci', 'token=zzz',
      ]) {
        expect(clean, isNot(contains(secret)), reason: secret);
      }
    });

    test('Lo que sirve para entender una falla queda', () {
      const raw = 'EXTRACTOR: ResolvedStream(A/WEB_REMIX, 140 kbps) video dQw4w9WgXcQ cargada en 2 s';
      expect(scrubPersonalData(raw), raw);
    });
  });

  group('Registro guardado', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('kiji_t3'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('Rota al pasar el tamaño: nunca ocupa más de dos archivos', () async {
      final log = LogFile(dir, maxBytes: 2000);
      for (var i = 0; i < 300; i++) {
        log.write(LogLine(DateTime(2026, 10, 18), 'línea número $i con algo de texto'));
      }
      expect(log.previous.existsSync(), isTrue);
      expect(await log.sizeBytes(), lessThan(2 * 2000 + 200));
      final all = await log.readAll();
      expect(all, contains('línea número 299'));
      expect(all, isNot(contains('línea número 0 ')));
    });

    test('Se guarda sin datos personales y se puede borrar', () async {
      final log = LogFile(dir);
      log.write(LogLine(DateTime(2026), 'correo ana@example.com'));
      expect(await log.readAll(), allOf(contains('[correo]'), isNot(contains('ana@'))));
      await log.delete();
      expect(await log.sizeBytes(), 0);
    });
  });

  group('Informes', () {
    setUp(ErrorReporter.instance.reset);

    test('Los cortes de red no son fallas de Kiji', () {
      ErrorReporter.instance.capture(const SocketException('Connection reset'), null, where: 'segundo plano');
      expect(ErrorReporter.instance.pending.value, isNull);
    });

    test('Como mucho un aviso por sesión, aunque los errores sean distintos', () {
      final reporter = ErrorReporter.instance;
      reporter.capture(StateError('falso'), StackTrace.current, where: 'interfaz');
      expect(reporter.pending.value?.summary, 'Algo falló en la pantalla');
      reporter.dismiss();
      reporter.capture(ArgumentError('otro'), StackTrace.current, where: 'segundo plano');
      reporter.unplayable('abcdefghijk');
      expect(reporter.pending.value, isNull);
      expect(reporter.recent.length, 3, reason: 'igual quedan en la lista de la sesión');
    });

    test('Errores de dibujo (un texto que no entra) van solo al registro, sin aviso', () {
      final reporter = ErrorReporter.instance;
      reporter.captureFlutter(FlutterErrorDetails(exception: FlutterError('A RenderFlex overflowed by 28 pixels on the right.')));
      reporter.capture(FlutterError('setState() or markNeedsBuild() called during build.'), null, where: 'interfaz');
      expect(reporter.pending.value, isNull);
      expect(reporter.recent, isEmpty);
    });

    test('El informe trae versión, qué pasó y el registro limpio', () {
      final text = buildReportText(
        ErrorReport(summary: 'Algo falló al reproducir', where: 'reproducción', detail: 'StateError: mail a@b.com'),
        log: 'línea 1\nlínea con https://x.googlevideo.com/videoplayback?ip=1.2.3.4\nlínea 3',
        platform: 'android 16',
      );
      expect(text, contains('Versión:'));
      expect(text, contains('Qué pasó: Algo falló al reproducir'));
      expect(text, contains('línea 3'));
      expect(text, isNot(contains('a@b.com')));
      expect(text, isNot(contains('1.2.3.4')));
    });

    test('El enlace de GitHub usa el formulario de errores y no se pasa de largo', () {
      final longLog = List.generate(500, (i) => 'REPRODUCCION: línea larga de prueba número $i ' * 3).join('\n');
      final uri = githubIssueUri(ErrorReport(summary: 'Algo falló', where: 'interfaz'), log: longLog);
      expect(uri.host, 'github.com');
      expect(uri.path, '/kijiplayer/kiji-player/issues/new');
      expect(uri.queryParameters['template'], 'error.yml');
      expect(uri.queryParameters['informe'], contains('Qué pasó: Algo falló'));
      expect(uri.toString().length, lessThanOrEqualTo(7500));
    });
  });

  test('Los ajustes nuevos vienen prendidos y se guardan', () {
    const d = AppSettings();
    expect(d.saveLogs, isTrue);
    expect(d.offerErrorReports, isTrue);
    final back = AppSettings.fromJson(d.copyWith(saveLogs: false, offerErrorReports: false).toJson());
    expect(back.saveLogs, isFalse);
    expect(back.offerErrorReports, isFalse);
  });
}
