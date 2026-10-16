// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivos de referencia: app/src/main/kotlin/.../ui/player/Queue.kt y ui/menu/QueueMenu.kt
// (reordenar, quitar y "reproducir a continuación").

import '../../../models/track.dart';

/// Una cola y la posición de la canción que suena dentro de ella.
///
/// Todas las operaciones son puras (devuelven una cola nueva) para poder
/// probarlas sin reproductor: lo delicado es mantener [currentIndex]
/// apuntando a la misma canción cuando cambian las de alrededor.
class QueueSnapshot {
  const QueueSnapshot(this.tracks, this.currentIndex);

  final List<Track> tracks;
  final int currentIndex;

  Track? get current =>
      currentIndex >= 0 && currentIndex < tracks.length ? tracks[currentIndex] : null;

  /// Mueve la canción de [from] a [to] (índices finales, ya ajustados).
  QueueSnapshot move(int from, int to) {
    if (from == to || from < 0 || from >= tracks.length || to < 0 || to >= tracks.length) {
      return this;
    }
    final list = [...tracks];
    final track = list.removeAt(from);
    list.insert(to, track);

    var current = currentIndex;
    if (from == currentIndex) {
      current = to;
    } else if (from < currentIndex && to >= currentIndex) {
      current--;
    } else if (from > currentIndex && to <= currentIndex) {
      current++;
    }
    return QueueSnapshot(list, current);
  }

  /// Quita la canción en [index]. Si era la que sonaba, [currentIndex] pasa a
  /// la que quedó en su lugar (la siguiente), o a la anterior si era la última.
  QueueSnapshot remove(int index) {
    if (index < 0 || index >= tracks.length) return this;
    final list = [...tracks]..removeAt(index);
    var current = currentIndex;
    if (index < currentIndex) {
      current--;
    } else if (index == currentIndex && current >= list.length) {
      current = list.length - 1;
    }
    return QueueSnapshot(list, list.isEmpty ? 0 : current);
  }

  /// Vuelve a poner [track] en [index] (para "Deshacer").
  /// [wasCurrent]: era la que sonaba cuando se quitó.
  QueueSnapshot insert(int index, Track track, {bool wasCurrent = false}) {
    final at = index.clamp(0, tracks.length);
    final list = [...tracks]..insert(at, track);
    if (tracks.isEmpty) return QueueSnapshot(list, 0);
    var current = currentIndex;
    if (wasCurrent) {
      current = at;
    } else if (at <= currentIndex) {
      current++;
    }
    return QueueSnapshot(list, current);
  }

  /// Pone [track] justo después de la que suena. Si ya estaba en la cola, se
  /// mueve (no se duplica).
  QueueSnapshot playNext(Track track) {
    if (tracks.isEmpty) return QueueSnapshot([track], 0);
    final existing = tracks.indexWhere((t) => t.id == track.id);
    if (existing == currentIndex) return this;
    if (existing != -1) {
      final target = existing < currentIndex ? currentIndex : currentIndex + 1;
      return move(existing, target);
    }
    return insert(currentIndex + 1, track);
  }

  /// Agrega [track] al final. Si ya estaba, no hace nada.
  QueueSnapshot addToEnd(Track track) {
    if (tracks.any((t) => t.id == track.id)) return this;
    return QueueSnapshot([...tracks, track], tracks.isEmpty ? 0 : currentIndex);
  }
}
