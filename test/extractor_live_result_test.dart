import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/extractor/data/extractor_tester.dart';

void main() {
  const bot = 'UNPLAYABLE: Inicia sesión para confirmar que no eres un bot';
  const botEn = "LOGIN_REQUIRED: Sign in to confirm you're not a bot";

  test('Anda: búsqueda y al menos 2 de 3 canciones', () {
    expect(liveCheckResult(searchOk: true, songsOk: 3, songs: 3, failures: const []), 'ok');
    expect(liveCheckResult(searchOk: true, songsOk: 2, songs: 3, failures: const ['403']), 'ok');
  });

  test('Bloqueo de la IP: la búsqueda anda y todo falla solo por "no eres un bot"', () {
    expect(liveCheckResult(searchOk: true, songsOk: 0, songs: 3, failures: const [bot, botEn, bot]), 'bloqueo');
  });

  test('Falla real: otro motivo, o la búsqueda rota', () {
    expect(liveCheckResult(searchOk: true, songsOk: 0, songs: 3, failures: const [bot, '400 Precondition check failed']),
        'falla');
    expect(liveCheckResult(searchOk: true, songsOk: 1, songs: 3, failures: const ['corta antes del final']), 'falla');
    expect(liveCheckResult(searchOk: false, songsOk: 0, songs: 3, failures: const [bot]), 'falla');
    expect(liveCheckResult(searchOk: true, songsOk: 0, songs: 3, failures: const []), 'falla');
  });
}
