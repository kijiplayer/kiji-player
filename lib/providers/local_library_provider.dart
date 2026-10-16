import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/local_library/data/android_media_store_source.dart';
import '../features/local_library/data/desktop_folder_source.dart';
import '../features/local_library/domain/local_library_source.dart';

/// Fuente de la biblioteca local según la plataforma.
final localLibrarySourceProvider = Provider<LocalLibrarySource>((ref) {
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    return AndroidMediaStoreSource();
  }
  return DesktopFolderSource();
});
