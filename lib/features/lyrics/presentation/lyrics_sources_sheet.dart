import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/kiji_tokens.dart';
import '../../settings/data/settings_store.dart';
import '../../translation/presentation/lyrics_settings_screens.dart';
import '../data/lyrics_repository.dart';
import '../domain/lyrics.dart';
import '../lyrics_provider.dart';

import 'package:kiji_player/l10n/l10n.dart';
import 'package:kiji_player/widgets/nocturne/kiji_sheet.dart';

/// ⋯ → Fuente: todas las fuentes de letras, cuál se usa ahora, cuáles tienen esta letra y si está
/// sincronizada. Tocar una fuente que la tiene la usa para esta canción.
Future<void> showLyricsSourcesSheet(
  BuildContext context,
  LyricsRequest request, {
  required LyricsSource? current,
  required VoidCallback onSearchByHand,
  required VoidCallback onImport,
}) {
  return showKijiSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black38,
    showDragHandle: false,
    builder: (_) => AlwaysDark(
      child: _SourcesSheet(request: request, current: current, onSearchByHand: onSearchByHand, onImport: onImport),
    ),
  );
}

class _SourcesSheet extends ConsumerStatefulWidget {
  const _SourcesSheet({
    required this.request,
    required this.current,
    required this.onSearchByHand,
    required this.onImport,
  });

  final LyricsRequest request;
  final LyricsSource? current;
  final VoidCallback onSearchByHand;
  final VoidCallback onImport;

  @override
  ConsumerState<_SourcesSheet> createState() => _SourcesSheetState();
}

class _SourcesSheetState extends ConsumerState<_SourcesSheet> {
  final Map<LyricsSource, LyricsProbe> _results = {};
  StreamSubscription<LyricsProbe>? _sub;
  LyricsSource? _current;

  @override
  void initState() {
    super.initState();
    _current = widget.current;
    final settings = ref.read(settingsProvider);
    _sub = ref
        .read(lyricsRepositoryProvider)
        .probe(widget.request, disabled: settings.disabledLyricsSources)
        .listen((probe) => setState(() => _results[probe.source] = probe));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _choose(LyricsProbe probe) async {
    final lyrics = probe.lyrics;
    if (lyrics == null) return;
    await ref.read(lyricsRepositoryProvider).choose(widget.request.id, lyrics);
    ref.invalidate(lyricsProvider(widget.request));
    ref.invalidate(lyricsOffsetProvider(widget.request.id));
    if (mounted) setState(() => _current = probe.source);
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(settingsProvider.select((s) => s.lyricsSourceOrder));
    final pending = order.where((s) => !_results.containsKey(s)).length;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        // Material (no un Container con color): los ListTile y sus toques se dibujan sobre él.
        child: Material(
          color: const Color(0xCC0B0B12),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
            child: SafeArea(
              top: false,
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(tx.fuenteDeLaLetra, style: KijiText.title(size: 22, color: Colors.white)),
                  const SizedBox(height: 6),
                  Text(
                    pending > 0 ? tx.preguntandoALasFuentes(pending) : tx.tocaUnaFuenteQueTengaLa,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  for (final source in [if (_current != null && !order.contains(_current)) _current!, ...order])
                    _SourceRow(
                      source: source,
                      probe: _results[source],
                      inUse: source == _current,
                      onTap: _results[source]?.lyrics == null || source == _current
                          ? null
                          : () => _choose(_results[source]!),
                    ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12),
                  _ActionRow(
                    icon: Icons.manage_search_rounded,
                    text: tx.buscarConOtroTituloOArtista,
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onSearchByHand();
                    },
                  ),
                  _ActionRow(
                    icon: Icons.file_open_outlined,
                    text: tx.importarUnArchivoLrc,
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onImport();
                    },
                  ),
                  _ActionRow(
                    icon: Icons.swap_vert_rounded,
                    text: tx.cambiarElOrdenDeLasFuentes,
                    onTap: () {
                      Navigator.of(context).pop();
                      LyricsSourcesScreen.open(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source, required this.probe, required this.inUse, required this.onTap});

  final LyricsSource source;
  final LyricsProbe? probe;
  final bool inUse;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (probe?.state) {
      null => (inUse ? tx.enUso : tx.buscando, Colors.white54),
      LyricsProbeState.synced => (tx.sincronizada, KijiColors.cyan),
      LyricsProbeState.plain => (tx.sinSincronizar, Colors.white),
      LyricsProbeState.none => (tx.noLaTiene, Colors.white38),
      LyricsProbeState.failed => (tx.noRespondio2, Colors.white38),
      LyricsProbeState.off => (tx.apagada, Colors.white38),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: inUse ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(KijiRadii.tile),
        child: InkWell(
          borderRadius: BorderRadius.circular(KijiRadii.tile),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  inUse ? Icons.check_circle_rounded : Icons.lyrics_outlined,
                  color: inUse ? KijiColors.cyan : Colors.white54,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.label,
                        style: KijiText.title(size: 17, weight: FontWeight.w600, color: Colors.white),
                      ),
                      if (inUse) Text(tx.esLaQueVesAhora, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (probe == null && !inUse)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Text(
                    label,
                    style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.text, required this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    leading: Icon(icon, color: Colors.white70),
    title: Text(text, style: const TextStyle(fontSize: 16)),
    onTap: onTap,
  );
}
