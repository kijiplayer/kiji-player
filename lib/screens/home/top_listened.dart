import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/customize/presentation/track_text.dart';
import '../../features/history/listening_history.dart';
import '../../features/recommendations/presentation/home_sections.dart';
import '../../providers/playback_provider.dart';
import '../../theme/kiji_tokens.dart';
import '../../widgets/album_cover.dart';
import '../../widgets/nocturne/glass.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Dónde se calcula lo de Inicio: "calculado en esta PC" o "calculado en tu teléfono". Nada sale
/// del equipo.
String calculatedHereNote() => switch (defaultTargetPlatform) {
  TargetPlatform.windows || TargetPlatform.linux || TargetPlatform.macOS => tx.calculadoEnEstaPc,
  _ => tx.calculadoEnTuTelefono,
};

/// "Tus más escuchadas": un top con el puesto en grande, la portada grande y cuántas veces la
/// escuchaste. La #1 va destacada arriba; el resto, en filas (dos columnas en pantallas anchas).
class TopListened extends ConsumerWidget {
  const TopListened({super.key, required this.entries});

  final List<HistoryEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final tracks = [for (final e in entries) e.track];
    void play(int index) => ref.read(playbackProvider.notifier).playQueue(tracks, startIndex: index);
    final rest = entries.skip(1).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(tx.tusMasEscuchadas, note: calculatedHereNote()),
        _First(entry: entries.first, onTap: () => play(0)),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, box) {
              final columns = box.maxWidth >= 720 ? 2 : 1;
              final width = (box.maxWidth - 12 * (columns - 1)) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  for (final (i, entry) in rest.indexed)
                    SizedBox(
                      width: width,
                      child: _Row(rank: i + 2, entry: entry, onTap: () => play(i + 1)),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

/// El número del puesto, grande y fino.
class _Rank extends StatelessWidget {
  const _Rank(this.rank, {required this.size});

  final int rank;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
    '$rank',
    textScaler: TextScaler.noScaling,
    style: KijiText.title(
      size: size,
      weight: FontWeight.w300,
      color: rank == 1 ? KijiColors.text : KijiColors.muted,
    ).copyWith(height: 1, fontFeatures: const [FontFeature.tabularFigures()]),
  );
}

/// La #1: tarjeta con el puesto enorme, la portada grande, título, artista y las veces.
class _First extends StatelessWidget {
  const _First({required this.entry, required this.onTap});

  final HistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final track = entry.track;
    return Semantics(
      label: tx.puestoN(1),
      child: Glass(
        blur: false,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: LayoutBuilder(
              builder: (context, box) {
                final cover = min(132.0, box.maxWidth * 0.34);
                return Row(
                  children: [
                    _Rank(1, size: cover * 0.62),
                    const SizedBox(width: 12),
                    TrackArtwork(track: track, size: cover, radius: KijiLook.cover(KijiRadii.tile)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tx.vecesEscuchada(entry.playCount).toUpperCase(), style: KijiText.mono(size: 11)),
                          const SizedBox(height: 6),
                          TrackTitleText(
                            track,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: KijiText.title(size: 20),
                          ),
                          const SizedBox(height: 2),
                          TrackArtistText(
                            track,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: KijiColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Puesto 2 en adelante: el número, la portada, título y artista, y las veces a la derecha.
class _Row extends StatelessWidget {
  const _Row({required this.rank, required this.entry, required this.onTap});

  final int rank;
  final HistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final track = entry.track;
    return Semantics(
      label: tx.puestoN(rank),
      child: InkWell(
        borderRadius: BorderRadius.circular(KijiRadii.tile),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(width: 40, child: Center(child: _Rank(rank, size: 34))),
              const SizedBox(width: 8),
              TrackArtwork(track: track, size: 64, radius: KijiLook.cover(KijiRadii.tile)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrackTitleText(
                      track,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    TrackArtistText(
                      track,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: KijiColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(tx.vecesEscuchada(entry.playCount), style: KijiText.mono(size: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
