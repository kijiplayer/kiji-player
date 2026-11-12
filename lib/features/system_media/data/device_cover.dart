import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../models/track.dart';
import '../../../providers/downloads_provider.dart';
import '../../customize/data/track_overrides.dart';
import '../../local_library/data/group_covers.dart';
import '../../local_library/domain/local_groups.dart';
import 'cover_art.dart';

/// La portada de [track] que ya está en el dispositivo, en el mismo orden que el reproductor: la
/// foto elegida para la canción, la elegida para su álbum o carpeta, la del archivo, la de la
/// descarga o la guardada en la caché. Para la notificación, la pantalla de bloqueo y los widgets,
/// que así la muestran también sin internet. null si no hay ninguna guardada.
Future<String?> deviceCoverFor(Ref ref, Track track) async {
  try {
    final preferred = <String>[];
    final covers = await ref.read(coversFolderProvider.future);
    final custom = ref.read(trackOverridesProvider)[track.id]?.coverFile;
    if (custom != null) preferred.add(p.join(covers.path, custom));
    if (track.source == TrackSource.local) {
      final chosen = ref.read(groupCoversProvider);
      final group = chosen[albumKeyOf(track)] ?? chosen[folderKeyOf(track)];
      if (group != null) preferred.add(p.join(covers.path, group));
    }
    final downloads = ref.read(downloadsProvider);
    final videoId = track.youtubeVideoId;
    return await localCoverPath(
      track,
      support: await getApplicationSupportDirectory(),
      downloadsDir: downloads.directoryPath,
      downloadThumb: videoId == null ? null : downloads.completed[videoId]?.thumbnailFileName,
      preferred: preferred,
    );
  } catch (error) {
    debugPrint('=== CONTROLES: sin portada guardada en el dispositivo (${error.runtimeType}) ===');
    return null;
  }
}
