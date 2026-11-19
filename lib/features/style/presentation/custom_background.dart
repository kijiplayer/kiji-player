import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:ui' as ui show Image;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player/video_player.dart';

import '../../../l10n/l10n.dart';
import '../../../providers/appearance_provider.dart';
import '../../../theme/kiji_tokens.dart';
import '../../customize/data/track_overrides.dart';
import '../../settings/data/settings_store.dart';
import '../../settings/domain/app_settings.dart';
import '../data/background_store.dart';
import '../../../widgets/nocturne/glass.dart';
import '../../../widgets/nocturne/liquid_glass.dart';

/// El fondo que se ve: el de la canción que suena (si tiene uno propio) o el general. La ruta es
/// relativa a la carpeta de fondos.
final effectiveBackgroundProvider = Provider<({String path, String kind})?>((ref) {
  final song = ref.watch(currentTrackStyleProvider);
  if (song?.backgroundFile != null) return (path: 'canciones/${song!.backgroundFile}', kind: song.backgroundKind ?? 'image');
  final s = ref.watch(settingsProvider.select((s) => (file: s.backgroundFile, kind: s.backgroundKind)));
  return s.file == null ? null : (path: s.file!, kind: s.kind);
});

/// El tono de una foto de fondo, para que la capa de
/// legibilidad sea la justa: una foto oscura casi no necesita capa y se ve entera; una blanca
/// necesita más. Se mide una vez por archivo, achicada a 16 × 16: el tono medio (la mediana de
/// brillo), así la mayor parte de la foto queda con 4,5:1. null si no se pudo medir (o es un video).
final backgroundToneProvider = FutureProvider.family<Color?, ({String path, bool light})>((ref, key) async {
  try {
    final bytes = await File(key.path).readAsBytes();
    final codec = await instantiateImageCodec(bytes, targetWidth: 16, targetHeight: 16);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData();
    frame.image.dispose();
    codec.dispose();
    if (data == null) return null;
    final pixels = <Color>[
      for (var i = 0; i + 3 < data.lengthInBytes; i += 4)
        Color.fromARGB(255, data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2)),
    ]..sort((a, b) => a.computeLuminance().compareTo(b.computeLuminance()));
    if (pixels.isEmpty) return null;
    return pixels[((pixels.length - 1) * 0.5).round()];
  } catch (error) {
    debugPrint('=== FONDO: no se pudo medir el tono de la foto: ${error.runtimeType} ===');
    return null;
  }
});

/// Tono que se supone para un video (no se mide cada cuadro): uno medio, ni el peor caso (que lo
/// taparía casi entero) ni ninguno.
Color videoBackgroundTone(KijiPalette palette) =>
    Color.lerp(palette.background, palette.isLight ? Colors.black : Colors.white, 0.45)!;

/// Hay un fondo propio a la vista (las pantallas principales dejan ver lo de atrás).
final hasCustomBackgroundProvider = Provider<bool>((ref) => ref.watch(effectiveBackgroundProvider) != null);

/// El fondo propio, detrás de las pantallas principales: la foto, el GIF o el video, con el
/// desenfoque y la opacidad elegidos, y encima una capa del color del estilo que deja el texto
/// siempre legible ([backgroundScrim]). Sin fondo propio no dibuja nada.
class CustomBackground extends ConsumerWidget {
  const CustomBackground({super.key, this.preview = false});

  /// Para la vista previa de Apariencia: el fondo general (no el de la canción), por capas y en
  /// vivo (sin componerlo en una imagen: cambia con cada movimiento de los controles).
  final bool preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final general = ref.watch(settingsProvider.select((s) => (file: s.backgroundFile, kind: s.backgroundKind)));
    final bg = preview
        ? (general.file == null ? null : (path: general.file!, kind: general.kind))
        : ref.watch(effectiveBackgroundProvider);
    final s = ref.watch(settingsProvider.select((s) => (blur: s.backgroundBlur, opacity: s.backgroundOpacity)));
    final folder = ref.watch(backgroundFolderProvider).valueOrNull;
    if (bg == null || folder == null) return const SizedBox.shrink();
    final file = File(p.join(folder.path, bg.path));
    final video = bg.kind == 'video' && BackgroundStore.videoSupported;
    final palette = KijiColors.palette;
    // Mientras se mide la foto (un instante) queda la capa del peor caso: nunca texto ilegible.
    final tone = video
        ? videoBackgroundTone(palette)
        : ref.watch(backgroundToneProvider((path: file.path, light: palette.isLight))).valueOrNull;
    final scrim = backgroundScrim(palette, s.opacity, tone: tone);
    final media = video
        // La clave es el archivo: con otro video (otro fondo, o el de otra canción) se cierra el
        // reproductor viejo y se abre uno nuevo (si no, seguía el anterior, abierto).
        ? (BackgroundStore.videoWithMediaKit
              ? _PcVideoBackground(key: ValueKey(file.path), file: file)
              : _VideoBackground(key: ValueKey(file.path), file: file))
        : Image.file(
            file,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            // Un archivo que ya no está: queda el fondo del estilo.
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          );
    final layers = IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: KijiColors.background),
          Opacity(
            opacity: s.opacity.clamp(AppSettings.minBackgroundOpacity, 1),
            child: s.blur <= 0.5
                ? media
                : ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: s.blur, sigmaY: s.blur), child: media),
          ),
          // Capa oscura (o clara en Papel) que asegura que el texto se lea.
          ColoredBox(key: const Key('background-scrim'), color: KijiColors.background.withValues(alpha: scrim)),
        ],
      ),
    );
    // Una foto fija (no un GIF ni un video): se compone una sola vez en una imagen del tamaño de la
    // pantalla (rendimiento: el vidrio de encima la desenfoca en cada cuadro, y antes en cada
    // cuadro se volvían a dibujar la foto, su desenfoque y la capa). Se ve igual.
    final still = !video && !file.path.toLowerCase().endsWith('.gif');
    if (preview || !still) return layers;
    return _StillBackground(
      file: file,
      background: KijiColors.background,
      opacity: s.opacity.clamp(AppSettings.minBackgroundOpacity, 1).toDouble(),
      blur: s.blur,
      scrim: KijiColors.background.withValues(alpha: scrim),
      fallback: layers,
    );
  }
}

/// La foto de fondo ya compuesta (fondo del estilo, foto con su opacidad y desenfoque, y la capa
/// de legibilidad) en una sola imagen. Mientras se compone, [fallback] (las capas de siempre).
class _StillBackground extends StatefulWidget {
  const _StillBackground({
    required this.file,
    required this.background,
    required this.opacity,
    required this.blur,
    required this.scrim,
    required this.fallback,
  });

  final File file;
  final Color background;
  final double opacity;
  final double blur;
  final Color scrim;
  final Widget fallback;

  @override
  State<_StillBackground> createState() => _StillBackgroundState();
}

class _StillBackgroundState extends State<_StillBackground> {
  ui.Image? _composed;
  Object? _composedFor;
  Object? _composing;

  Object _keyFor(Size size, double ratio) =>
      (widget.file.path, widget.background, widget.opacity, widget.blur, widget.scrim, size, ratio);

  Future<void> _compose(Size size, double ratio, Object key) async {
    _composing = key;
    try {
      final width = (size.width * ratio).round();
      final height = (size.height * ratio).round();
      if (width <= 0 || height <= 0) return;
      final bytes = await widget.file.readAsBytes();
      final codec = await instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      final photo = frame.image;
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final full = Offset.zero & Size(width.toDouble(), height.toDouble());
      canvas.drawRect(full, Paint()..color = widget.background);
      // La foto como BoxFit.cover, con su opacidad y su desenfoque.
      final src = Size(photo.width.toDouble(), photo.height.toDouble());
      final fitted = applyBoxFit(BoxFit.cover, src, full.size);
      final from = Alignment.center.inscribe(fitted.source, Offset.zero & src);
      final paint = Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(0, 0, 0, widget.opacity);
      if (widget.blur > 0.5) {
        final sigma = widget.blur * ratio;
        paint.imageFilter = ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal);
      }
      canvas.drawImageRect(photo, from, full, paint);
      canvas.drawRect(full, Paint()..color = widget.scrim);
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      picture.dispose();
      photo.dispose();
      // Para los vidrios de encima (0.8.3): la misma imagen, chica y ya desenfocada, una sola vez.
      final glass = await _blurredForGlass(image);
      if (!mounted || _composing != key) {
        image.dispose();
        glass?.dispose();
        return;
      }
      setState(() {
        _composed?.dispose();
        _composed = image;
        _composedFor = key;
      });
      _publish(glass);
    } catch (error) {
      debugPrint('=== FONDO: no se pudo componer la foto (${error.runtimeType}); se dibuja por capas ===');
    }
  }

  /// La foto compuesta, a 1/8 y desenfocada como el vidrio (lo que cada vidrio deja ver detrás).
  static Future<ui.Image?> _blurredForGlass(ui.Image image) async {
    try {
      final w = (image.width / 8).ceil().clamp(1, 1 << 14);
      final h = (image.height / 8).ceil().clamp(1, 1 << 14);
      const sigma = KijiSizes.glassBlur / 2.5;
      final recorder = PictureRecorder();
      Canvas(recorder).drawImageRect(
        image,
        Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
        Offset.zero & Size(w.toDouble(), h.toDouble()),
        Paint()
          ..filterQuality = FilterQuality.medium
          ..imageFilter = ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp),
      );
      final picture = recorder.endRecording();
      final small = await picture.toImage(w, h);
      picture.dispose();
      return small;
    } catch (error) {
      debugPrint('=== FONDO: no se pudo preparar el fondo para el vidrio (${error.runtimeType}) ===');
      return null;
    }
  }

  ui.Image? _glass;
  GlassBackdropController? _backdrop;

  /// Publica la foto desenfocada para los vidrios, en el lugar de la pantalla donde está el fondo.
  void _publish(ui.Image? glass) {
    if (glass == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = context.findRenderObject();
      if (!mounted || box is! RenderBox || !box.hasSize) {
        glass.dispose();
        return;
      }
      final backdrop = _backdrop = GlassBackdrop.maybeOf(context);
      backdrop?.set('photo', GlassLayer(glass, box.localToGlobal(Offset.zero) & box.size));
      _glass?.dispose();
      _glass = glass;
    });
  }

  @override
  void dispose() {
    _backdrop?.remove('photo');
    _glass?.dispose();
    _composed?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final key = _keyFor(size, ratio);
        if (key != _composedFor && key != _composing && size.isFinite) {
          unawaited(_compose(size, ratio, key));
        }
        final image = _composed;
        if (image == null || key != _composedFor) return widget.fallback;
        return IgnorePointer(child: RawImage(image: image, fit: BoxFit.fill, width: size.width, height: size.height));
      },
    );
  }
}

/// Video de fondo: sin sonido y en bucle. Se queda quieto cuando Kiji no está a la vista, con el
/// ahorro de batería o con "Reducir animaciones".
class _VideoBackground extends ConsumerStatefulWidget {
  const _VideoBackground({super.key, required this.file});

  final File file;

  @override
  ConsumerState<_VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends ConsumerState<_VideoBackground> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _visible = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_open());
  }

  Future<void> _open() async {
    // mixWithOthers: el video (mudo) no pide el foco de audio; si lo pidiera, Android pausaría la música.
    final controller = VideoPlayerController.file(widget.file, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
    try {
      await controller.initialize();
      await controller.setVolume(0);
      await controller.setLooping(true);
      _saving = await BackgroundStore.powerSaving();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      _sync();
    } catch (error) {
      debugPrint('=== FONDO: no se pudo abrir el video: $error ===');
      await controller.dispose();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _visible = state == AppLifecycleState.resumed;
    if (_visible) {
      unawaited(BackgroundStore.powerSaving().then((saving) {
        _saving = saving;
        _sync();
      }));
    } else {
      _sync();
    }
  }

  void _sync() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final still = !_visible || _saving || reduceMotion(context, ref);
    if (still && controller.value.isPlaying) {
      unawaited(controller.pause());
    } else if (!still && !controller.value.isPlaying) {
      unawaited(controller.play());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: controller.value.size.width,
        height: controller.value.size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}

/// Video de fondo en la PC, con media_kit (la librería completa de mpv): sin sonido, en bucle, y
/// quieto cuando Kiji no está a la vista o con "Reducir animaciones".
class _PcVideoBackground extends ConsumerStatefulWidget {
  const _PcVideoBackground({super.key, required this.file});

  final File file;

  @override
  ConsumerState<_PcVideoBackground> createState() => _PcVideoBackgroundState();
}

class _PcVideoBackgroundState extends ConsumerState<_PcVideoBackground> with WidgetsBindingObserver {
  final _player = mk.Player();
  late final _controller = VideoController(_player);
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      await _player.setVolume(0);
      await _player.setPlaylistMode(mk.PlaylistMode.single);
      await _player.open(mk.Media(widget.file.path), play: false);
      _sync();
    } catch (error) {
      debugPrint('=== FONDO: no se pudo abrir el video en la PC: $error ===');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _visible = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    if (!mounted) return;
    final still = !_visible || reduceMotion(context, ref);
    if (still && _player.state.playing) {
      unawaited(_player.pause());
    } else if (!still && !_player.state.playing) {
      unawaited(_player.play());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    return Video(controller: _controller, fit: BoxFit.cover, controls: NoVideoControls, fill: Colors.transparent);
  }
}

/// Elegir, ajustar o quitar el fondo propio (Apariencia y el asistente).
class BackgroundOptions extends ConsumerWidget {
  const BackgroundOptions({super.key});

  Future<void> _choose(BuildContext context, WidgetRef ref, {required bool video}) async {
    final store = ref.read(backgroundStoreProvider);
    try {
      final path = await store.pick(video: video);
      if (path == null) return;
      final name = await store.keep(path);
      await ref
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(backgroundFile: name, backgroundKind: video ? 'video' : 'image'));
      debugPrint('=== FONDO: fondo propio elegido (${video ? 'video' : 'imagen'}) ===');
    } catch (error) {
      debugPrint('=== FONDO: no se pudo usar el archivo: $error ===');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tx.fondoNoSePudo)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final has = s.backgroundFile != null;
    final notifier = ref.read(settingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.image_outlined),
              label: Text(tx.elegirImagen),
              onPressed: () => _choose(context, ref, video: false),
            ),
            if (BackgroundStore.videoSupported)
              OutlinedButton.icon(
                icon: const Icon(Icons.movie_outlined),
                label: Text(tx.elegirVideo),
                onPressed: () => _choose(context, ref, video: true),
              ),
            if (has)
              TextButton.icon(
                icon: const Icon(Icons.hide_image_outlined),
                label: Text(tx.quitarFondo),
                onPressed: () async {
                  await notifier.update((s) => s.copyWith(clearBackground: true));
                  await ref.read(backgroundStoreProvider).removeAll();
                },
              ),
          ],
        ),
        if (has) ...[
          const SizedBox(height: 16),
          // Cómo queda Kiji con este fondo: cambia al momento con el desenfoque y la opacidad.
          const BackgroundPreview(),
          const SizedBox(height: 12),
          Text(tx.desenfoque, style: KijiText.mono(size: 11)),
          Slider(
            value: s.backgroundBlur,
            max: AppSettings.maxBackgroundBlur,
            onChanged: (v) => notifier.update((s) => s.copyWith(backgroundBlur: v)),
          ),
          Text(tx.opacidad, style: KijiText.mono(size: 11)),
          Slider(
            value: s.backgroundOpacity.clamp(AppSettings.minBackgroundOpacity, 1),
            min: AppSettings.minBackgroundOpacity,
            onChanged: (v) => notifier.update((s) => s.copyWith(backgroundOpacity: v)),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          BackgroundStore.videoSupported ? tx.fondoPrivadoNota : tx.fondoPrivadoNotaPc,
          style: TextStyle(color: KijiColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

/// Vista previa del fondo propio: la app de verdad (fondo, una tarjeta, texto y el mini-reproductor
/// encima), armada al tamaño de la pantalla y achicada, así el desenfoque y la opacidad se ven
/// exactamente como van a quedar. Cambia al momento mientras se mueven los controles.
class BackgroundPreview extends StatelessWidget {
  const BackgroundPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final aspect = screen.width <= 0 || screen.height <= 0 ? 0.5 : screen.width / screen.height;
        // Con la proporción de la pantalla (en la PC, apaisada como la ventana): como mucho 280 de
        // ancho y 420 de alto, así se ve entera (antes, al limitar el alto, se recortaba).
        final width = [constraints.maxWidth, 280.0, 420.0 * aspect].reduce((a, b) => a < b ? a : b);
        final height = width / aspect;
        return Center(
          child: Semantics(
            label: tx.fondoVistaPrevia,
            child: IgnorePointer(
              child: Container(
                key: const Key('background-preview'),
                width: width,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: KijiColors.glassBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox.fromSize(
                    size: screen,
                    child: const Stack(fit: StackFit.expand, children: [CustomBackground(preview: true), _PreviewContent()]),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Lo que va encima en la vista previa: un saludo, una tarjeta y el mini-reproductor (de ejemplo).
class _PreviewContent extends StatelessWidget {
  const _PreviewContent();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 64, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tx.fondoVistaPreviaSaludo, style: KijiText.display(size: 34).copyWith(color: KijiColors.text)),
          const SizedBox(height: 20),
          Glass(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(Icons.queue_music_rounded, color: KijiColors.cyan, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tx.fondoVistaPreviaTarjeta, style: KijiText.title(size: 20).copyWith(color: KijiColors.text)),
                      const SizedBox(height: 4),
                      Text(tx.fondoVistaPreviaTarjetaNota, style: TextStyle(color: KijiColors.muted, fontSize: 15)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(tx.fondoVistaPreviaTexto, style: TextStyle(color: KijiColors.text, fontSize: 17, height: 1.4)),
          const Spacer(),
          Glass(
            floating: true,
            radius: KijiRadii.miniPlayer,
            padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: KijiColors.accentGradientDiagonal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tx.fondoVistaPreviaCancion, style: TextStyle(color: KijiColors.text, fontWeight: FontWeight.w600, fontSize: 16)),
                      Text(tx.fondoVistaPreviaArtista, style: TextStyle(color: KijiColors.muted, fontSize: 14)),
                    ],
                  ),
                ),
                Icon(Icons.pause_rounded, color: KijiColors.text, size: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
