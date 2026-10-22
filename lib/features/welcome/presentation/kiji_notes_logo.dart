import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../theme/kiji_tokens.dart';
import '../../../widgets/kiji_logo.dart';

/// Entre una barra y la siguiente (igual que entre las notas de assets/sounds/kiji_notes.wav).
const _gap = Duration(milliseconds: 180);
const _grow = Duration(milliseconds: 520);

/// El logo de Kiji que se arma barra por barra, con una nota por barra (las 5 notas de Kiji,
/// bajito). Después la onda "respira" despacio. Con [reduceMotion], aparece quieto.
class KijiNotesLogo extends StatefulWidget {
  const KijiNotesLogo({super.key, this.size = 148, required this.muted, this.reduceMotion = false});

  final double size;

  /// Sin sonido (el botón de silencio de la bienvenida).
  final bool muted;
  final bool reduceMotion;

  @override
  State<KijiNotesLogo> createState() => _KijiNotesLogoState();
}

class _KijiNotesLogoState extends State<KijiNotesLogo> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: _gap * (kijiLogoBars.length - 1) + _grow,
  );
  late final AnimationController _breath = AnimationController(vsync: this, duration: KijiMotion.breath * 1.5);
  AudioPlayer? _player;

  @override
  void initState() {
    super.initState();
    if (widget.reduceMotion) {
      _intro.value = 1;
    } else {
      _intro.forward().whenComplete(() {
        if (mounted) _breath.repeat();
      });
    }
    if (!widget.muted) _play();
  }

  @override
  void didUpdateWidget(KijiNotesLogo old) {
    super.didUpdateWidget(old);
    if (widget.muted && !old.muted) _player?.stop();
  }

  /// Suena una sola vez, bajito, sin quitarle el audio a otras apps.
  Future<void> _play() async {
    try {
      final player = _player = AudioPlayer(handleInterruptions: false, handleAudioSessionActivation: false);
      await player.setVolume(0.35);
      await player.setAsset('assets/sounds/kiji_notes.wav');
      if (mounted && !widget.muted) await player.play();
    } catch (error) {
      debugPrint('=== BIENVENIDA: no sonaron las notas: $error ===');
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _breath.dispose();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: Listenable.merge([_intro, _breath]),
          builder: (context, _) => CustomPaint(
            size: Size.square(widget.size),
            painter: KijiLogoPainter(
              border: true,
              grow: [
                for (var i = 0; i < kijiLogoBars.length; i++)
                  Curves.easeOutBack.transform(
                    ((_intro.value * _intro.duration!.inMilliseconds - _gap.inMilliseconds * i) / _grow.inMilliseconds)
                        .clamp(0.0, 1.0),
                  ),
              ],
              breath: _breath.isAnimating ? _breath.value : null,
            ),
          ),
        ),
      ),
    );
  }
}
