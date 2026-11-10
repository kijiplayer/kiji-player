import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../models/track.dart';
import '../../../providers/appearance_provider.dart';
import '../../../providers/playback_provider.dart';
import '../../../theme/kiji_tokens.dart';
import '../../settings/data/settings_store.dart';
import '../data/theater_store.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Qué se tiró.
enum TheaterKind { tomato, rose }

/// Un "lanzamiento" para la animación de la portada. [rain]: varios seguidos (lluvia).
@immutable
class TheaterBurst {
  const TheaterBurst(this.kind, this.seq, {this.rain = false});

  final TheaterKind kind;
  final int seq;
  final bool rain;
}

final theaterBurstProvider = StateProvider<TheaterBurst?>((ref) => null);

/// Los sonidos cortos (originales, ver tool/make_theater_sounds.py). Suenan encima de la música sin
/// quitarle el audio.
class TheaterSounds {
  TheaterSounds._();
  static final instance = TheaterSounds._();

  final _players = <String, AudioPlayer>{};

  Future<void> play(String name, {double volume = 0.6}) async {
    try {
      final player = _players[name] ??= AudioPlayer(handleInterruptions: false, handleAudioSessionActivation: false);
      if (player.audioSource == null) await player.setAsset('assets/sounds/$name.wav');
      await player.setVolume(volume);
      await player.seek(Duration.zero);
      unawaited(player.play());
    } catch (error) {
      debugPrint('=== TEATRO: no sonó $name: ${error.runtimeType} ===');
    }
  }
}

/// Tira un tomate a la canción que suena: lo cuenta, lo anima y, con el tercero, pasa a la
/// siguiente (y deja de recomendarse). Varios seguidos son una lluvia, con abucheo.
final _recentTomatoes = <DateTime>[];

Future<void> throwTomato(BuildContext context, WidgetRef ref, Track track) async {
  final now = DateTime.now();
  _recentTomatoes
    ..removeWhere((t) => now.difference(t) > const Duration(seconds: 2))
    ..add(now);
  final rain = _recentTomatoes.length >= 3;
  final result = ref.read(theaterProvider.notifier).tomato(track);
  final seq = (ref.read(theaterBurstProvider)?.seq ?? 0) + 1;
  ref.read(theaterBurstProvider.notifier).state = TheaterBurst(TheaterKind.tomato, seq, rain: rain);
  unawaited(TheaterSounds.instance.play('splat'));
  if (rain || result == TomatoResult.booedOff) unawaited(TheaterSounds.instance.play('boo', volume: 0.45));
  if (result == TomatoResult.booedOff) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    // Si todavía suena la misma, se va del escenario.
    if (ref.read(playbackProvider).track?.id == track.id) await ref.read(playbackProvider.notifier).nextTrack();
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(tx.abucheadaNoVuelveARecomendarse(track.title))));
  }
}

/// Una rosa: aplausos y "me gusta".
void throwRose(WidgetRef ref, Track track) {
  ref.read(theaterProvider.notifier).rose(track);
  final seq = (ref.read(theaterBurstProvider)?.seq ?? 0) + 1;
  ref.read(theaterBurstProvider.notifier).state = TheaterBurst(TheaterKind.rose, seq);
  unawaited(TheaterSounds.instance.play('applause', volume: 0.5));
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

/// Sacudir el teléfono tira un tomate (Android e iOS; con el reproductor a la vista).
class TheaterShake extends ConsumerStatefulWidget {
  const TheaterShake({super.key, required this.child});

  final Widget child;

  /// Fuerza de la sacudida (m/s², sin la gravedad).
  static const threshold = 18.0;

  @override
  ConsumerState<TheaterShake> createState() => _TheaterShakeState();
}

class _TheaterShakeState extends ConsumerState<TheaterShake> {
  StreamSubscription<UserAccelerometerEvent>? _sub;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    if (!_supported) return;
    try {
      _sub = userAccelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
        _onEvent,
        onError: (Object e) {
          debugPrint('=== TEATRO: sin sensor de movimiento: ${e.runtimeType} ===');
        },
      );
    } catch (error) {
      debugPrint('=== TEATRO: sin sensor de movimiento: ${error.runtimeType} ===');
    }
  }

  void _onEvent(UserAccelerometerEvent e) {
    if (sqrt(e.x * e.x + e.y * e.y + e.z * e.z) < TheaterShake.threshold) return;
    final now = DateTime.now();
    if (now.difference(_last) < const Duration(milliseconds: 700)) return;
    _last = now;
    if (!mounted || !ref.read(settingsProvider).theaterReactions) return;
    final track = ref.read(playbackProvider).track;
    if (track != null) unawaited(throwTomato(context, ref, track));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _Flyer {
  _Flyer(this.kind, this.start, this.target, this.born, this.spin);
  final TheaterKind kind;
  final Offset start;
  final Offset target;
  final Duration born;
  final double spin;
}

class _Stain {
  _Stain(this.at, this.born, this.seed);
  final Offset at;
  final Duration born;
  final int seed;
}

/// La animación sobre la portada: tomates que vuelan y se estrellan (manchas que escurren y la
/// portada que tiembla) o rosas que suben. Con "reducir animaciones", nada (queda el sonido).
class TheaterOverlay extends ConsumerStatefulWidget {
  const TheaterOverlay({super.key, required this.child, required this.trackId});

  final Widget child;

  /// Al cambiar de canción, las manchas se limpian.
  final String trackId;

  @override
  ConsumerState<TheaterOverlay> createState() => _TheaterOverlayState();
}

class _TheaterOverlayState extends ConsumerState<TheaterOverlay> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  Duration _now = Duration.zero;
  Duration _shakeUntil = Duration.zero;
  final _flyers = <_Flyer>[];
  final _stains = <_Stain>[];
  final _random = Random();

  static const flight = Duration(milliseconds: 420);
  static const stainLife = Duration(seconds: 6);

  void _tick(Duration elapsed) {
    _now = elapsed;
    _flyers.removeWhere((f) {
      if (_now - f.born < flight) return false;
      if (f.kind == TheaterKind.tomato) {
        _stains.add(_Stain(f.target, _now, _random.nextInt(1 << 20)));
        _shakeUntil = _now + const Duration(milliseconds: 260);
      }
      return true;
    });
    _stains.removeWhere((s) => _now - s.born > stainLife);
    if (_flyers.isEmpty && _stains.isEmpty && _now > _shakeUntil) _ticker.stop();
    setState(() {});
  }

  void _launch(TheaterBurst burst) {
    if (reduceMotion(context, ref)) return;
    if (!_ticker.isActive) {
      _ticker.start();
      _now = Duration.zero;
    }
    final count = burst.kind == TheaterKind.rose ? 9 : (burst.rain ? 7 : 1);
    for (var i = 0; i < count; i++) {
      final born = _now + Duration(milliseconds: i * (burst.kind == TheaterKind.rose ? 70 : 90));
      final target = Offset(0.2 + _random.nextDouble() * 0.6, 0.2 + _random.nextDouble() * 0.55);
      final start = burst.kind == TheaterKind.rose
          ? Offset(0.1 + _random.nextDouble() * 0.8, 1.15)
          : Offset(0.5 + (_random.nextDouble() - 0.5) * 0.6, 1.4);
      _flyers.add(_Flyer(burst.kind, start, target, born, (_random.nextDouble() - 0.5) * 6));
    }
  }

  @override
  void didUpdateWidget(TheaterOverlay old) {
    super.didUpdateWidget(old);
    if (old.trackId != widget.trackId) _stains.clear();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TheaterBurst?>(theaterBurstProvider, (_, burst) {
      if (burst != null) _launch(burst);
    });
    final shaking = _now < _shakeUntil;
    final shake = shaking ? Offset(sin(_now.inMilliseconds / 18) * 5, cos(_now.inMilliseconds / 23) * 3) : Offset.zero;
    return Transform.translate(
      offset: shake,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (_flyers.isNotEmpty || _stains.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _TheaterPainter(
                    flyers: List.of(_flyers),
                    stains: List.of(_stains),
                    now: _now,
                    tomato: const Color(0xFFD7262E),
                    rose: KijiColors.like,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TheaterPainter extends CustomPainter {
  _TheaterPainter({
    required this.flyers,
    required this.stains,
    required this.now,
    required this.tomato,
    required this.rose,
  });

  final List<_Flyer> flyers;
  final List<_Stain> stains;
  final Duration now;
  final Color tomato;
  final Color rose;

  @override
  void paint(Canvas canvas, Size size) {
    Offset at(Offset rel) => Offset(rel.dx * size.width, rel.dy * size.height);
    final unit = size.shortestSide;

    // Manchas: un borrón irregular con gotas que escurren hacia abajo y se van apagando.
    for (final s in stains) {
      final age = (now - s.born).inMilliseconds / _TheaterOverlayState.stainLife.inMilliseconds;
      final fade = (1 - age).clamp(0.0, 1.0);
      final paint = Paint()..color = tomato.withValues(alpha: 0.85 * fade);
      final random = Random(s.seed);
      final center = at(s.at);
      final r = unit * 0.07;
      canvas.drawCircle(center, r, paint);
      for (var i = 0; i < 7; i++) {
        final a = random.nextDouble() * pi * 2;
        final d = r * (0.6 + random.nextDouble() * 0.9);
        canvas.drawCircle(center + Offset(cos(a), sin(a)) * d, r * (0.25 + random.nextDouble() * 0.35), paint);
      }
      // Escurre: gotas que se alargan con el tiempo.
      final grow = Curves.easeOut.transform((age * 2.5).clamp(0.0, 1.0));
      for (var i = 0; i < 3; i++) {
        final x = center.dx + (random.nextDouble() - 0.5) * r * 1.4;
        final len = unit * (0.05 + random.nextDouble() * 0.12) * grow;
        final w = r * (0.18 + random.nextDouble() * 0.12);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x - w / 2, center.dy, w, r * 0.6 + len), Radius.circular(w / 2)),
          paint,
        );
        canvas.drawCircle(Offset(x, center.dy + r * 0.6 + len), w * 0.75, paint);
      }
    }

    // Lo que vuela.
    for (final f in flyers) {
      final t = ((now - f.born).inMilliseconds / _TheaterOverlayState.flight.inMilliseconds);
      if (t < 0) continue;
      final k = Curves.easeOutQuad.transform(t.clamp(0.0, 1.0));
      if (f.kind == TheaterKind.tomato) {
        // Arco: sube y cae sobre la portada, achicándose (se aleja).
        final pos = Offset.lerp(at(f.start), at(f.target), k)! - Offset(0, sin(k * pi) * unit * 0.25);
        final r = unit * (0.09 - 0.035 * k);
        canvas.drawCircle(pos, r, Paint()..color = tomato);
        canvas.drawCircle(
          pos - Offset(r * 0.35, r * 0.35),
          r * 0.3,
          Paint()..color = Colors.white.withValues(alpha: 0.25),
        );
        canvas.drawCircle(pos - Offset(0, r * 0.95), r * 0.28, Paint()..color = const Color(0xFF2E9B3A));
      } else {
        // Rosas que suben girando y se desvanecen al final.
        final pos = Offset.lerp(
          at(f.start),
          at(Offset(f.target.dx, -0.1)),
          Curves.easeOut.transform(t.clamp(0.0, 1.0) * 0.7 + 0.0),
        )!;
        final alpha = (1 - (t - 0.6) / 0.4).clamp(0.0, 1.0);
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(f.spin * t);
        final r = unit * 0.045;
        final petal = Paint()..color = rose.withValues(alpha: alpha);
        for (var i = 0; i < 5; i++) {
          final a = i * 2 * pi / 5;
          canvas.drawCircle(Offset(cos(a), sin(a)) * r * 0.6, r * 0.6, petal);
        }
        canvas.drawCircle(
          Offset.zero,
          r * 0.45,
          Paint()..color = Color.lerp(rose, Colors.black, 0.25)!.withValues(alpha: alpha),
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_TheaterPainter old) => true;
}
