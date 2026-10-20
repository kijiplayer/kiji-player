// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivo de referencia: app/src/main/kotlin/.../recommendation/LocalTasteEngine.kt (el gusto
// se calcula en el teléfono con el historial; a YouTube solo se le piden relacionadas).

import '../../../models/track.dart';
import '../../history/listening_history.dart';

/// Canciones "semilla": de ellas se piden las relacionadas a YouTube Music.
/// Solo se manda su videoId; el historial nunca sale del teléfono.
class HomeSeeds {
  const HomeSeeds({this.becauseOf, this.mix = const [], this.discover = const []});

  /// La de "Porque escuchaste X": la última de YouTube que sonó.
  final Track? becauseOf;

  /// Las más escuchadas (para "Mezcla para ti").
  final List<Track> mix;

  /// Me gusta y artistas frecuentes (para "Descubre").
  final List<Track> discover;

  List<Track> get all => {for (final t in [?becauseOf, ...mix, ...discover]) t.id: t}.values.toList();

  /// Clave estable: si no cambia, no se vuelve a pedir nada.
  String get key => [for (final t in all) t.id].join(',');
}

/// Lo que muestra Inicio.
class HomeFeed {
  const HomeFeed({this.becauseOf, this.because = const [], this.mix = const [], this.discover = const []});

  final Track? becauseOf;
  final List<Track> because;
  final List<Track> mix;
  final List<Track> discover;

  bool get isEmpty => because.isEmpty && mix.isEmpty && discover.isEmpty;
}

/// Lógica pura de las recomendaciones (testeable sin red).
abstract final class HomeFeedLogic {
  static bool _isYouTube(Track t) => t.youtubeVideoId != null;

  /// Elige las semillas con el historial y los me gusta.
  static HomeSeeds seeds(List<HistoryEntry> history, List<Track> liked) {
    final yt = [for (final e in history) if (_isYouTube(e.track)) e];
    if (yt.isEmpty && liked.where(_isYouTube).isEmpty) return const HomeSeeds();
    final byRecent = [...yt]..sort((a, b) => b.lastPlayed.compareTo(a.lastPlayed));
    final becauseOf = byRecent.isEmpty ? null : byRecent.first.track;
    final byCount = [...yt]..sort((a, b) {
        final c = b.playCount.compareTo(a.playCount);
        return c != 0 ? c : b.lastPlayed.compareTo(a.lastPlayed);
      });
    final mix = [for (final e in byCount) if (e.track.id != becauseOf?.id) e.track].take(2).toList();
    // Descubre: me gusta y, si faltan, la mejor de cada artista frecuente.
    final used = {becauseOf?.id, for (final t in mix) t.id};
    final discover = <Track>[];
    for (final t in liked.where(_isYouTube)) {
      if (discover.length >= 2) break;
      if (used.add(t.id)) discover.add(t);
    }
    final artists = <String>{for (final t in [?becauseOf, ...mix]) t.artist};
    for (final e in byCount) {
      if (discover.length >= 2) break;
      if (artists.add(e.track.artist) && used.add(e.track.id)) discover.add(e.track);
    }
    return HomeSeeds(becauseOf: becauseOf, mix: mix, discover: discover);
  }

  /// Arma Inicio con las relacionadas de cada semilla ([related], por id).
  /// "Mezcla" combina tus más escuchadas con relacionadas; "Descubre" son
  /// solo canciones que nunca sonaron ni tienen me gusta.
  static HomeFeed build({
    required HomeSeeds seeds,
    required Map<String, List<Track>> related,
    required List<HistoryEntry> history,
    required List<Track> liked,
  }) {
    final known = {for (final e in history) e.track.id, for (final t in liked) t.id};
    final because = [
      for (final t in related[seeds.becauseOf?.id] ?? const <Track>[])
        if (!known.contains(t.id)) t,
    ].take(15).toList();

    final shown = {for (final t in because) t.id};
    final top = HistoryLogic.forYou(history, limit: 10);
    final fresh = [
      for (final seed in seeds.mix)
        for (final t in related[seed.id] ?? const <Track>[])
          if (!known.contains(t.id)) t,
    ];
    final mix = <Track>[];
    final inMix = <String>{};
    for (var i = 0; mix.length < 25 && (i < top.length || i < fresh.length); i++) {
      if (i < top.length && inMix.add(top[i].id)) mix.add(top[i]);
      if (i < fresh.length && !shown.contains(fresh[i].id) && inMix.add(fresh[i].id)) mix.add(fresh[i]);
    }

    shown.addAll(inMix);
    final discover = <Track>[];
    final lists = [for (final seed in seeds.discover) related[seed.id] ?? const <Track>[]];
    // Alternando entre semillas, para que no sea todo del mismo artista.
    for (var i = 0; discover.length < 15 && lists.any((l) => i < l.length); i++) {
      for (final list in lists) {
        if (i < list.length && !known.contains(list[i].id) && shown.add(list[i].id)) discover.add(list[i]);
      }
    }
    return HomeFeed(becauseOf: seeds.becauseOf, because: because, mix: mix, discover: discover.take(15).toList());
  }
}
