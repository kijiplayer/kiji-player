import '../../lyrics/domain/lyrics.dart';

/// Preferencias de Kiji. Se guardan solo en el teléfono.
///
/// Las de descargas ("solo con WiFi", límite de espacio) siguen en
/// `DownloadSettings`, para que haya una sola fuente de verdad; la pantalla
/// de Configuración las muestra igual.
class AppSettings {
  const AppSettings({
    this.rememberQueue = true,
    this.reduceMotion = false,
    this.streamCacheLimitBytes = defaultCacheLimit,
    this.hideShortAudios = false,
    this.pauseOnMute = false,
    this.resumeOnBluetooth = true,
    this.batteryAsked = false,
    this.crossfadeSeconds = 0,
    this.dataSaver = false,
    this.autoBackup = true,
    this.backupFolder,
    this.disabledLyricsSources = const {},
    this.translationTarget = 'es',
    this.useGemini = false,
    this.geminiEnabled = false,
    this.geminiModel,
    this.checkUpdates = true,
    this.autoExtractorTests = true,
    this.ytDlpAccepted = false,
    this.saveLogs = true,
    this.offerErrorReports = true,
    this.lyricsSourceOrder = LyricsSource.online,
    this.accountPromptsOff = false,
    this.language = 'system',
    this.timeFormat = 'system',
    this.downloadLiked = false,
    this.accent = 'nocturne',
    this.theme = 'dark',
    this.font = 'kiji',
    this.lyricsSize = 'normal',
    this.lastSeenVersion,
    this.closeAction = 'ask',
    this.globalHotkeys = false,
    this.hotkeys = const {},
    this.highPerformance = false,
  });

  /// Opciones de la transición suave entre canciones (0 = apagada).
  static const crossfadeOptions = [0, 3, 5, 8, 12];

  static const _mb = 1024 * 1024;
  static const defaultCacheLimit = 300 * _mb;

  /// Opciones del límite de la caché de lo escuchado.
  static const cacheLimitOptions = [100 * _mb, 300 * _mb, 1024 * _mb, 2048 * _mb];

  /// Idiomas de la app: 'system' sigue al del teléfono.
  static const languages = ['system', 'es', 'en'];

  /// Formato de hora: el del sistema, 12 h o 24 h.
  static const timeFormats = ['system', '12', '24'];

  /// Colores de acento (Configuración → Apariencia). El primero es el de siempre.
  static const accents = ['nocturne', 'aurora', 'ember', 'mint', 'ocean'];

  /// Temas: oscuro (el de siempre), más oscuro (negro puro, ahorra batería en OLED) y claro.
  static const themes = ['dark', 'darker', 'light'];

  /// Tipografía de los títulos: la de Kiji (Space Grotesk) o la del sistema.
  static const fonts = ['kiji', 'system'];

  /// Tamaño de la letra de las canciones.
  static const lyricsSizes = ['small', 'normal', 'large'];

  /// PC: qué hace la ✕ de la ventana. 'ask' pregunta la primera vez.
  static const closeActions = ['ask', 'tray', 'exit'];

  /// Duración mínima para no ser "audio corto" (sonidos de juegos, avisos).
  static const shortAudioMs = 30 * 1000;

  /// Reproductor: al reabrir, volver a la cola y al segundo donde quedó.
  /// Si se apaga, se borra la cola guardada.
  final bool rememberQueue;

  /// Apariencia: sin animaciones decorativas (además de lo del sistema).
  final bool reduceMotion;

  /// Almacenamiento: espacio máximo de la caché de lo escuchado.
  final int streamCacheLimitBytes;

  /// Contenido: ocultar de la Biblioteca los audios de menos de 30 s.
  final bool hideShortAudios;

  /// Reproductor: pausar si el volumen del teléfono llega a cero y
  /// seguir al subirlo (solo si fue esa la causa de la pausa).
  final bool pauseOnMute;

  /// Reproductor: si se cortó la música al desconectarse los
  /// auriculares Bluetooth, seguir al reconectarlos (dentro de 10 minutos).
  final bool resumeOnBluetooth;

  /// Android: ya se explicó y pidió una vez quitar la optimización de batería.
  final bool batteryAsked;

  /// Reproductor: segundos de la transición suave entre canciones.
  final int crossfadeSeconds;

  /// Almacenamiento: con datos móviles, YouTube a la calidad más
  /// baja. Con WiFi, siempre la mejor.
  final bool dataSaver;

  /// Copia de seguridad: una copia por día, automática.
  final bool autoBackup;

  /// Carpeta elegida para las copias; null = la de fábrica (Documentos/Kiji).
  final String? backupFolder;

  /// Letras: fuentes por internet apagadas por el usuario.
  final Set<LyricsSource> disabledLyricsSources;

  /// Traducción de letras: idioma al que se traduce.
  final String translationTarget;

  /// Traducir con Gemini en vez de en el teléfono (solo si está activado).
  final bool useGemini;

  /// Apartado "Con IA (Gemini)": apagado de fábrica; se activa después de
  /// leer los avisos.
  final bool geminiEnabled;

  /// Modelo de Gemini elegido (por ejemplo, "models/gemini-2.5-flash-lite").
  final String? geminiModel;

  /// Buscar actualizaciones en GitHub una vez por día. Se puede apagar.
  final bool checkUpdates;

  /// Pruebas automáticas del extractor con canciones de control. Se puede apagar.
  final bool autoExtractorTests;

  /// Motor C (solo PC): el usuario aceptó bajar y usar yt-dlp. Apagado de fábrica.
  final bool ytDlpAccepted;

  /// Guardar un registro en el dispositivo, sin datos personales.
  final bool saveLogs;

  /// Cuando algo falla, preguntar si se quiere mandar un informe.
  final bool offerErrorReports;

  /// En qué orden se buscan las letras en internet (Configuración → Letras → Fuentes).
  final List<LyricsSource> lyricsSourceOrder;

  /// "No volver a preguntar" si iniciar sesión (Configuración → Cuenta).
  final bool accountPromptsOff;

  /// Idioma de la app (Configuración → Idioma): 'system', 'es' o 'en'.
  final String language;

  /// Hora de 12 o 24 horas: 'system' (la del teléfono), '12' o '24'.
  final String timeFormat;

  /// Al marcar "me gusta" una canción de YouTube, bajarla (respeta "solo con WiFi"). Apagado de
  /// fábrica.
  final bool downloadLiked;

  /// Personalización: color de acento, tema, tipografía y tamaño de la letra de las canciones.
  final String accent;
  final String theme;
  final String font;
  final String lyricsSize;

  /// Última versión cuyas novedades se mostraron (para "Novedades de esta versión").
  final String? lastSeenVersion;

  /// PC: al cerrar la ventana, 'ask' (preguntar), 'tray' (seguir en la bandeja) o 'exit'.
  final String closeAction;

  /// PC: atajos de teclado que funcionan aunque Kiji no esté al frente. Apagados de fábrica.
  final bool globalHotkeys;

  /// PC: atajo de cada acción ('playPause', 'next', 'previous'), como lo guarda hotkey_manager.
  /// Las acciones que faltan usan el de fábrica.
  final Map<String, Map<String, dynamic>> hotkeys;

  /// Apariencia: "Modo alto rendimiento" (pantalla a su máxima frecuencia, más partículas,
  /// desenfoques reales, colores más intensos). Apagado de fábrica: gasta más batería.
  final bool highPerformance;

  AppSettings copyWith({
    bool? rememberQueue,
    bool? reduceMotion,
    int? streamCacheLimitBytes,
    bool? hideShortAudios,
    bool? pauseOnMute,
    bool? resumeOnBluetooth,
    bool? batteryAsked,
    int? crossfadeSeconds,
    bool? dataSaver,
    bool? autoBackup,
    String? backupFolder,
    bool defaultBackupFolder = false,
    Set<LyricsSource>? disabledLyricsSources,
    String? translationTarget,
    bool? useGemini,
    bool? geminiEnabled,
    String? geminiModel,
    bool? checkUpdates,
    bool? autoExtractorTests,
    bool? ytDlpAccepted,
    bool? saveLogs,
    bool? offerErrorReports,
    List<LyricsSource>? lyricsSourceOrder,
    bool? accountPromptsOff,
    String? language,
    String? timeFormat,
    bool? downloadLiked,
    String? accent,
    String? theme,
    String? font,
    String? lyricsSize,
    String? lastSeenVersion,
    String? closeAction,
    bool? globalHotkeys,
    Map<String, Map<String, dynamic>>? hotkeys,
    bool? highPerformance,
  }) =>
      AppSettings(
        rememberQueue: rememberQueue ?? this.rememberQueue,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        streamCacheLimitBytes: streamCacheLimitBytes ?? this.streamCacheLimitBytes,
        hideShortAudios: hideShortAudios ?? this.hideShortAudios,
        pauseOnMute: pauseOnMute ?? this.pauseOnMute,
        resumeOnBluetooth: resumeOnBluetooth ?? this.resumeOnBluetooth,
        batteryAsked: batteryAsked ?? this.batteryAsked,
        crossfadeSeconds: crossfadeSeconds ?? this.crossfadeSeconds,
        dataSaver: dataSaver ?? this.dataSaver,
        autoBackup: autoBackup ?? this.autoBackup,
        backupFolder: defaultBackupFolder ? null : (backupFolder ?? this.backupFolder),
        disabledLyricsSources: disabledLyricsSources ?? this.disabledLyricsSources,
        translationTarget: translationTarget ?? this.translationTarget,
        useGemini: useGemini ?? this.useGemini,
        geminiEnabled: geminiEnabled ?? this.geminiEnabled,
        geminiModel: geminiModel ?? this.geminiModel,
        checkUpdates: checkUpdates ?? this.checkUpdates,
        autoExtractorTests: autoExtractorTests ?? this.autoExtractorTests,
        ytDlpAccepted: ytDlpAccepted ?? this.ytDlpAccepted,
        saveLogs: saveLogs ?? this.saveLogs,
        offerErrorReports: offerErrorReports ?? this.offerErrorReports,
        lyricsSourceOrder: lyricsSourceOrder ?? this.lyricsSourceOrder,
        accountPromptsOff: accountPromptsOff ?? this.accountPromptsOff,
        language: language ?? this.language,
        timeFormat: timeFormat ?? this.timeFormat,
        downloadLiked: downloadLiked ?? this.downloadLiked,
        accent: accent ?? this.accent,
        theme: theme ?? this.theme,
        font: font ?? this.font,
        lyricsSize: lyricsSize ?? this.lyricsSize,
        lastSeenVersion: lastSeenVersion ?? this.lastSeenVersion,
        closeAction: closeAction ?? this.closeAction,
        globalHotkeys: globalHotkeys ?? this.globalHotkeys,
        hotkeys: hotkeys ?? this.hotkeys,
        highPerformance: highPerformance ?? this.highPerformance,
      );

  Map<String, dynamic> toJson() => {
        'version': 1,
        'rememberQueue': rememberQueue,
        'reduceMotion': reduceMotion,
        'streamCacheLimitBytes': streamCacheLimitBytes,
        'hideShortAudios': hideShortAudios,
        'pauseOnMute': pauseOnMute,
        'resumeOnBluetooth': resumeOnBluetooth,
        'batteryAsked': batteryAsked,
        'crossfadeSeconds': crossfadeSeconds,
        'dataSaver': dataSaver,
        'autoBackup': autoBackup,
        if (backupFolder != null) 'backupFolder': backupFolder,
        'disabledLyricsSources': [for (final s in disabledLyricsSources) s.name],
        'translationTarget': translationTarget,
        'useGemini': useGemini,
        'geminiEnabled': geminiEnabled,
        if (geminiModel != null) 'geminiModel': geminiModel,
        'checkUpdates': checkUpdates,
        'autoExtractorTests': autoExtractorTests,
        'ytDlpAccepted': ytDlpAccepted,
        'saveLogs': saveLogs,
        'offerErrorReports': offerErrorReports,
        'lyricsSourceOrder': [for (final s in lyricsSourceOrder) s.name],
        'accountPromptsOff': accountPromptsOff,
        'language': language,
        'timeFormat': timeFormat,
        'downloadLiked': downloadLiked,
        'accent': accent,
        'theme': theme,
        'font': font,
        'lyricsSize': lyricsSize,
        if (lastSeenVersion != null) 'lastSeenVersion': lastSeenVersion,
        'closeAction': closeAction,
        'globalHotkeys': globalHotkeys,
        'hotkeys': hotkeys,
        'highPerformance': highPerformance,
      };

  /// Valores que falten o tengan otro tipo vuelven al de fábrica (un archivo
  /// de una versión vieja o nueva no rompe nada).
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    const d = AppSettings();
    T read<T>(String key, T fallback) => json[key] is T ? json[key] as T : fallback;
    final limit = read<int>('streamCacheLimitBytes', d.streamCacheLimitBytes);
    final crossfade = read<int>('crossfadeSeconds', d.crossfadeSeconds);
    return AppSettings(
      rememberQueue: read('rememberQueue', d.rememberQueue),
      reduceMotion: read('reduceMotion', d.reduceMotion),
      streamCacheLimitBytes: cacheLimitOptions.contains(limit) ? limit : d.streamCacheLimitBytes,
      hideShortAudios: read('hideShortAudios', d.hideShortAudios),
      pauseOnMute: read('pauseOnMute', d.pauseOnMute),
      resumeOnBluetooth: read('resumeOnBluetooth', d.resumeOnBluetooth),
      batteryAsked: read('batteryAsked', d.batteryAsked),
      crossfadeSeconds: crossfadeOptions.contains(crossfade) ? crossfade : d.crossfadeSeconds,
      dataSaver: read('dataSaver', d.dataSaver),
      autoBackup: read('autoBackup', d.autoBackup),
      backupFolder: json['backupFolder'] is String && (json['backupFolder'] as String).isNotEmpty
          ? json['backupFolder'] as String
          : null,
      disabledLyricsSources: {
        if (json['disabledLyricsSources'] is List)
          for (final name in json['disabledLyricsSources'] as List) ?LyricsSource.values.asNameMap()['$name'],
      },
      translationTarget: read('translationTarget', d.translationTarget),
      useGemini: read('useGemini', d.useGemini),
      geminiEnabled: read('geminiEnabled', d.geminiEnabled),
      geminiModel: json['geminiModel'] is String ? json['geminiModel'] as String : null,
      checkUpdates: read('checkUpdates', d.checkUpdates),
      autoExtractorTests: read('autoExtractorTests', d.autoExtractorTests),
      ytDlpAccepted: read('ytDlpAccepted', d.ytDlpAccepted),
      saveLogs: read('saveLogs', d.saveLogs),
      offerErrorReports: read('offerErrorReports', d.offerErrorReports),
      lyricsSourceOrder: lyricsOrderFrom(json['lyricsSourceOrder']),
      accountPromptsOff: read('accountPromptsOff', d.accountPromptsOff),
      language: languages.contains(json['language']) ? json['language'] as String : d.language,
      timeFormat: timeFormats.contains(json['timeFormat']) ? json['timeFormat'] as String : d.timeFormat,
      downloadLiked: read('downloadLiked', d.downloadLiked),
      accent: accents.contains(json['accent']) ? json['accent'] as String : d.accent,
      theme: themes.contains(json['theme']) ? json['theme'] as String : d.theme,
      font: fonts.contains(json['font']) ? json['font'] as String : d.font,
      lyricsSize: lyricsSizes.contains(json['lyricsSize']) ? json['lyricsSize'] as String : d.lyricsSize,
      lastSeenVersion: json['lastSeenVersion'] is String ? json['lastSeenVersion'] as String : null,
      closeAction: closeActions.contains(json['closeAction']) ? json['closeAction'] as String : d.closeAction,
      globalHotkeys: read('globalHotkeys', d.globalHotkeys),
      hotkeys: {
        if (json['hotkeys'] is Map)
          for (final MapEntry(:key, :value) in (json['hotkeys'] as Map).entries)
            if (key is String && value is Map) key: Map<String, dynamic>.from(value),
      },
      highPerformance: read('highPerformance', d.highPerformance),
    );
  }

  /// true si [durationMs] es un audio corto que hay que ocultar.
  bool hides(int durationMs) =>
      hideShortAudios && durationMs > 0 && durationMs < shortAudioMs;
}

/// El orden guardado de las fuentes de letras: las conocidas en ese orden y, al final, las que
/// falten (fuentes nuevas de una versión más nueva de Kiji).
List<LyricsSource> lyricsOrderFrom(Object? json) {
  final names = LyricsSource.values.asNameMap();
  final order = <LyricsSource>[
    if (json is List)
      for (final name in json)
        if (names['$name'] case final source? when LyricsSource.online.contains(source)) source,
  ];
  return [...order.toSet(), for (final s in LyricsSource.online) if (!order.contains(s)) s];
}

/// ¿La hora se muestra en 24 horas? `timeFormat` es el ajuste ('system', '12' o '24');
/// con 'system' manda la preferencia del teléfono o de la PC ([system]).
bool use24HourClock(String timeFormat, {required bool system}) => switch (timeFormat) {
      '12' => false,
      '24' => true,
      _ => system,
    };

/// Cuánto se agranda la letra de las canciones según "Tamaño de las letras".
double lyricsScaleFor(String size) => switch (size) {
  'small' => 0.85,
  'large' => 1.2,
  _ => 1.0,
};
