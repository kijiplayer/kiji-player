// El fondo propio de una canción se ve solo en su reproductor; el resto de la app usa el general.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/customize/data/track_overrides.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/features/style/presentation/custom_background.dart';

class _Settings extends SettingsNotifier {
  _Settings(this.initial);
  final AppSettings initial;
  @override
  AppSettings build() => initial;
}

ProviderContainer _make({String? general, String? song}) {
  final c = ProviderContainer(overrides: [
    settingsProvider.overrideWith(() => _Settings(AppSettings(backgroundFile: general, backgroundKind: 'image'))),
    currentTrackStyleProvider.overrideWithValue(
      song == null ? null : TrackOverride(backgroundFile: song, backgroundKind: 'image'),
    ),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('Solo la canción tiene fondo: se ve en el reproductor, no en la app', () {
    final c = _make(song: 'gato.jpg');
    expect(c.read(hasCustomBackgroundProvider), isFalse, reason: 'Inicio, Biblioteca, Búsqueda: el estilo');
    expect(c.read(playerHasCustomBackgroundProvider), isTrue);
    expect(c.read(effectiveBackgroundProvider)!.path, 'canciones/gato.jpg');
  });

  test('Con fondo general y de canción: la app usa el general, el reproductor el de la canción', () {
    final c = _make(general: 'mio.jpg', song: 'gato.jpg');
    expect(c.read(hasCustomBackgroundProvider), isTrue);
    expect(c.read(generalBackgroundProvider)!.path, 'mio.jpg');
    expect(c.read(effectiveBackgroundProvider)!.path, 'canciones/gato.jpg');
  });

  test('Sin fondos propios: nada', () {
    final c = _make();
    expect(c.read(hasCustomBackgroundProvider), isFalse);
    expect(c.read(playerHasCustomBackgroundProvider), isFalse);
  });
}
