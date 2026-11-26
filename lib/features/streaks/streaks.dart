import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../providers/playback_provider.dart';
import '../../utils/json_file.dart';

/// "aaaa-mm-dd" de [d] (hora local).
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Días seguidos escuchando, hasta hoy. Si hoy todavía no sonó nada, la racha de ayer sigue viva
/// (no se "pierde" a la mañana).
int currentStreak(Set<String> days, DateTime now) {
  var day = DateTime(now.year, now.month, now.day);
  if (!days.contains(dayKey(day))) day = day.subtract(const Duration(days: 1));
  var streak = 0;
  while (days.contains(dayKey(day))) {
    streak++;
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return streak;
}

/// Los días en que sonó música (solo en este dispositivo, `<appSupport>/streaks.json`; como mucho
/// los últimos 400). Sin notificaciones: solo se muestra, discreto, en Inicio.
class StreaksNotifier extends Notifier<Set<String>> {
  StreaksNotifier({Future<String> Function()? directory}) : _directory = directory; // ignore: prefer_initializing_formals

  static const maxDays = 400;
  final Future<String> Function()? _directory;
  JsonFile? _file;

  Future<JsonFile> _jsonFile() async => _file ??= JsonFile(
    p.join(await (_directory ?? () async => (await getApplicationSupportDirectory()).path)(), 'streaks.json'),
    logTag: 'RACHAS', // l10n-ignore
  );

  @override
  Set<String> build() {
    unawaited(Future.microtask(_load));
    return const {};
  }

  Future<void> _load() async {
    try {
      final json = await (await _jsonFile()).read();
      if (json is List) state = {...state, for (final d in json) if (d is String) d};
    } catch (error) {
      debugPrint('=== RACHAS: no se pudieron leer: ${error.runtimeType} ===');
    }
  }

  /// Hoy sonó música (una vez por día alcanza).
  void markDay(DateTime now) {
    final key = dayKey(now);
    if (state.contains(key)) return;
    final days = ({...state, key}.toList()..sort());
    state = days.skip(days.length > maxDays ? days.length - maxDays : 0).toSet();
    unawaited(_save());
  }

  Future<void> _saving = Future.value();

  /// Guarda de a uno (varios días seguidos no se pisan): cada guardado espera al anterior.
  Future<void> _save() => _saving = _saving.then((_) async {
    try {
      await (await _jsonFile()).write(state.toList()..sort());
    } catch (error) {
      debugPrint('=== RACHAS: no se pudieron guardar: ${error.runtimeType} ===');
    }
  });
}

final streaksProvider = NotifierProvider<StreaksNotifier, Set<String>>(StreaksNotifier.new);

/// Racha actual (0 si no hay).
final currentStreakProvider = Provider<int>((ref) => currentStreak(ref.watch(streaksProvider), DateTime.now()));

/// Anota el día cuando empieza a sonar algo (se llama una vez, desde la app).
void watchStreaks(WidgetRef ref) {
  ref.listenManual(playbackProvider.select((p) => p.isPlaying), (_, playing) {
    if (playing) ref.read(streaksProvider.notifier).markDay(DateTime.now());
  });
}
