import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Espera a que la app esté a la vista: el primer cuadro dibujado y la app en primer plano (en
/// Android, con la Activity lista). Para lo que necesita la pantalla (pedir un permiso) o puede
/// esperar a que Kiji ya se vea (tareas del arranque). Nunca espera más de [limit].
Future<void> whenAppVisible({Duration limit = const Duration(seconds: 20)}) async {
  final binding = WidgetsBinding.instance;
  try {
    if (!binding.firstFrameRasterized) await binding.waitUntilFirstFrameRasterized.timeout(limit);
    if (binding.lifecycleState == AppLifecycleState.resumed || binding.lifecycleState == null) {
      await SchedulerBinding.instance.endOfFrame.timeout(limit);
      return;
    }
    final resumed = Completer<void>();
    final listener = AppLifecycleListener(onResume: () {
      if (!resumed.isCompleted) resumed.complete();
    });
    try {
      await resumed.future.timeout(limit);
    } finally {
      listener.dispose();
    }
  } on TimeoutException {
    debugPrint('=== ARRANQUE: la pantalla tardó en estar lista; se sigue igual ===');
  }
}
