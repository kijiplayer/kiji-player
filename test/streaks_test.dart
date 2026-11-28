// Rachas (0.9): días seguidos escuchando, la mejor racha y los logros, solo en el dispositivo.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/backup/data/backup_service.dart';
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

  test('La mejor racha', () {
    expect(longestStreak({'2026-11-01', '2026-11-02', '2026-11-03', '2026-11-10', '2026-11-11'}), 3);
    expect(longestStreak({}), 0);
  });

  test('El formato de la 0.9 inicial (solo la lista de días) se lee igual, con su mejor racha y logros', () {
    final days = [for (var i = 0; i < 8; i++) ago(i)];
    final data = StreakData.fromJson(days);
    expect(data.days, days.toSet());
    expect(data.best, 8);
    expect(data.achievements.keys, containsAll([3, 7]));
    expect(data.achievements.containsKey(14), isFalse);
    // Y vuelve igual después de guardarlo con el formato nuevo.
    final again = StreakData.fromJson(jsonDecode(jsonEncode(data.toJson())));
    expect(again.days, data.days);
    expect(again.best, 8);
    expect(again.achievements, data.achievements);
  });

  test('La mejor racha guardada no se pierde aunque sus días ya no estén', () {
    final data = StreakData.fromJson({'days': [ago(0)], 'best': 40, 'achievements': {'30': '2025-01-30'}});
    expect(data.best, 40);
    expect(data.achievements[30], '2025-01-30');
  });

  test('Al ganar un logro se festeja una vez', () {
    final c = ProviderContainer(overrides: [
      streaksProvider.overrideWith(() => StreaksNotifier(directory: () async => Directory.systemTemp.createTempSync('kiji_r').path)),
    ]);
    addTearDown(c.dispose);
    final n = c.read(streaksProvider.notifier);
    n.markDay(DateTime(2026, 11, 24));
    n.markDay(DateTime(2026, 11, 25));
    expect(c.read(streaksProvider).celebrate, isNull);
    n.markDay(DateTime(2026, 11, 26));
    expect(c.read(streaksProvider).celebrate, 3);
    expect(c.read(streaksProvider).achievements[3], '2026-11-26');
    n.celebrated();
    expect(c.read(streaksProvider).celebrate, isNull);
    n.markDay(DateTime(2026, 11, 26, 23));
    expect(c.read(streaksProvider).celebrate, isNull, reason: 'el mismo día no vuelve a festejar');
  });

  test('Se guarda en el dispositivo y se lee al volver', () async {
    final dir = Directory.systemTemp.createTempSync('kiji_rachas');
    final c = ProviderContainer(overrides: [
      streaksProvider.overrideWith(() => StreaksNotifier(directory: () async => dir.path)),
    ]);
    final n = c.read(streaksProvider.notifier);
    await n.loaded;
    n
      ..markDay(DateTime(2026, 11, 25))
      ..markDay(DateTime(2026, 11, 26))
      ..markDay(DateTime(2026, 11, 26, 23));
    bool saved() {
      final f = File('${dir.path}/streaks.json');
      return f.existsSync() && f.readAsStringSync().contains('2026-11-26');
    }

    for (var i = 0; i < 500 && !saved(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await n.flush();
    c.dispose();
    final again = ProviderContainer(overrides: [
      streaksProvider.overrideWith(() => StreaksNotifier(directory: () async => dir.path)),
    ]);
    addTearDown(again.dispose);
    again.read(streaksProvider);
    await again.read(streaksProvider.notifier).loaded;
    expect(again.read(streaksProvider).days, {'2026-11-25', '2026-11-26'});
    expect(again.read(streaksProvider).best, 2);
    await again.read(streaksProvider.notifier).flush();
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows a veces tarda en soltar el archivo: la carpeta temporal se borra sola después.
    }
  });

  test('Las rachas y la sincronización van en la copia de seguridad completa', () {
    expect(backedUpFiles, containsAll(['streaks.json', 'yt_sync.json', 'playlists.json']));
  });
}
