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
  int tomatoesToday = 0,
  int rosesToday = 0,
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
    'tomatoesToday': tomatoesToday,
    'rosesToday': rosesToday,
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
    'curtain': KijiColors.theaterCurtain.toARGB32(),
    'gold': KijiColors.theaterGold.toARGB32(),
  };
}

/// Cuánto falta para la próxima línea de la letra (null si no hay otra o no es sincronizada).
Duration? untilNextLine(Lyrics? lyrics, Duration position) {
  if (lyrics == null || !lyrics.isSynced) return null;
  final i = currentLineIndex(lyrics.synced, position);
  if (i + 1 >= lyrics.synced.length) return null;
  final wait = lyrics.synced[i + 1].time - position;
  return wait.isNegative ? Duration.zero : wait;
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

/// Mantiene al día los widgets de Android (Anillo, Ahora suena, Letra, Teatro y Barra): la canción,
/// si suena, el progreso, la portada (la del dispositivo: sin internet también), el "me gusta", lo
/// de hoy del teatro, la línea de la letra (solo la que ya está en el teléfono: nunca la pide a
/// internet) y los colores del estilo. Solo si hay alguno puesto, y solo al cambiar de canción, de
/// play/pausa, el "me gusta", el teatro o el estilo. La letra, además, una línea a la vez mientras
/// suena y solo con un widget Letra (o Ahora suena) puesto. Sin widgets, nada.
/// También atiende los botones ❤️, 🍅 y 🌹 de los widgets.
final homeWidgetsProvider = Provider<void>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  const channel = MethodChannel('kiji/widgets');
  Timer? nextLine;
  var sending = false;
  String? lyricsFor;
  Lyrics? lyrics;

  /// Cuántos hay puestos de cada tipo ("ring", "now", "lyrics", "theater", "bar").
  Future<Map<String, int>> counts() async {
    try {
      final raw = await channel.invokeMapMethod<String, int>('counts');
      return raw ?? const {};
    } catch (error) {
      debugPrint('=== WIDGETS: no se pudo saber si hay widgets: ${error.runtimeType} ===');
      return const {};
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
    nextLine?.cancel();
    nextLine = null;
    try {
      final placed = await counts();
      if (placed.values.every((n) => n == 0)) return;
      final playback = ref.read(playbackProvider);
      final track = playback.track;
      final cover = track == null ? null : await deviceCoverFor(ref, track);
      final withLyrics = (placed['lyrics'] ?? 0) > 0 || (placed['now'] ?? 0) > 0;
      final songLyrics = track == null || !withLyrics ? null : await lyricsOf(track);
      final (tomatoes, roses) = ref.read(theaterProvider).today(DateTime.now());
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
          lyric: lyricLineAt(songLyrics, playback.position),
          tomatoesToday: tomatoes,
          rosesToday: roses,
        ),
      );
      // La próxima línea, justo cuando empieza (solo mientras suena).
      final wait = playback.isPlaying ? untilNextLine(songLyrics, playback.position) : null;
      if (wait != null) nextLine = Timer(wait + const Duration(milliseconds: 60), () => unawaited(send()));
    } catch (error) {
      debugPrint('=== WIDGETS: no se pudieron actualizar: ${error.runtimeType} ===');
    } finally {
      sending = false;
    }
  }

  /// ❤️, 🍅 y 🌹 tocados en un widget.
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
      case 'rose':
        if (!ref.read(settingsProvider).theaterReactions) return;
        ref.read(theaterProvider.notifier).rose(track);
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

  // Canción, play/pausa o lista para sonar: enseguida (y la letra sigue sola, línea por línea).
  ref.listen(
    playbackProvider.select((s) => (id: s.track?.id, playing: s.isPlaying, ready: s.isInitialized)),
    (_, _) => unawaited(send()),
    fireImmediately: true,
  );
  // El "me gusta" de la que suena, el teatro (lo de hoy) y su ajuste.
  ref.listen(favoritesProvider.select((f) => f.length), (_, _) => unawaited(send()));
  ref.listen(theaterProvider.select((t) => t.today(DateTime.now())), (_, _) => unawaited(send()));
  ref.listen(settingsProvider.select((s) => s.theaterReactions), (_, _) => unawaited(send()));
  // Otro estilo o color: los widgets también (después de que la app cambie la paleta).
  ref.listen(settingsProvider.select((s) => (s.style, s.theme, s.accent, s.customAccent)), (_, _) {
    unawaited(Future<void>.delayed(const Duration(milliseconds: 400), send));
  });
  ref.onDispose(() {
    nextLine?.cancel();
    channel.setMethodCallHandler(null);
  });
});
