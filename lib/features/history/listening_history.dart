import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/track.dart';
import '../../utils/json_file.dart';


/// Una canción escuchada: cuándo fue la última vez y cuántas veces.
class HistoryEntry {
  const HistoryEntry({required this.track, required this.lastPlayed, required this.playCount});

  final Track track;
  final DateTime lastPlayed;
  final int playCount;

  Map<String, dynamic> toJson() => {
    'track': track.toJson(),
    'lastPlayed': lastPlayed.millisecondsSinceEpoch,
    'playCount': playCount,
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    track: Track.fromJson(json['track'] as Map<String, dynamic>),
    lastPlayed: DateTime.fromMillisecondsSinceEpoch(json['lastPlayed'] as int),
    playCount: json['playCount'] as int? ?? 1,
  );
}

/// Lógica pura del historial (testeable sin disco).
abstract final class HistoryLogic {
  /// Cuántas canciones distintas se recuerdan como máximo.
  static const maxEntries = 100;

  static List<HistoryEntry> record(List<HistoryEntry> entries, Track track, DateTime now) {
    final existing = entries.where((e) => e.track.id == track.id).firstOrNull;
    final updated = HistoryEntry(
      // Sin URL de audio guardada (vence); se queda la info más nueva.
      track: track,
      lastPlayed: now,
      playCount: (existing?.playCount ?? 0) + 1,
    );
    final rest = entries.where((e) => e.track.id != track.id);
    return [updated, ...rest].take(maxEntries).toList();
  }

  /// "Escuchado recientemente": de la más reciente a la más vieja.
  static List<Track> recent(List<HistoryEntry> entries, {int limit = 12}) =>
      ([...entries]..sort((a, b) => b.lastPlayed.compareTo(a.lastPlayed))).take(limit).map((e) => e.track).toList();

  /// "Para ti · calculado en tu teléfono": las que más escuchaste (empate:
  /// la más reciente), sin la que está sonando.
  static List<Track> forYou(List<HistoryEntry> entries, {String? excludeId, int limit = 4}) =>
      ([...entries.where((e) => e.track.id != excludeId)]..sort((a, b) {
            final byCount = b.playCount.compareTo(a.playCount);
            return byCount != 0 ? byCount : b.lastPlayed.compareTo(a.lastPlayed);
          }))
          .take(limit)
          .map((e) => e.track)
          .toList();
}

/// Historial de escucha. Se guarda solo en el teléfono
/// (`<appSupportDir>/history.json`) y nunca sale de él.
class ListeningHistoryNotifier extends Notifier<List<HistoryEntry>> {
  JsonFile? _file;

  Future<JsonFile> _jsonFile() async =>
      _file ??= JsonFile(p.join((await getApplicationSupportDirectory()).path, 'history.json'), logTag: 'HISTORIAL');

  @override
  List<HistoryEntry> build() {
    unawaited(Future.microtask(_load));
    return const [];
  }

  Future<void> _load() async {
    try {
      final json = await (await _jsonFile()).read();
      if (json is! List) return;
      state = [
        for (final item in json)
          if (item is Map<String, dynamic>) HistoryEntry.fromJson(item),
      ];
    } catch (error) {
      debugPrint('=== HISTORIAL: no se pudo leer: $error ===');
    }
  }

  void record(Track track) {
    state = HistoryLogic.record(state, track, DateTime.now());
    unawaited(_save());
  }

  /// Importar: agrega solo canciones que no estaban en el
  /// historial (nunca cambia lo existente). Devuelve los ids agregados.
  List<String> importEntries(List<HistoryEntry> entries) {
    final existing = {for (final e in state) e.track.id};
    final toAdd = [
      for (final e in entries)
        if (existing.add(e.track.id)) e,
    ];
    if (toAdd.isEmpty) return const [];
    state = [...state, ...toAdd]..sort((a, b) => b.lastPlayed.compareTo(a.lastPlayed));
    if (state.length > HistoryLogic.maxEntries) {
      state = state.take(HistoryLogic.maxEntries).toList();
    }
    unawaited(_save());
    final kept = {for (final e in state) e.track.id};
    return [
      for (final e in toAdd)
        if (kept.contains(e.track.id)) e.track.id,
    ];
  }

  /// Deshacer una importación: quita solo estas.
  void removeIds(Iterable<String> ids) {
    final remove = ids.toSet();
    state = [
      for (final e in state)
        if (!remove.contains(e.track.id)) e,
    ];
    unawaited(_save());
  }

  /// Borra todo el historial (Configuración → Privacidad).
  Future<void> clear() async {
    state = const [];
    await (await _jsonFile()).delete();
  }

  Future<void> _save() async {
    try {
      await (await _jsonFile()).write([for (final e in state) e.toJson()]);
    } catch (error) {
      debugPrint('=== HISTORIAL: no se pudo guardar: $error ===');
    }
  }
}

final listeningHistoryProvider = NotifierProvider<ListeningHistoryNotifier, List<HistoryEntry>>(
  ListeningHistoryNotifier.new,
);
