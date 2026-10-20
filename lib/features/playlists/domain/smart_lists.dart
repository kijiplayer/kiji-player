// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivo de referencia: app/src/main/kotlin/.../ui/screens/playlist/AutoPlaylistScreen.kt
// (listas automáticas: me gusta, más escuchadas, descargadas).

import '../../../models/track.dart';
import '../../history/listening_history.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Lo que necesitan las listas inteligentes. Todo sale del teléfono.
class SmartListInputs {
  const SmartListInputs({required this.now, this.liked = const [], this.history = const [], this.downloaded = const [], this.local = const []});

  final DateTime now;
  final List<Track> liked;
  final List<HistoryEntry> history;
  final List<Track> downloaded;
  final List<Track> local;
}

/// Listas inteligentes con reglas que se ven y se entienden (Tarea M).
enum SmartList {
  liked,
  mostPlayed,
  recent,
  forgottenFavorites,
  downloaded,
  neverPlayed;

  String get title => switch (this) {
    SmartList.liked => tx.meGusta2,
    SmartList.mostPlayed => tx.masEscuchadas,
    SmartList.recent => tx.escuchadasHacePoco,
    SmartList.forgottenFavorites => tx.favoritasOlvidadas,
    SmartList.downloaded => tx.descargadas,
    SmartList.neverPlayed => tx.nuncaEscuchadas,
  };

  /// La regla, en palabras simples (se muestra siempre).
  String get rule => switch (this) {
    SmartList.liked => tx.lasCancionesQueMarcasteCon,
    SmartList.mostPlayed => tx.las25QueMasVecesEscuchaste,
    SmartList.recent => tx.lasUltimas25QueEscuchaste,
    SmartList.forgottenFavorites => tx.conQueNoEscuchasHaceMas,
    SmartList.downloaded => tx.todoLoQueGuardasteParaEscuchar,
    SmartList.neverPlayed => tx.deTuMusicaDelDispositivoLas,
  };

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
            if (lastPlayed[track.id] == null || inputs.now.difference(lastPlayed[track.id]!) > forgottenAfter) track,
        ];
      case SmartList.downloaded:
        return inputs.downloaded;
      case SmartList.neverPlayed:
        final played = {for (final e in inputs.history) e.track.id};
        return [
          for (final t in inputs.local)
            if (!played.contains(t.id)) t,
        ];
    }
  }
}
