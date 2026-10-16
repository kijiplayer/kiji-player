import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/system_media/data/system_media_controls_factory.dart';
import '../features/system_media/domain/system_media_controls.dart';

/// Controles multimedia del sistema. `main.dart` lo reemplaza por la
/// implementación de la plataforma (se inicia antes de `runApp`); el valor
/// por defecto no hace nada, y es el que usan los tests.
final systemMediaControlsProvider =
    Provider<SystemMediaControls>((ref) => const NoSystemMediaControls());
