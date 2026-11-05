import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/track.dart';
import '../../providers/appearance_provider.dart';
import '../../theme/kiji_tokens.dart';
import '../../widgets/album_cover.dart';

/// "Vidrio de museo" de Grafito: el fondo del reproductor, el grano, el brillo al abrir, la
/// portada que se inclina y el título que entra deslizándose. Todo se apaga con "Reducir
/// animaciones" y lo que se mueve solo se detiene en pausa y en segundo plano.

/// ¿La app se ve? (en segundo plano o minimizada no se anima nada).
bool _appVisible() =>
    (WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed) == AppLifecycleState.resumed;

/// Portadas ya pasadas a blanco y negro y desenfocadas (las últimas, por id de canción).
final _museumImages = <String, ui.Image>{};

/// La portada de [track] en blanco y negro, muy desenfocada y con los grises estirados, en
/// 48 × 48 px. Se hace una sola vez por canción: después se dibuja ampliada (el suavizado al
/// ampliarla completa el desenfoque), así que moverla no cuesta un desenfoque por cuadro.
Future<ui.Image?> museumImageFor(String id, ImageProvider provider) async {
  final known = _museumImages[id];
  if (known != null) return known;
  final source = await _resolve(ResizeImage(provider, width: 96, allowUpscaling: false));
  if (source == null) return null;
  const side = 48.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final crop = min(source.width, source.height).toDouble();
  canvas.drawImageRect(
    source,
    Rect.fromCenter(center: Offset(source.width / 2, source.height / 2), width: crop, height: crop),
    const Rect.fromLTWH(0, 0, side, side),
    Paint()
      ..filterQuality = FilterQuality.medium
      // Blanco y negro (luminancia).
      ..colorFilter = const ColorFilter.matrix([
        0.2126, 0.7152, 0.0722, 0, 0, //
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0, 0, 0, 1, 0,
      ])
      ..imageFilter = ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3, tileMode: TileMode.clamp),
  );
  source.dispose();
  final gray = await recorder.endRecording().toImage(side.toInt(), side.toInt());
  final bytes = await gray.toByteData();
  gray.dispose();
  if (bytes == null) return null;
  // Se estiran los grises de punta a punta: lo más oscuro de la portada queda negro y lo más claro,
  // en el blanco máximo con el que se calculó el contraste. Así se notan las formas de cualquier
  // portada (también de una gris o muy oscura) sin pasar nunca de ese brillo.
  final pixels = bytes.buffer.asUint8List();
  var low = 255, high = 0;
  for (var i = 0; i < pixels.length; i += 4) {
    low = min(low, pixels[i]);
    high = max(high, pixels[i]);
  }
  final range = max(24, high - low);
  for (var i = 0; i < pixels.length; i += 4) {
    final v = ((pixels[i] - low) / range * 255 * KijiMuseum.backdropBrightness).round().clamp(0, 255);
    pixels
      ..[i] = v
      ..[i + 1] = v
      ..[i + 2] = v
      ..[i + 3] = 255;
  }
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(pixels, side.toInt(), side.toInt(), ui.PixelFormat.rgba8888, completer.complete);
  final image = await completer.future;
  if (_museumImages.length >= 6) _museumImages.remove(_museumImages.keys.first)?.dispose();
  return _museumImages[id] = image;
}

Future<ui.Image?> _resolve(ImageProvider provider) {
  final completer = Completer<ui.Image?>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      stream.removeListener(listener);
      if (!completer.isCompleted) completer.complete(info.image.clone());
      info.dispose();
    },
    onError: (Object error, StackTrace? _) {
      stream.removeListener(listener);
      debugPrint('=== GRAFITO: sin portada para el fondo ($error) ===');
      if (!completer.isCompleted) completer.complete(null);
    },
  );
  stream.addListener(listener);
  return completer.future;
}

/// Fondo del reproductor en Grafito: la portada en blanco y negro, muy desenfocada y oscura, que se
/// mueve muy lento mientras suena. Con alto rendimiento, además, un grano de película sutil.
class MuseumBackdrop extends ConsumerStatefulWidget {
  const MuseumBackdrop({super.key, required this.track, required this.playing});

  final Track track;
  final bool playing;

  @override
  ConsumerState<MuseumBackdrop> createState() => _MuseumBackdropState();
}

class _MuseumBackdropState extends ConsumerState<MuseumBackdrop> with SingleTickerProviderStateMixin {
  /// Un recorrido completo de la deriva: un minuto y medio, apenas (Grafito 0.8: casi quieto).
  late final AnimationController _drift = AnimationController(vsync: this, duration: const Duration(seconds: 90));
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onStateChange: (_) => mounted ? setState(() {}) : null,
  );
  ui.Image? _image;
  String? _imageFor;
  bool _reduce = false;

  bool get _moving => widget.playing && !_reduce && _appVisible();

  /// Arranca o detiene la deriva según [_moving] (después de cada build).
  void _sync() {
    if (!mounted) return;
    if (_moving && !_drift.isAnimating) {
      _drift.repeat();
    } else if (!_moving && _drift.isAnimating) {
      _drift.stop();
    }
  }

  ImageProvider? _provider;

  /// Carga la portada cuando aparece o cambia (las carpetas de portadas pueden tardar en estar).
  void _load(ImageProvider? provider) {
    final id = widget.track.id;
    if (_imageFor == id && _provider == provider) return;
    _imageFor = id;
    _provider = provider;
    if (provider == null) {
      _image = null;
      return;
    }
    museumImageFor(id, provider).then((image) {
      if (mounted && widget.track.id == id) setState(() => _image = image);
    });
  }

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _load(trackImageProvider(ref, widget.track));
    _reduce = reduceMotion(context, ref);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    final image = _image;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: KijiColors.background),
        // Fundido entre la portada anterior y la nueva al cambiar de canción.
        AnimatedSwitcher(
          duration: _reduce ? Duration.zero : const Duration(milliseconds: 900),
          // Las dos portadas (la que se va y la que llega) ocupan toda la pantalla.
          layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
          child: image == null
              ? const SizedBox.expand()
              : AnimatedBuilder(
                  key: ValueKey(image),
                  animation: _drift,
                  // Solo cambia la transformación de una capa ya dibujada: no se redibuja nada.
                  builder: (context, child) {
                    final t = _drift.value * 2 * pi;
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..scaleByDouble(1.3 + 0.015 * sin(t), 1.3 + 0.015 * sin(t), 1, 1)
                        ..translateByDouble(6 * cos(t), 8 * sin(2 * t), 0, 1),
                      child: child,
                    );
                  },
                  child: RepaintBoundary(child: CustomPaint(painter: _CoverPainter(image))),
                ),
        ),
      ],
    );
  }
}

class _CoverPainter extends CustomPainter {
  _CoverPainter(this.image);

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final side = max(size.width, size.height);
    final dst = Rect.fromCenter(center: size.center(Offset.zero), width: side, height: side);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = const Color.fromRGBO(0, 0, 0, KijiMuseum.backdropOpacity),
    );
  }

  @override
  bool shouldRepaint(_CoverPainter old) => old.image != image;
}

/// Una línea de texto que entra deslizándose (la usa el Escaparate de la letra con [always]; en
/// Grafito 0.8 el reproductor ya no la anima).
class MuseumLineIn extends ConsumerStatefulWidget {
  const MuseumLineIn({super.key, required this.trackId, required this.line, required this.child, this.always = false});

  final String trackId;

  /// También fuera de Grafito (el Escaparate de la letra, en los tres estilos).
  final bool always;

  /// 0 = título, 1 = artista (entra un poco después).
  final int line;
  final Widget child;

  @override
  ConsumerState<MuseumLineIn> createState() => _MuseumLineInState();
}

class _MuseumLineInState extends ConsumerState<MuseumLineIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 820));
  bool _started = false;
  bool _reduce = false;

  // Grafito 0.8: el título ya no entra deslizándose (menos movimiento a la vez); queda para quien lo pida.
  bool get _active => widget.always && !_reduce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduce = reduceMotion(context, ref);
    _active ? _c.forward() : _c.value = 1;
  }

  @override
  void didUpdateWidget(MuseumLineIn old) {
    super.didUpdateWidget(old);
    if (old.trackId != widget.trackId) _active ? _c.forward(from: 0) : _c.value = 1;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _reduce = reduceMotion(context, ref);
    final start = widget.line * 0.18;
    final curve = CurvedAnimation(
      parent: _c,
      curve: Interval(start, start + 0.7, curve: KijiMotion.spring),
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) {
        final t = curve.value;
        Widget moved = Transform.translate(offset: Offset(28 * (1 - t), 0), child: child);
        // El título, además, llega desenfocado y se enfoca (solo mientras entra).
        if (widget.line == 0 && t < 1) {
          final sigma = 6 * (1 - t);
          moved = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: moved,
          );
        }
        return Opacity(opacity: t.clamp(0.0, 1.0), child: moved);
      },
      child: widget.child,
    );
  }
}
