import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/features/style/data/background_store.dart';
import 'package:kiji_player/features/style/presentation/custom_background.dart';
import 'package:kiji_player/l10n/app_localizations.dart';

class _Settings extends SettingsNotifier {
  _Settings(this.initial);
  final AppSettings initial;
  @override
  AppSettings build() => initial;
  @override
  Future<void> update(AppSettings Function(AppSettings) change) async => state = change(state);
}

/// Vista previa del fondo (0.8.3): la app con el fondo elegido, que cambia al momento.
void main() {
  testWidgets('Con un fondo elegido se ve la vista previa, y el desenfoque cambia al momento', (tester) async {
    // Carpeta temporal fija (se reutiliza): en Windows, la imagen queda abierta un rato y la
    // carpeta no se puede borrar enseguida.
    final dir = Directory('${Directory.systemTemp.path}/kiji_fondo_prueba')..createSync(recursive: true);
    // Un PNG inventado de 1 × 1.
    File('${dir.path}/fondo.png').writeAsBytesSync(const [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
      0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0, //
      0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, //
      0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ]);
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backgroundFolderProvider.overrideWith((ref) async => dir),
          settingsProvider.overrideWith(() => _Settings(const AppSettings(backgroundFile: 'fondo.png', backgroundBlur: 0))),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: SingleChildScrollView(child: BackgroundOptions())),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('background-preview')), findsOneWidget);
    // Con la proporción de la pantalla: se ve entera, sin recortes.
    final preview = tester.getSize(find.byKey(const Key('background-preview')));
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(preview.width / preview.height, closeTo(screen.width / screen.height, 0.01));
    // Sin desenfoque, nada que desenfocar; al mover el control, al momento.
    expect(find.descendant(of: find.byKey(const Key('background-preview')), matching: find.byType(ImageFiltered)), findsNothing);
    await container.read(settingsProvider.notifier).update((s) => s.copyWith(backgroundBlur: 12));
    await tester.pump();
    final filtered = tester.widget<ImageFiltered>(
      find.descendant(of: find.byKey(const Key('background-preview')), matching: find.byType(ImageFiltered)),
    );
    expect(filtered.imageFilter, ImageFilter.blur(sigmaX: 12, sigmaY: 12));
    // Sin fondo, no hay vista previa.
    await container.read(settingsProvider.notifier).update((s) => s.copyWith(clearBackground: true));
    await tester.pump();
    expect(find.byKey(const Key('background-preview')), findsNothing);
  });
}
