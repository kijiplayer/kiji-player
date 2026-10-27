import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/kiji_tokens.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Botón PLAY de 84 px con degradado y un anillo de luz que "respira"
/// mientras suena. Con "reducir animaciones" el anillo queda quieto.
class BreathingPlayButton extends StatefulWidget {
  const BreathingPlayButton({
    super.key,
    required this.isPlaying,
    required this.onPressed,
    this.reduceMotion = false,
    this.size = KijiSizes.playButton,
  });

  final bool isPlaying;
  final VoidCallback onPressed;
  final bool reduceMotion;
  final double size;

  @override
  State<BreathingPlayButton> createState() => _BreathingPlayButtonState();
}

class _BreathingPlayButtonState extends State<BreathingPlayButton> with TickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(vsync: this, duration: KijiMotion.breath);

  /// Play que se transforma en pausa.
  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: KijiMotion.normal,
    value: widget.isPlaying ? 1 : 0,
  );

  /// Rebote al tocar.
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    value: 1,
  );

  void _tap() {
    if (!widget.reduceMotion) {
      HapticFeedback.lightImpact();
      _bounce.forward(from: 0);
    }
    widget.onPressed();
  }

  bool get _animate => breathingShouldAnimate(isPlaying: widget.isPlaying, reduceMotion: widget.reduceMotion);

  @override
  void initState() {
    super.initState();
    if (_animate) _breath.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(BreathingPlayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      final target = widget.isPlaying ? 1.0 : 0.0;
      widget.reduceMotion ? _morph.value = target : _morph.animateTo(target, curve: Curves.easeInOut);
    }
    if (_animate && !_breath.isAnimating) {
      _breath.repeat(reverse: true);
    } else if (!_animate && _breath.isAnimating) {
      _breath.stop();
      _breath.value = 0;
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _morph.dispose();
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    // Capa propia: el anillo que respira no obliga a redibujar el resto del reproductor.
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: size * 1.35,
        child: AnimatedBuilder(
          animation: _breath,
          builder: (context, child) {
            // Curva suave de "respiración" (0 → 1 → 0).
            final t = Curves.easeInOut.transform(_breath.value);
            final ringScale = 1.0 + 0.12 * t;
            final ringOpacity = widget.isPlaying ? 0.35 + 0.35 * (1 - t) : 0.18;
            final glowOpacity = (0.25 + 0.2 * t) / 0.45;
            return Stack(
              alignment: Alignment.center,
              children: [
                // El brillo y el anillo se dibujan una sola vez (capas propias) y solo se escalan y
                // atenúan: recalcular la sombra desenfocada en cada cuadro costaba tiempo de dibujo.
                Transform.scale(
                  scale: ringScale,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: glowOpacity.clamp(0.0, 1.0),
                        child: _RingGlow(size: size * 1.18),
                      ),
                      Opacity(
                        opacity: (ringOpacity / 0.7).clamp(0.0, 1.0),
                        child: _Ring(size: size * 1.18),
                      ),
                    ],
                  ),
                ),
                child!,
              ],
            );
          },
          child: Semantics(
            button: true,
            label: widget.isPlaying ? tx.pausar : tx.reproducir,
            child: Tooltip(
              message: widget.isPlaying ? tx.pausar : tx.reproducir,
              excludeFromSemantics: true,
              child: Material(
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                color: Colors.transparent,
                child: Ink(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: KijiColors.accentGradientDiagonal),
                  child: InkWell(
                    onTap: _tap,
                    child: ScaleTransition(
                      // Se achica un poco y vuelve con rebote.
                      scale: _bounce.drive(
                        TweenSequence([
                          TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.82), weight: 30),
                          TweenSequenceItem(
                            tween: Tween(begin: 0.82, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
                            weight: 70,
                          ),
                        ]),
                      ),
                      child: Center(
                        child: AnimatedIcon(
                          icon: AnimatedIcons.play_pause,
                          progress: _morph,
                          color: KijiColors.onAccent,
                          size: size * 0.48,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Brillo violeta detrás del anillo (con la intensidad máxima; se atenúa con Opacity).
class _RingGlow extends StatelessWidget {
  const _RingGlow({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: KijiColors.violet.withValues(alpha: 0.45), blurRadius: 30, spreadRadius: 1)],
        ),
      ),
    ),
  );
}

/// El anillo cian de 2 px (con la opacidad máxima; se atenúa con Opacity).
class _Ring extends StatelessWidget {
  const _Ring({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(width: 2, color: KijiColors.cyan.withValues(alpha: 0.7)),
        ),
      ),
    ),
  );
}

/// El anillo solo se anima mientras suena y si no se pidió reducir
/// animaciones.
bool breathingShouldAnimate({required bool isPlaying, required bool reduceMotion}) => isPlaying && !reduceMotion;
