import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../models/track.dart';
import '../../../providers/downloads_provider.dart';
import '../../../utils/json_file.dart';
import '../domain/download_failure.dart';
import '../../settings/data/settings_store.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Canciones que esperan para bajarse solas (al dar "me gusta" con la opción prendida, o
/// varias elegidas a la vez). Si falta el WiFi (con "solo con WiFi" o con el ahorro de datos) o el
/// espacio, esperan sin molestar y siguen cuando cambia la conexión o al volver a abrir Kiji.
class AutoDownloadsState {
  const AutoDownloadsState({this.pending = const [], this.waitingReason, this.batch = const []});

  final List<Track> pending;

  /// Por qué están frenadas (sin WiFi, sin espacio); null si avanzan.
  final String? waitingReason;

  /// La tanda actual (videoIds): las que se pidieron juntas desde que la anterior terminó. Con
  /// esto se muestra el avance de todas juntas.
  final List<String> batch;

  AutoDownloadsState copyWith({List<Track>? pending, String? Function()? waitingReason, List<String>? batch}) =>
      AutoDownloadsState(
        pending: pending ?? this.pending,
        waitingReason: waitingReason == null ? this.waitingReason : waitingReason(),
        batch: batch ?? this.batch,
      );
}

/// El avance de una tanda de descargas: cuántas ya están, cuántas fallaron, el total y la
/// fracción (contando lo que va de las que se están bajando).
class BatchProgress {
  const BatchProgress({
    required this.done,
    required this.failed,
    required this.total,
    required this.fraction,
    this.waitingReason,
  });

  final int done;
  final int failed;
  final int total;
  final double fraction;
  final String? waitingReason;

  /// Terminó la tanda (bajadas o fallidas todas).
  bool get finished => done + failed >= total;

  /// El avance de [auto] con lo que dicen las descargas ([downloads]). null si no hay una tanda
  /// de varias (con una sola alcanza su propio avance) o si ya terminó.
  static BatchProgress? of(AutoDownloadsState auto, DownloadsState downloads) {
    final ids = auto.batch;
    if (ids.length < 2) return null;
    var done = 0, failed = 0;
    var partial = 0.0;
    for (final id in ids) {
      if (downloads.completed.containsKey(id)) {
        done++;
        continue;
      }
      final active = downloads.active[id];
      if (active == null) continue;
      if (active.status == ActiveDownloadStatus.failed) {
        failed++;
      } else {
        partial += active.progress ?? 0;
      }
    }
    // Una que no está bajada, ni bajando, ni esperando: se quitó (se canceló). No cuenta.
    final pendingIds = {for (final t in auto.pending) t.youtubeVideoId};
    final gone = [
      for (final id in ids)
        if (!downloads.completed.containsKey(id) && !downloads.active.containsKey(id) && !pendingIds.contains(id)) id,
    ].length;
    final total = ids.length - gone;
    if (total < 2 || done + failed >= total) return null;
    return BatchProgress(
      done: done,
      failed: failed,
      total: total,
      fraction: ((done + failed + partial) / total).clamp(0.0, 1.0),
      waitingReason: auto.waitingReason,
    );
  }
}

/// El avance de la tanda actual (null si no hay varias bajando).
final batchProgressProvider = Provider<BatchProgress?>(
  (ref) => BatchProgress.of(ref.watch(autoDownloadsProvider), ref.watch(downloadsProvider)),
);

/// Dónde se guarda la lista de espera (se cambia en las pruebas).
final autoDownloadsFileProvider = Provider<Future<JsonFile>>(
  (ref) async =>
      JsonFile(p.join((await getApplicationSupportDirectory()).path, 'auto_downloads.json'), logTag: 'DESCARGAS AUTO'), // l10n-ignore
);

/// Avisos de cambio de conexión (en las pruebas, ninguno).
final connectivityChangesProvider = Provider<Stream<List<ConnectivityResult>>>((ref) => _connectivityChanges());

/// Una sola escucha del sistema por proceso, que nunca se corta: en Windows, volver a empezar a
/// escuchar después de cortar falla (`NetworkManager::StartListen`).
StreamController<List<ConnectivityResult>>? _changes;

Stream<List<ConnectivityResult>> _connectivityChanges() {
  if (_changes case final changes?) return changes.stream;
  // ignore: close_sinks (vive mientras viva la app, a propósito)
  final changes = _changes = StreamController<List<ConnectivityResult>>.broadcast();
  try {
    Connectivity().onConnectivityChanged.listen(
      changes.add,
      onError: (Object error) => debugPrint('=== DESCARGAS AUTO: error de la conexión: $error ==='),
    );
  } catch (error) {
    debugPrint('=== DESCARGAS AUTO: no se puede escuchar la conexión: $error ===');
  }
  return changes.stream;
}

class AutoDownloadsNotifier extends Notifier<AutoDownloadsState> {
  bool _running = false;
  bool _again = false;
  bool _loaded = false;
  StreamSubscription<List<ConnectivityResult>>? _connection;

  DownloadsNotifier get _downloads => ref.read(downloadsProvider.notifier);

  @override
  AutoDownloadsState build() {
    ref.onDispose(() => _connection?.cancel());
    unawaited(Future.microtask(_load));
    return const AutoDownloadsState();
  }

  Future<void> _load() async {
    try {
      final json = await (await ref.read(autoDownloadsFileProvider)).read();
      if (json is List) {
        final saved = [
          for (final item in json)
            if (item is Map<String, dynamic>) Track.fromJson(item),
        ];
        final pending = _merge(saved, state.pending);
        // Al reabrir Kiji con varias esperando, siguen siendo una tanda (con su avance).
        state = state.copyWith(
          pending: pending,
          batch: state.batch.isEmpty ? [for (final t in pending) ?t.youtubeVideoId] : state.batch,
        );
      }
    } catch (error) {
      debugPrint('=== DESCARGAS AUTO: no se pudo leer la lista de espera: $error ===');
    }
    _loaded = true;
    try {
      // Al volver el WiFi (o cualquier cambio de conexión) se reintenta.
      _connection = ref
          .read(connectivityChangesProvider)
          .listen(
            (_) => process(),
            onError: (Object error) => debugPrint('=== DESCARGAS AUTO: error de la conexión: $error ==='),
          );
    } catch (error) {
      debugPrint('=== DESCARGAS AUTO: no se puede escuchar la conexión: $error ===');
    }
    unawaited(process());
  }

  /// Agrega [tracks] a la espera (solo las de YouTube que no están bajadas ni bajando) y
  /// arranca. Devuelve cuántas se agregaron.
  int enqueue(List<Track> tracks) {
    final downloads = ref.read(downloadsProvider);
    final fresh = [
      for (final track in tracks)
        if (track.youtubeVideoId case final id?)
          if (!downloads.completed.containsKey(id) && !downloads.active.containsKey(id)) track,
    ];
    final merged = _merge(state.pending, fresh);
    final added = merged.length - state.pending.length;
    if (added == 0) return 0;
    // Si la tanda anterior ya terminó, empieza otra; si no, estas se suman a la que va.
    final previous = BatchProgress.of(state, downloads);
    final ids = [for (final t in fresh) t.youtubeVideoId!];
    final batch = previous == null && state.pending.isEmpty ? ids : {...state.batch, ...ids}.toList();
    state = state.copyWith(pending: merged, batch: batch);
    debugPrint('=== DESCARGAS AUTO: $added en espera (${merged.length} en total) ===');
    unawaited(_save());
    unawaited(process());
    return added;
  }

  /// Saca de la espera (por ejemplo, al quitar el "me gusta"). Lo ya bajado no se toca.
  void remove(String trackId) {
    if (!state.pending.any((t) => t.id == trackId)) return;
    _set([
      for (final t in state.pending)
        if (t.id != trackId) t,
    ]);
  }

  /// Revisa la lista: baja las que se puedan y deja esperando las demás.
  Future<void> process() async {
    if (!_loaded) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        await _processOnce();
      } while (_again);
    } finally {
      _running = false;
    }
  }

  Future<void> _processOnce() async {
    String? waiting;
    while (state.pending.isNotEmpty) {
      final track = state.pending.first;
      final id = track.youtubeVideoId!;
      final downloads = ref.read(downloadsProvider);
      if (downloads.completed.containsKey(id) || downloads.active.containsKey(id)) {
        _set(state.pending.skip(1).toList());
        continue;
      }
      // Ahorro de datos: con datos móviles las descargas de a varias esperan al WiFi.
      if (ref.read(settingsProvider).dataSaver && !await _downloads.onWifiOrEthernet()) {
        waiting = tx.conElAhorroDeDatosEsperanAlWifi;
        debugPrint('=== DESCARGAS AUTO: en espera (${state.pending.length}): ahorro de datos sin WiFi ===');
        break;
      }
      final check = await _downloads.check(track);
      if (check.waitingForWifi || (check.blockedReason != null && check.estimate != null)) {
        // Sin WiFi o sin espacio: todas esperan al próximo cambio de conexión o al reabrir.
        waiting = check.blockedReason;
        debugPrint('=== DESCARGAS AUTO: en espera (${state.pending.length}): $waiting ===');
        break;
      }
      if (state.pending.firstOrNull?.id != track.id) continue; // la quitaron mientras se revisaba
      if (check.canDownload) {
        _downloads.start(track, check.estimate!);
      } else {
        // YouTube no dio el audio: queda en Descargadas como fallida, con su motivo.
        _downloads.recordFailure(track, check.failure ?? DownloadFailure.unknown);
      }
      _set(state.pending.skip(1).toList());
    }
    state = state.copyWith(waitingReason: () => waiting);
  }

  /// "Cancelar": las que esperan salen de la lista y las de la tanda que se están bajando se
  /// cortan. Lo ya bajado queda.
  Future<void> cancelBatch() async {
    final downloads = ref.read(downloadsProvider);
    final ids = state.batch;
    _set(const []);
    for (final id in ids) {
      final active = downloads.active[id];
      if (active != null && active.status != ActiveDownloadStatus.failed) await _downloads.cancel(id);
    }
    debugPrint('=== DESCARGAS AUTO: tanda cancelada (${ids.length}) ===');
  }

  void _set(List<Track> pending) {
    state = state.copyWith(pending: pending, waitingReason: () => pending.isEmpty ? null : state.waitingReason);
    unawaited(_save());
  }

  Future<void> _save() async {
    try {
      await (await ref.read(autoDownloadsFileProvider)).write([for (final t in state.pending) t.toJson()]);
    } catch (error) {
      debugPrint('=== DESCARGAS AUTO: no se pudo guardar la lista de espera: $error ===');
    }
  }

  static List<Track> _merge(List<Track> a, List<Track> b) {
    final seen = <String>{};
    return [
      for (final t in [...a, ...b])
        if (seen.add(t.id)) t,
    ];
  }
}

final autoDownloadsProvider = NotifierProvider<AutoDownloadsNotifier, AutoDownloadsState>(AutoDownloadsNotifier.new);
