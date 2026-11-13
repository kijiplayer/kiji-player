import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/kiji_tokens.dart';
import '../../../widgets/nocturne/glass.dart';
import '../data/auto_downloads.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Varias canciones bajándose juntas (desde la selección): cuántas van, el avance de todas, por
/// qué esperan (sin WiFi, ahorro de datos, sin espacio) y "Cancelar". No se ve si no hay una tanda.
class BatchDownloadProgress extends ConsumerWidget {
  const BatchDownloadProgress({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batch = ref.watch(batchProgressProvider);
    if (batch == null) return const SizedBox.shrink();
    final percent = (batch.fraction * 100).floor();
    return Padding(
      padding: padding,
      child: Glass(
        key: const Key('batch-download-progress'),
        blur: false,
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
        child: Semantics(
          liveRegion: true,
          label: tx.bajandoNDeM(batch.done + batch.failed, batch.total),
          value: '$percent %',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.download_rounded, size: 20, color: KijiColors.cyan),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tx.bajandoNDeM(batch.done + batch.failed, batch.total),
                      style: KijiText.title(size: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('$percent %', style: KijiText.mono(size: 12)),
                  TextButton(
                    key: const Key('batch-download-cancel'),
                    onPressed: () => ref.read(autoDownloadsProvider.notifier).cancelBatch(),
                    child: Text(tx.cancelar),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(KijiRadii.pill),
                  child: SizedBox(
                    height: 5,
                    child: Stack(
                      children: [
                        Positioned.fill(child: ColoredBox(color: KijiColors.waveRest)),
                        FractionallySizedBox(
                          widthFactor: batch.fraction,
                          heightFactor: 1,
                          child: DecoratedBox(decoration: BoxDecoration(gradient: KijiColors.accentGradient)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (batch.waitingReason != null || batch.failed > 0) ...[
                const SizedBox(height: 6),
                Text(
                  [
                    ?batch.waitingReason,
                    if (batch.failed > 0) tx.nNoSePudieron(batch.failed),
                  ].join(' · '),
                  style: TextStyle(color: KijiColors.muted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
