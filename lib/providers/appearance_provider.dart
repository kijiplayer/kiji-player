import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Reducir animaciones" elegido dentro de Kiji. La Tarea G (Configuración)
/// lo guarda; mientras tanto vale lo del sistema.
final reduceMotionSettingProvider = StateProvider<bool>((ref) => false);

/// true si hay que evitar animaciones: lo pidió el usuario en Kiji o en el
/// sistema (accesibilidad). Respetado en toda la app (§7).
bool reduceMotion(BuildContext context, WidgetRef ref) =>
    ref.watch(reduceMotionSettingProvider) || MediaQuery.disableAnimationsOf(context);
