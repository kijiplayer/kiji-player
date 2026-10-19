import 'package:flutter/services.dart';

/// Kiji Dev (flavor `dev`). Es una constante de compilación (`--flavor dev` define
/// `FLUTTER_APP_FLAVOR`): en Kiji (flavor `prod`) todo lo que depende de ella queda fuera de la
/// app compilada: las herramientas de desarrollo, el 🐞 y el medidor de cuadros.
const bool isDevBuild = appFlavor == 'dev';
