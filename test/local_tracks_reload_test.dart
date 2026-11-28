// La música del teléfono se lee una vez: cambiar el estilo u otro ajuste que no tiene que ver no
// vuelve a leer el MediaStore entero (antes: «52 audios que no son música quedan afuera» decenas
// de veces al cambiar de tema o deslizar).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/local_library/domain/local_exclusions.dart';
import 'package:kiji_player/features/local_library/domain/local_library_source.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/local_library_provider.dart';

class _CountingSource implements LocalLibrarySource {
  int loads = 0;

  @override
  bool get usesFolders => false;
  @override
  Future<List<String>> folders() async => const [];
  @override
  Future<bool> hasAccess() async => true;
  @override
  Future<bool> requestAccess() async => true;
  @override
  Future<void> removeFolder(String folder) async {}
  @override
  Future<List<Track>> loadTracks({bool force = false, LocalExclusions exclusions = LocalExclusions.defaults}) async {
    loads++;
    return const [];
  }
}

class _Settings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings(phoneMusic: 'on');
  @override
  Future<void> update(AppSettings Function(AppSettings) change) async => state = change(state);
}

void main() {
  test('Cambiar el estilo, el tema u otros ajustes no vuelve a leer la música del teléfono', () async {
    final source = _CountingSource();
    final c = ProviderContainer(
      overrides: [
        localLibrarySourceProvider.overrideWithValue(source),
        settingsProvider.overrideWith(_Settings.new),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(localTracksProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(localTracksProvider.future);
    expect(source.loads, 1);

    for (final style in ['graphite', 'paper', 'nocturne']) {
      await c.read(settingsProvider.notifier).update((s) => s.copyWith(style: style));
      await Future<void>.delayed(Duration.zero);
      await c.read(localTracksProvider.future);
    }
    await c.read(settingsProvider.notifier).update((s) => s.copyWith(highPerformance: true));
    await Future<void>.delayed(Duration.zero);
    expect(source.loads, 1, reason: 'nada de eso cambia la lista');

    // Lo que sí la cambia: ocultar los audios cortos.
    await c.read(settingsProvider.notifier).update((s) => s.copyWith(hideShortAudios: true));
    await Future<void>.delayed(Duration.zero);
    await c.read(localTracksProvider.future);
    expect(source.loads, 2);
  });

  test('Sin la música del dispositivo (0.9) no se lee nada ni se pide permiso', () async {
    final source = _CountingSource();
    final c = ProviderContainer(
      overrides: [
        localLibrarySourceProvider.overrideWithValue(source),
        settingsProvider.overrideWith(_Off.new),
      ],
    );
    addTearDown(c.dispose);
    expect(await c.read(localTracksProvider.future), isEmpty);
    expect(source.loads, 0);
  });
}

class _Off extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings(phoneMusic: 'off');
  @override
  Future<void> update(AppSettings Function(AppSettings) change) async => state = change(state);
}