import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/updates/update_checker.dart';
import 'package:kiji_player/features/updates/updates_screen.dart';

/// GitHub falso: cuenta las consultas y responde lo que diga el test.
class _FakeGitHub extends Interceptor {
  int calls = 0;
  int status = 200;
  Object? body;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    calls++;
    expect(options.uri.toString(), 'https://api.github.com/repos/$kijiRepo/releases/latest');
    handler.resolve(Response(requestOptions: options, statusCode: status, data: body));
  }
}

void main() {
  test('kijiVersion coincide con pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*([^+\s]+)', multiLine: true).firstMatch(pubspec)!.group(1);
    expect(kijiVersion, version);
  });

  test('Comparar versiones', () {
    expect(compareVersions('1.2.10', '1.2.9'), greaterThan(0));
    expect(compareVersions('1.0.0', '1.0.0'), 0);
    expect(compareVersions('1.0', '1.0.1'), lessThan(0));
    expect(compareVersions('2.0.0+5', '2.0.0'), 0);
  });

  test('Versión publicada: solo se abre la página del repositorio oficial', () {
    final ok = Release.fromJson({
      'tag_name': 'v1.2.0',
      'name': 'Kiji 1.2',
      'body': 'Novedades inventadas',
      'html_url': 'https://github.com/$kijiRepo/releases/tag/v1.2.0',
    })!;
    expect(ok.version, '1.2.0');
    expect(ok.url, 'https://github.com/$kijiRepo/releases/tag/v1.2.0');
    final raro = Release.fromJson({'tag_name': 'v9', 'html_url': 'https://otro-sitio.example/bajar'})!;
    expect(raro.url, kijiReleasesPage);
    expect(Release.fromJson({'tag_name': 'v2', 'prerelease': true}), isNull);
  });

  test('"Hace…" en palabras', () {
    final now = DateTime(2026, 10, 17, 12);
    expect(agoText(now.subtract(const Duration(seconds: 20)), now), 'recién');
    expect(agoText(now.subtract(const Duration(hours: 1)), now), 'hace 1 hora');
    expect(agoText(now.subtract(const Duration(days: 3)), now), 'hace 3 días');
  });

  group('Consultas', () {
    late Directory dir;
    late _FakeGitHub github;
    late DateTime now;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('kiji_upd');
      github = _FakeGitHub();
      now = DateTime(2026, 10, 17, 12);
    });
    tearDown(() async {
      // Que terminen las escrituras en segundo plano antes de borrar (Windows no deja).
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        try {
          dir.deleteSync(recursive: true);
          return;
        } on FileSystemException {
          continue;
        }
      }
    });

    ProviderContainer container({bool enabled = true}) {
      if (!enabled) File('${dir.path}/settings.json').writeAsStringSync('{"checkUpdates": false}');
      final c = ProviderContainer(overrides: [
        settingsProvider.overrideWith(() => SettingsNotifier(directory: () async => dir)),
        updateProvider.overrideWith(() => UpdateNotifier(
              dio: Dio()..interceptors.add(github),
              directory: () async => dir.path,
              now: () => now,
            )),
      ]);
      addTearDown(c.dispose);
      c.read(settingsProvider);
      return c;
    }

    Future<void> settle() async {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }

    test('Apagado: nunca consulta', () async {
      final c = container(enabled: false);
      await c.read(updateProvider.notifier).checkIfDue();
      expect(github.calls, 0);
    });

    test('Versión nueva: la muestra; y no vuelve a consultar el mismo día', () async {
      github.body = {'tag_name': 'v9.0.0', 'name': 'Kiji 9', 'body': 'Cambios', 'html_url': 'https://github.com/$kijiRepo/releases/tag/v9.0.0'};
      final c = container();
      await c.read(updateProvider.notifier).checkIfDue();
      expect(github.calls, 1);
      expect(c.read(updateProvider).latest?.version, '9.0.0');
      await settle();

      now = now.add(const Duration(hours: 5));
      await c.read(updateProvider.notifier).checkIfDue();
      expect(github.calls, 1, reason: 'una vez por día');

      now = now.add(const Duration(days: 1));
      await c.read(updateProvider.notifier).checkIfDue();
      expect(github.calls, 2);
    });

    test('Misma versión o sin versiones publicadas: nada nuevo', () async {
      github.body = {'tag_name': 'v$kijiVersion', 'html_url': 'https://github.com/$kijiRepo/releases/tag/v$kijiVersion'};
      final c = container();
      await c.read(updateProvider.notifier).checkNow();
      expect(c.read(updateProvider).latest, isNull);
      expect(c.read(updateProvider).message, contains('última versión'));

      github.status = 404;
      github.body = null;
      await c.read(updateProvider.notifier).checkNow();
      expect(c.read(updateProvider).message, 'Todavía no hay versiones publicadas.');
    });
  });
}
