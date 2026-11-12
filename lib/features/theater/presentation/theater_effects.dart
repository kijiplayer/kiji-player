import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../models/track.dart';
import '../../../providers/playback_provider.dart';
import '../../settings/data/settings_store.dart';
import '../data/theater_store.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Qué se tiró.
enum TheaterKind { tomato, rose }

/// Un "lanzamiento" para la animación de la portada (TheaterOverlay, en theater_stage.dart).
@immutable
class TheaterBurst {
  const TheaterBurst(
    this.kind,
    this.seq, {
    this.rain = false,
    this.count = 1,
    this.variant = 0,
    this.booedOff = false,
    this.ovation = false,
  });

  final TheaterKind kind;
  final int seq;

  /// Varios tomates seguidos (lluvia).
  final bool rain;

  /// Tomates seguidos a esta canción (x2, x3…) o rosas seguidas (los aplausos crecen).
  final int count;

  /// Cuál de las versiones de la animación (al azar).
  final int variant;

  /// Con este tomate la canción se va: cae el telón.
  final bool booedOff;

  /// 5 rosas o más: ovación de pie, "¡BRAVO!", confeti y reverencia.
  final bool ovation;
}

final theaterBurstProvider = StateProvider<TheaterBurst?>((ref) => null);

/// Los sonidos cortos (originales, ver tool/make_theater_sounds.py). Suenan encima de la música sin
/// quitarle el audio. Hay varias versiones de cada uno: [pick] elige una al azar.
class TheaterSounds {
  TheaterSounds._();
  static final instance = TheaterSounds._();

  final _players = <String, AudioPlayer>{};

  Future<void> play(String name, {double volume = 0.6}) async {
    try {
      final player = _players[name] ??= AudioPlayer(handleInterruptions: false, handleAudioSessionActivation: false);
      if (player.audioSource == null) await player.setAsset('assets/sounds/$name.wav');
      await player.setVolume(volume.clamp(0.0, 1.0));
      await player.seek(Duration.zero);
      unawaited(player.play());
    } catch (error) {
      debugPrint('=== TEATRO: no sonó $name: ${error.runtimeType} ===');
    }
  }

  /// "splat" → "splat_1", "splat_2" o "splat_3".
  static String pick(String base, {int versions = 3}) => '${base}_${_random.nextInt(versions) + 1}';
}

final _random = Random();

/// Un golpe (o uno largo con la ovación), si la vibración del teatro está prendida.
void _vibrate(WidgetRef ref, {bool long = false}) {
  if (!ref.read(settingsProvider).theaterVibration) return;
  unawaited(long ? HapticFeedback.vibrate() : HapticFeedback.heavyImpact());
}

/// Tira un tomate a la canción que suena: lo cuenta, lo anima (con el contador x2, x3…) y, con el
/// tercero seguido, cae el telón y pasa a la siguiente sin cambiar play/pausa (y deja de
/// recomendarse). Varios seguidos son una lluvia, con abucheo.
final _recentTomatoes = <DateTime>[];

Future<void> throwTomato(BuildContext context, WidgetRef ref, Track track) async {
  final now = DateTime.now();
  _recentTomatoes
    ..removeWhere((t) => now.difference(t) > const Duration(seconds: 2))
    ..add(now);
  final rain = _recentTomatoes.length >= 3;
  final result = ref.read(theaterProvider.notifier).tomato(track);
  final streak = ref.read(theaterProvider).songs[track.id]?.streak ?? 1;
  final booedOff = result == TomatoResult.booedOff;
  final seq = (ref.read(theaterBurstProvider)?.seq ?? 0) + 1;
  ref.read(theaterBurstProvider.notifier).state = TheaterBurst(
    TheaterKind.tomato,
    seq,
    rain: rain,
    count: streak,
    variant: _random.nextInt(4),
    booedOff: booedOff,
  );
  _vibrate(ref);
  unawaited(TheaterSounds.instance.play(TheaterSounds.pick('splat'), volume: 0.55 + _random.nextDouble() * 0.15));
  if (booedOff) {
    unawaited(TheaterSounds.instance.play('boo_2', volume: 0.5));
    unawaited(Future<void>.delayed(const Duration(milliseconds: 250), () => TheaterSounds.instance.play('curtain', volume: 0.55)));
  } else if (rain || streak >= 2) {
    unawaited(TheaterSounds.instance.play(TheaterSounds.pick('boo'), volume: 0.45));
  }
  if (booedOff) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    // Se espera a que el telón termine de cerrarse.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    // Si todavía es la misma, se va del escenario (en pausa queda en pausa: un tomate nunca
    // arranca la música).
    if (ref.read(playbackProvider).track?.id == track.id) await ref.read(playbackProvider.notifier).skipKeepingPause();
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(tx.abucheadaNoVuelveARecomendarse(track.title))));
  }
}

/// Una rosa: reflector, pétalos y aplausos que crecen con cada rosa seguida; con 5 rosas o más,
/// ovación de pie ("¡BRAVO!", confeti y la portada hace una reverencia). Cuenta como "me gusta".
final _recentRoses = <DateTime>[];

void throwRose(WidgetRef ref, Track track) {
  final now = DateTime.now();
  _recentRoses
    ..removeWhere((t) => now.difference(t) > const Duration(seconds: 6))
    ..add(now);
  final streak = _recentRoses.length;
  ref.read(theaterProvider.notifier).rose(track);
  final total = ref.read(theaterProvider).songs[track.id]?.roses ?? 1;
  final ovation = total >= 5;
  final seq = (ref.read(theaterBurstProvider)?.seq ?? 0) + 1;
  ref.read(theaterBurstProvider.notifier).state = TheaterBurst(
    TheaterKind.rose,
    seq,
    count: streak,
    variant: _random.nextInt(2),
    ovation: ovation,
  );
  if (ovation) {
    _vibrate(ref, long: true);
    unawaited(TheaterSounds.instance.play('ovation', volume: 0.7));
  } else {
    // Los aplausos crecen: más gente y más fuerte con cada rosa seguida.
    unawaited(TheaterSounds.instance.play('applause_${streak.clamp(1, 3)}', volume: (0.35 + 0.12 * streak).clamp(0.35, 0.85)));
  }
}

/// 🍅 y 🌹 del reproductor (con "Reacciones de teatro" prendido).
class TheaterButtons extends ConsumerWidget {
  const TheaterButtons({super.key, required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(settingsProvider.select((s) => s.theaterReactions))) return const SizedBox.shrink();
    Widget button(String emoji, String label, VoidCallback onPressed, Key key) => IconButton(
      key: key,
      tooltip: label,
      onPressed: onPressed,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: Text(emoji, style: const TextStyle(fontSize: 22), semanticsLabel: label),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button('🍅', tx.tirarUnTomate, () => throwTomato(context, ref, track), const Key('theater-tomato')),
        button('🌹', tx.tirarUnaRosa, () => throwRose(ref, track), const Key('theater-rose')),
      ],
    );
  }
}

/// Reconoce una sacudida fuerte y clara, no el movimiento del bolsillo o de caminar: hacen falta
/// [peaks] golpes por encima de [threshold] (m/s², sin la gravedad) en menos de [window], cada
/// uno separado del anterior (la fuerza tiene que bajar de [release] entre golpe y golpe). Después
/// de una sacudida, nada durante [cooldown].
class ShakeDetector {
  ShakeDetector({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  static const threshold = 25.0;
  static const release = 10.0;
  static const peaks = 3;
  static const window = Duration(milliseconds: 900);
  static const cooldown = Duration(milliseconds: 1500);

  final _peaks = <DateTime>[];
  bool _above = false;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  /// Una lectura del acelerómetro. true si con ella se completó una sacudida.
  bool add(double x, double y, double z) {
    final force = sqrt(x * x + y * y + z * z);
    if (force < release) {
      _above = false;
      return false;
    }
    if (_above || force < threshold) return false;
    _above = true;
    final now = _clock();
    if (now.difference(_last) < cooldown) return false;
    _peaks
      ..removeWhere((t) => now.difference(t) > window)
      ..add(now);
    if (_peaks.length < peaks) return false;
    _peaks.clear();
    _last = now;
    return true;
  }

  void reset() {
    _peaks.clear();
    _above = false;
  }
}

/// Sacudir el teléfono tira un tomate (Android e iOS). El sensor solo está prendido con Kiji a la
/// vista, en la pantalla del reproductor y con la música sonando; en cualquier otro caso se apaga
/// (tampoco gasta batería).
class TheaterShake extends ConsumerStatefulWidget {
  const TheaterShake({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TheaterShake> createState() => _TheaterShakeState();
}

class _TheaterShakeState extends ConsumerState<TheaterShake> with WidgetsBindingObserver {
  StreamSubscription<UserAccelerometerEvent>? _sub;
  final _detector = ShakeDetector();
  bool _resumed = true;

  bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _resumed = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _update();
  }

  /// ¿Corresponde escuchar el sensor ahora?
  bool get _wanted {
    if (!_supported || !mounted || !_resumed) return false;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    return ref.read(settingsProvider).theaterReactions && ref.read(playbackProvider).isPlaying;
  }

  void _update() {
    final wanted = _wanted;
    if (wanted && _sub == null) {
      try {
        _detector.reset();
        _sub = userAccelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
          _onEvent,
          onError: (Object e) {
            debugPrint('=== TEATRO: sin sensor de movimiento: ${e.runtimeType} ===');
          },
        );
      } catch (error) {
        debugPrint('=== TEATRO: sin sensor de movimiento: ${error.runtimeType} ===');
      }
    } else if (!wanted && _sub != null) {
      unawaited(_sub!.cancel());
      _sub = null;
    }
  }

  void _onEvent(UserAccelerometerEvent e) {
    if (!_detector.add(e.x, e.y, e.z)) return;
    // Por las dudas: lo mismo que para prender el sensor, en el momento de la sacudida.
    if (!_wanted) return;
    final track = ref.read(playbackProvider).track;
    if (track != null) unawaited(throwTomato(context, ref, track));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Se vuelve a decidir al cambiar play/pausa, el ajuste o la pantalla de arriba.
    ref.listen(playbackProvider.select((s) => s.isPlaying), (_, _) => _update());
    ref.listen(settingsProvider.select((s) => s.theaterReactions), (_, _) => _update());
    ModalRoute.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
    return widget.child;
  }
}
