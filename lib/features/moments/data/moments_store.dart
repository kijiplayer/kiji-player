import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../models/track.dart';
import '../../../utils/json_file.dart';
import '../domain/moment.dart';


/// Los Momentos guardados, el más nuevo primero. Solo en este dispositivo
/// (`<appSupport>/moments.json`).
class MomentsNotifier extends Notifier<List<Moment>> {
  MomentsNotifier({Future<String> Function()? directory}) : _directoryPath = directory;

  final Future<String> Function()? _directoryPath;
  JsonFile? _file;

  Future<JsonFile> _jsonFile() async => _file ??= JsonFile(
    p.join(await (_directoryPath ?? () async => (await getApplicationSupportDirectory()).path)(), 'moments.json'),
    logTag: 'MOMENTOS',
  );

  @override
  List<Moment> build() {
    unawaited(Future.microtask(_load));
    return const [];
  }

  Future<void> _load() async {
    try {
      final json = await (await _jsonFile()).read();
      if (json is List) state = [for (final m in json) ?Moment.fromJson(m)];
    } catch (error) {
      debugPrint('=== MOMENTOS: no se pudieron leer: $error ===');
    }
  }

  /// Guarda el segundo [position] de [track] (redondeado al segundo) o, con [end], el tramo de
  /// [position] a [end].
  Moment add(Track track, Duration position, {Duration? end, DateTime? now}) {
    final at = now ?? DateTime.now();
    final moment = Moment(
      id: '${at.microsecondsSinceEpoch}',
      track: track.copyWith(audioUrl: track.source == TrackSource.youtube ? '' : track.audioUrl),
      position: Duration(seconds: position.inSeconds),
      end: end == null || end.inSeconds <= position.inSeconds ? null : Duration(seconds: end.inSeconds),
      createdAt: at,
    );
    state = [moment, ...state];
    unawaited(_save());
    return moment;
  }

  /// Borra un Momento; devuelve lo necesario para deshacerlo.
  (int, Moment)? remove(String id) {
    final index = state.indexWhere((m) => m.id == id);
    if (index < 0) return null;
    final removed = state[index];
    state = [...state]..removeAt(index);
    unawaited(_save());
    return (index, removed);
  }

  void restore(int index, Moment moment) {
    state = [...state]..insert(index.clamp(0, state.length), moment);
    unawaited(_save());
  }

  Future<void> _save() async => (await _jsonFile()).write([for (final m in state) m.toJson()]);
}

final momentsProvider = NotifierProvider<MomentsNotifier, List<Moment>>(MomentsNotifier.new);
