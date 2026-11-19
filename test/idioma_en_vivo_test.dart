// Con la app en inglés no queda nada en español (presets del ecualizador, cartelera del Teatro, lo
// que se le pide a YouTube Music), y al cambiar de idioma cambia todo sin reiniciar.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/equalizer/domain/equalizer_model.dart';
import 'package:kiji_player/features/yt_music/data/ytm_client.dart';
import 'package:kiji_player/l10n/l10n.dart';

void main() {
  tearDown(() => setKijiLocale(const Locale('es')));

  test('Presets del ecualizador, cartelera y YouTube Music siguen el idioma de la app', () {
    setKijiLocale(const Locale('es'));
    // Se leen primero en español (como cuando Kiji arranca)…
    expect(eqPresets.map((p) => p.label), containsAll(['Bajos', 'Voz', 'Noche', 'Acústico']));
    expect(tx.cartelKijiTeatro, contains('TEATRO'));
    expect(ytLanguage, 'es');

    // …y al pasar a inglés ya no queda nada en español.
    setKijiLocale(const Locale('en'));
    final labels = eqPresets.map((p) => p.label).toList();
    expect(labels, containsAll(['Bass', 'Vocal', 'Night', 'Acoustic']));
    expect(labels, isNot(contains('Bajos')));
    expect(tx.cartelKijiTeatro, contains('THEATER'));
    expect(ytLanguage, 'en');
  });
}
