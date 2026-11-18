// "Actualizar" desde Kiji: qué APK se elige por arquitectura, cómo se verifica la descarga y que
// con una suma o una firma distinta no se instala nada. Las "releases" se sirven desde la misma PC.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/updates/app_update.dart';
import 'package:kiji_player/features/updates/data/windows_update_installer.dart';
import 'package:kiji_player/features/updates/domain/update_assets.dart';
import 'package:kiji_player/features/updates/domain/update_installer.dart';
import 'package:kiji_player/features/updates/update_checker.dart';

ReleaseAsset _asset(String name, {String? digest}) =>
    ReleaseAsset(name: name, url: 'https://github.com/$kijiRepo/releases/download/v9.9.9/$name', size: 10, digest: digest);

final _all = [
  for (final name in [
    'Kiji-Player-9.9.9.apk',
    'Kiji-Player-9.9.9-arm64-v8a.apk',
    'Kiji-Player-9.9.9-armeabi-v7a.apk',
    'Kiji-Player-9.9.9-x86_64.apk',
    'Kiji-Player.apk',
    'Kiji-Player-arm64.apk',
    'Kiji-Player-Windows-Setup.exe',
  ])
    _asset(name),
];

/// Instalador de mentira: anota qué se instaló.
class _FakeInstaller implements UpdateInstaller {
  _FakeInstaller({this.signer = true, this.permission = true, this.confirm = false});

  final bool? signer;
  bool permission;
  final bool confirm;
  final installed = <String>[];

  @override
  Future<ReleaseAsset?> pickAsset(Release release) async =>
      pickAndroidAsset(const ['arm64-v8a', 'armeabi-v7a'], release.assets, release.version);

  @override
  Future<bool> canInstall() async => permission;

  @override
  Future<void> openInstallPermission() async {}

  @override
  Future<bool?> sameSigner(File file) async => signer;

  @override
  bool get confirmBeforeInstall => confirm;

  @override
  Future<void> install(File file) async => installed.add(file.uri.pathSegments.last);
}

void main() {
  group('Elegir el APK', () {
    test('arm64-v8a: el arm64 de nombre fijo', () {
      expect(pickAndroidAsset(['arm64-v8a', 'armeabi-v7a', 'armeabi'], _all, '9.9.9')!.name, 'Kiji-Player-arm64.apk');
    });
    test('armeabi-v7a y x86_64: el de su arquitectura', () {
      expect(pickAndroidAsset(['armeabi-v7a', 'armeabi'], _all, '9.9.9')!.name, 'Kiji-Player-9.9.9-armeabi-v7a.apk');
      expect(pickAndroidAsset(['x86_64', 'x86'], _all, '9.9.9')!.name, 'Kiji-Player-9.9.9-x86_64.apk');
    });
    test('si no está el de su arquitectura, o es otra (x86), el universal', () {
      final sinV7 = _all.where((a) => !a.name.contains('armeabi')).toList();
      expect(pickAndroidAsset(['armeabi-v7a'], sinV7, '9.9.9')!.name, 'Kiji-Player.apk');
      expect(pickAndroidAsset(['x86'], _all, '9.9.9')!.name, 'Kiji-Player.apk');
      expect(pickAndroidAsset([], _all, '9.9.9')!.name, 'Kiji-Player.apk');
    });
    test('sin ningún APK conocido: ninguno (se ofrece la página)', () {
      expect(pickAndroidAsset(['arm64-v8a'], [_asset('otra-cosa.apk')], '9.9.9'), isNull);
    });
    test('Windows: el instalador de nombre fijo', () {
      expect(pickWindowsAsset(_all, '9.9.9')!.name, 'Kiji-Player-Windows-Setup.exe');
    });
  });

  group('Windows', () {
    test('solo se ofrece si Kiji vino del instalador (está unins000.exe)', () async {
      final dir = Directory.systemTemp.createTempSync('kiji_win');
      addTearDown(() => dir.deleteSync(recursive: true));
      final exe = '${dir.path}${Platform.pathSeparator}kiji_player.exe';
      final release = Release(version: '9.9.9', name: 'v9.9.9', notes: '', url: kijiReleasesPage, assets: _all);
      expect(await WindowsUpdateInstaller(executable: exe).pickAsset(release), isNull);
      File('${dir.path}${Platform.pathSeparator}unins000.exe').writeAsStringSync('');
      expect((await WindowsUpdateInstaller(executable: exe).pickAsset(release))!.name, 'Kiji-Player-Windows-Setup.exe');
    });
    test('el instalador se abre en silencio, en modo actualización, y vuelve a abrir Kiji', () {
      expect(WindowsUpdateInstaller.arguments, containsAll(['/SILENT', '/SUPPRESSMSGBOXES', '/KIJIUPDATE=1']));
      expect(WindowsUpdateInstaller().confirmBeforeInstall, isTrue);
    });
  });

  group('Verificar', () {
    final a = 'a' * 64, b = 'b' * 64;

    test('lee SHA256SUMS.txt (con y sin asterisco)', () {
      final sums = parseSha256Sums('$a  Kiji-Player.apk\n${b.toUpperCase()} *Kiji-Player-Windows-Setup.exe\nbasura\n');
      expect(sums, {'Kiji-Player.apk': a, 'Kiji-Player-Windows-Setup.exe': b});
    });
    test('la suma esperada: SHA256SUMS, o la de GitHub; si no coinciden, ninguna', () {
      expect(expectedSha256(_asset('x.apk', digest: a), {'x.apk': a}), a);
      expect(expectedSha256(_asset('x.apk'), {'x.apk': a}), a);
      expect(expectedSha256(_asset('x.apk', digest: b), const {}), b);
      expect(expectedSha256(_asset('x.apk', digest: b), {'x.apk': a}), isNull);
      expect(expectedSha256(_asset('x.apk'), const {}), isNull);
    });
    test('el GitHub "digest" del JSON de la release', () {
      final asset = ReleaseAsset.fromJson({
        'name': 'Kiji-Player.apk',
        'browser_download_url': 'https://github.com/$kijiRepo/releases/download/v1/Kiji-Player.apk',
        'size': 5,
        'digest': 'sha256:$a',
      })!;
      expect(asset.digest, a);
    });
    test('el archivo coincide o no; sin suma, nunca', () async {
      final dir = Directory.systemTemp.createTempSync('kiji_suma');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/x.apk')..writeAsStringSync('kiji');
      final right = sha256.convert(utf8.encode('kiji')).toString();
      expect(await verifySha256(file, right), isTrue);
      expect(await verifySha256(file, a), isFalse);
      expect(await verifySha256(file, null), isFalse);
    });
  });

  group('Actualizar de punta a punta (release servida en 127.0.0.1)', () {
    late HttpServer server;
    late Directory dir;
    final apk = utf8.encode('APK de prueba de Kiji');
    final apkSha = sha256.convert(apk).toString();
    late UpdateSource source;

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('kiji_actualizar');
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      source = UpdateSource(downloadPrefix: 'http://127.0.0.1:${server.port}/', test: true);
    });
    tearDown(() async {
      await server.close(force: true);
      dir.deleteSync(recursive: true);
    });

    void serve(String sums) => server.listen((request) {
      final body = switch (request.uri.path) {
        '/Kiji-Player-arm64.apk' => apk,
        '/SHA256SUMS.txt' => utf8.encode(sums),
        _ => null,
      };
      if (body == null) request.response.statusCode = 404;
      request.response
        ..headers.contentLength = body?.length ?? 0
        ..add(body ?? const [])
        ..close();
    });

    Release release() => Release(
      version: '9.9.9',
      name: 'v9.9.9',
      notes: '',
      url: kijiReleasesPage,
      assets: [
        ReleaseAsset(name: 'Kiji-Player-arm64.apk', url: '${source.downloadPrefix}Kiji-Player-arm64.apk', size: apk.length),
        ReleaseAsset(name: sha256SumsName, url: '${source.downloadPrefix}SHA256SUMS.txt', size: 100),
      ],
    );

    ProviderContainer container(_FakeInstaller installer, {bool askMobile = false}) {
      final c = ProviderContainer(
        overrides: [
          appUpdateProvider.overrideWith(
            () => AppUpdateNotifier(
              installer: installer,
              directory: () async => dir,
              mustAskForMobileData: () async => askMobile,
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    File downloaded() => File('${dir.path}/updates/Kiji-Player-arm64.apk');

    test('con la suma y la firma correctas, instala', () async {
      serve('$apkSha  Kiji-Player-arm64.apk\n');
      final installer = _FakeInstaller();
      final c = container(installer);
      await c.read(appUpdateProvider.notifier).start(release(), source: source);
      expect(installer.installed, ['Kiji-Player-arm64.apk']);
      expect(c.read(appUpdateProvider).phase, AppUpdatePhase.installing);
      expect(downloaded().existsSync(), isTrue);
    });

    test('con un hash incorrecto NO instala y borra el archivo', () async {
      serve('${'0' * 64}  Kiji-Player-arm64.apk\n');
      final installer = _FakeInstaller();
      final c = container(installer);
      await c.read(appUpdateProvider.notifier).start(release(), source: source);
      expect(installer.installed, isEmpty);
      expect(c.read(appUpdateProvider).failure, AppUpdateFailure.checksum);
      expect(downloaded().existsSync(), isFalse);
    });

    test('sin suma publicada NO instala', () async {
      serve('');
      final installer = _FakeInstaller();
      final c = container(installer);
      await c.read(appUpdateProvider.notifier).start(release(), source: source);
      expect(installer.installed, isEmpty);
      expect(c.read(appUpdateProvider).failure, AppUpdateFailure.noChecksum);
      expect(downloaded().existsSync(), isFalse);
    });

    test('con otro certificado NO instala y borra el archivo', () async {
      serve('$apkSha  Kiji-Player-arm64.apk\n');
      final installer = _FakeInstaller(signer: false);
      final c = container(installer);
      await c.read(appUpdateProvider.notifier).start(release(), source: source);
      expect(installer.installed, isEmpty);
      expect(c.read(appUpdateProvider).failure, AppUpdateFailure.signer);
      expect(downloaded().existsSync(), isFalse);
    });

    test('una dirección fuera del repositorio oficial no se baja', () async {
      serve('$apkSha  Kiji-Player-arm64.apk\n');
      final installer = _FakeInstaller();
      final c = container(installer);
      // Fuente oficial, archivos en 127.0.0.1: no se acepta.
      await c.read(appUpdateProvider.notifier).start(release());
      expect(installer.installed, isEmpty);
      expect(c.read(appUpdateProvider).failure, AppUpdateFailure.noAsset);
    });

    test('sin permiso: primero se explica; con el permiso, instala', () async {
      serve('$apkSha  Kiji-Player-arm64.apk\n');
      final installer = _FakeInstaller(permission: false);
      final c = container(installer);
      await c.read(appUpdateProvider.notifier).start(release(), source: source);
      expect(c.read(appUpdateProvider).phase, AppUpdatePhase.needsPermission);
      expect(installer.installed, isEmpty);
      installer.permission = true;
      await c.read(appUpdateProvider.notifier).resumeAfterPermission();
      expect(installer.installed, ['Kiji-Player-arm64.apk']);
    });

    test('sin WiFi (con "solo WiFi" o ahorro de datos): pregunta antes de bajar', () async {
      serve('$apkSha  Kiji-Player-arm64.apk\n');
      final installer = _FakeInstaller();
      final c = container(installer, askMobile: true);
      await c.read(appUpdateProvider.notifier).start(release(), source: source);
      expect(c.read(appUpdateProvider).phase, AppUpdatePhase.askMobileData);
      expect(downloaded().existsSync(), isFalse);
      await c.read(appUpdateProvider.notifier).useMobileData();
      expect(installer.installed, ['Kiji-Player-arm64.apk']);
    });

    test('Cancelar a mitad: no instala, borra lo bajado y vuelve al principio', () async {
      // Una descarga lenta: 1 KB cada 20 ms.
      server.listen((request) async {
        if (request.uri.path == '/SHA256SUMS.txt') {
          request.response.write('$apkSha  Kiji-Player-arm64.apk\n');
          await request.response.close();
          return;
        }
        request.response.headers.contentLength = 200 * 1024;
        try {
          for (var i = 0; i < 200; i++) {
            request.response.add(List.filled(1024, 1));
            await request.response.flush();
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
          await request.response.close();
        } catch (_) {
          // El cliente cortó (se canceló): es lo esperado en esta prueba.
        }
      });
      final installer = _FakeInstaller();
      final c = container(installer);
      final notifier = c.read(appUpdateProvider.notifier);
      final running = notifier.start(release(), source: source);
      while (c.read(appUpdateProvider).received == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(c.read(appUpdateProvider).phase, AppUpdatePhase.downloading);
      notifier.cancel();
      await running;
      expect(c.read(appUpdateProvider).phase, AppUpdatePhase.idle);
      expect(installer.installed, isEmpty);
      expect(downloaded().existsSync(), isFalse);
    });

    test('Windows: verificado, espera la confirmación', () async {
      serve('$apkSha  Kiji-Player-arm64.apk\n');
      final installer = _FakeInstaller(confirm: true);
      final c = container(installer);
      await c.read(appUpdateProvider.notifier).start(release(), source: source);
      expect(c.read(appUpdateProvider).phase, AppUpdatePhase.readyToInstall);
      expect(installer.installed, isEmpty);
      await c.read(appUpdateProvider.notifier).install();
      expect(installer.installed, ['Kiji-Player-arm64.apk']);
    });
  });
}
