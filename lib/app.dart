import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/playback_extras/data/playback_automation.dart';
import 'screens/home/home_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/playback_shortcuts.dart';

class KijiApp extends ConsumerWidget {
  const KijiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pausar al silenciar y retomar con el Bluetooth (Tarea K). Vive acá y no
    // en el reproductor porque escucha al reproductor.
    ref.watch(playbackAutomationProvider);
    return MaterialApp(
      title: 'Kiji Player',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      // Atajos de teclado en todas las pantallas (PC y teclados físicos, §9).
      builder: (context, child) => PlaybackShortcuts(child: child ?? const SizedBox.shrink()),
      home: const HomeScreen(),
    );
  }
}
