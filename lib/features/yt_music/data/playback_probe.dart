import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'yt_clients.dart';
import 'ytm_client.dart';

/// Comprueba que una forma que resolvió **suene de verdad**: la reproduce
/// con un reproductor aparte, en silencio y sin pedir el foco de audio (la
/// música que esté sonando sigue), salta cerca del final y verifica que
/// avance. Devuelve el motivo si no suena, o null si suena entera.
Future<String?> checkPlays(StreamAttempt attempt, YtPlayerClient client) async {
  final url = attempt.url;
  if (url == null) return attempt.reason ?? 'No resolvió';
  final player = AudioPlayer(handleAudioSessionActivation: false, handleInterruptions: false);
  try {
    await player.setVolume(0);
    final duration = await player
        .setAudioSource(attempt.isHls
            ? HlsAudioSource(Uri.parse(url))
            : AudioSource.uri(Uri.parse(url), headers: {'User-Agent': client.userAgent}))
        .timeout(const Duration(seconds: 20));
    player.play().ignore();
    await player.positionStream
        .firstWhere((p) => p > const Duration(seconds: 2))
        .timeout(const Duration(seconds: 20), onTimeout: () => throw StateError('no arrancó'));
    // Con HLS, algunos reproductores (mpv en la PC) informan la duración
    // recién cuando ya está sonando.
    // mpv puede informar 0: se toma la primera duración razonable.
    Duration? valid(Duration? d) => d != null && d > const Duration(seconds: 30) ? d : null;
    final total = valid(duration) ??
        valid(player.duration) ??
        valid(attempt.duration) ??
        await player.durationStream
            .firstWhere((d) => valid(d) != null)
            .timeout(const Duration(seconds: 10), onTimeout: () => null);
    if (total == null || total < const Duration(seconds: 30)) return 'El reproductor no supo la duración';
    final target = total - const Duration(seconds: 12);
    await player.seek(target);
    await player.positionStream
        .firstWhere((p) => p > target + const Duration(seconds: 2))
        .timeout(const Duration(seconds: 25), onTimeout: () => throw StateError('no avanzó cerca del final'));
    debugPrint('=== YTM prueba [${client.label}]: suena entera (${total.inSeconds} s) ===');
    return null;
  } catch (error) {
    debugPrint('=== YTM prueba [${client.label}]: no suena: $error ===');
    return 'Resolvió, pero no suena: ${'$error'.split('\n').first}';
  } finally {
    await player.dispose();
  }
}
