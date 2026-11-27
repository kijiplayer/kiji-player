// Rachas (0.9): días seguidos escuchando, solo en el dispositivo y sin avisos.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/streaks/streaks.dart';

void main() {
  final now = DateTime(2026, 11, 26, 21);
  String ago(int n) => dayKey(DateTime(now.year, now.month, now.day - n));

  test('Días seguidos hasta hoy', () {
    expect(currentStreak({ago(0), ago(1), ago(2)}, now), 3);
    expect(currentStreak({ago(0), ago(2)}, now), 1, reason: 'un hueco corta la racha');
  });

  test('Si hoy todavía no sonó nada, la racha de ayer sigue viva', () {
    expect(currentStreak({ago(1), ago(2), ago(3), ago(4)}, now), 4);
    expect(currentStreak({ago(2), ago(3)}, now), 0, reason: 'ayer no: se cortó');
  });

  test('Cruza meses y años', () {
    final jan1 = DateTime(2027, 1, 1, 10);
    expect(currentStreak({'2026-12-30', '2026-12-31', '2027-01-01'}, jan1), 3);
  });

  test('Se guarda en el dispositivo y se lee al volver', () async {
    final dir = Directory.systemTemp.createTempSync('kiji_rachas');
    addTearDown(() => dir.deleteSync(recursive: true));
    final c = ProviderContainer(overrides: [
      streaksProvider.overrideWith(() => StreaksNotifier(directory: () async => dir.path)),
    ]);
    c.read(streaksProvider.notifier)
      ..markDay(DateTime(2026, 11, 25))
      ..markDay(DateTime(2026, 11, 26))
      ..markDay(DateTime(2026, 11, 26, 23));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    c.dispose();
    final again = ProviderContainer(overrides: [
      streaksProvider.overrideWith(() => StreaksNotifier(directory: () async => dir.path)),
    ]);
    addTearDown(again.dispose);
    again.read(streaksProvider);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(again.read(streaksProvider), {'2026-11-25', '2026-11-26'});
  });
}
