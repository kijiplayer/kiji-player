import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../models/track.dart';
import '../../../theme/kiji_tokens.dart';
import '../../../widgets/nocturne/kiji_sheet.dart';
import '../../lyrics/presentation/lyrics_views.dart' show lyricsPanelLabel;
import '../../style/data/background_store.dart';
import '../../style/presentation/accent_picker.dart';
import '../../style/presentation/style_parts.dart';
import '../data/track_overrides.dart';

/// "Estilo de esta canción" (⋯ del reproductor): el fondo, el color de acento y la vista de la
/// letra solo para [track], con la vista previa en vivo (se aplica en el momento, porque suena) y
/// "Volver al estilo general".
Future<void> showTrackStyleSheet(BuildContext context, WidgetRef ref, Track track) => showKijiSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => TrackStyleSheet(track: track),
);

class TrackStyleSheet extends ConsumerWidget {
  const TrackStyleSheet({super.key, required this.track});

  final Track track;

  Future<void> _chooseBackground(BuildContext context, WidgetRef ref, {required bool video}) async {
    final store = ref.read(backgroundStoreProvider);
    try {
      final path = await store.pick(video: video);
      if (path == null) return;
      final previous = ref.read(trackOverridesProvider)[track.id]?.backgroundFile;
      final name = await store.keepForTrack(track.id, path, previous: previous);
      ref
          .read(trackOverridesProvider.notifier)
          .setStyle(track.id, (s) => s.copyWith(backgroundFile: name, backgroundKind: video ? 'video' : 'image'));
    } catch (error) {
      debugPrint('=== ESTILO DE CANCION: no se pudo usar el fondo: $error ===');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tx.fondoNoSePudo)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(trackOverridesProvider.select((all) => all[track.id])) ?? const TrackOverride();
    final notifier = ref.read(trackOverridesProvider.notifier);
    final store = ref.read(backgroundStoreProvider);

    Widget dot(Color color, {required bool selected, required VoidCallback onTap, String? label}) => Tooltip(
      message: label ?? colorHex(color),
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Container(
          width: 36,
          height: 36,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: selected ? KijiColors.text : Colors.transparent, width: 2),
          ),
          child: ClipOval(child: ColoredBox(color: color)),
        ),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx.estiloDeEstaCancion, style: KijiText.title(size: 20)),
                    const SizedBox(height: 4),
                    Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: KijiColors.muted)),
                  ],
                ),
              ),
              // La vista previa en vivo: la miniatura con los colores que suenan ahora.
              SizedBox(
                width: 86,
                child: StylePreview(style: KijiLook.style, palette: KijiColors.palette, titleFont: KijiText.titleFamily),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(tx.colorDeAcento.toUpperCase(), style: KijiText.mono(size: 11)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: Text(tx.elGeneral),
                selected: style.accent == null,
                onSelected: (_) => notifier.setStyle(track.id, (s) => s.copyWith(clearAccent: true)),
              ),
              for (final color in accentSwatches)
                dot(
                  color,
                  selected: style.accent == color.toARGB32(),
                  onTap: () => notifier.setStyle(track.id, (s) => s.copyWith(accent: color.toARGB32())),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(tx.fondo.toUpperCase(), style: KijiText.mono(size: 11)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(tx.elGeneral),
                selected: style.backgroundFile == null,
                onSelected: (_) async {
                  final old = style.backgroundFile;
                  notifier.setStyle(track.id, (s) => s.copyWith(clearBackground: true));
                  await store.removeTrack(old);
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.image_outlined),
                label: Text(tx.elegirImagen),
                onPressed: () => _chooseBackground(context, ref, video: false),
              ),
              if (BackgroundStore.videoSupported)
                OutlinedButton.icon(
                  icon: const Icon(Icons.movie_outlined),
                  label: Text(tx.elegirVideo),
                  onPressed: () => _chooseBackground(context, ref, video: true),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(tx.vistaDeLaLetra.toUpperCase(), style: KijiText.mono(size: 11)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(tx.elGeneral),
                selected: style.lyricsPanel == null,
                onSelected: (_) => notifier.setStyle(track.id, (s) => s.copyWith(clearLyricsPanel: true)),
              ),
              for (final panel in const ['full', 'simple', 'showcase'])
                ChoiceChip(
                  label: Text(lyricsPanelLabel(panel)),
                  selected: style.lyricsPanel == panel,
                  onSelected: (_) => notifier.setStyle(track.id, (s) => s.copyWith(lyricsPanel: panel)),
                ),
            ],
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            key: const Key('track-style-reset'),
            icon: const Icon(Icons.restart_alt_rounded),
            label: Text(tx.volverAlEstiloGeneral),
            onPressed: style.hasStyle
                ? () async {
                    final old = style.backgroundFile;
                    notifier.clearStyle(track.id);
                    await store.removeTrack(old);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
