// "Carpetas de música": cada carpeta con su nombre y cuántos audios tiene; el interruptor la
// muestra u oculta (y se guarda). Datos inventados.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/local_library/domain/music_filter.dart';
import 'package:kiji_player/features/local_library/presentation/music_folders_screen.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/l10n/l10n.dart';

class _Settings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
  @override
  Future<void> update(AppSettings Function(AppSettings) change) async => state = change(state);
}

void main() {
  testWidgets('Lista las carpetas y el interruptor guarda la elección', (tester) async {
    setKijiLocale(const Locale('en'));
    addTearDown(() => setKijiLocale(const Locale('es')));
    const download = '/storage/emulated/0/Download';
    final c = ProviderContainer(overrides: [
      settingsProvider.overrideWith(_Settings.new),
      musicFoldersProvider.overrideWith((ref) async {
        final choices = ref.watch(settingsProvider.select((s) => s.musicFolderChoices));
        return [
          const MusicFolder(path: '/storage/emulated/0/Music', total: 12, withArtist: 12, shown: true),
          MusicFolder(path: download, total: 6, withArtist: 1, shown: choices[download] ?? false),
        ];
      }),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const MaterialApp(home: MusicFoldersScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Music'), findsOneWidget);
    expect(find.textContaining('12 audios'), findsOneWidget);
    final tile = find.byKey(const Key('music-folder-$download'));
    expect(tester.widget<SwitchListTile>(tile).value, isFalse, reason: 'empieza oculta');
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).musicFolderChoices, {download: true});
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);
  });
}
