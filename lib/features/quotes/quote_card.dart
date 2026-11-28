import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../theme/kiji_tokens.dart';
import '../../widgets/kiji_logo.dart';
import '../../widgets/nocturne/glass.dart';
import '../lyrics/presentation/lyrics_share.dart' show renderToPng;
import '../share_cards/now_playing_card.dart' show kijiCardUrl;
import 'quotes.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// En Inicio: la frase de ahora, con su autor y su fuente, y «Compartir».
class DailyQuoteCard extends ConsumerWidget {
  const DailyQuoteCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quote = ref.watch(currentQuoteProvider);
    if (quote == null) return const SizedBox.shrink();
    return Glass(
      key: Key('daily-quote-${quote.id}'),
      blur: false,
      radius: KijiRadii.tile,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 6, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.fraseDelDia.toUpperCase(), style: KijiText.mono(size: 11)),
                  const SizedBox(height: 6),
                  Text('«${quote.text}»', style: KijiText.title(size: 16)),
                  const SizedBox(height: 6),
                  Text(
                    '${quote.authorText} · ${quote.sourceText}',
                    style: TextStyle(color: KijiColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('daily-quote-share'),
              tooltip: tx.compartirFrase,
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => _QuoteShareScreen(quote: quote)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La imagen para compartir: la frase, su autor, el logo y la página de Kiji (9:16).
class QuoteImage extends StatelessWidget {
  const QuoteImage({super.key, required this.quote});

  final Quote quote;

  @override
  Widget build(BuildContext context) {
    const ink = Colors.white;
    final muted = Colors.white.withValues(alpha: 0.72);
    return SizedBox(
      width: 360,
      height: 640,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A1F5C), Color(0xFF0B0B14), Color(0xFF0E3440)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('“', style: KijiText.display(size: 72).copyWith(color: muted, height: 0.8)),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 304,
                      child: Text(quote.text, style: KijiText.display(size: 30).copyWith(color: ink, height: 1.15)),
                    ),
                  ),
                ),
              ),
              Text(quote.authorText, style: KijiText.title(size: 18).copyWith(color: ink)),
              const SizedBox(height: 2),
              Text(quote.sourceText, style: TextStyle(color: muted, fontSize: 12)),
              const SizedBox(height: 24),
              Row(
                children: [
                  const KijiLogo(size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(kijiCardUrl, style: KijiText.mono(size: 11, color: muted)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuoteShareScreen extends StatefulWidget {
  const _QuoteShareScreen({required this.quote});

  final Quote quote;

  @override
  State<_QuoteShareScreen> createState() => _QuoteShareScreenState();
}

class _QuoteShareScreenState extends State<_QuoteShareScreen> {
  final _key = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    final file = await renderToPng(_key, 'kiji-frase');
    if (!mounted) return;
    setState(() => _sharing = false);
    if (file == null) return;
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: '«${widget.quote.text}» — ${widget.quote.authorText}',
        ),
      );
    } catch (error) {
      debugPrint('=== FRASES: no se pudo compartir la imagen: ${error.runtimeType} ===');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tx.compartirFrase)),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: FittedBox(child: RepaintBoundary(key: _key, child: QuoteImage(quote: widget.quote))),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('quote-share'),
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
