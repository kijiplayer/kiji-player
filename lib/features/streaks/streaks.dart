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

/// La racha más larga dentro de [days].
int longestStreak(Set<String> days) {
  final sorted = days.map(DateTime.tryParse).whereType<DateTime>().toList()..sort();
  var best = 0, run = 0;
  DateTime? previous;
  for (final day in sorted) {
    run = previous != null && DateTime(previous.year, previous.month, previous.day + 1) == day ? run + 1 : 1;
    if (run > best) best = run;
    previous = day;
  }
  return best;
}

/// Los logros de racha (0.9): días seguidos.
const streakMilestones = [3, 7, 14, 30, 100, 365];

/// Lo guardado de las rachas: los días en que sonó música (como mucho los últimos
/// [StreaksNotifier.maxDays]), la mejor racha (aunque sea más vieja que eso) y cuándo se ganó cada
/// logro.
@immutable
class StreakData {
  const StreakData({this.days = const {}, this.best = 0, this.achievements = const {}, this.celebrate});

  final Set<String> days;

  /// La mejor racha de siempre.
  final int best;

  /// Logro (días) → día en que se ganó ("aaaa-mm-dd").
  final Map<int, String> achievements;

  /// Un logro recién ganado, para festejarlo una vez (no se guarda).
  final int? celebrate;

  StreakData copyWith({Set<String>? days, int? best, Map<int, String>? achievements, int? Function()? celebrate}) =>
      StreakData(
        days: days ?? this.days,
        best: best ?? this.best,
        achievements: achievements ?? this.achievements,
        celebrate: celebrate == null ? this.celebrate : celebrate(),
      );

  Map<String, dynamic> toJson() => {
    'version': 2,
    'days': days.toList()..sort(),
    'best': best,
    'achievements': {for (final e in achievements.entries) '${e.key}': e.value},
  };

  /// Lee las dos formas: la de la 0.9 inicial (solo la lista de días) y la de ahora.
  static StreakData fromJson(Object? json) {
    if (json is List) {
      final days = {for (final d in json) if (d is String) d};
      return StreakData(days: days, best: longestStreak(days), achievements: _earnedFrom(days));
    }
    if (json is! Map) return const StreakData();
    final days = {for (final d in json['days'] as List? ?? const []) if (d is String) d};
    final achievements = <int, String>{
      for (final e in (json['achievements'] as Map? ?? const {}).entries)
        if (int.tryParse('${e.key}') case final n? when e.value is String) n: e.value as String,
    };
    final best = json['best'] is int ? json['best'] as int : 0;
    return StreakData(days: days, best: best > longestStreak(days) ? best : longestStreak(days), achievements: achievements);
  }

  /// Logros que ya se habían ganado según los días guardados (al pasar del formato viejo).
  static Map<int, String> _earnedFrom(Set<String> days) {
    final sorted = days.map(DateTime.tryParse).whereType<DateTime>().toList()..sort();
    final earned = <int, String>{};
    var run = 0;
    DateTime? previous;
    for (final day in sorted) {
      run = previous != null && DateTime(previous.year, previous.month, previous.day + 1) == day ? run + 1 : 1;
      for (final m in streakMilestones) {
        if (run >= m) earned.putIfAbsent(m, () => dayKey(day));
      }
      previous = day;
    }
    return earned;
  }
}

/// Las rachas, solo en este dispositivo (`<appSupport>/streaks.json`; van en la copia de
/// seguridad completa). Sin notificaciones: la tarjeta de Inicio y un festejo corto al ganar un logro.
class StreaksNotifier extends Notifier<StreakData> {
  StreaksNotifier({Future<String> Function()? directory}) : _directory = directory; // ignore: prefer_initializing_formals

  static const maxDays = 400;
  final Future<String> Function()? _directory;
  JsonFile? _file;
  final _loaded = Completer<void>();

  /// Termina cuando se leyó lo guardado.
  Future<void> get loaded => _loaded.future;

  Future<JsonFile> _jsonFile() async => _file ??= JsonFile(
    p.join(await (_directory ?? () async => (await getApplicationSupportDirectory()).path)(), 'streaks.json'),
    logTag: 'RACHAS', // l10n-ignore
  );

  @override
  StreakData build() {
    unawaited(Future.microtask(_load));
    return const StreakData();
  }

  Future<void> _load() async {
    try {
      final saved = StreakData.fromJson(await (await _jsonFile()).read());
      // Lo que se haya marcado mientras se leía, también.
      final days = {...saved.days, ...state.days};
      state = saved.copyWith(days: days, best: [saved.best, longestStreak(days)].reduce((a, b) => a > b ? a : b));
    } catch (error) {
      debugPrint('=== RACHAS: no se pudieron leer: ${error.runtimeType} ===');
    } finally {
      if (!_loaded.isCompleted) _loaded.complete();
    }
  }

  /// Hoy sonó música (una vez por día alcanza). Si con esto se gana un logro, se festeja.
  void markDay(DateTime now) {
    final key = dayKey(now);
    if (state.days.contains(key)) return;
    final sorted = ({...state.days, key}.toList()..sort());
    final days = sorted.skip(sorted.length > maxDays ? sorted.length - maxDays : 0).toSet();
    final current = currentStreak(days, now);
    final achievements = {...state.achievements};
    int? fresh;
    for (final m in streakMilestones) {
      if (current >= m && !achievements.containsKey(m)) {
        achievements[m] = key;
        fresh = m;
      }
    }
    state = state.copyWith(
      days: days,
      best: current > state.best ? current : state.best,
      achievements: achievements,
      celebrate: fresh == null ? null : () => fresh,
    );
    if (fresh != null) debugPrint('=== RACHAS: logro de $fresh días ===');
    unawaited(_save());
  }

  /// El festejo ya se mostró.
  void celebrated() {
    if (state.celebrate != null) state = state.copyWith(celebrate: () => null);
  }

  Future<void> _saving = Future.value();

  /// Termina cuando se guardó todo lo pendiente.
  Future<void> flush() => _saving;

  /// Guarda de a uno (varios días seguidos no se pisan): cada guardado espera al anterior.
  Future<void> _save() => _saving = _saving.then((_) async {
    try {
      await (await _jsonFile()).write(state.toJson());
    } catch (error) {
      debugPrint('=== RACHAS: no se pudieron guardar: ${error.runtimeType} ===');
    }
  });
}

final streaksProvider = NotifierProvider<StreaksNotifier, StreakData>(StreaksNotifier.new);

/// Racha actual (0 si no hay).
final currentStreakProvider = Provider<int>((ref) => currentStreak(ref.watch(streaksProvider).days, DateTime.now()));

/// Anota el día cuando empieza a sonar algo (se llama una vez, desde la app).
void watchStreaks(WidgetRef ref) {
  ref.listenManual(playbackProvider.select((p) => p.isPlaying), (_, playing) {
    if (playing) ref.read(streaksProvider.notifier).markDay(DateTime.now());
  });
}
