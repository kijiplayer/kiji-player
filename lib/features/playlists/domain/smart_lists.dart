// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivo de referencia: app/src/main/kotlin/.../ui/screens/playlist/AutoPlaylistScreen.kt
// (listas automáticas: me gusta, más escuchadas, descargadas).

import '../../../models/track.dart';
import '../../history/listening_history.dart';

/// Lo que necesitan las listas inteligentes. Todo sale del teléfono.
class SmartListInputs {
  const SmartListInputs({
    required this.now,
    this.liked = const [],
    this.history = const [],
    this.downloaded = const [],
    this.local = const [],
  });

  final DateTime now;
  final List<Track> liked;
  final List<HistoryEntry> history;
  final List<Track> downloaded;
  final List<Track> local;
}

/// Listas inteligentes con reglas que se ven y se entienden (Tarea M).
enum SmartList {
  liked('Me gusta', 'Las canciones que marcaste con ♥.'),
  mostPlayed('Más escuchadas', 'Las 25 que más veces escuchaste en Kiji.'),
  recent('Escuchadas hace poco', 'Las últimas 25 que escuchaste.'),
  forgottenFavorites('Favoritas olvidadas', 'Con ♥, que no escuchas hace más de un mes.'),
  downloaded('Descargadas', 'Todo lo que guardaste para escuchar sin conexión.'),
  neverPlayed('Nunca escuchadas', 'De tu música del dispositivo, las que todavía no escuchaste en Kiji.');

  const SmartList(this.title, this.rule);

  final String title;

  /// La regla, en palabras simples (se muestra siempre).
  final String rule;

  static const limit = 25;
  static const forgottenAfter = Duration(days: 30);

  List<Track> compute(SmartListInputs inputs) {
    switch (this) {
      case SmartList.liked:
        return inputs.liked;
      case SmartList.mostPlayed:
        return HistoryLogic.forYou(inputs.history, limit: limit);
      case SmartList.recent:
        return HistoryLogic.recent(inputs.history, limit: limit);
      case SmartList.forgottenFavorites:
        final lastPlayed = {for (final e in inputs.history) e.track.id: e.lastPlayed};
        return [
          for (final track in inputs.liked)
            if (lastPlayed[track.id] == null ||
                inputs.now.difference(lastPlayed[track.id]!) > forgottenAfter)
              track,
        ];
      case SmartList.downloaded:
        return inputs.downloaded;
      case SmartList.neverPlayed:
        final played = {for (final e in inputs.history) e.track.id};
        return [for (final t in inputs.local) if (!played.contains(t.id)) t];
    }
  }
}
