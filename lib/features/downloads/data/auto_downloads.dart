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

/// Canciones que esperan para bajarse solas (al dar "me gusta" con la opción prendida, o
/// varias elegidas a la vez). Si falta el WiFi (con "solo con WiFi") o el espacio, esperan
/// sin molestar y siguen cuando cambia la conexión o al volver a abrir Kiji.
class AutoDownloadsState {
  const AutoDownloadsState({this.pending = const [], this.waitingReason});

  final List<Track> pending;

  /// Por qué están frenadas (sin WiFi, sin espacio); null si avanzan.
  final String? waitingReason;
}

/// Dónde se guarda la lista de espera (se cambia en las pruebas).
final autoDownloadsFileProvider = Provider<Future<JsonFile>>(
  (ref) async =>
      JsonFile(p.join((await getApplicationSupportDirectory()).path, 'auto_downloads.json'), logTag: 'DESCARGAS AUTO'), // l10n-ignore
);

/// Avisos de cambio de conexión (en las pruebas, ninguno).
final connectivityChangesProvider = Provider<Stream<List<ConnectivityResult>>>(
  (ref) => Connectivity().onConnectivityChanged,
);

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
        state = AutoDownloadsState(pending: _merge(saved, state.pending));
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
    state = AutoDownloadsState(pending: merged, waitingReason: state.waitingReason);
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
    state = AutoDownloadsState(pending: state.pending, waitingReason: waiting);
  }

  void _set(List<Track> pending) {
    state = AutoDownloadsState(pending: pending, waitingReason: pending.isEmpty ? null : state.waitingReason);
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
