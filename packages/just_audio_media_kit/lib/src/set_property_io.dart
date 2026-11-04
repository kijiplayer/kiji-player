// Copia de just_audio_media_kit 2.1.0 (Unlicense). Cambio de Kiji: sin nombre de biblioteca (aviso del análisis).
library;

import 'package:media_kit/media_kit.dart';

Future<void> setProperty(Player player, String key, dynamic value) async {
  if (player.platform is! NativePlayer) return;
  await (player.platform as NativePlayer).setProperty(key, value);
}
