import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/track.dart';
import '../../../providers/appearance_provider.dart';
import '../../../providers/playback_provider.dart';
import '../../../screens/player/player_screen.dart' show PlaybackControlsRow;
import '../../../theme/app_theme.dart';
import '../../../theme/kiji_tokens.dart';
import '../../../utils/duration_formatter.dart';
import '../../../widgets/album_cover.dart';
import '../../customize/presentation/track_text.dart';
import '../../settings/data/settings_store.dart';
import '../../settings/domain/app_settings.dart';
import '../../sleep_timer/presentation/timer_waveform.dart';
import '../../translation/presentation/translate_sheet.dart';
import '../../translation/presentation/translated_lyrics.dart';
import '../lyrics_provider.dart';
import 'lyrics_menu_sheet.dart' show LyricsLayoutPicker, lyricsSizeLabel;

import 'package:kiji_player/l10n/l10n.dart';

/// Letra en la PC (ventana ancha), columna derecha: la portada grande, título, artista, la onda,
/// los controles y, debajo, los ajustes de la letra a mano (tamaño, alineación, traducción y
/// sincronía). Va con los colores del estilo (no con los de la letra, siempre oscura): en un
/// estilo claro es una tarjeta clara sobre el fondo oscuro de la letra.
class LyricsSidePanel extends ConsumerWidget {
  const LyricsSidePanel({super.key, required this.track, required this.synced});

  final Track track;

  /// La letra es sincronizada (si no, no hay sincronía que ajustar).
  final bool synced;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final light = KijiColors.palette.isLight;
    return Theme(
      // Vuelve al tema del estilo (la pantalla de la letra fuerza el oscuro).
      data: AppTheme.darkWith(reduceMotion: reduceMotion(context, ref)),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: KijiColors.text),
        child: IconTheme.merge(
          data: IconThemeData(color: KijiColors.text),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 24, 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: light ? KijiColors.surface : KijiColors.glassFill,
                borderRadius: BorderRadius.circular(KijiRadii.card),
                border: Border.all(color: KijiColors.glassBorder),
              ),
              // Material propio: el interruptor y los botones pintan aquí su efecto al tocar.
              child: Material(
                type: MaterialType.transparency,
                child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: TrackArtwork(
                            track: track,
                            size: min(min(box.maxWidth - 48, 320), max(120, box.maxHeight * 0.5)),
                            radius: KijiLook.cover(KijiRadii.cover),
                            showDownloadState: false,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TrackTitleText(
                          track,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: KijiText.title(size: 24),
                        ),
                        const SizedBox(height: 4),
                        TrackArtistText(
                          track,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: KijiColors.muted, fontSize: 15),
                        ),
                        const SizedBox(height: 16),
                        const TimerWaveform(height: 40),
                        const _Times(),
                        const SizedBox(height: 8),
                        // Compactos, y más chicos si la columna es angosta (ventana de 1000 px).
                        const FittedBox(fit: BoxFit.scaleDown, child: PlaybackControlsRow(compact: true)),
                        const SizedBox(height: 20),
                        Divider(color: KijiColors.glassBorder, height: 1),
                        const SizedBox(height: 16),
                        Text(tx.ajustesDeLaLetra, style: KijiText.mono(size: 11)),
                        const SizedBox(height: 12),
                        _LyricsSettings(trackId: track.id, synced: synced),
                      ],
                    ),
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

class _Times extends ConsumerWidget {
  const _Times();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(playbackProvider.select((s) => (position: s.position, duration: s.duration)));
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(formatDuration(p.position), style: KijiText.mono(size: 12)),
          Text(formatDuration(p.duration), style: KijiText.mono(size: 12)),
        ],
      ),
    );
  }
}

/// Tamaño, alineación, traducción y sincronía de la letra.
class _LyricsSettings extends ConsumerWidget {
  const _LyricsSettings({required this.trackId, required this.synced});

  final String trackId;
  final bool synced;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(
      settingsProvider.select((s) => (size: s.lyricsSize, align: s.lyricsAlign, layout: s.lyricsLayout)),
    );
    final notifier = ref.read(settingsProvider.notifier);
    final translating = ref.watch(lyricsTranslationOnProvider);
    final offset = ref.watch(lyricsOffsetProvider(trackId)).valueOrNull ?? Duration.zero;

    Future<void> move(int ms) async {
      await ref.read(lyricsRepositoryProvider).setOffset(trackId, offset + Duration(milliseconds: ms));
      ref.invalidate(lyricsOffsetProvider(trackId));
    }

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: TextStyle(color: KijiColors.muted, fontSize: 13)),
    );

    final seconds = offset.inMilliseconds / 1000;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label(tx.tamanoDeLasLetras),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            for (final option in AppSettings.lyricsSizes)
              ButtonSegment(value: option, label: Text(lyricsSizeLabel(option), maxLines: 1)),
          ],
          selected: {settings.size},
          onSelectionChanged: (v) => notifier.update((s) => s.copyWith(lyricsSize: v.first)),
        ),
        const SizedBox(height: 14),
        label(tx.disenoDeLaLetra),
        LyricsLayoutPicker(
          layout: settings.layout,
          onChanged: (value) => notifier.update((s) => s.copyWith(lyricsLayout: value)),
        ),
        const SizedBox(height: 14),
        label(tx.alineacionDeLaLetra),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: 'start',
              icon: const Icon(Icons.format_align_left_rounded),
              label: Text(tx.alinearIzquierda, maxLines: 1),
            ),
            ButtonSegment(
              value: 'center',
              icon: const Icon(Icons.format_align_center_rounded),
              label: Text(tx.alinearCentro, maxLines: 1),
            ),
          ],
          selected: {settings.align},
          onSelectionChanged: (v) => notifier.update((s) => s.copyWith(lyricsAlign: v.first)),
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tx.traduccion),
          value: translating,
          // Prendida: se elige cómo traducir (teléfono o IA). Apagada: se quita.
          onChanged: (on) =>
              on ? showTranslateSheet(context, ref) : ref.read(lyricsTranslationOnProvider.notifier).state = false,
        ),
        if (synced) ...[
          label(tx.sincroniaDeLaLetra),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => move(-500),
                child: Tooltip(message: tx.laLetraVaDespues, child: const Text('−0,5 s')), // l10n-ignore
              ),
              Expanded(
                child: Text(
                  offset == Duration.zero
                      ? tx.sinDesfase
                      : '${seconds > 0 ? '+' : ''}${seconds.toStringAsFixed(1).replaceAll('.', kijiLanguage == 'es' ? ',' : '.')} s',
                  textAlign: TextAlign.center,
                  style: KijiText.mono(size: 13, color: KijiColors.text),
                ),
              ),
              OutlinedButton(
                onPressed: () => move(500),
                child: Tooltip(message: tx.laLetraVaAntes, child: const Text('+0,5 s')), // l10n-ignore
              ),
            ],
          ),
        ],
      ],
    );
  }
}
