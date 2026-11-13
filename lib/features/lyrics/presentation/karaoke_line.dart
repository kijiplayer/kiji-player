import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/playback_provider.dart';
import '../../../theme/kiji_tokens.dart';
import '../../equalizer/data/equalizer_notifier.dart';
import '../domain/lyrics.dart';

/// Colores del karaoke sobre el fondo oscuro de la letra: lo que falta cantar, apagado; lo cantado,
/// un blanco teñido con los acentos del estilo (Nocturne violeta→cian, Grafito blanco, Papel su
/// rojo), del principio al final de la línea.
({Color unsung, Color from, Color to}) karaokeColors(Color base) => (
  unsung: base.withValues(alpha: base.a * 0.42),
  from: Color.lerp(base, KijiColors.violet, 0.3)!,
  to: Color.lerp(base, KijiColors.cyan, 0.3)!,
);

/// La línea que suena, que se "llena" de color de forma suave a medida que avanza: palabra por
/// palabra si la fuente trae esos tiempos, o pareja hasta la línea siguiente. Se dibuja con el
/// estilo de texto de alrededor (crece con la animación de la línea activa).
///
/// Con "Reducir animaciones" no hay relleno continuo: con tiempos por palabra se pintan de a
/// palabras enteras; sin ellos, la línea entera, como antes.
class KaraokeLine extends ConsumerStatefulWidget {
  const KaraokeLine({
    super.key,
    required this.line,
    this.next,
    this.offset = Duration.zero,
    this.textAlign = TextAlign.start,
    this.calm = false,
  });

  final LyricLine line;

  /// Cuándo empieza la línea siguiente (para repartir el tiempo si no hay tiempos por palabra).
  final Duration? next;

  /// Desfase de la letra (positivo = va antes).
  final Duration offset;
  final TextAlign textAlign;
  final bool calm;

  @override
  ConsumerState<KaraokeLine> createState() => KaraokeLineState();
}

class KaraokeLineState extends ConsumerState<KaraokeLine> with SingleTickerProviderStateMixin {
  /// Para las pruebas: cuántos caracteres ya se pintaron.
  @visibleForTesting
  double get sung => _sung.value;

  /// Caracteres ya cantados (con fracción); solo esto cambia en cada cuadro.
  final _sung = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker((elapsed) {
    _elapsed = elapsed;
    _tick();
  });

  /// La posición llega cada tanto: entre una y otra se calcula con el reloj del ticker (y la
  /// velocidad de "Sonido"). El ticker corre solo mientras suena y falta llenar la línea.
  Duration _anchor = Duration.zero;
  Duration _elapsed = Duration.zero, _anchorTick = Duration.zero;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    final p = ref.read(playbackProvider);
    _setAnchor(p.position, p.isPlaying);
  }

  @override
  void didUpdateWidget(KaraokeLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.calm != widget.calm || oldWidget.line != widget.line) _sync();
  }

  void _setAnchor(Duration position, bool playing) {
    _anchor = position;
    _playing = playing;
    _anchorTick = _elapsed;
    _sync();
  }

  Duration get _now {
    if (!_playing) return _anchor;
    final speed = ref.read(equalizerProvider).settings.playbackRate.speed;
    return _anchor + (_elapsed - _anchorTick) * speed;
  }

  bool get _complete => sungCharacters(widget.line, _now + widget.offset, next: widget.next) >= widget.line.text.length;

  void _sync() {
    final active = !widget.calm && _playing && !_complete;
    if (active && !_ticker.isActive) {
      _anchor = _now;
      _elapsed = Duration.zero;
      _anchorTick = Duration.zero;
      _ticker.start();
    } else if (!active && _ticker.isActive) {
      _ticker.stop();
    }
    _tick();
  }

  void _tick() {
    final position = _now + widget.offset;
    final sung = sungCharacters(widget.line, position, next: widget.next);
    if (!widget.calm) {
      _sung.value = sung;
      if (sung >= widget.line.text.length && _ticker.isActive) _ticker.stop();
      return;
    }
    // Sin animaciones: de a palabras enteras, o la línea entera si no hay tiempos por palabra.
    if (!widget.line.hasWords) {
      _sung.value = widget.line.text.length.toDouble();
      return;
    }
    final text = widget.line.text;
    var end = sung.floor();
    while (end < text.length && end > 0 && text[end] != ' ') {
      end++;
    }
    _sung.value = end.toDouble();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _sung.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(playbackProvider.select((p) => (position: p.position, playing: p.isPlaying)), (_, p) {
      _setAnchor(p.position, p.playing);
    });
    final style = DefaultTextStyle.of(context).style;
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth.isFinite ? box.maxWidth : 10000.0;
        final painter = _KaraokePainter(
          text: widget.line.text,
          style: style,
          align: widget.textAlign,
          scaler: scaler,
          width: width,
          sung: _sung,
          direction: Directionality.of(context),
        );
        return CustomPaint(size: Size(box.maxWidth.isFinite ? width : painter.textWidth, painter.height), painter: painter);
      },
    );
  }
}

class _KaraokePainter extends CustomPainter {
  _KaraokePainter({
    required this.text,
    required this.style,
    required this.align,
    required this.scaler,
    required this.width,
    required this.sung,
    required this.direction,
  }) : super(repaint: sung) {
    final colors = karaokeColors(style.color ?? KijiColors.text);
    _unsung = _layout(style.copyWith(color: colors.unsung));
    _from = colors.from;
    _to = colors.to;
    _bright = _layout(style);
  }

  final String text;
  final TextStyle style;
  final TextAlign align;
  final TextScaler scaler;
  final double width;
  final ValueNotifier<double> sung;
  final TextDirection direction;

  late final TextPainter _unsung, _bright;
  late final Color _from, _to;

  /// Ancho del borde suave entre lo cantado y lo que falta.
  double get _edge => (style.fontSize ?? 24) * 0.9;

  TextPainter _layout(TextStyle s) => TextPainter(
    text: TextSpan(text: text, style: s),
    textAlign: align,
    textDirection: direction,
    textScaler: scaler,
  )..layout(minWidth: align == TextAlign.start ? 0 : width, maxWidth: width);

  double get height => _unsung.height;
  double get textWidth => _unsung.width;

  @override
  void paint(Canvas canvas, Size size) {
    _unsung.paint(canvas, Offset.zero);
    final done = sung.value.clamp(0, text.length).toDouble();
    if (done <= 0) return;
    final whole = done.floor();
    final path = Path();
    for (final box in _bright.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: whole))) {
      path.addRect(box.toRect().inflate(2));
    }
    Rect? partial;
    if (whole < text.length) {
      final boxes = _bright.getBoxesForSelection(TextSelection(baseOffset: whole, extentOffset: whole + 1));
      if (boxes.isNotEmpty) {
        final b = boxes.first.toRect();
        final x = b.left + b.width * (done - whole);
        partial = Rect.fromLTRB(b.left, b.top, x, b.bottom).inflate(2);
        path.addRect(partial);
      }
    }
    final bounds = Offset.zero & size;
    canvas.saveLayer(bounds.inflate(4), Paint());
    canvas.clipPath(path);
    _bright.paint(canvas, Offset.zero);
    // El color: un degradado de los acentos del estilo a lo largo de la línea.
    canvas.drawRect(
      bounds,
      Paint()
        ..blendMode = BlendMode.srcIn
        ..shader = LinearGradient(colors: [_from, _to]).createShader(bounds),
    );
    // Borde suave donde va el canto (no un corte seco).
    final edgeLine = partial;
    if (edgeLine != null && edgeLine.width > 0) {
      final fade = Rect.fromLTRB(max(bounds.left, edgeLine.right - _edge), edgeLine.top, edgeLine.right, edgeLine.bottom);
      canvas.drawRect(
        fade,
        Paint()
          ..blendMode = BlendMode.dstIn
          // Máscara de transparencia (dstIn): solo cuenta el alfa, no es un color que se vea.
          ..shader = const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)]).createShader(fade),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_KaraokePainter old) =>
      old.text != text || old.style != style || old.align != align || old.width != width || old.scaler != scaler;
}
