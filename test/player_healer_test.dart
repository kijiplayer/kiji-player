import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:kiji_player/providers/playback_provider.dart';

/// Autocuración (0.8.2): un error del reproductor mismo (como el NullPointerException del
/// ecualizador) reinicia el reproductor una vez, solo; los errores de internet o del archivo no.
void main() {
  final t0 = DateTime(2026, 11, 16, 12);

  test('El NullPointerException del ecualizador reinicia el reproductor; uno de internet, no', () {
    final healer = PlayerHealer();
    final npe = PlatformException(
      code: 'error',
      message: "NullPointerException: Attempt to invoke virtual method 'short android.media.audiofx.Equalizer.getNumberOfBands()' on a null object reference",
    );
    expect(healer.shouldHeal(npe, t0), isTrue);
    expect(PlayerHealer().shouldHeal(PlayerException(403, 'Forbidden', 0), t0), isFalse);
    expect(PlayerHealer().shouldHeal(Exception('sin red'), t0), isFalse);
  });

  test('Una vez cada 30 s: si vuelve a fallar enseguida no se insiste', () {
    final healer = PlayerHealer();
    final error = PlatformException(code: 'error');
    expect(healer.shouldHeal(error, t0), isTrue);
    expect(healer.shouldHeal(error, t0.add(const Duration(seconds: 5))), isFalse);
    expect(healer.shouldHeal(error, t0.add(const Duration(seconds: 31))), isTrue);
  });
}
