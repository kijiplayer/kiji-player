import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/kiji_tokens.dart';

/// Nombre de [style] en la interfaz.
String styleName(KijiStyle style) => switch (style) {
  KijiStyle.nocturne => tx.estiloNocturne,
  KijiStyle.graphite => tx.estiloGrafito,
  KijiStyle.paper => tx.estiloPapel,
};

/// Nombre de cada opción de "Tipografía" (las fuentes van con su nombre propio).
String fontLabel(String font) => switch (font) {
  'system' => tx.tipografiaSistema,
  'spacegrotesk' => 'Space Grotesk', // l10n-ignore
  'inter' => 'Inter', // l10n-ignore
  'newsreader' => 'Newsreader', // l10n-ignore
  'jetbrainsmono' => 'JetBrains Mono', // l10n-ignore
  _ => tx.tipografiaKiji,
};

String _phrase(KijiStyle style) => switch (style) {
  KijiStyle.nocturne => tx.estiloNocturneFrase,
  KijiStyle.graphite => tx.estiloGrafitoFrase,
  KijiStyle.paper => tx.estiloPapelFrase,
};

/// Un estilo con su miniatura, para elegirlo ("Personaliza Kiji", paso 1).
class StyleCard extends StatelessWidget {
  const StyleCard({super.key, required this.style, required this.selected, required this.wide, required this.onTap});

  final KijiStyle style;
  final bool selected;
  final bool wide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: Text(styleName(style), style: KijiText.title(size: 18))),
            if (selected) Icon(Icons.check_circle_rounded, color: KijiColors.text, size: 22),
          ],
        ),
        const SizedBox(height: 4),
        Text(_phrase(style), style: TextStyle(color: KijiColors.muted, height: 1.3)),
      ],
    );
    // Un solo anuncio por tarjeta: "Papel. Claro y tranquilo…".
    return Semantics(
      button: true,
      selected: selected,
      label: '${styleName(style)}. ${_phrase(style)}',
      excludeSemantics: true,
      child: Material(
        color: KijiColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? KijiColors.text : KijiColors.glassBorder, width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: wide
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [StylePreview(style: style), const SizedBox(height: 12), text],
                  )
                : Row(
                    children: [
                      SizedBox(width: 112, child: StylePreview(style: style)),
                      const SizedBox(width: 14),
                      Expanded(child: text),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Miniatura del reproductor en [style]: se dibuja con la paleta y la letra de ese estilo, no con
/// las del estilo activo (así se ven los tres a la vez).
class StylePreview extends StatelessWidget {
  const StylePreview({super.key, required this.style, this.palette, this.titleFont});

  final KijiStyle style;

  /// Para la vista previa en vivo de "Personaliza Kiji": la paleta y la letra elegidas (si no, las
  /// de fábrica de [style]).
  final KijiPalette? palette;
  final String? titleFont;

  @override
  Widget build(BuildContext context) {
    final palette = this.palette ?? KijiPalette.forStyle(style);
    final nocturne = style == KijiStyle.nocturne;
    final titleFont = this.titleFont ?? KijiText.titleFamilyOf(style);
    final coverRadius = switch (style) {
      KijiStyle.nocturne => 10.0,
      KijiStyle.graphite => 3.0,
      KijiStyle.paper => 2.0,
    };
    final accent = LinearGradient(colors: [palette.violet, palette.cyan]);
    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: 0.78,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.glassBorder),
            // Nocturne: un rastro de la aurora (en la miniatura, fija). Grafito: la portada en
            // blanco y negro, desenfocada, detrás de todo.
            gradient: switch (style) {
              KijiStyle.nocturne => RadialGradient(
                center: const Alignment(-0.4, -0.7),
                radius: 1.1,
                colors: [palette.violet.withValues(alpha: 0.35), palette.background],
              ),
              KijiStyle.graphite => RadialGradient(
                center: const Alignment(0.2, -0.45),
                radius: 0.9,
                colors: [const Color(0xFF2B2B2E), palette.background],
              ),
              KijiStyle.paper => null,
            },
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Portada.
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(coverRadius),
                              gradient: switch (style) {
                                KijiStyle.nocturne => LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [palette.violet, palette.cyan],
                                ),
                                KijiStyle.graphite => const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF8A8A8E), Color(0xFF3A3A3E), Color(0xFF1E1E20)],
                                ),
                                KijiStyle.paper => null,
                              },
                              color: style == KijiStyle.paper ? const Color(0xFFCFC9BC) : null,
                              // Grafito: una foto en blanco y negro, detrás de vidrio.
                              border: style == KijiStyle.graphite ? Border.all(color: palette.glassBorder) : null,
                              boxShadow: nocturne
                                  ? [BoxShadow(color: palette.violet.withValues(alpha: 0.5), blurRadius: 14)]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: w * 0.06),
                    Text(
                      'Glass Harbor', // l10n-ignore
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontFamily: titleFont,
                        fontSize: w * 0.1,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'The Velvet Tides', // l10n-ignore
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontFamily: nocturne ? null : KijiText.inter,
                        fontSize: w * 0.075,
                        color: palette.muted,
                      ),
                    ),
                    SizedBox(height: w * 0.06),
                    SizedBox(height: w * 0.1, width: w, child: CustomPaint(painter: _MiniProgress(style, palette))),
                    SizedBox(height: w * 0.04),
                    Center(
                      child: Container(
                        width: w * 0.24,
                        height: w * 0.24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: nocturne ? accent : null,
                          color: nocturne ? null : palette.text,
                          border: nocturne ? Border.all(color: palette.cyan.withValues(alpha: 0.6), width: 1.5) : null,
                        ),
                        child: Icon(Icons.play_arrow_rounded, color: palette.onAccent, size: w * 0.15),
                      ),
                    ),
                    // Grafito: los botones de vidrio esmerilado de abajo (Letra, Cola).
                    if (style == KijiStyle.graphite) ...[
                      SizedBox(height: w * 0.05),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final i in [0, 1]) ...[
                            if (i > 0) SizedBox(width: w * 0.05),
                            Container(
                              width: w * 0.3,
                              height: w * 0.09,
                              decoration: BoxDecoration(
                                color: palette.glassFill,
                                borderRadius: BorderRadius.circular(w),
                                border: Border.all(color: palette.glassBorder),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
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

/// El progreso de cada estilo: la onda, en violeta → cian (Nocturne), blanco (Grafito) o tinta (Papel).
class _MiniProgress extends CustomPainter {
  _MiniProgress(this.style, this.palette);

  final KijiStyle style;
  final KijiPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    const progress = 0.42;
    const bars = 18;
    final y = size.height / 2;
    final step = size.width / bars;
    final played = Paint()
      ..shader = LinearGradient(colors: [palette.violet, palette.cyan]).createShader(Offset.zero & size);
    final rest = Paint()..color = palette.waveRest;
    for (var i = 0; i < bars; i++) {
      final h = size.height * (0.3 + 0.7 * ((i * 7) % 5) / 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(i * step + step * 0.25, y - h / 2, step * 0.5, h), const Radius.circular(2)),
        i / bars < progress ? played : rest,
      );
    }
  }

  @override
  bool shouldRepaint(_MiniProgress old) => old.style != style || old.palette != palette;
}
