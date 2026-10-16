import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/track.dart';
import '../domain/playback_rules.dart';

/// Abre el menú "Compartir" del sistema con la canción (Tarea K). En la PC,
/// share_plus muestra el diálogo de Windows. Kiji no envía nada por su cuenta.
Future<void> shareTrack(Track track) async {
  try {
    await SharePlus.instance.share(ShareParams(text: shareTextFor(track), subject: track.title));
  } catch (error) {
    debugPrint('=== COMPARTIR: no se pudo abrir el menú: $error ===');
  }
}
