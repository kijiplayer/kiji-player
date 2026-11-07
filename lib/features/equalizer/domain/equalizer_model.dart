// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivos de referencia: ui/screens/equalizer/EqScreen.kt, EQViewModel.kt y
// dsp-core/.../models/SavedEQProfile.kt (perfiles guardados y uno activo). La
// curva por puntos, el perfil por dispositivo de salida y el resto de "Sonido" son propios de Kiji.

import 'dart:math' as math;

import 'package:kiji_player/l10n/l10n.dart';

import 'sound_engine.dart';

export 'sound_engine.dart';

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

/// Un preset: la curva en dB sobre 10 frecuencias. Se adapta a las bandas reales de cada
/// dispositivo con [gainAt] (en la PC son esas 10; en Android, las que dé el teléfono).
class EqPreset {
  const EqPreset(this.id, this.label, this.points);
  final String id;
  final String label;
  final Map<int, double> points;
}

/// Las 10 bandas de la PC (y las frecuencias de los presets).
const tenBands = [31.0, 62.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0];

Map<int, double> _curve(List<double> db) => {for (var i = 0; i < tenBands.length; i++) tenBands[i].round(): db[i]};

final eqPresets = <EqPreset>[
  EqPreset('flat', tx.eqNormal, _curve([0, 0, 0, 0, 0, 0, 0, 0, 0, 0])),
  EqPreset('bass', tx.eqBajos, _curve([6, 6, 5, 3, 1, 0, 0, 0, 0, 0])),
  EqPreset('vocal', tx.eqVoz, _curve([-3, -3, -2, -1, 1, 3, 4, 3, 1, 0])),
  EqPreset('rock', 'Rock', _curve([5, 4, 3, 1, -1, -1, 1, 3, 4, 5])), // l10n-ignore
  EqPreset('electronic', tx.electronica, _curve([5, 5, 3, 0, -1, 1, 0, 2, 4, 5])),
  EqPreset('acoustic', tx.eqAcustico, _curve([3, 3, 2, 1, 1, 1, 2, 2, 3, 2])),
  EqPreset('night', tx.eqNoche, _curve([-4, -3, -2, 0, 1, 1, 0, -1, -3, -4])),
];

/// Presets que tuvo Kiji antes (5 frecuencias): un perfil guardado con uno de estos pasa a
/// Personalizado con la misma curva, para que nada suene distinto de golpe.
const _legacyPresets = <String, List<double>>{
  'treble': [0, 0, 0, 3, 6],
  'pop': [-1, 2, 4, 2, -1],
  'classical': [4, 2, -1, 2, 4],
};
const _legacyBands = [60, 230, 910, 3600, 14000];

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

Map<int, double> _readPoints(Object? raw) {
  final points = <int, double>{};
  if (raw is Map) {
    for (final e in raw.entries) {
      final hz = int.tryParse('${e.key}');
      final db = e.value;
      if (hz != null && hz > 0 && db is num) points[hz] = db.toDouble().clamp(-15, 15);
    }
  }
  return points;
}

Map<String, double> _writePoints(Map<int, double> points) => {for (final e in points.entries) '${e.key}': e.value};

/// Un preset propio, guardado por el usuario.
class EqUserPreset {
  const EqUserPreset({required this.id, required this.name, required this.points});

  final String id;
  final String name;
  final Map<int, double> points;

  String get profileId => '${EqProfile.userPrefix}$id';

  EqUserPreset copyWith({String? name}) => EqUserPreset(id: id, name: name ?? this.name, points: points);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'points': _writePoints(points)};

  static EqUserPreset? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], name = json['name'];
    final points = _readPoints(json['points']);
    if (id is! String || id.isEmpty || name is! String || name.trim().isEmpty || points.isEmpty) return null;
    return EqUserPreset(id: id, name: name.trim(), points: points);
  }
}

/// Un perfil: un preset de fábrica, uno propio (`user:<id>`, con su curva y su nombre copiados)
/// o una curva hecha a mano (`presetId == custom`).
class EqProfile {
  const EqProfile({this.presetId = 'flat', this.points = const {}, this.name});

  static const custom = 'custom';
  static const userPrefix = 'user:';

  final String presetId;

  /// Para [custom] y los propios: dB por frecuencia (Hz).
  final Map<int, double> points;

  /// Nombre del preset propio.
  final String? name;

  bool get isUser => presetId.startsWith(userPrefix);

  Map<int, double> get curve =>
      presetId == custom || isUser ? points : (presetById(presetId)?.points ?? const {});

  String get label => presetId == custom
      ? tx.personalizado
      : isUser
      ? (name ?? tx.personalizado)
      : (presetById(presetId)?.label ?? tx.eqNormal);

  /// Ganancias para las bandas reales del dispositivo, dentro de su rango.
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
    if (presetId == custom || isUser) 'points': _writePoints(points),
    if (isUser && name != null) 'name': name,
  };

  factory EqProfile.fromJson(Object? json) {
    if (json is! Map) return const EqProfile();
    final preset = json['preset'];
    final points = _readPoints(json['points']);
    if (preset == custom && points.isNotEmpty) return EqProfile(presetId: custom, points: points);
    if (preset is String && preset.startsWith(userPrefix) && points.isNotEmpty) {
      final name = json['name'];
      return EqProfile(presetId: preset, points: points, name: name is String ? name : null);
    }
    final legacy = _legacyPresets[preset];
    if (legacy != null) {
      return EqProfile(presetId: custom, points: {for (var i = 0; i < legacy.length; i++) _legacyBands[i]: legacy[i]});
    }
    if (preset is String && presetById(preset) != null) return EqProfile(presetId: preset);
    return const EqProfile();
  }
}

/// Velocidad (0.5x–2x) y tono (−6 a +6 semitonos).
const minSpeed = 0.5, maxSpeed = 2.0, maxSemitones = 6;

/// Ajustes de "Sonido": ecualizador, bajos, reverb, velocidad y tono. Todo pasa por un solo
/// interruptor, "Efectos", apagado de fábrica (Cero Sorpresas): apagado, el sonido sale tal cual.
class EqualizerSettings {
  const EqualizerSettings({
    this.enabled = false,
    this.perDevice = false,
    this.general = const EqProfile(),
    this.byOutput = const {},
    this.userPresets = const [],
    this.bass = 0,
    this.reverb = ReverbMode.off,
    this.keepSpeedPitch = false,
    this.speed = 1,
    this.semitones = 0,
  });

  /// El interruptor "Efectos".
  final bool enabled;

  /// Un perfil distinto para parlante, auriculares y Bluetooth.
  final bool perDevice;
  final EqProfile general;
  final Map<AudioOutputKind, EqProfile> byOutput;
  final List<EqUserPreset> userPresets;

  /// Refuerzo de bajos, de 0 (nada) a 1 (todo).
  final double bass;
  final ReverbMode reverb;

  /// Si es false, la velocidad y el tono vuelven a lo normal con cada canción (y no se guardan).
  final bool keepSpeedPitch;
  final double speed;
  final int semitones;

  /// El perfil que suena con la salida [output].
  EqProfile profileFor(AudioOutputKind output) => perDevice ? (byOutput[output] ?? const EqProfile()) : general;

  /// El tono como factor de frecuencia (1 = normal).
  double get pitch => math.pow(2, semitones / 12).toDouble();

  bool get speedPitchNormal => speed == 1 && semitones == 0;

  /// Lo que se le pide al reproductor: con "Efectos" apagado, siempre lo normal.
  ({double speed, double pitch}) get playbackRate => enabled ? (speed: speed, pitch: pitch) : (speed: 1, pitch: 1);

  /// Cambia el perfil que se está editando: el de [output] si hay perfil por
  /// dispositivo, o el general.
  EqualizerSettings withProfile(AudioOutputKind output, EqProfile profile) =>
      perDevice ? copyWith(byOutput: {...byOutput, output: profile}) : copyWith(general: profile);

  /// Aplica [change] a todos los perfiles (al renombrar o borrar un preset propio).
  EqualizerSettings mapProfiles(EqProfile Function(EqProfile profile) change) => copyWith(
    general: change(general),
    byOutput: {for (final e in byOutput.entries) e.key: change(e.value)},
  );

  EqualizerSettings copyWith({
    bool? enabled,
    bool? perDevice,
    EqProfile? general,
    Map<AudioOutputKind, EqProfile>? byOutput,
    List<EqUserPreset>? userPresets,
    double? bass,
    ReverbMode? reverb,
    bool? keepSpeedPitch,
    double? speed,
    int? semitones,
  }) => EqualizerSettings(
    enabled: enabled ?? this.enabled,
    perDevice: perDevice ?? this.perDevice,
    general: general ?? this.general,
    byOutput: byOutput ?? this.byOutput,
    userPresets: userPresets ?? this.userPresets,
    bass: bass ?? this.bass,
    reverb: reverb ?? this.reverb,
    keepSpeedPitch: keepSpeedPitch ?? this.keepSpeedPitch,
    speed: speed ?? this.speed,
    semitones: semitones ?? this.semitones,
  );

  Map<String, dynamic> toJson() => {
    'version': 2,
    'enabled': enabled,
    'perDevice': perDevice,
    'general': general.toJson(),
    'byOutput': {for (final e in byOutput.entries) e.key.name: e.value.toJson()},
    'userPresets': [for (final preset in userPresets) preset.toJson()],
    'bass': bass,
    'reverb': reverb.name,
    'keepSpeedPitch': keepSpeedPitch,
    // Solo si se eligió mantenerlos entre canciones.
    if (keepSpeedPitch) 'speed': speed,
    if (keepSpeedPitch) 'semitones': semitones,
  };

  factory EqualizerSettings.fromJson(Map<String, dynamic> json) {
    final byOutput = <AudioOutputKind, EqProfile>{};

    final raw = json['byOutput'];
    if (raw is Map) {
      for (final kind in AudioOutputKind.values) {
        if (raw[kind.name] != null) byOutput[kind] = EqProfile.fromJson(raw[kind.name]);
      }
    }
    final presets = json['userPresets'];
    final keep = json['keepSpeedPitch'] == true;
    final speed = json['speed'], semitones = json['semitones'], bass = json['bass'];
    return EqualizerSettings(
      enabled: json['enabled'] == true,
      perDevice: json['perDevice'] == true,
      general: EqProfile.fromJson(json['general']),
      byOutput: byOutput,
      userPresets: [
        if (presets is List)
          for (final p in presets) ?EqUserPreset.fromJson(p),
      ],
      bass: bass is num ? bass.toDouble().clamp(0, 1) : 0,
      reverb: ReverbMode.values.where((m) => m.name == json['reverb']).firstOrNull ?? ReverbMode.off,
      keepSpeedPitch: keep,
      speed: keep && speed is num ? speed.toDouble().clamp(minSpeed, maxSpeed) : 1,
      semitones: keep && semitones is num ? semitones.round().clamp(-maxSemitones, maxSemitones) : 0,
    );
  }
}
