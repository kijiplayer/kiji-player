import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../theme/kiji_tokens.dart';
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
  final _keys = [GlobalKey(), GlobalKey(), GlobalKey(), GlobalKey()];
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
      _NowShowingPoster(theater: theater),
      _RankPoster(
        title: tx.teatroMasAbucheadas,
        emoji: '🍅',
        entries: theater.topTomatoes(),
        count: (e) => e.tomatoes,
        // Mantener presionada una abucheada: "perdonarla" (vuelve a recomendarse).
        onLongPress: (e) {
          if (!e.booed) return;
          ref.read(theaterProvider.notifier).forgive(e.id);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tx.perdonadaVuelveARecomendarse(e.title))));
        },
      ),
      _RankPoster(title: tx.topAplaudidas, emoji: '🌹', entries: theater.topRoses(), count: (e) => e.roses),
      _AwardsPoster(theater: theater, now: DateTime.now()),
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
                child: Text(
                  tx.tuTeatroVacio,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: KijiColors.muted),
                ),
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
                            color: i == _page ? KijiColors.theaterPosterAccent : KijiColors.waveRest,
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

/// Un cartel de teatro antiguo: papel, marco doble, luces de marquesina arriba y abajo y letra
/// con serifa. Se desplaza si no entra (pantalla chica, letra grande).
class _Poster extends StatelessWidget {
  const _Poster({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final accent = KijiColors.theaterPosterAccent;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KijiColors.theaterPosterPaper,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent, width: 2),
        boxShadow: [BoxShadow(color: KijiColors.background.withValues(alpha: 0.5), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: accent.withValues(alpha: 0.7))),
          child: Column(
            children: [
              const _Bulbs(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                ),
              ),
              const _Bulbs(),
            ],
          ),
        ),
      ),
    );
  }
}

/// La fila de luces de la marquesina (una sí, una no, más fuertes).
class _Bulbs extends StatelessWidget {
  const _Bulbs();

  @override
  Widget build(BuildContext context) {
    final accent = KijiColors.theaterPosterAccent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < 13; i++)
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: i.isEven ? 1 : 0.4),
                boxShadow: i.isEven ? [BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 6)] : null,
              ),
            ),
        ],
      ),
    );
  }
}

/// Encabezado de cartel: "KIJI · TEATRO", el título grande y un adorno.
class _Heading extends StatelessWidget {
  const _Heading({required this.title, this.emoji});

  final String title;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    final accent = KijiColors.theaterPosterAccent;
    return Column(
      children: [
        Text('KIJI  ·  TEATRO', textAlign: TextAlign.center, style: KijiText.poster(size: 12, spacing: 4, color: accent)), // l10n-ignore
        const SizedBox(height: 10),
        if (emoji != null) Text(emoji!, style: const TextStyle(fontSize: 38)),
        Text(title.toUpperCase(), textAlign: TextAlign.center, style: KijiText.poster(size: 26, spacing: 1)),
        const SizedBox(height: 8),
        const _Ornament(),
        const SizedBox(height: 14),
      ],
    );
  }
}

class _Ornament extends StatelessWidget {
  const _Ornament();

  @override
  Widget build(BuildContext context) {
    final accent = KijiColors.theaterPosterAccent;
    final line = Expanded(child: Container(height: 1, color: accent.withValues(alpha: 0.6)));
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('✦  ✦  ✦', style: KijiText.poster(size: 12, color: accent)), // l10n-ignore
        ),
        line,
      ],
    );
  }
}

/// "En cartelera": la estrella de la temporada (la de más rosas) y los totales.
class _NowShowingPoster extends StatelessWidget {
  const _NowShowingPoster({required this.theater});

  final TheaterState theater;

  @override
  Widget build(BuildContext context) {
    final star = theater.topRoses(1).firstOrNull;
    final ink = KijiColors.theaterPosterInk;
    final accent = KijiColors.theaterPosterAccent;
    return _Poster(
      children: [
        _Heading(title: tx.teatroEnCartelera),
        if (star == null)
          Text(tx.teatroSinFuncion, textAlign: TextAlign.center, style: KijiText.poster(size: 16, weight: FontWeight.w400))
        else ...[
          Text(tx.teatroEstrella, textAlign: TextAlign.center, style: KijiText.poster(size: 14, weight: FontWeight.w400, color: accent)),
          const SizedBox(height: 10),
          Text('«${star.title}»', textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: KijiText.poster(size: 34)),
          const SizedBox(height: 6),
          Text(star.artist, textAlign: TextAlign.center, style: KijiText.poster(size: 18, weight: FontWeight.w400, color: ink)),
          const SizedBox(height: 6),
          Text('🌹 × ${star.roses}', textAlign: TextAlign.center, style: KijiText.poster(size: 18, color: accent)),
        ],
        const SizedBox(height: 18),
        const _Ornament(),
        const SizedBox(height: 10),
        Text(
          tx.teatroFunciones(theater.totalTomatoes, theater.totalRoses),
          textAlign: TextAlign.center,
          style: KijiText.poster(size: 15, weight: FontWeight.w400),
        ),
        const SizedBox(height: 6),
        Text('Kiji Player', textAlign: TextAlign.center, style: KijiText.poster(size: 11, spacing: 3, color: accent)), // l10n-ignore
      ],
    );
  }
}

/// Un ranking de cartel: los puestos en números romanos, el título y el artista.
class _RankPoster extends StatelessWidget {
  const _RankPoster({
    required this.title,
    required this.emoji,
    required this.entries,
    required this.count,
    this.onLongPress,
  });

  final String title;
  final String emoji;
  final List<TheaterEntry> entries;
  final int Function(TheaterEntry) count;
  final void Function(TheaterEntry entry)? onLongPress;

  static const _roman = ['I', 'II', 'III', 'IV', 'V']; // l10n-ignore

  @override
  Widget build(BuildContext context) {
    final accent = KijiColors.theaterPosterAccent;
    return _Poster(
      children: [
        _Heading(title: title, emoji: emoji),
        if (entries.isEmpty) Text(tx.nadaPorAhora, textAlign: TextAlign.center, style: KijiText.poster(size: 16, weight: FontWeight.w400)),
        for (final (i, e) in entries.indexed)
          GestureDetector(
            onLongPress: onLongPress == null ? null : () => onLongPress!(e),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  SizedBox(width: 40, child: Text(_roman[i.clamp(0, 4)], style: KijiText.poster(size: 22, color: accent))),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: KijiText.poster(size: 18)),
                        Text(e.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: KijiText.poster(size: 13, weight: FontWeight.w400)),
                      ],
                    ),
                  ),
                  Text('$emoji ${count(e)}', style: KijiText.poster(size: 15, color: accent)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 6),
        Text('Kiji Player', textAlign: TextAlign.center, style: KijiText.poster(size: 11, spacing: 3, color: accent)), // l10n-ignore
      ],
    );
  }
}

/// Los premios del público (graciosos): la más odiada del mes, la ovación de la temporada, el
/// artista más abucheado, la peor función y cuántas salieron de escena.
class _AwardsPoster extends StatelessWidget {
  const _AwardsPoster({required this.theater, required this.now});

  final TheaterState theater;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final accent = KijiColors.theaterPosterAccent;
    final hated = theater.mostHatedOfMonth(now);
    final loved = theater.topRoses(1).firstOrNull;
    final artist = theater.mostBooedArtist;
    final day = theater.worstDay;
    final off = theater.booedOff.length;
    Widget award(String emoji, String prize, String winner, String detail) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Text('$emoji  ${prize.toUpperCase()}', textAlign: TextAlign.center, style: KijiText.poster(size: 12, spacing: 1.5, color: accent)),
          const SizedBox(height: 3),
          Text(winner, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: KijiText.poster(size: 20)),
          Text(detail, textAlign: TextAlign.center, style: KijiText.poster(size: 13, weight: FontWeight.w400)),
        ],
      ),
    );
    return _Poster(
      children: [
        _Heading(title: tx.teatroPremios, emoji: '🏆'),
        if (hated != null) award('🍅', tx.teatroPremioOdiadaMes, '«${hated.title}»', '${hated.artist} · 🍅 ${hated.tomatoes}'),
        if (loved != null) award('🌹', tx.teatroPremioOvacion, '«${loved.title}»', '${loved.artist} · 🌹 ${loved.roses}'),
        if (artist != null) award('😤', tx.teatroPremioArtista, artist.$1, '🍅 ${artist.$2}'),
        if (day != null) award('🌧', tx.teatroPremioNoche, formatDayMonth(day.$1), '🍅 ${day.$2}'),
        award('🎭', tx.teatroPremioTelon, tx.teatroCanciones(off), ''),
        Text('Kiji Player', textAlign: TextAlign.center, style: KijiText.poster(size: 11, spacing: 3, color: accent)), // l10n-ignore
      ],
    );
  }
}

/// "10/11/2026".
String formatDayMonth(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
