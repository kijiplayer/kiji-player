// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivos de referencia: ui/screens/equalizer/EqScreen.kt, EQViewModel.kt y
// dsp-core/.../models/SavedEQProfile.kt (perfiles guardados y uno activo). La
// curva por puntos y el perfil por dispositivo de salida son propios de Kiji.

import 'dart:math' as math;

import 'package:kiji_player/l10n/l10n.dart';

/// Por dónde sale el sonido. Cada salida puede tener su propio perfil.
enum AudioOutputKind {
  speaker,
  headphones,
  bluetooth;

  String get label => switch (this) {
    AudioOutputKind.speaker => tx.parlante,
    AudioOutputKind.headphones => tx.auricularesConCable,
    AudioOutputKind.bluetooth => 'Bluetooth', // l10n-ignore
  };
}

/// Un preset: la curva en dB sobre las 5 frecuencias típicas de Android.
/// Se adapta a las bandas reales de cada teléfono con [gainAt].
class EqPreset {
  const EqPreset(this.id, this.label, this.points);
  final String id;
  final String label;
  final Map<int, double> points;
}

const _f = [60, 230, 910, 3600, 14000];

Map<int, double> _curve(List<double> db) => {for (var i = 0; i < _f.length; i++) _f[i]: db[i]};

final eqPresets = <EqPreset>[
  EqPreset('flat', tx.plano, _curve([0, 0, 0, 0, 0])),
  EqPreset('bass', tx.masGraves, _curve([6, 4, 0, 0, 0])),
  EqPreset('treble', tx.masAgudos, _curve([0, 0, 0, 3, 6])),
  EqPreset('vocal', tx.voces, _curve([-2, -1, 3, 4, 1])),
  EqPreset('rock', 'Rock', _curve([5, 3, -1, 3, 5])), // l10n-ignore
  EqPreset('pop', 'Pop', _curve([-1, 2, 4, 2, -1])), // l10n-ignore
  EqPreset('electronic', tx.electronica, _curve([5, 3, 0, 2, 4])),
  EqPreset('acoustic', tx.acustica, _curve([3, 1, 1, 2, 3])),
  EqPreset('classical', tx.clasica, _curve([4, 2, -1, 2, 4])),
  EqPreset('night', tx.nocheSuave, _curve([-3, -1, 1, 0, -3])),
];

EqPreset? presetById(String? id) {
  for (final preset in eqPresets) {
    if (preset.id == id) return preset;
  }
  return null;
}

/// Ganancia (dB) de una curva en [hz]: interpolación lineal sobre la escala
/// logarítmica de frecuencias (como se oye). Fuera de los extremos, se queda
/// con el valor del extremo.
double gainAt(Map<int, double> points, double hz) {
  if (points.isEmpty) return 0;
  final keys = points.keys.toList()..sort();
  if (hz <= keys.first) return points[keys.first]!;
  if (hz >= keys.last) return points[keys.last]!;
  for (var i = 0; i < keys.length - 1; i++) {
    final a = keys[i], b = keys[i + 1];
    if (hz <= b) {
      final t = (math.log(hz) - math.log(a)) / (math.log(b) - math.log(a));
      return points[a]! + (points[b]! - points[a]!) * t;
    }
  }
  return points[keys.last]!;
}

/// Un perfil: un preset o una curva hecha a mano (`presetId == custom`).
class EqProfile {
  const EqProfile({this.presetId = 'flat', this.points = const {}});

  static const custom = 'custom';

  final String presetId;

  /// Solo para [custom]: dB por frecuencia (Hz) de cada banda movida.
  final Map<int, double> points;

  Map<int, double> get curve => presetId == custom ? points : (presetById(presetId)?.points ?? const {});

  String get label => presetId == custom ? tx.personalizado : (presetById(presetId)?.label ?? tx.plano);

  /// Ganancias para las bandas reales del teléfono, dentro de su rango.
  List<double> gainsFor(List<double> centers, {double min = -15, double max = 15}) => [
    for (final hz in centers) double.parse(gainAt(curve, hz).clamp(min, max).toStringAsFixed(1)),
  ];

  /// El perfil con la banda [index] en [db] y las demás como suenan ahora.
  EqProfile withBand(List<double> centers, int index, double db) {
    final gains = gainsFor(centers);
    gains[index] = db;
    return EqProfile(presetId: custom, points: {for (var i = 0; i < centers.length; i++) centers[i].round(): gains[i]});
  }

  Map<String, dynamic> toJson() => {
    'preset': presetId,
    if (presetId == custom) 'points': {for (final e in points.entries) '${e.key}': e.value},
  };

  factory EqProfile.fromJson(Object? json) {
    if (json is! Map) return const EqProfile();
    final preset = json['preset'];
    final rawPoints = json['points'];
    final points = <int, double>{};
    if (rawPoints is Map) {
      for (final e in rawPoints.entries) {
        final hz = int.tryParse('${e.key}');
        final db = e.value;
        if (hz != null && hz > 0 && db is num) points[hz] = db.toDouble().clamp(-15, 15);
      }
    }
    if (preset == custom && points.isNotEmpty) return EqProfile(presetId: custom, points: points);
    if (preset is String && presetById(preset) != null) return EqProfile(presetId: preset);
    return const EqProfile();
  }
}

/// Ajustes del ecualizador. Apagado de fábrica (Cero Sorpresas).
class EqualizerSettings {
  const EqualizerSettings({
    this.enabled = false,
    this.perDevice = false,
    this.general = const EqProfile(),
    this.byOutput = const {},
  });

  final bool enabled;

  /// Un perfil distinto para parlante, auriculares y Bluetooth.
  final bool perDevice;
  final EqProfile general;
  final Map<AudioOutputKind, EqProfile> byOutput;

  /// El perfil que suena con la salida [output].
  EqProfile profileFor(AudioOutputKind output) => perDevice ? (byOutput[output] ?? const EqProfile()) : general;

  /// Cambia el perfil que se está editando: el de [output] si hay perfil por
  /// dispositivo, o el general.
  EqualizerSettings withProfile(AudioOutputKind output, EqProfile profile) =>
      perDevice ? copyWith(byOutput: {...byOutput, output: profile}) : copyWith(general: profile);

  EqualizerSettings copyWith({
    bool? enabled,
    bool? perDevice,
    EqProfile? general,
    Map<AudioOutputKind, EqProfile>? byOutput,
  }) => EqualizerSettings(
    enabled: enabled ?? this.enabled,
    perDevice: perDevice ?? this.perDevice,
    general: general ?? this.general,
    byOutput: byOutput ?? this.byOutput,
  );

  Map<String, dynamic> toJson() => {
    'version': 1,
    'enabled': enabled,
    'perDevice': perDevice,
    'general': general.toJson(),
    'byOutput': {for (final e in byOutput.entries) e.key.name: e.value.toJson()},
  };

  factory EqualizerSettings.fromJson(Map<String, dynamic> json) {
    final byOutput = <AudioOutputKind, EqProfile>{};

    final raw = json['byOutput'];
    if (raw is Map) {
      for (final kind in AudioOutputKind.values) {
        if (raw[kind.name] != null) byOutput[kind] = EqProfile.fromJson(raw[kind.name]);
      }
    }
    return EqualizerSettings(
      enabled: json['enabled'] == true,
      perDevice: json['perDevice'] == true,
      general: EqProfile.fromJson(json['general']),
      byOutput: byOutput,
    );
  }
}
