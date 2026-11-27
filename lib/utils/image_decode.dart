import 'package:flutter/widgets.dart';

/// Píxeles reales para decodificar una imagen que se ve de [logical] px lógicos: así una miniatura
/// de 44 px no se decodifica a 720 px (menos memoria y menos trabajo al aparecer; se ve igual).
int decodeSize(BuildContext context, double logical) => (logical * MediaQuery.devicePixelRatioOf(context)).ceil();
