import 'package:flutter/material.dart';

import '../../theme/kiji_tokens.dart';

/// Botón PLAY de 84 px con degradado y un anillo de luz que "respira"
/// mientras suena (§7). Con "reducir animaciones" el anillo queda quieto.
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

class _BreathingPlayButtonState extends State<BreathingPlayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath =
      AnimationController(vsync: this, duration: KijiMotion.breath);

  bool get _animate =>
      breathingShouldAnimate(isPlaying: widget.isPlaying, reduceMotion: widget.reduceMotion);

  @override
  void initState() {
    super.initState();
    if (_animate) _breath.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(BreathingPlayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return SizedBox.square(
      dimension: size * 1.35,
      child: AnimatedBuilder(
        animation: _breath,
        builder: (context, child) {
          // Curva suave de "respiración" (0 → 1 → 0).
          final t = Curves.easeInOut.transform(_breath.value);
          final ringScale = 1.0 + 0.12 * t;
          final ringOpacity = widget.isPlaying ? 0.35 + 0.35 * (1 - t) : 0.18;
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: ringScale,
                child: Container(
                  width: size * 1.18,
                  height: size * 1.18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      width: 2,
                      color: KijiColors.cyan.withValues(alpha: ringOpacity),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: KijiColors.violet.withValues(alpha: 0.25 + 0.2 * t),
                        blurRadius: 24 + 12 * t,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
              child!,
            ],
          );
        },
        child: Semantics(
          button: true,
          label: widget.isPlaying ? 'Pausar' : 'Reproducir',
          child: Tooltip(
            message: widget.isPlaying ? 'Pausar' : 'Reproducir',
            excludeFromSemantics: true,
            child: Material(
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              color: Colors.transparent,
              child: Ink(
                width: size,
                height: size,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: KijiColors.accentGradientDiagonal,
                ),
                child: InkWell(
                  onTap: widget.onPressed,
                  child: Icon(
                    widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: KijiColors.onAccent,
                    size: size * 0.48,
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

/// El anillo solo se anima mientras suena y si no se pidió reducir
/// animaciones.
bool breathingShouldAnimate({required bool isPlaying, required bool reduceMotion}) =>
    isPlaying && !reduceMotion;
