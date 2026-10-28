import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/backup/data/backup_notifier.dart';
import 'features/playback_extras/data/battery_optimization.dart';
import 'features/style/presentation/style_chooser_screen.dart';
import 'features/desktop/desktop_integration.dart';
import 'features/desktop/desktop_window.dart';
import 'features/downloads/data/auto_downloads.dart';
import 'features/playback_extras/data/playback_automation.dart';
import 'features/extractor/data/auto_tests.dart';
import 'features/performance/device_performance.dart';
import 'features/reports/data/error_reporter.dart';
import 'l10n/l10n.dart';
import 'features/reports/data/kiji_logs.dart';
import 'features/reports/presentation/error_report_dialog.dart';
import 'features/settings/data/settings_store.dart';
import 'features/settings/domain/app_settings.dart';
import 'providers/playback_provider.dart';
import 'features/updates/update_checker.dart';
import 'features/updates/whats_new.dart';
import 'features/updates/whats_new_screen.dart';
import 'providers/appearance_provider.dart';
import 'screens/home/home_screen.dart';
import 'theme/app_theme.dart';
import 'theme/kiji_tokens.dart';
import 'widgets/global_mini_player.dart';
import 'utils/clock_format.dart';
import 'widgets/playback_shortcuts.dart';
import 'features/moments/presentation/moment_marks.dart';
import 'features/account/data/account_store.dart';
import 'features/account/presentation/account_screens.dart';
import 'features/welcome/data/welcome_store.dart';
import 'features/welcome/presentation/welcome_screen.dart';

class KijiApp extends ConsumerStatefulWidget {
  const KijiApp({super.key});

  @override
  ConsumerState<KijiApp> createState() => _KijiAppState();
}

class _KijiAppState extends ConsumerState<KijiApp> with WidgetsBindingObserver {
  final _routes = MiniPlayerRouteObserver();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // PC: al cerrar la ventana, guardar la cola antes de salir (ver DesktopWindow).
    DesktopWindow.instance.beforeExit = () => ref.read(playbackProvider.notifier).saveNow();
    // PC: bandeja del sistema y atajos globales.
    watchDesktop(ref);
    // Modo alto rendimiento: la pantalla a su frecuencia más alta (Android).
    ref.listenManual(
      settingsProvider.select((s) => s.highPerformance),
      (before, on) {
        // Al abrir con el modo apagado no hace falta pedir nada.
        if (before != null || on) applyHighRefreshRate(on);
      },
      fireImmediately: true,
    );
    // Android: la primera vez que suena música, explicar por qué conviene quitar la optimización de batería.
    ref.listenManual(playbackProvider.select((s) => s.isPlaying), (_, playing) {
      final context = kijiNavigatorKey.currentContext;
      if (playing && context != null && context.mounted) unawaited(offerBatteryExemptionOnce(context, ref));
    });
    // Actualizaciones: como mucho una consulta por día, si está prendido.
    Future.microtask(() => ref.read(updateProvider.notifier).checkIfDue());
    // Salud del Extractor: pruebas automáticas con canciones de control.
    Future.microtask(() => ref.read(extractorAutoTestsProvider).start());
    // Descargas que esperaban (sin WiFi o al cerrar Kiji): siguen solas.
    Future.microtask(() => ref.read(autoDownloadsProvider));
    // Registros e informes.
    ref.listenManual(
      settingsProvider.select((s) => s.saveLogs),
      (_, on) => KijiLogs.setEnabled(on),
      fireImmediately: true,
    );
    ErrorReporter.instance.pending.addListener(_offerReport);
    // Repetir un tramo (Momentos): vuelve al principio al llegar al final.
    watchMomentLoop(ref);
    // Cuenta opcional: se carga la sesión guardada (si hay) y se ofrece cuando una canción la necesita.
    ref.read(accountProvider);
    ref.listenManual(accountOfferProvider, (_, offer) {
      if (offer == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final context = kijiNavigatorKey.currentContext;
        ref.read(accountOfferProvider.notifier).state = null;
        if (context == null || !context.mounted) return;
        final signedIn = await showAccountOfferDialog(context, ref, offer);
        if (signedIn) await ref.read(playbackProvider.notifier).playTrack(offer.track);
      });
    });
    // Bienvenida (solo a quien recién instala, una única vez).
    _maybeWelcome();
    // Nunca mientras suena música: si llegó un aviso sonando, se ofrece al pausar.
    ref.listenManual(playbackProvider.select((s) => s.isPlaying), (_, playing) {
      if (!playing) _offerReport();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ErrorReporter.instance.pending.removeListener(_offerReport);
    super.dispose();
  }

  /// Al abrir: la bienvenida a quien recién instala o, después de actualizar, una sola vez
  /// "Novedades de esta versión".
  Future<void> _maybeWelcome() async {
    final fresh = await WelcomeStore().shouldShow();
    final settings = await ref.read(settingsProvider.notifier).loaded;
    final showNews = shouldShowWhatsNew(lastSeenVersion: settings.lastSeenVersion, freshInstall: fresh);
    Future<void> markSeen() async {
      if (ref.read(settingsProvider).lastSeenVersion == kijiVersion) return;
      await ref.read(settingsProvider.notifier).update((s) => s.copyWith(lastSeenVersion: kijiVersion));
    }

    // "¿Cómo quieres que se vea Kiji?": al instalar (después de la bienvenida) y, a quien
    // actualiza, una sola vez.
    Future<void> chooseStyleOnce() async {
      if (ref.read(settingsProvider).styleChosen) return;
      final context = kijiNavigatorKey.currentContext;
      if (context != null && context.mounted) await StyleChooserScreen.open(context, ref);
    }

    if (fresh) {
      // Se anota al cerrar la bienvenida: si Kiji se cierra a mitad, la bienvenida vuelve.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final context = kijiNavigatorKey.currentContext;
        if (context != null && context.mounted) await WelcomeScreen.open(context, instant: true);
        await markSeen();
        await chooseStyleOnce();
      });
      return;
    }
    await markSeen();
    if (!settings.styleChosen) {
      final done = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await chooseStyleOnce();
        done.complete();
      });
      await done.future;
    }
    // Después de los estilos (si hacía falta elegir), "Qué hay de nuevo", una sola vez.
    if (!showNews) return;
    debugPrint('=== NOVEDADES: se muestra "Qué hay de nuevo" de $kijiVersion ===');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = kijiNavigatorKey.currentContext;
      if (context != null && context.mounted) WhatsNewScreen.open(context);
    });
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

  /// El idioma del teléfono cambió (importa si Kiji sigue al del sistema).
  @override
  void didChangeLocales(List<Locale>? locales) => setState(() {});

  /// Si Kiji arrancó sin pantalla (desde los auriculares), la frecuencia se pide al aparecer la ventana.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && ref.read(settingsProvider).highPerformance) {
      applyHighRefreshRate(true);
    }
  }

  /// Idioma de la app (Configuración → Idioma): se aplica sin reiniciar. Los textos salen de
  /// [tx], así que después de cambiarlo se vuelve a dibujar todo.
  Locale _applyLanguage() {
    final language = ref.watch(settingsProvider.select((s) => s.language));
    final locale = resolveKijiLocale(language, WidgetsBinding.instance.platformDispatcher.locale);
    if (locale.languageCode != kijiLanguage) {
      setKijiLocale(locale);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        void rebuild(Element element) {
          element.markNeedsBuild();
          element.visitChildren(rebuild);
        }

        (context as Element).visitChildren(rebuild);
      });
    }
    return locale;
  }

  /// Tema, acento y tipografía (Configuración → Apariencia). Los colores salen de una paleta
  /// global ([KijiColors.palette]): al cambiarla se redibuja todo, como con el idioma.
  void _applyAppearance() {
    final (styleName, theme, accent, font, rich, calm) = ref.watch(
      settingsProvider.select((s) => (s.style, s.theme, s.accent, s.font, s.highPerformance, s.reduceMotion)),
    );
    final style = KijiStyle.parse(styleName);
    final palette = KijiPalette.forStyle(style, theme: theme, accent: accent);
    final systemFont = font == 'system';
    if (style == KijiLook.style &&
        palette == KijiColors.palette &&
        systemFont == KijiText.useSystemFont &&
        rich == KijiEffects.rich &&
        calm == KijiEffects.calm) {
      return;
    }
    KijiLook.style = style;
    KijiColors.palette = palette;
    KijiText.useSystemFont = systemFont;
    KijiEffects.rich = rich;
    KijiEffects.calm = calm;
    // La primera vez (al abrir) no hace falta: todavía no se dibujó nada.
    if (!_appearanceReady) return;
    debugPrint('=== APARIENCIA: estilo ${style.name}, tema $theme, acento $accent, letra $font, alto rendimiento $rich ===');
    WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildAll());
  }

  bool _appearanceReady = false;

  void _rebuildAll() {
    if (!mounted) return;
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) {
    _applyAppearance();
    _appearanceReady = true;
    final locale = _applyLanguage();
    // Pausar al silenciar y retomar con el Bluetooth. Vive aquí y no
    // en el reproductor porque escucha al reproductor.
    ref.watch(playbackAutomationProvider);
    // Copia de seguridad diaria: se revisa al abrir Kiji.
    ref.watch(backupProvider);
    return MaterialApp(
      title: 'Kiji Player', // l10n-ignore
      debugShowCheckedModeBanner: false,
      // Textos en ARB (español e inglés); los de Material siguen el mismo idioma.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      theme: AppTheme.darkWith(reduceMotion: ref.watch(reduceMotionSettingProvider)),
      darkTheme: AppTheme.darkWith(reduceMotion: ref.watch(reduceMotionSettingProvider)),
      themeMode: KijiColors.palette.isLight ? ThemeMode.light : ThemeMode.dark,
      // Atajos de teclado en todas las pantallas (PC y teclados físicos).
      // El mini-reproductor se ve en todas las pantallas.
      navigatorKey: kijiNavigatorKey,
      navigatorObservers: [_routes],
      builder: (context, child) {
        // Hora de 12 o 24 horas (Configuración → Apariencia); "Sistema" deja la del teléfono.
        kijiUse24Hour = use24HourClock(
          ref.watch(settingsProvider.select((s) => s.timeFormat)),
          system: MediaQuery.alwaysUse24HourFormatOf(context),
        );
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: kijiUse24Hour),
          child: BackdropGroup(
            child: PlaybackShortcuts(
              child: GlobalMiniPlayer(observer: _routes, child: child ?? const SizedBox.shrink()),
            ),
          ),
        );
      },
      home: const HomeScreen(),
    );
  }
}
