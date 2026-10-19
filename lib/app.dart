import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/backup/data/backup_notifier.dart';
import 'features/playback_extras/data/playback_automation.dart';
import 'features/extractor/data/auto_tests.dart';
import 'features/reports/data/error_reporter.dart';
import 'l10n/app_localizations.dart';
import 'features/reports/data/kiji_logs.dart';
import 'features/reports/presentation/error_report_dialog.dart';
import 'features/settings/data/settings_store.dart';
import 'providers/playback_provider.dart';
import 'features/updates/update_checker.dart';
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
  void initState() {
    super.initState();
    // Actualizaciones (Tarea W1): como mucho una consulta por día, si está prendido.
    Future.microtask(() => ref.read(updateProvider.notifier).checkIfDue());
    // Salud del Extractor (Tarea Z8): pruebas automáticas con canciones de control.
    Future.microtask(() => ref.read(extractorAutoTestsProvider).start());
    // Registros e informes (Tarea T3).
    ref.listenManual(settingsProvider.select((s) => s.saveLogs), (_, on) => KijiLogs.setEnabled(on),
        fireImmediately: true);
    ErrorReporter.instance.pending.addListener(_offerReport);
    // Nunca mientras suena música: si llegó un aviso sonando, se ofrece al pausar.
    ref.listenManual(playbackProvider.select((s) => s.isPlaying), (_, playing) {
      if (!playing) _offerReport();
    });
  }

  @override
  void dispose() {
    ErrorReporter.instance.pending.removeListener(_offerReport);
    super.dispose();
  }

  bool _offering = false;

  /// Algo falló: se pregunta si se quiere mandar un informe (una vez por tipo de error).
  void _offerReport() {
    final report = ErrorReporter.instance.pending.value;
    if (report == null || _offering) return;
    if (!ref.read(settingsProvider).offerErrorReports) {
      ErrorReporter.instance.dismiss();
      return;
    }
    if (ref.read(playbackProvider).isPlaying) return;
    _offering = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final context = kijiNavigatorKey.currentContext;
      try {
        if (context != null && context.mounted) await showErrorReportDialog(context, report);
      } finally {
        _offering = false;
        ErrorReporter.instance.dismiss();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Pausar al silenciar y retomar con el Bluetooth (Tarea K). Vive aquí y no
    // en el reproductor porque escucha al reproductor.
    ref.watch(playbackAutomationProvider);
    // Copia de seguridad diaria (Tarea U): se revisa al abrir Kiji.
    ref.watch(backupProvider);
    return MaterialApp(
      title: 'Kiji Player',
      debugShowCheckedModeBanner: false,
      // Textos en ARB (Tarea T5). Por ahora siempre en español: el inglés se activa cuando
      // estén traducidos todos los textos (los de Material, como "Cancelar", ya salen en español).
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('es'),
      theme: AppTheme.darkWith(reduceMotion: ref.watch(reduceMotionSettingProvider)),
      darkTheme: AppTheme.darkWith(reduceMotion: ref.watch(reduceMotionSettingProvider)),
      themeMode: ThemeMode.dark,
      // Atajos de teclado en todas las pantallas (PC y teclados físicos, §9).
      // El mini-reproductor se ve en todas las pantallas (Tarea Z7).
      navigatorKey: kijiNavigatorKey,
      navigatorObservers: [_routes],
      builder: (context, child) => BackdropGroup(
        child: PlaybackShortcuts(
          child: GlobalMiniPlayer(observer: _routes, child: child ?? const SizedBox.shrink()),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
