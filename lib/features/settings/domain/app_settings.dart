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
  });

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

  AppSettings copyWith({
    bool? rememberQueue,
    bool? reduceMotion,
    int? streamCacheLimitBytes,
    bool? hideShortAudios,
  }) =>
      AppSettings(
        rememberQueue: rememberQueue ?? this.rememberQueue,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        streamCacheLimitBytes: streamCacheLimitBytes ?? this.streamCacheLimitBytes,
        hideShortAudios: hideShortAudios ?? this.hideShortAudios,
      );

  Map<String, dynamic> toJson() => {
        'version': 1,
        'rememberQueue': rememberQueue,
        'reduceMotion': reduceMotion,
        'streamCacheLimitBytes': streamCacheLimitBytes,
        'hideShortAudios': hideShortAudios,
      };

  /// Valores que falten o tengan otro tipo vuelven al de fábrica (un archivo
  /// de una versión vieja o nueva no rompe nada).
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    const d = AppSettings();
    T read<T>(String key, T fallback) => json[key] is T ? json[key] as T : fallback;
    final limit = read<int>('streamCacheLimitBytes', d.streamCacheLimitBytes);
    return AppSettings(
      rememberQueue: read('rememberQueue', d.rememberQueue),
      reduceMotion: read('reduceMotion', d.reduceMotion),
      streamCacheLimitBytes: cacheLimitOptions.contains(limit) ? limit : d.streamCacheLimitBytes,
      hideShortAudios: read('hideShortAudios', d.hideShortAudios),
    );
  }

  /// true si [durationMs] es un audio corto que hay que ocultar.
  bool hides(int durationMs) =>
      hideShortAudios && durationMs > 0 && durationMs < shortAudioMs;
}
