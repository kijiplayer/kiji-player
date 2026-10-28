import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/track.dart';
import '../../../providers/appearance_provider.dart';
import '../../../providers/playback_provider.dart';
import '../../../screens/player/museum.dart' show MuseumLineIn;
import '../../../screens/player/player_motion.dart' show auroraColorsFor;
import '../../../screens/player/player_screen.dart' show PlaybackControlsRow;
import '../../../theme/kiji_tokens.dart';
import '../../../widgets/album_cover.dart';
import '../../../widgets/kiji_logo.dart';
import '../../customize/presentation/track_text.dart';
import '../../loudness/data/loudness_analyzer.dart';
import '../../loudness/domain/loudness.dart';
import '../../settings/data/settings_store.dart';
import 'lyrics_side_panel.dart' show LyricsPanelFrame, LyricsTimes;

import 'package:kiji_player/l10n/l10n.dart';

/// Vista del panel de la letra: Completo (con los ajustes), Simple (reproductor limpio) o
/// Escaparate (para grabar y compartir). Se elige con el botón de arriba y se recuerda.
String lyricsPanelLabel(String panel) => switch (panel) {
  'simple' => tx.panelSimple,
  'showcase' => tx.panelEscaparate,
  _ => tx.panelCompleto,
};

IconData lyricsPanelIcon(String panel) => switch (panel) {
  'simple' => Icons.tune_rounded,
  'showcase' => Icons.auto_awesome_rounded,
  _ => Icons.view_sidebar_outlined,
};

/// La vista que sigue al tocar el botón (Completo → Simple → Escaparate → Completo).
String nextLyricsPanel(String panel) => switch (panel) {
  'full' => 'simple',
  'simple' => 'showcase',
  _ => 'full',
};

// --- Simple ---------------------------------------------------------------------------------

/// Simple: portada, título, artista, barra de progreso con tiempos, los controles y el volumen.
/// Sin los ajustes de la letra. [compact] es la versión de abajo de la letra (una columna).
class LyricsSimplePanel extends ConsumerWidget {
  const LyricsSimplePanel({super.key, required this.track, this.compact = false});

  final Track track;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = Column(
      crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        TrackTitleText(
          track,
          maxLines: compact ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          textAlign: compact ? TextAlign.start : TextAlign.center,
          style: KijiText.title(size: compact ? 17 : 24),
        ),
        const SizedBox(height: 2),
        TrackArtistText(
          track,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: compact ? TextAlign.start : TextAlign.center,
          style: TextStyle(color: KijiColors.muted, fontSize: compact ? 13 : 15),
        ),
      ],
    );
    final controls = [
      const _SeekBar(),
      const LyricsTimes(),
      const SizedBox(height: 4),
      const FittedBox(fit: BoxFit.scaleDown, child: PlaybackControlsRow(compact: true)),
      const SizedBox(height: 4),
      const _VolumeRow(),
    ];
    if (compact) {
      return LyricsPanelFrame(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  TrackArtwork(
                    track: track,
                    size: 52,
                    radius: KijiLook.cover(KijiRadii.tile),
                    showDownloadState: false,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: info),
                ],
              ),
              const SizedBox(height: 6),
              ...controls,
            ],
          ),
        ),
      );
    }
    return LyricsPanelFrame(
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            // Centrado en el alto del panel cuando entra.
            constraints: BoxConstraints(minHeight: max(0, box.maxHeight - 48)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: TrackArtwork(
                    track: track,
                    size: min(min(box.maxWidth - 48, 300), max(120, box.maxHeight * 0.45)),
                    radius: KijiLook.cover(KijiRadii.cover),
                    showDownloadState: false,
                  ),
                ),
                const SizedBox(height: 20),
                info,
                const SizedBox(height: 16),
                ...controls,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra de progreso fina que se puede arrastrar.
class _SeekBar extends ConsumerWidget {
  const _SeekBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(playbackProvider.select((p) => p.progress));
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: KijiColors.violet,
        inactiveTrackColor: KijiColors.waveRest,
        thumbColor: KijiColors.violet,
      ),
      child: SizedBox(
        height: 28,
        child: Slider(
          value: progress.clamp(0.0, 1.0),
          onChanged: ref.read(playbackProvider.notifier).seekToProgress,
          semanticFormatterCallback: (_) => tx.progresoDeLaCancion,
        ),
      ),
    );
  }
}

class _VolumeRow extends ConsumerWidget {
  const _VolumeRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(playbackProvider.select((p) => p.volume));
    final notifier = ref.read(playbackProvider.notifier);
    return Row(
      children: [
        Icon(volume == 0 ? Icons.volume_off_rounded : Icons.volume_down_rounded, color: KijiColors.muted, size: 20),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: KijiColors.text,
              inactiveTrackColor: KijiColors.waveRest,
              thumbColor: KijiColors.text,
            ),
            child: Slider(
              value: volume,
              onChanged: (value) => notifier.changeVolume(value - volume),
              semanticFormatterCallback: (value) => tx.volumen((value * 100).round()),
            ),
          ),
        ),
        Icon(Icons.volume_up_rounded, color: KijiColors.muted, size: 20),
      ],
    );
  }
}

// --- Escaparate -----------------------------------------------------------------------------

/// ¿La app se ve? (en segundo plano o minimizada no se anima nada).
bool _appVisible() =>
    (WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed) == AppLifecycleState.resumed;

/// Escaparate (para grabar y compartir): la portada grande que late con el volumen real, un
/// resplandor de sus colores (en Grafito, grises) que respira con la música, su reflejo debajo,
/// el título y el artista que entran animados y un play/pausa simple, que se esconde solo junto
/// con la barra de arriba ([ChromeAutoHide]). Con [line], la línea de la letra que suena debajo.
class LyricsShowcase extends ConsumerStatefulWidget {
  const LyricsShowcase({super.key, required this.track, this.line});

  final Track track;
  final String? line;

  @override
  ConsumerState<LyricsShowcase> createState() => _LyricsShowcaseState();
}

class _LyricsShowcaseState extends ConsumerState<LyricsShowcase> with SingleTickerProviderStateMixin {
  /// Volumen (0..1) ahora, suavizado: sube rápido con cada golpe y baja despacio.
  final _level = ValueNotifier<double>(0);
  late final _ticker = createTicker(_tick);
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onStateChange: (_) => mounted ? setState(() {}) : null,
  );
  Loudness? _loudness;
  Duration _anchor = Duration.zero;
  final _sinceAnchor = Stopwatch();

  void _tick(Duration _) {
    final loudness = _loudness;
    if (loudness == null) return;
    final now = _anchor + Duration(milliseconds: min(1000, _sinceAnchor.elapsedMilliseconds));
    final target = loudness.at(now);
    final current = _level.value;
    _level.value = target > current ? current + (target - current) * 0.45 : current + (target - current) * 0.07;
  }

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _ticker.dispose();
    _level.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final playing = ref.watch(playbackProvider.select((p) => p.isPlaying));
    // El volumen de la canción (el mismo de la onda en vivo; solo con archivo en el dispositivo).
    _loudness = ref.watch(loudnessProvider(track.id)).value;
    ref.listen(playbackProvider.select((p) => p.position), (_, position) {
      _anchor = position;
      _sinceAnchor
        ..reset()
        ..start();
    });
    final calm = reduceMotion(context, ref);
    final on = _loudness != null && playing && !calm && _appVisible();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (on && !_ticker.isActive) {
        _ticker.start();
      } else if (!on && _ticker.isActive) {
        _ticker.stop();
        _level.value = 0;
      }
    });
    final mark = ref.watch(settingsProvider.select((s) => s.showcaseMark));
    final colors = _glowColors(track);

    return LayoutBuilder(
      builder: (context, box) {
        final cover = min(min(box.maxWidth * 0.78, 420.0), box.maxHeight * 0.48);
        return Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: cover,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // El resplandor detrás (capa propia: solo cambia su color con la música).
                          Positioned.fill(
                            child: IgnorePointer(
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  painter: _GlowPainter(_level, colors, KijiLook.cover(KijiRadii.cover)),
                                ),
                              ),
                            ),
                          ),
                          ValueListenableBuilder<double>(
                            valueListenable: _level,
                            builder: (context, level, child) => Transform.scale(scale: 1 + 0.035 * level, child: child),
                            child: RepaintBoundary(
                              child: TrackArtwork(
                                track: track,
                                size: cover,
                                radius: KijiLook.cover(KijiRadii.cover),
                                showDownloadState: false,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // El reflejo, como sobre un piso brillante.
                    _Reflection(track: track, size: cover),
                    const SizedBox(height: 8),
                    MuseumLineIn(
                      trackId: track.id,
                      line: 0,
                      always: true,
                      child: TrackTitleText(
                        track,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: KijiText.title(size: 28, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 4),
                    MuseumLineIn(
                      trackId: track.id,
                      line: 1,
                      always: true,
                      child: TrackArtistText(
                        track,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 17),
                      ),
                    ),
                    if (widget.line != null && widget.line!.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      AnimatedSwitcher(
                        duration: calm ? Duration.zero : KijiMotion.normal,
                        child: Text(
                          widget.line!,
                          key: ValueKey(widget.line),
                          textAlign: TextAlign.center,
                          style: KijiText.title(size: 20, weight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    HideWhenIdle(child: _PlayPause(playing: playing)),
                  ],
                ),
              ),
            ),
            if (mark)
              const Positioned(
                right: 16,
                bottom: 12,
                child: IgnorePointer(child: Opacity(opacity: 0.55, child: KijiLogo(size: 22))),
              ),
          ],
        );
      },
    );
  }

  /// Los colores de la portada para el resplandor; en Grafito, pasados a grises.
  List<Color> _glowColors(Track track) {
    final colors = auroraColorsFor(track).take(2).toList();
    if (!KijiLook.museum) return colors;
    return [
      for (final c in colors)
        Color.lerp(Colors.white, Colors.black, 1 - (0.35 + 0.5 * c.computeLuminance()).clamp(0.0, 1.0))!,
    ];
  }
}

/// Resplandor detrás de la portada: dos sombras desenfocadas de sus colores, más intensas y
/// grandes cuanto más fuerte suena. Sin datos o quieto, queda tenue y fijo.
class _GlowPainter extends CustomPainter {
  _GlowPainter(this.level, this.colors, this.radius) : super(repaint: level);

  final ValueNotifier<double> level;
  final List<Color> colors;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final l = level.value.clamp(0.0, 1.0);
    for (final (i, color) in colors.indexed) {
      final shift = Offset(i == 0 ? -size.width * 0.06 : size.width * 0.06, size.height * 0.04);
      final rect = (shift & size).inflate(size.width * (0.02 + 0.05 * l));
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        Paint()
          ..color = color.withValues(alpha: 0.30 + 0.35 * l)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34),
      );
    }
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.colors != colors || old.radius != radius;
}

/// La portada reflejada debajo, que se desvanece hacia abajo.
class _Reflection extends StatelessWidget {
  const _Reflection({required this.track, required this.size});

  final Track track;
  final double size;

  @override
  Widget build(BuildContext context) {
    final height = size * 0.22;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: height,
          child: ClipRect(
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x47FFFFFF), Color(0x00FFFFFF)],
              ).createShader(bounds),
              child: OverflowBox(
                alignment: Alignment.topCenter,
                maxHeight: size,
                child: Transform.flip(
                  flipY: true,
                  child: TrackArtwork(
                    track: track,
                    size: size,
                    radius: KijiLook.cover(KijiRadii.cover),
                    showDownloadState: false,
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

class _PlayPause extends ConsumerWidget {
  const _PlayPause({required this.playing});

  final bool playing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: playing ? tx.pausar : tx.reproducir,
      excludeSemantics: true,
      child: Material(
        color: Colors.white.withValues(alpha: 0.14),
        shape: CircleBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.22))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: ref.read(playbackProvider.notifier).togglePlayPause,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 32),
          ),
        ),
      ),
    );
  }
}

// --- Esconderse solo ------------------------------------------------------------------------

/// En el Escaparate, la barra de arriba y los botones se esconden a los 3 s sin tocar la pantalla
/// (ni mover el mouse) y vuelven al tocarla. Fuera del Escaparate ([enabled] false) siempre se ven.
class ChromeAutoHide extends StatefulWidget {
  const ChromeAutoHide({super.key, required this.enabled, required this.child});

  static const idle = Duration(seconds: 3);

  final bool enabled;
  final Widget child;

  @override
  State<ChromeAutoHide> createState() => _ChromeAutoHideState();
}

class _ChromeAutoHideState extends State<ChromeAutoHide> {
  final _visible = ValueNotifier<bool>(true);
  Timer? _timer;

  void _wake() {
    _visible.value = true;
    _timer?.cancel();
    if (widget.enabled) _timer = Timer(ChromeAutoHide.idle, () => _visible.value = false);
  }

  @override
  void initState() {
    super.initState();
    _wake();
  }

  @override
  void didUpdateWidget(ChromeAutoHide old) {
    super.didUpdateWidget(old);
    if (old.enabled != widget.enabled) _wake();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _visible.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _wake(),
      onPointerHover: (_) => _wake(),
      child: _ChromeVisible(notifier: _visible, child: widget.child),
    );
  }
}

class _ChromeVisible extends InheritedNotifier<ValueNotifier<bool>> {
  const _ChromeVisible({required super.notifier, required super.child});
}

/// Algo que se esconde con [ChromeAutoHide] (con un fundido; sin él, con "Reducir animaciones").
class HideWhenIdle extends ConsumerWidget {
  const HideWhenIdle({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = context.dependOnInheritedWidgetOfExactType<_ChromeVisible>()?.notifier?.value ?? true;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: reduceMotion(context, ref) ? Duration.zero : KijiMotion.emphasized,
        child: child,
      ),
    );
  }
}
