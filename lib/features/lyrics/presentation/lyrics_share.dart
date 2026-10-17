import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/track.dart';
import '../../../theme/kiji_tokens.dart';
import '../../../widgets/album_cover.dart';

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

/// Tarjeta Kiji Nocturne con la carátula, las líneas y el nombre (Tarea Z4).
class LyricsCard extends StatelessWidget {
  const LyricsCard({super.key, required this.track, required this.lines});

  final Track track;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(track.coverColor, KijiColors.background, 0.35)!, KijiColors.background],
        ),
        border: Border.all(color: KijiColors.glassBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TrackArtwork(track: track, size: 56, radius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: KijiText.title(size: 16, weight: FontWeight.w700)),
                    Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: KijiColors.muted, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(line, style: KijiText.title(size: 22, weight: FontWeight.w700)),
            ),
          const SizedBox(height: 14),
          Container(height: 2, width: 48, decoration: const BoxDecoration(gradient: KijiColors.accentGradient)),
          const SizedBox(height: 8),
          Text('KIJI PLAYER', style: KijiText.mono(size: 10)),
        ],
      ),
    );
  }
}

/// Vista previa de la tarjeta y botón para compartirla como imagen.
Future<void> showLyricsCardDialog(BuildContext context, List<String> lines, Track track) {
  final key = GlobalKey();
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(child: RepaintBoundary(key: key, child: LyricsCard(track: track, lines: lines))),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () async {
                    final file = await renderToPng(key, 'kiji-letra');
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    if (file == null) return;
                    try {
                      await SharePlus.instance.share(ShareParams(
                        files: [XFile(file.path, mimeType: 'image/png')],
                        text: '${track.title} — ${track.artist}',
                      ));
                    } catch (error) {
                      debugPrint('=== LETRAS: no se pudo compartir la imagen: $error ===');
                    }
                  },
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Compartir imagen'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Dibuja el widget de [key] en un PNG temporal.
Future<File?> renderToPng(GlobalKey key, String name) async {
  try {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return null;
    final file = File(p.join((await getTemporaryDirectory()).path, '$name-${DateTime.now().millisecondsSinceEpoch}.png'));
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return file;
  } catch (error) {
    debugPrint('=== LETRAS: no se pudo dibujar la tarjeta: $error ===');
    return null;
  }
}
