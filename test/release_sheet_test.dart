// La hoja de una versión nueva: novedades en el idioma de la app, "Actualizar (tamaño)" y siempre
// la página oficial. Nada se baja sin tocar el botón.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/updates/app_update.dart';
import 'package:kiji_player/features/updates/domain/update_assets.dart';
import 'package:kiji_player/features/updates/domain/update_installer.dart';
import 'package:kiji_player/features/updates/update_checker.dart';
import 'package:kiji_player/features/updates/updates_screen.dart';
import 'package:kiji_player/l10n/l10n.dart';

class _Installer implements UpdateInstaller {
  _Installer(this.asset);
  final ReleaseAsset? asset;
  var installs = 0;

  @override
  Future<ReleaseAsset?> pickAsset(Release release) async => asset;
  @override
  Future<bool> canInstall() async => true;
  @override
  Future<void> openInstallPermission() async {}
  @override
  Future<bool?> sameSigner(File file) async => true;
  @override
  bool get confirmBeforeInstall => false;
  @override
  Future<void> install(File file) async => installs++;
}

const _apk = ReleaseAsset(
  name: 'Kiji-Player-arm64.apk',
  url: 'https://github.com/$kijiRepo/releases/download/v9.9.9/Kiji-Player-arm64.apk',
  size: 34531473,
);

const _release = Release(
  version: '9.9.9',
  name: 'v9.9.9',
  notes: '## Novedades\n- Something new\n\n## Español\n\n## Novedades\n- Algo nuevo',
  url: kijiReleasesPage,
  assets: [_apk],
);

void main() {
  for (final (language, label, note) in [('es', 'Actualizar', 'Algo nuevo'), ('en', 'Update', 'Something new')]) {
    testWidgets('Hoja de versión nueva ($language), también en horizontal', (tester) async {
      setKijiLocale(Locale(language));
      tester.view.physicalSize = const Size(2400, 1080);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final installer = _Installer(_apk);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appUpdateProvider.overrideWith(() => AppUpdateNotifier(installer: installer))],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) =>
                    TextButton(onPressed: () => showReleaseSheet(context, _release), child: const Text('abrir')),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining(note), findsOneWidget);
      // El botón dice el tamaño; nada se bajó todavía.
      expect(find.textContaining('$label (32'), findsOneWidget);
      expect(find.byKey(const Key('update-open-page')), findsOneWidget);
      expect(installer.installs, 0);
    });
  }

  testWidgets('Sin archivo para este equipo: solo la página oficial', (tester) async {
    setKijiLocale(const Locale('es'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appUpdateProvider.overrideWith(() => AppUpdateNotifier(installer: _Installer(null)))],
        child: const MaterialApp(home: Scaffold(body: ReleaseSheet(release: _release))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('update-start')), findsNothing);
    expect(find.byKey(const Key('update-open-page')), findsOneWidget);
  });
}
