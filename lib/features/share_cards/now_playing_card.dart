import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/track.dart';
import '../../theme/kiji_tokens.dart';
import '../../widgets/album_cover.dart';
import '../../widgets/kiji_logo.dart';
import '../../widgets/nocturne/waveform_progress.dart' show waveformBars;
import '../customize/presentation/track_text.dart' show displayTrack;
import '../lyrics/presentation/lyrics_share.dart' show renderToPng;

import 'package:kiji_player/l10n/l10n.dart';

/// Estilos de la tarjeta de la canción que suena (0.9). **Nunca lleva letras** (tienen derechos).
enum ShareCardStyle {
  nowPlaying,
  vinyl,
  poster;

  String get label => switch (this) {
    ShareCardStyle.nowPlaying => tx.tarjetaSonandoAhora,
    ShareCardStyle.vinyl => tx.tarjetaVinilo,
    ShareCardStyle.poster => tx.tarjetaPoster,
  };
}

/// Formatos: historia (9:16), publicación (4:5) y cuadrado.
enum ShareCardFormat {
  story(360, 640),
  post(360, 450),
  square(360, 360);

  const ShareCardFormat(this.width, this.height);
  final double width;
  final double height;

  String get label => switch (this) {
    ShareCardFormat.story => 'Story', // l10n-ignore
    ShareCardFormat.post => 'Post', // l10n-ignore
    ShareCardFormat.square => 'Square', // l10n-ignore
  };
}

/// La página de Kiji, al pie de cada tarjeta.
const kijiCardUrl = 'kijiplayer.github.io/kiji-player'; // l10n-ignore

/// La tarjeta: portada, título, artista, el logo y la página de Kiji. Sin letras.
class NowPlayingCard extends ConsumerWidget {
  const NowPlayingCard({super.key, required this.track, this.style = ShareCardStyle.nowPlaying, this.format = ShareCardFormat.story});

  final Track track;
  final ShareCardStyle style;
  final ShareCardFormat format;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = displayTrack(ref, track);
    final accent = track.coverColor;
    // La portada según el alto: en cuadrado, más chica para que entren el título y la onda.
    final cover = math.min(
      format.width - 96,
      format.height * switch (format) { ShareCardFormat.story => 0.5, ShareCardFormat.post => 0.42, ShareCardFormat.square => 0.32 },
    );
    // Los colores de la tarjeta no siguen el estilo de la app: siempre oscura (se ve bien en
    // historias) con el color de la canción. Texto blanco sobre fondo oscuro: contraste alto.
    const ink = Colors.white;
    final muted = Colors.white.withValues(alpha: 0.72);

    Widget names({double size = 24, TextAlign align = TextAlign.center, bool upper = false}) => Column(
      crossAxisAlignment: align == TextAlign.center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          upper ? shown.title.toUpperCase() : shown.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: KijiText.display(size: size).copyWith(color: ink, height: 1.05),
        ),
        const SizedBox(height: 6),
        Text(
          shown.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: TextStyle(color: muted, fontSize: size * 0.55, fontWeight: FontWeight.w600),
        ),
      ],
    );

    final footer = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const KijiLogo(size: 18),
        const SizedBox(width: 8),
        Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(kijiCardUrl, style: KijiText.mono(size: 11, color: muted)))),
      ],
    );

    final Widget body = switch (style) {
      ShareCardStyle.nowPlaying => Column(
        children: [
          Text(tx.sonandoAhoraEnKiji.toUpperCase(), style: KijiText.mono(size: 11, color: muted)),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: TrackArtwork(track: track, size: cover, radius: 20, showDownloadState: false),
          ),
          const SizedBox(height: 22),
          names(),
          const SizedBox(height: 16),
          _Wave(seed: track.id, color: ink, width: cover),
          const Spacer(),
          footer,
        ],
      ),
      ShareCardStyle.vinyl => Column(
        children: [
          const Spacer(),
          _Vinyl(track: track, size: cover + 24),
          const SizedBox(height: 24),
          names(),
          const Spacer(),
          footer,
        ],
      ),
      ShareCardStyle.poster => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // La portada grande, sin pasar de la mitad del alto (en cuadrado no entraría con el título).
          TrackArtwork(track: track, size: math.min(format.width - 48, format.height * 0.52), radius: 6, showDownloadState: false),
          const SizedBox(height: 18),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topLeft,
                child: SizedBox(width: format.width - 48, child: names(size: 34, align: TextAlign.start, upper: true)),
              ),
            ),
          ),
          footer,
        ],
      ),
    };

    return SizedBox(
      width: format.width,
      height: format.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(accent, Colors.black, 0.35)!, Color.lerp(accent, Colors.black, 0.85)!],
          ),
        ),
        child: Padding(padding: const EdgeInsets.fromLTRB(24, 22, 24, 18), child: body),
      ),
    );
  }
}

/// Una onda decorativa (la firma de la canción en Kiji, no un espectro real).
class _Wave extends StatelessWidget {
  const _Wave({required this.seed, required this.color, required this.width});

  final String seed;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    final bars = waveformBars(seed, 32);
    return SizedBox(
      width: width,
      height: 28,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final b in bars)
            Container(
              width: 3,
              height: 28 * b,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(2)),
            ),
        ],
      ),
    );
  }
}

/// Un disco de vinilo con la portada como etiqueta del centro.
class _Vinyl extends StatelessWidget {
  const _Vinyl({required this.track, required this.size});

  final Track track;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(size: Size.square(size), painter: _GroovesPainter()),
        ClipOval(child: TrackArtwork(track: track, size: size * 0.42, radius: size, showDownloadState: false)),
        Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle)),
      ],
    ),
  );
}

class _GroovesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(center, r, Paint()..color = const Color(0xFF0E0E12));
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.06);
    for (var rr = r * 0.25; rr < r - 4; rr += 3.5) {
      canvas.drawCircle(center, rr, groove);
    }
    // Un brillo, como la luz sobre el disco.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r * 0.8),
      -2.4,
      0.9,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.35
        ..color = Colors.white.withValues(alpha: 0.05),
    );
  }

  @override
  bool shouldRepaint(_GroovesPainter old) => false;
}

/// Pantalla «Compartir tarjeta»: estilo, formato y compartir como imagen.
Future<void> showShareCardScreen(BuildContext context, Track track) => Navigator.of(context).push(
  MaterialPageRoute<void>(builder: (_) => _ShareCardScreen(track: track)),
);

class _ShareCardScreen extends StatefulWidget {
  const _ShareCardScreen({required this.track});

  final Track track;

  @override
  State<_ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<_ShareCardScreen> {
  final _key = GlobalKey();
  var _style = ShareCardStyle.nowPlaying;
  var _format = ShareCardFormat.story;
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    final file = await renderToPng(_key, 'kiji-tarjeta');
    if (!mounted) return;
    setState(() => _sharing = false);
    if (file == null) return;
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: '${widget.track.title} — ${widget.track.artist}',
        ),
      );
    } catch (error) {
      debugPrint('=== TARJETAS: no se pudo compartir la imagen: ${error.runtimeType} ===');
    }
  }

  Widget _chips<T>(String title, List<T> values, T selected, String Function(T) label, ValueChanged<T> onPick) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: KijiText.mono(size: 11, color: KijiColors.cyan)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in values)
                ChoiceChip(
                  key: Key('share-card-$v'),
                  label: Text(label(v)),
                  selected: v == selected,
                  onSelected: (_) => onPick(v),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tx.compartirTarjeta)),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: FittedBox(
                  child: RepaintBoundary(
                    key: _key,
                    child: NowPlayingCard(track: widget.track, style: _style, format: _format),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _chips(tx.estilo, ShareCardStyle.values, _style, (s) => s.label, (s) => setState(() => _style = s)),
                _chips(tx.formato, ShareCardFormat.values, _format, (f) => f.label, (f) => setState(() => _format = f)),
                FilledButton.icon(
                  key: const Key('share-card-share'),
                  onPressed: _sharing ? null : _share,
                  icon: const Icon(Icons.ios_share_rounded),
                  label: Text(tx.compartirImagen),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
