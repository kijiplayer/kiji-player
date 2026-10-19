import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Kiji Dev (flavor `dev`) o una compilación de depuración: muestra las herramientas de
/// desarrollo (Tarea T2). En Kiji de verdad nunca aparecen.
bool get isDevBuild => appFlavor == 'dev' || kDebugMode;
