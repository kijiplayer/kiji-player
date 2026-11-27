/// Sincronizar una playlist de YouTube Music de ida y vuelta (0.9): qué cambió en Kiji y qué en
/// YouTube desde la última vez ([base]), qué hay que mandarle a YouTube y cómo queda.
///
/// Son conjuntos de videos: lo que se agregó en un lado se agrega en el otro; lo que se quitó en un
/// lado se quita en el otro. Así no se pierde nada de ninguno de los dos lados. El orden es el de
/// YouTube, con lo agregado en Kiji al final (YouTube también agrega al final).
class YtPlaylistMerge {
  const YtPlaylistMerge({
    required this.result,
    required this.toAdd,
    required this.toRemove,
    required this.changedInKiji,
    required this.changedInYouTube,
  });

  /// Cómo queda la playlist (ids de video, en orden).
  final List<String> result;

  /// Agregadas en Kiji que YouTube todavía no tiene.
  final List<String> toAdd;

  /// Quitadas en Kiji que YouTube todavía tiene.
  final List<String> toRemove;

  final bool changedInKiji;
  final bool changedInYouTube;

  /// Cambió en los dos lados desde la última vez (se avisa: se juntaron los cambios).
  bool get conflict => changedInKiji && changedInYouTube;

  bool get needsPush => toAdd.isNotEmpty || toRemove.isNotEmpty;
}

/// [editable] = la playlist es del usuario. Si no (guardada de otro), no se le manda nada a
/// YouTube: lo de Kiji queda solo en Kiji y lo de YouTube se trae igual.
YtPlaylistMerge mergeYtPlaylist({
  required List<String> base,
  required List<String> local,
  required List<String> remote,
  bool editable = true,
}) {
  final baseSet = base.toSet();
  final localSet = local.toSet();
  final remoteSet = remote.toSet();
  final addedInKiji = [for (final id in local) if (!baseSet.contains(id)) id];
  final removedInKiji = {for (final id in base) if (!localSet.contains(id)) id};
  final changedInYouTube = remote.any((id) => !baseSet.contains(id)) || base.any((id) => !remoteSet.contains(id));

  final toAdd = [for (final id in addedInKiji) if (!remoteSet.contains(id)) id];
  final toRemove = [for (final id in remote) if (removedInKiji.contains(id)) id];
  final seen = <String>{};
  final result = [
    for (final id in remote)
      if (!removedInKiji.contains(id) && seen.add(id)) id,
    for (final id in toAdd)
      if (seen.add(id)) id,
  ];
  return YtPlaylistMerge(
    result: result,
    toAdd: editable ? toAdd : const [],
    toRemove: editable ? toRemove : const [],
    changedInKiji: addedInKiji.isNotEmpty || removedInKiji.isNotEmpty,
    changedInYouTube: changedInYouTube,
  );
}
