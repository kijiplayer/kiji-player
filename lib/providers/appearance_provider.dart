import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/data/settings_store.dart';

/// "Reducir animaciones" elegido en Configuración → Apariencia.
final reduceMotionSettingProvider =
    Provider<bool>((ref) => ref.watch(settingsProvider.select((s) => s.reduceMotion)));

/// true si hay que evitar animaciones: lo pidió el usuario en Kiji o en el
/// sistema (accesibilidad). Respetado en toda la app (§7).
bool reduceMotion(BuildContext context, WidgetRef ref) =>
    ref.watch(reduceMotionSettingProvider) || MediaQuery.disableAnimationsOf(context);
