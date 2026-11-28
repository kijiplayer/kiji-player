// Ecualizador de 10 bandas (0.9): lo guardado con las 5 bandas de un teléfono pasa a las 10 sin
// perder la forma, y los presets y los perfiles por dispositivo siguen como estaban.
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/equalizer/domain/equalizer_model.dart';

void main() {
  // Las 5 bandas típicas del ecualizador de Android (Hz).
  const phoneBands = [60.0, 230.0, 910.0, 3600.0, 14000.0];

  test('Un «Personalizado» de 5 bandas se lee igual en 10: mismos dB en sus frecuencias', () {
    final saved = EqProfile(presetId: EqProfile.custom, points: {
      for (final (i, hz) in phoneBands.indexed) hz.round(): [4.0, 2.0, -1.0, 3.0, 5.0][i],
    });
    final back = EqProfile.fromJson(saved.toJson());
    // En las frecuencias de antes, el mismo valor.
    expect(back.gainsFor(phoneBands), [4.0, 2.0, -1.0, 3.0, 5.0]);
    // En las 10 bandas, una curva suave entre esos puntos (sin saltos raros).
    final ten = back.gainsFor(tenBands);
    expect(ten, hasLength(10));
    expect(ten.first, 4.0, reason: '31 Hz, antes de la primera: el valor del extremo');
    expect(ten.last, 5.0, reason: '16 kHz, después de la última');
    for (final g in ten) {
      expect(g, inInclusiveRange(-1.0, 5.0));
    }
  });

  test('Los presets ya son de 10 frecuencias: «Bajos» sube los graves y deja los agudos', () {
    const bass = EqProfile(presetId: 'bass');
    final gains = bass.gainsFor(tenBands);
    expect(gains.take(3).every((g) => g >= 5), isTrue);
    expect(gains.skip(6).every((g) => g == 0), isTrue);
  });

  test('Los perfiles por dispositivo se guardan y vuelven', () {
    const settings = EqualizerSettings(
      perDevice: true,
      byOutput: {
        AudioOutputKind.headphones: EqProfile(presetId: 'bass'),
        AudioOutputKind.speaker: EqProfile(presetId: EqProfile.custom, points: {1000: 3, 8000: -2}),
      },
    );
    final back = EqualizerSettings.fromJson(settings.toJson());
    expect(back.profileFor(AudioOutputKind.headphones).presetId, 'bass');
    expect(back.profileFor(AudioOutputKind.speaker).gainsFor(tenBands)[5], 3.0);
  });

  test('Mover una banda de las 10 deja las demás como sonaban', () {
    const rock = EqProfile(presetId: 'rock');
    final before = rock.gainsFor(tenBands);
    final moved = rock.withBand(tenBands, 4, 6);
    final after = moved.gainsFor(tenBands);
    expect(after[4], 6);
    for (var i = 0; i < 10; i++) {
      if (i != 4) expect(after[i], before[i]);
    }
  });
}
