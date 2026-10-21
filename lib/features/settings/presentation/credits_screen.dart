import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/kiji_tokens.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Un bloque de `CREDITS.md`, ya simplificado para mostrarlo en pantalla.
sealed class CreditsBlock {
  const CreditsBlock(this.text);
  final String text;
}

class CreditsHeading extends CreditsBlock {
  const CreditsHeading(super.text, this.level);
  final int level;
}

class CreditsParagraph extends CreditsBlock {
  const CreditsParagraph(super.text);
}

class CreditsBullet extends CreditsBlock {
  const CreditsBullet(super.text);
}

/// Una fila de tabla: sus celdas, sin el formato de Markdown.
class CreditsRow extends CreditsBlock {
  CreditsRow(this.cells, {this.header = false}) : super(cells.join(' · '));
  final List<String> cells;
  final bool header;
}

/// Quita el formato en línea: `[texto](url)` → texto, `**x**` → x, `` `x` `` → x.
/// Los enlaces no se abren desde la app (nada sale del teléfono sin pedirlo).
String stripInlineMarkdown(String text) => text
    .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m[1]!)
    .replaceAll('**', '')
    .replaceAll('`', '')
    .trim();

/// Convierte `CREDITS.md` en bloques simples (títulos, párrafos, viñetas y
/// filas de tabla). Alcanza para ese archivo; no es un Markdown completo.
List<CreditsBlock> parseCredits(String markdown) {
  final blocks = <CreditsBlock>[];
  for (final raw in markdown.split('\n')) {
    final line = raw.trimRight();
    if (line.trim().isEmpty) continue;
    final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
    if (heading != null) {
      blocks.add(CreditsHeading(stripInlineMarkdown(heading[2]!), heading[1]!.length));
    } else if (line.trimLeft().startsWith('|')) {
      final cells = line.trim().replaceAll(RegExp(r'^\||\|$'), '').split('|').map((c) => c.trim()).toList();
      if (cells.every((c) => RegExp(r'^:?-{3,}:?$').hasMatch(c))) continue; // |---|---|
      final isHeader = blocks.isEmpty || blocks.last is! CreditsRow;
      blocks.add(CreditsRow([for (final c in cells) stripInlineMarkdown(c)], header: isHeader));
    } else if (RegExp(r'^\s*(-|\*|\d+\.)\s+').hasMatch(line)) {
      blocks.add(CreditsBullet(stripInlineMarkdown(line.replaceFirst(RegExp(r'^\s*(-|\*|\d+\.)\s+'), ''))));
    } else if (line.startsWith('>')) {
      blocks.add(CreditsParagraph(stripInlineMarkdown(line.substring(1))));
    } else {
      blocks.add(CreditsParagraph(stripInlineMarkdown(line)));
    }
  }
  return blocks;
}

/// "Acerca de → Créditos": muestra `CREDITS.md` dentro de la app.
class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key, this.bundle});

  /// Para tests; si es null usa el de la app.
  final AssetBundle? bundle;

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CreditsScreen()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tx.creditos)),
      body: FutureBuilder<String>(
        future: (bundle ?? rootBundle).loadString('CREDITS.md'),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(tx.noSePudieronLeerLosCreditos));
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final blocks = parseCredits(snapshot.data!);
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            itemCount: blocks.length,
            itemBuilder: (context, index) => _CreditsBlockView(block: blocks[index]),
          );
        },
      ),
    );
  }
}

class _CreditsBlockView extends StatelessWidget {
  const _CreditsBlockView({required this.block});

  final CreditsBlock block;

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      CreditsHeading(:final text, :final level) => Padding(
        padding: EdgeInsets.only(top: level == 1 ? 8 : 20, bottom: 8),
        child: Text(text, style: KijiText.title(size: level == 1 ? 26 : 18)),
      ),
      CreditsParagraph(:final text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: TextStyle(color: KijiColors.muted, height: 1.4)),
      ),
      CreditsBullet(:final text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 8),
        child: Text('•  $text', style: TextStyle(color: KijiColors.muted, height: 1.4)),
      ),
      CreditsRow(:final cells, :final header) =>
        header
            ? const SizedBox.shrink() // los encabezados de tabla no aportan en pantalla angosta
            : Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: KijiColors.glassFill,
                  borderRadius: BorderRadius.circular(KijiRadii.tile),
                  border: Border.all(color: KijiColors.glassBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cells.first, style: const TextStyle(fontWeight: FontWeight.w600)),
                    for (final cell in cells.skip(1))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(cell, style: TextStyle(color: KijiColors.muted, fontSize: 13)),
                      ),
                  ],
                ),
              ),
    };
  }
}
