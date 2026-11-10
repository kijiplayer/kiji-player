import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../theme/kiji_tokens.dart';
import '../../../widgets/nocturne/glass.dart';
import '../../lyrics/presentation/lyrics_share.dart' show renderToPng;
import '../data/theater_store.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// "Tu Teatro": como un resumen del año, en tarjetas. Lo más tomateado, lo más aplaudido y datos
/// graciosos. Todo sale del dispositivo; una tarjeta se guarda o comparte como imagen solo si se
/// toca "Compartir".
class TheaterScreen extends ConsumerStatefulWidget {
  const TheaterScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TheaterScreen()));

  @override
  ConsumerState<TheaterScreen> createState() => _TheaterScreenState();
}

class _TheaterScreenState extends ConsumerState<TheaterScreen> {
  final _keys = [GlobalKey(), GlobalKey(), GlobalKey()];
  final _pages = PageController(viewportFraction: 0.88);
  int _page = 0;
  bool _sharing = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    final file = await renderToPng(_keys[_page], 'kiji-teatro');
    if (!mounted) return;
    setState(() => _sharing = false);
    if (file == null) return;
    try {
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'image/png')]));
    } catch (error) {
      debugPrint('=== TEATRO: no se pudo compartir la tarjeta: ${error.runtimeType} ===');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theater = ref.watch(theaterProvider);
    final cards = [
      _RankCard(title: tx.topTomateadas, emoji: '🍅', entries: theater.topTomatoes(), count: (e) => e.tomatoes),
      _RankCard(title: tx.topAplaudidas, emoji: '🌹', entries: theater.topRoses(), count: (e) => e.roses),
      _FactsCard(theater: theater),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(tx.tuTeatro),
        actions: [
          IconButton(
            key: const Key('theater-share'),
            tooltip: tx.compartirEstaTarjeta,
            onPressed: theater.isEmpty || _sharing ? null : _share,
            icon: _sharing
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: theater.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(tx.tuTeatroVacio, textAlign: TextAlign.center, style: TextStyle(color: KijiColors.muted)),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: cards.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                      child: RepaintBoundary(key: _keys[i], child: cards[i]),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < cards.length; i++)
                        AnimatedContainer(
                          duration: KijiMotion.fast,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _page ? 20 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _page ? KijiColors.violet : KijiColors.waveRest,
                            borderRadius: BorderRadius.circular(KijiRadii.pill),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Glass(
    blur: false,
    radius: KijiRadii.card,
    padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
    // Se desplaza si no entra (pantalla chica, letra grande).
    child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)),
  );
}

class _RankCard extends StatelessWidget {
  const _RankCard({required this.title, required this.emoji, required this.entries, required this.count});

  final String title;
  final String emoji;
  final List<TheaterEntry> entries;
  final int Function(TheaterEntry) count;

  @override
  Widget build(BuildContext context) => _Card(
    children: [
      Text(emoji, style: const TextStyle(fontSize: 44)),
      const SizedBox(height: 8),
      Text(title, style: KijiText.title(size: 26)),
      const SizedBox(height: 18),
      if (entries.isEmpty) Text(tx.nadaPorAhora, style: TextStyle(color: KijiColors.muted)),
      for (final (i, e) in entries.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              SizedBox(width: 30, child: Text('${i + 1}', style: KijiText.mono(size: 18, color: KijiColors.cyan))),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: KijiText.title(size: 16)),
                    Text(e.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: KijiColors.muted, fontSize: 13)),
                  ],
                ),
              ),
              Text('$emoji ${count(e)}', style: KijiText.mono(size: 14)),
            ],
          ),
        ),
      const SizedBox(height: 12),
      Text('Kiji Player', style: KijiText.mono(size: 10)), // l10n-ignore
    ],
  );
}

class _FactsCard extends StatelessWidget {
  const _FactsCard({required this.theater});

  final TheaterState theater;

  @override
  Widget build(BuildContext context) {
    final artist = theater.mostBooedArtist;
    final day = theater.worstDay;
    Widget fact(String big, String small) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(big, style: KijiText.title(size: 22)),
          const SizedBox(height: 2),
          Text(small, style: TextStyle(color: KijiColors.muted)),
        ],
      ),
    );
    return _Card(
      children: [
        const Text('🎭', style: TextStyle(fontSize: 44)),
        const SizedBox(height: 8),
        Text(tx.datosDelTeatro, style: KijiText.title(size: 26)),
        const SizedBox(height: 18),
        fact('🍅 ${theater.totalTomatoes}', tx.tomatesEnTotal),
        fact('🌹 ${theater.totalRoses}', tx.rosasEnTotal),
        if (artist != null) fact(artist.$1, tx.elMasAbucheado(artist.$2)),
        if (day != null) fact(formatDayMonth(day.$1), tx.peorDiaDeTomates(day.$2)),
        const SizedBox(height: 12),
        Text('Kiji Player', style: KijiText.mono(size: 10)), // l10n-ignore
      ],
    );
  }
}

/// "10/11/2026".
String formatDayMonth(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
