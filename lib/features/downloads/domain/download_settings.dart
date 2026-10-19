/// Preferencias de descargas. Viven aquí hasta que exista la pantalla de
/// Configuración (Tarea G), que las mostrará también.
class DownloadSettings {
  const DownloadSettings({this.wifiOnly = true, this.limitBytes});

  /// Cero Sorpresas: por defecto no se gastan datos móviles.
  final bool wifiOnly;

  /// Espacio máximo para descargas. null = sin límite.
  final int? limitBytes;

  /// Opciones que ofrece la UI para el límite.
  static const limitOptions = <int?>[
    null,
    1 * _gb,
    2 * _gb,
    5 * _gb,
    10 * _gb,
  ];
  static const _gb = 1024 * 1024 * 1024;

  DownloadSettings copyWith({bool? wifiOnly, int? Function()? limitBytes}) => DownloadSettings(
        wifiOnly: wifiOnly ?? this.wifiOnly,
        limitBytes: limitBytes != null ? limitBytes() : this.limitBytes,
      );

  Map<String, dynamic> toJson() => {
        'wifiOnly': wifiOnly,
        'limitBytes': limitBytes,
      };

  factory DownloadSettings.fromJson(Map<String, dynamic> json) => DownloadSettings(
        wifiOnly: json['wifiOnly'] as bool? ?? true,
        limitBytes: json['limitBytes'] as int?,
      );
}
