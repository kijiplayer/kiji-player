import 'package:flutter/material.dart';

import 'screens/home/home_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/playback_shortcuts.dart';

class KijiApp extends StatelessWidget {
  const KijiApp({super.key});

  @override
  Widget build(BuildContext context) {
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
