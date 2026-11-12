import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/track.dart';
import '../../../providers/playback_provider.dart';
import '../../../theme/kiji_tokens.dart';
import '../../../widgets/nocturne/waveform_progress.dart' show waveformBars;
import '../../favorites/favorites.dart';
import '../../lyrics/domain/lyrics.dart';
import '../../lyrics/lyrics_provider.dart';
import '../../settings/data/settings_store.dart';
import '../../theater/data/theater_store.dart';
import 'device_cover.dart';

/// Cada cuánto se redibujan los widgets mientras suena (el progreso, la onda y la línea de la
/// letra). Al cambiar de canción, de play/pausa, el "me gusta" o el estilo, enseguida.
const widgetTick = Duration(seconds: 5);

/// Barras de la onda que se mandan al widget (la misma onda del reproductor).
const widgetBars = 48;

/// Lo que se le manda al widget (sin la portada, que la busca [deviceCoverFor]).
Map<String, Object?> widgetPayload({
  required Track? track,
  required bool playing,
  required Duration position,
  required Duration duration,
  required String? cover,
  required bool liked,
  required bool theater,
  required String? lyric,
}) {
  final total = duration.inMilliseconds;
  final palette = KijiColors.palette;
  return {
    'title': track?.title,
    'artist': track?.artist,
    'playing': playing,
    'progress': total <= 0 ? 0 : (position.inMilliseconds * 1000 ~/ total).clamp(0, 1000),
    'cover': cover,
    'liked': liked,
    'theater': theater,
    'lyric': lyric,
    'bars': track == null ? null : [for (final b in waveformBars(track.id, widgetBars)) (b * 100).round()],
    'style': KijiLook.style.name,
    'light': palette.isLight,
    'background': palette.background.toARGB32(),
    'text': palette.text.toARGB32(),
    'muted': palette.muted.toARGB32(),
    'accent': palette.violet.toARGB32(),
    'accent2': palette.cyan.toARGB32(),
    'onAccent': palette.onAccent.toARGB32(),
    'like': KijiColors.like.toARGB32(),
  };
}

/// La línea de la letra sincronizada en [position] (null si no hay letra sincronizada o todavía
/// no empezó).
String? lyricLineAt(Lyrics? lyrics, Duration position) {
  if (lyrics == null || !lyrics.isSynced) return null;
  final i = currentLineIndex(lyrics.synced, position);
  if (i < 0) return null;
  final text = lyrics.synced[i].text.trim();
  return text.isEmpty ? null : text;
}

/// Mantiene al día los widgets de Android: la canción, si suena, el progreso, la portada, el "me
/// gusta", la línea de la letra (solo la que ya está en el teléfono: el widget nunca la pide a
/// internet) y los colores del estilo. Solo si hay algún widget puesto: al cambiar de canción, de
/// play/pausa, el "me gusta" o el estilo, y cada [widgetTick] mientras suena. Sin widgets, nada.
/// También atiende los botones ❤️ y 🍅 del widget.
final homeWidgetsProvider = Provider<void>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  const channel = MethodChannel('kiji/widgets');
  Timer? ticker;
  var sending = false;
  String? lyricsFor;
  Lyrics? lyrics;

  /// ¿Hay algún widget de Kiji puesto? Sin ninguno, no se manda nada (ni el temporizador corre).
  Future<bool> anyPlaced() async {
    try {
      return (await channel.invokeMethod<int>('count') ?? 0) > 0;
    } catch (error) {
      debugPrint('=== WIDGETS: no se pudo saber si hay widgets: ${error.runtimeType} ===');
      return false;
    }
  }

  /// La letra de la canción, una vez por canción y solo de lo guardado en el teléfono.
  Future<Lyrics?> lyricsOf(Track track) async {
    if (lyricsFor == track.id) return lyrics;
    lyricsFor = track.id;
    lyrics = await ref.read(lyricsRepositoryProvider).onDeviceOnly(lyricsRequestFor(track));
    return lyrics;
  }

  Future<void> send() async {
    if (sending) return;
    sending = true;
    try {
      if (!await anyPlaced()) {
        ticker?.cancel();
        ticker = null;
        return;
      }
      final playback = ref.read(playbackProvider);
      final track = playback.track;
      final cover = track == null ? null : await deviceCoverFor(ref, track);
      final line = track == null ? null : lyricLineAt(await lyricsOf(track), playback.position);
      await channel.invokeMethod<void>(
        'update',
        widgetPayload(
          track: track,
          playing: playback.isPlaying,
          position: playback.position,
          duration: playback.duration,
          cover: cover,
          liked: track != null && ref.read(favoritesProvider).containsKey(track.id),
          theater: ref.read(settingsProvider).theaterReactions,
          lyric: line,
        ),
      );
    } catch (error) {
      debugPrint('=== WIDGETS: no se pudieron actualizar: ${error.runtimeType} ===');
    } finally {
      sending = false;
    }
  }

  /// ❤️ y 🍅 tocados en el widget.
  Future<void> onAction(String action) async {
    final track = ref.read(playbackProvider).track;
    if (track == null) return;
    switch (action) {
      case 'like':
        ref.read(favoritesProvider.notifier).toggle(track);
      case 'tomato':
        if (!ref.read(settingsProvider).theaterReactions) return;
        final result = ref.read(theaterProvider.notifier).tomato(track);
        // Abucheada: se va, sin cambiar play/pausa (un tomate nunca arranca la música).
        if (result == TomatoResult.booedOff && ref.read(playbackProvider).track?.id == track.id) {
          await ref.read(playbackProvider.notifier).skipKeepingPause();
        }
    }
    await send();
  }

  channel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'action':
        if (call.arguments case final String action) await onAction(action);
      case 'refresh':
        await send();
    }
    return null;
  });

  ref.listen(
    playbackProvider.select((s) => (id: s.track?.id, playing: s.isPlaying, ready: s.isInitialized)),
    (_, next) {
      ticker?.cancel();
      ticker = null;
      unawaited(() async {
        if (!await anyPlaced()) return;
        await send();
        if (next.playing && ref.read(playbackProvider).isPlaying) {
          ticker?.cancel();
          ticker = Timer.periodic(widgetTick, (_) => unawaited(send()));
        }
      }());
    },
    fireImmediately: true,
  );
  // El "me gusta" de la que suena y el ajuste del teatro.
  ref.listen(favoritesProvider.select((f) => f.length), (_, _) => unawaited(send()));
  ref.listen(settingsProvider.select((s) => s.theaterReactions), (_, _) => unawaited(send()));
  // Otro estilo o color: los widgets también (después de que la app cambie la paleta).
  ref.listen(settingsProvider.select((s) => (s.style, s.theme, s.accent, s.customAccent)), (_, _) {
    unawaited(Future<void>.delayed(const Duration(milliseconds: 400), send));
  });
  ref.onDispose(() {
    ticker?.cancel();
    channel.setMethodCallHandler(null);
  });
});
