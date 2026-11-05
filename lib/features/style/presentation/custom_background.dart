import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

import '../../../l10n/l10n.dart';
import '../../../providers/appearance_provider.dart';
import '../../../theme/kiji_tokens.dart';
import '../../settings/data/settings_store.dart';
import '../../settings/domain/app_settings.dart';
import '../data/background_store.dart';

/// Hay un fondo propio elegido (las pantallas principales dejan ver lo de atrás).
final hasCustomBackgroundProvider = Provider<bool>(
  (ref) => ref.watch(settingsProvider.select((s) => s.backgroundFile != null)),
);

/// El fondo propio, detrás de las pantallas principales: la foto, el GIF o el video, con el
/// desenfoque y la opacidad elegidos, y encima una capa del color del estilo que deja el texto
/// siempre legible ([backgroundScrim]). Sin fondo propio no dibuja nada.
class CustomBackground extends ConsumerWidget {
  const CustomBackground({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(
      settingsProvider.select(
        (s) => (file: s.backgroundFile, kind: s.backgroundKind, blur: s.backgroundBlur, opacity: s.backgroundOpacity),
      ),
    );
    final folder = ref.watch(backgroundFolderProvider).valueOrNull;
    if (s.file == null || folder == null) return const SizedBox.shrink();
    final file = File(p.join(folder.path, s.file!));
    final media = s.kind == 'video' && BackgroundStore.videoSupported
        ? _VideoBackground(file: file)
        : Image.file(
            file,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            // Un archivo que ya no está: queda el fondo del estilo.
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          );
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: KijiColors.background),
          Opacity(
            opacity: s.opacity.clamp(0.1, 1),
            child: s.blur <= 0.5
                ? media
                : ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: s.blur, sigmaY: s.blur), child: media),
          ),
          // Capa oscura (o clara en Papel) que asegura que el texto se lea.
          ColoredBox(color: KijiColors.background.withValues(alpha: backgroundScrim(KijiColors.palette, s.opacity))),
        ],
      ),
    );
  }
}

/// Video de fondo: sin sonido y en bucle. Se queda quieto cuando Kiji no está a la vista, con el
/// ahorro de batería o con "Reducir animaciones".
class _VideoBackground extends ConsumerStatefulWidget {
  const _VideoBackground({required this.file});

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
    final controller = VideoPlayerController.file(widget.file);
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
          const SizedBox(height: 12),
          Text(tx.desenfoque, style: KijiText.mono(size: 11)),
          Slider(
            value: s.backgroundBlur,
            max: AppSettings.maxBackgroundBlur,
            onChanged: (v) => notifier.update((s) => s.copyWith(backgroundBlur: v)),
          ),
          Text(tx.opacidad, style: KijiText.mono(size: 11)),
          Slider(
            value: s.backgroundOpacity,
            min: 0.1,
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
