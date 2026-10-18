import '../../lyrics/domain/lyrics.dart';

/// Preferencias de Kiji (Tarea G). Se guardan solo en el teléfono.
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
  });

  /// Opciones de la transición suave entre canciones (0 = apagada).
  static const crossfadeOptions = [0, 3, 5, 8, 12];

  static const _mb = 1024 * 1024;
  static const defaultCacheLimit = 300 * _mb;

  /// Opciones del límite de la caché de lo escuchado.
  static const cacheLimitOptions = [100 * _mb, 300 * _mb, 1024 * _mb, 2048 * _mb];

  /// Duración mínima para no ser "audio corto" (sonidos de juegos, avisos).
  static const shortAudioMs = 30 * 1000;

  /// Reproductor: al reabrir, volver a la cola y al segundo donde quedó
  /// (Tarea A). Si se apaga, se borra la cola guardada.
  final bool rememberQueue;

  /// Apariencia: sin animaciones decorativas (además de lo del sistema).
  final bool reduceMotion;

  /// Almacenamiento: espacio máximo de la caché de lo escuchado (Tarea D).
  final int streamCacheLimitBytes;

  /// Contenido: ocultar de la Biblioteca los audios de menos de 30 s.
  final bool hideShortAudios;

  /// Reproductor (Tarea K): pausar si el volumen del teléfono llega a cero y
  /// seguir al subirlo (solo si fue esa la causa de la pausa).
  final bool pauseOnMute;

  /// Reproductor (Tarea K): si se cortó la música al desconectarse los
  /// auriculares Bluetooth, seguir al reconectarlos (dentro de 10 minutos).
  final bool resumeOnBluetooth;

  /// Reproductor (Tarea K): segundos de la transición suave entre canciones.
  final int crossfadeSeconds;

  /// Almacenamiento (Tarea K): con datos móviles, YouTube a la calidad más
  /// baja. Con WiFi, siempre la mejor.
  final bool dataSaver;

  /// Copia de seguridad (Tarea U): una copia por día, automática.
  final bool autoBackup;

  /// Carpeta elegida para las copias; null = la de fábrica (Documentos/Kiji).
  final String? backupFolder;

  /// Letras (Tarea Z4): fuentes por internet apagadas por el usuario.
  final Set<LyricsSource> disabledLyricsSources;

  /// Traducción de letras (Tarea Z4): idioma al que se traduce.
  final String translationTarget;

  /// Traducir con Gemini en vez de en el teléfono (solo si está activado).
  final bool useGemini;

  /// Apartado "Con IA (Gemini)": apagado de fábrica; se activa después de
  /// leer los avisos.
  final bool geminiEnabled;

  /// Modelo de Gemini elegido (por ejemplo, "models/gemini-2.5-flash-lite").
  final String? geminiModel;

  /// Buscar actualizaciones en GitHub una vez por día (Tarea W1). Se puede apagar.
  final bool checkUpdates;

  /// Pruebas automáticas del extractor con canciones de control (Tarea Z8). Se puede apagar.
  final bool autoExtractorTests;

  AppSettings copyWith({
    bool? rememberQueue,
    bool? reduceMotion,
    int? streamCacheLimitBytes,
    bool? hideShortAudios,
    bool? pauseOnMute,
    bool? resumeOnBluetooth,
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
  }) =>
      AppSettings(
        rememberQueue: rememberQueue ?? this.rememberQueue,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        streamCacheLimitBytes: streamCacheLimitBytes ?? this.streamCacheLimitBytes,
        hideShortAudios: hideShortAudios ?? this.hideShortAudios,
        pauseOnMute: pauseOnMute ?? this.pauseOnMute,
        resumeOnBluetooth: resumeOnBluetooth ?? this.resumeOnBluetooth,
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
      );

  Map<String, dynamic> toJson() => {
        'version': 1,
        'rememberQueue': rememberQueue,
        'reduceMotion': reduceMotion,
        'streamCacheLimitBytes': streamCacheLimitBytes,
        'hideShortAudios': hideShortAudios,
        'pauseOnMute': pauseOnMute,
        'resumeOnBluetooth': resumeOnBluetooth,
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
    );
  }

  /// true si [durationMs] es un audio corto que hay que ocultar.
  bool hides(int durationMs) =>
      hideShortAudios && durationMs > 0 && durationMs < shortAudioMs;
}
