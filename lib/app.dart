import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/backup/data/backup_notifier.dart';
import 'features/playback_extras/data/playback_automation.dart';
import 'providers/appearance_provider.dart';
import 'screens/home/home_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/global_mini_player.dart';
import 'widgets/playback_shortcuts.dart';

class KijiApp extends ConsumerStatefulWidget {
  const KijiApp({super.key});

  @override
  ConsumerState<KijiApp> createState() => _KijiAppState();
}

class _KijiAppState extends ConsumerState<KijiApp> {
  final _routes = MiniPlayerRouteObserver();

  @override
  Widget build(BuildContext context) {
    // Pausar al silenciar y retomar con el Bluetooth (Tarea K). Vive acá y no
    // en el reproductor porque escucha al reproductor.
    ref.watch(playbackAutomationProvider);
    // Copia de seguridad diaria (Tarea U): se revisa al abrir Kiji.
    ref.watch(backupProvider);
    return MaterialApp(
      title: 'Kiji Player',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkWith(reduceMotion: ref.watch(reduceMotionSettingProvider)),
      darkTheme: AppTheme.darkWith(reduceMotion: ref.watch(reduceMotionSettingProvider)),
      themeMode: ThemeMode.dark,
      // Atajos de teclado en todas las pantallas (PC y teclados físicos, §9).
      // El mini-reproductor se ve en todas las pantallas (Tarea Z7).
      navigatorKey: kijiNavigatorKey,
      navigatorObservers: [_routes],
      builder: (context, child) => PlaybackShortcuts(
        child: GlobalMiniPlayer(observer: _routes, child: child ?? const SizedBox.shrink()),
      ),
      home: const HomeScreen(),
    );
  }
}
