import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/local_library/data/android_media_store_source.dart';
import '../features/local_library/data/desktop_folder_source.dart';
import '../features/local_library/domain/local_library_source.dart';
import '../models/track.dart';

/// Fuente de la biblioteca local según la plataforma.
final localLibrarySourceProvider = Provider<LocalLibrarySource>((ref) {
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    return AndroidMediaStoreSource();
  }
  return DesktopFolderSource();
});

/// Canciones locales ya accesibles (sin pedir permisos ni abrir el selector
/// de carpetas: si no hay acceso, lista vacía). Las usa "Mis archivos".
final localTracksProvider = FutureProvider<List<Track>>((ref) async {
  final source = ref.watch(localLibrarySourceProvider);
  try {
    if (!await source.hasAccess()) return const [];
    return await source.loadTracks();
  } catch (error) {
    debugPrint('=== BIBLIOTECA: no se pudo leer para buscar: $error ===');
    return const [];
  }
});
