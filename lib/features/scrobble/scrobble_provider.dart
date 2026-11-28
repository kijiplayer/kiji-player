import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/track.dart';
import '../../providers/playback_provider.dart';
import '../../utils/secret_store.dart';
import 'listenbrainz.dart';

final listenBrainzClientProvider = Provider<ListenBrainzClient>((ref) => ListenBrainzClient());
final scrobbleSecretsProvider = Provider<SecretStore>((ref) => createSecretStore());

/// ListenBrainz conectado: el nombre de usuario, o null (de fábrica, sin conectar).
class ListenBrainzNotifier extends Notifier<String?> {
  String? _token;

  @override
  String? build() {
    unawaited(Future.microtask(_load));
    return null;
  }

  Future<void> _load() async {
    try {
      final saved = jsonDecode(await ref.read(scrobbleSecretsProvider).read(listenBrainzSecret) ?? 'null');
      if (saved is Map && saved['token'] is String) {
        _token = saved['token'] as String;
        state = saved['user'] as String? ?? '?';
      }
    } catch (error) {
      // Nunca se registra el token: solo que no se pudo leer.
      debugPrint('=== LISTENBRAINZ: no se pudo leer la conexión guardada (${error.runtimeType}) ===');
    }
  }

  String? get token => _token;

  /// Comprueba el token con ListenBrainz y, si sirve, lo guarda cifrado. Devuelve si se conectó.
  Future<bool> connect(String token) async {
    final clean = token.trim();
    if (clean.isEmpty) return false;
    final user = await ref.read(listenBrainzClientProvider).validate(clean);
    if (user == null) return false;
    final saved = await ref.read(scrobbleSecretsProvider).write(
      listenBrainzSecret,
      jsonEncode({'token': clean, 'user': user}),
    );
    if (!saved) debugPrint('=== LISTENBRAINZ: el token no se pudo guardar (solo vale mientras Kiji esté abierta) ===');
    _token = clean;
    state = user;
    return true;
  }

  /// Desconectar: se borra el token del dispositivo.
  Future<void> disconnect() async {
    _token = null;
    state = null;
    await ref.read(scrobbleSecretsProvider).delete(listenBrainzSecret);
  }
}

final listenBrainzProvider = NotifierProvider<ListenBrainzNotifier, String?>(ListenBrainzNotifier.new);

/// Cuenta cuánto se escuchó de verdad cada canción (no los saltos) y, al llegar a la mitad o a 4
/// minutos, manda la escucha a ListenBrainz (una vez por reproducción). Sin conectar, no hace nada.
class ScrobbleTracker {
  Track? _track;
  DateTime? _startedAt;
  Duration _played = Duration.zero;
  Duration? _last;
  bool _sent = false;

  /// Una canción nueva empieza a sonar.
  void start(Track? track, DateTime now) {
    _track = track;
    _startedAt = now;
    _played = Duration.zero;
    _last = null;
    _sent = false;
  }

  /// La posición avanzó. Devuelve la canción a mandar cuando corresponde (una sola vez).
  ({Track track, DateTime startedAt})? tick(Duration position, {required bool playing}) {
    final last = _last;
    _last = position;
    final track = _track;
    if (track == null || _sent || !playing || last == null) return null;
    final delta = position - last;
    // Solo lo que avanzó al sonar (no los saltos hacia adelante ni atrás).
    if (delta > Duration.zero && delta <= const Duration(seconds: 2)) _played += delta;
    if (!shouldScrobble(played: _played, length: Duration(milliseconds: track.durationMs))) return null;
    _sent = true;
    return (track: track, startedAt: _startedAt!);
  }
}

/// Engancha el scrobbling al reproductor (se llama una vez, desde la app).
void watchScrobble(WidgetRef ref) {
  final tracker = ScrobbleTracker();
  ref.listenManual(playbackProvider.select((p) => p.track?.id), (_, _) {
    tracker.start(ref.read(playbackProvider).track, DateTime.now());
  }, fireImmediately: true);
  ref.listenManual(playbackProvider.select((p) => p.position), (_, position) {
    final notifier = ref.read(listenBrainzProvider.notifier);
    final token = notifier.token;
    if (token == null) return;
    final due = tracker.tick(position, playing: ref.read(playbackProvider).isPlaying);
    if (due == null) return;
    unawaited(ref.read(listenBrainzClientProvider).submit(token, due.track, due.startedAt));
  });
}
