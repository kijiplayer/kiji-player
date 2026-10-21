import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/track.dart';
import '../../../screens/player/player_motion.dart';
import '../../../theme/kiji_tokens.dart';
import '../../../widgets/album_cover.dart';
import '../../../widgets/global_mini_player.dart';
import '../../../widgets/kiji_logo.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Texto para compartir unas líneas: entre comillas y con la canción.
String lyricsShareText(List<String> lines, Track track) =>
    '${lines.map((l) => '“$l”').join('\n')}\n— ${track.title}, ${track.artist}';

Future<void> shareLyricsText(List<String> lines, Track track) async {
  try {
    await SharePlus.instance.share(ShareParams(text: lyricsShareText(lines, track)));
  } catch (error) {
    debugPrint('=== LETRAS: no se pudo compartir el texto: $error ===');
  }
}

/// Formatos de la imagen para compartir.
enum CardFormat {
  story(360, 640),
  square(360, 360),
  portrait(360, 450),
  landscape(480, 270),
  minimal(360, null);

  const CardFormat(this.width, this.height);
  String get label => switch (this) {
    CardFormat.story => tx.historia916,
    CardFormat.square => tx.cuadrado11,
    CardFormat.portrait => tx.vertical45,
    CardFormat.landscape => tx.horizontal169,
    CardFormat.minimal => tx.soloTexto,
  };

  final double width;

  /// null: se ajusta al texto.
  final double? height;
}

/// Fondo de la tarjeta.
enum CardBackground {
  blurred,
  solid,
  dark;

  String get label => switch (this) {
    CardBackground.blurred => tx.portadaDifuminada,
    CardBackground.solid => tx.colorDeLaCancion,
    CardBackground.dark => tx.oscuro,
  };
}

/// Qué texto lleva la tarjeta.
enum CardText {
  original,
  translation,
  both;

  String get label => switch (this) {
    CardText.original => 'Original', // l10n-ignore
    CardText.translation => tx.traduccion,
    CardText.both => tx.ambas,
  };
}

/// La tarjeta para compartir unas líneas de la letra.
class LyricsCard extends ConsumerWidget {
  const LyricsCard({
    super.key,
    required this.track,
    required this.lines,
    this.translations,
    this.text = CardText.original,
    this.format = CardFormat.story,
    this.background = CardBackground.blurred,
    this.showLogo = true,
  });

  final Track track;
  final List<String> lines;

  /// Traducción de cada línea elegida (mismo orden), o null.
  final List<String?>? translations;
  final CardText text;
  final CardFormat format;
  final CardBackground background;
  final bool showLogo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = knownCoverAccent(track.id) ?? track.coverColor;
    final image = trackImageProvider(ref, track);
    final minimal = format == CardFormat.minimal;
    final landscape = format == CardFormat.landscape;

    final body = Column(
      mainAxisSize: minimal ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!minimal)
          Row(
            children: [
              TrackArtwork(track: track, size: landscape ? 44 : 56, radius: 12, showDownloadState: false),
              const SizedBox(width: 12),
              Expanded(child: _Names(track: track)),
            ],
          ),
        // Las líneas, centradas en el espacio libre; se achican si no entran (nunca se cortan).
        if (minimal)
          _Lines(lines: lines, translations: translations, text: text, large: true)
        else
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: format.width - 48,
                  child: _Lines(lines: lines, translations: translations, text: text, large: !landscape),
                ),
              ),
            ),
          ),
        if (minimal) ...[
          const SizedBox(height: 14),
          Text(
            '— ${track.title}, ${track.artist}',
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic),
          ),
        ],
        if (showLogo) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              const KijiLogo(size: 18),
              const SizedBox(width: 6),
              Text('KIJI PLAYER', style: KijiText.mono(size: 10, color: Colors.white70)), // l10n-ignore
            ],
          ),
        ],
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(minimal ? 20 : 28),
      child: SizedBox(
        width: format.width,
        height: format.height,
        child: Stack(
          fit: minimal ? StackFit.loose : StackFit.expand,
          children: [
            if (!minimal)
              Positioned.fill(
                child: _Background(background: background, accent: accent, image: image),
              ),
            if (minimal) Positioned.fill(child: ColoredBox(color: _flat(background, accent))),
            Padding(padding: const EdgeInsets.all(24), child: body),
          ],
        ),
      ),
    );
  }

  static Color _flat(CardBackground b, Color accent) =>
      b == CardBackground.dark ? KijiColors.background : Color.lerp(accent, Colors.black, 0.45)!;
}

class _Names extends StatelessWidget {
  const _Names({required this.track});
  final Track track;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: KijiText.title(size: 17, weight: FontWeight.w700),
      ),
      Text(
        track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
      ),
    ],
  );
}

class _Lines extends StatelessWidget {
  const _Lines({required this.lines, required this.translations, required this.text, required this.large});

  final List<String> lines;
  final List<String?>? translations;
  final CardText text;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final main = KijiText.title(size: large ? 26 : 22, weight: FontWeight.w800).copyWith(height: 1.2);
    final sub = TextStyle(color: Colors.white70, fontSize: large ? 17 : 15, fontStyle: FontStyle.italic, height: 1.25);
    final hasTranslation = translations != null && translations!.any((t) => t != null && t.isNotEmpty);
    final mode = hasTranslation ? text : CardText.original;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (mode != CardText.translation) Text(lines[i], style: main),
          if (mode != CardText.original && i < translations!.length && (translations![i]?.isNotEmpty ?? false))
            Padding(
              padding: EdgeInsets.only(top: mode == CardText.both ? 2 : 0),
              child: Text(translations![i]!, style: mode == CardText.translation ? main : sub),
            ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _Background extends StatelessWidget {
  const _Background({required this.background, required this.accent, required this.image});

  final CardBackground background;
  final Color accent;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    switch (background) {
      case CardBackground.dark:
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.lerp(accent, KijiColors.background, 0.82)!, KijiColors.background],
            ),
          ),
        );
      case CardBackground.solid:
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(accent, Colors.black, 0.25)!, Color.lerp(accent, Colors.black, 0.6)!],
            ),
          ),
        );
      case CardBackground.blurred:
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: KijiColors.background),
            if (image != null)
              Image(
                image: ResizeImage(image!, width: 24, height: 24),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            const ColoredBox(color: Color(0x8C000000)),
          ],
        );
    }
  }
}

/// Compartir como imagen: vista previa en vivo con formato, fondo, texto y logo.
Future<void> showLyricsCardDialog(
  BuildContext context,
  List<String> lines,
  Track track, {
  List<String?>? translations,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      settings: const RouteSettings(name: KijiRoutes.share),
      builder: (_) => _ShareCardScreen(lines: lines, track: track, translations: translations),
    ),
  );
}

class _ShareCardScreen extends StatefulWidget {
  const _ShareCardScreen({required this.lines, required this.track, this.translations});

  final List<String> lines;
  final Track track;
  final List<String?>? translations;

  @override
  State<_ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<_ShareCardScreen> {
  final _key = GlobalKey();
  var _format = CardFormat.story;
  var _background = CardBackground.blurred;
  var _text = CardText.original;
  var _logo = true;
  bool _sharing = false;

  bool get _hasTranslation => widget.translations?.any((t) => t != null && t.isNotEmpty) ?? false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    final file = await renderToPng(_key, 'kiji-letra');
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
      debugPrint('=== LETRAS: no se pudo compartir la imagen: $error ===');
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
                ChoiceChip(label: Text(label(v)), selected: v == selected, onSelected: (_) => onPick(v)),
            ],
          ),
          const SizedBox(height: 14),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tx.compartirComoImagen)),
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
                      child: LyricsCard(
                        track: widget.track,
                        lines: widget.lines,
                        translations: widget.translations,
                        text: _text,
                        format: _format,
                        background: _background,
                        showLogo: _logo,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _chips(tx.formato, CardFormat.values, _format, (f) => f.label, (f) => setState(() => _format = f)),
                    _chips(
                      tx.fondo,
                      CardBackground.values,
                      _background,
                      (b) => b.label,
                      (b) => setState(() => _background = b),
                    ),
                    if (_hasTranslation)
                      _chips(tx.texto, CardText.values, _text, (t) => t.label, (t) => setState(() => _text = t)),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(tx.logoDeKiji),
                      value: _logo,
                      onChanged: (v) => setState(() => _logo = v),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _sharing ? null : _share,
                  icon: const Icon(Icons.ios_share_rounded),
                  label: Text(tx.compartirImagen),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dibuja el widget de [key] en un PNG temporal.
Future<File?> renderToPng(GlobalKey key, String name) async {
  try {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return null;
    final file = File(
      p.join((await getTemporaryDirectory()).path, '$name-${DateTime.now().millisecondsSinceEpoch}.png'),
    );
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return file;
  } catch (error) {
    debugPrint('=== LETRAS: no se pudo dibujar la tarjeta: $error ===');
    return null;
  }
}
