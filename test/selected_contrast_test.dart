import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/theme/app_theme.dart';
import 'package:kiji_player/theme/kiji_tokens.dart';

import 'style_test.dart' show contrast;

/// Las paletas a revisar: Grafito, Papel y Nocturne con cada tema y cada acento.
final _looks = <String, (KijiStyle, KijiPalette)>{
  for (final theme in ['dark', 'darker', 'light'])
    for (final accent in KijiPalette.accents.keys)
      'nocturne $theme $accent': (KijiStyle.nocturne, KijiPalette.resolve(theme: theme, accent: accent)),
  'grafito': (KijiStyle.graphite, KijiPalette.graphite),
  'papel': (KijiStyle.paper, KijiPalette.paper),
};

void _use(KijiStyle style, KijiPalette palette) {
  KijiLook.style = style;
  KijiColors.palette = palette;
}

const _selected = {WidgetState.selected};
const _idle = <WidgetState>{};

void main() {
  tearDown(() => _use(KijiStyle.nocturne, KijiPalette.nocturne));

  test('todo lo "elegido" se lee (texto 4,5:1; interruptores, radios y casillas 3:1)', () {
    for (final MapEntry(key: name, value: (style, palette)) in _looks.entries) {
      _use(style, palette);
      final theme = AppTheme.darkWith();
      final bg = palette.background;
      final seg = theme.segmentedButtonTheme.style!;
      final chip = theme.chipTheme;
      final sw = theme.switchTheme;
      final filled = theme.filledButtonTheme.style!;
      final tab = theme.tabBarTheme;
      final text = <String, (Color, Color)>{
        'pestaña elegida (Canciones/Descargadas…)': (
          seg.foregroundColor!.resolve(_selected)!,
          seg.backgroundColor!.resolve(_selected)!,
        ),
        'pestaña sin elegir': (seg.foregroundColor!.resolve(_idle)!, bg),
        'chip o filtro elegido': (
          WidgetStateProperty.resolveAs(chip.labelStyle!.color, _selected)!,
          chip.selectedColor!,
        ),
        'chip sin elegir': (WidgetStateProperty.resolveAs(chip.labelStyle!.color, _idle)!, bg),
        'botón relleno': (filled.foregroundColor!.resolve(_idle)!, filled.backgroundColor!.resolve(_idle)!),
        'pestaña de arriba elegida': (tab.labelColor!, bg),
        // Barra de navegación (píldora y lateral), casilla de selección y botones del menú de la letra:
        // degradado del acento con el texto en onAccent.
        'navegación elegida (inicio del degradado)': (palette.onAccent, palette.violet),
        'navegación elegida (final del degradado)': (palette.onAccent, palette.cyan),
        'fila elegida (selección múltiple)': (
          palette.text,
          Color.alphaBlend(palette.violet.withValues(alpha: 0.14), bg),
        ),
        'botón activo (aleatorio, repetir, temporizador)': (palette.cyan, bg),
      };
      for (final MapEntry(key: what, value: (fg, back)) in text.entries) {
        expect(contrast(fg, back), greaterThanOrEqualTo(4.5), reason: '$name: $what');
      }
      final shapes = <String, (Color, Color)>{
        'interruptor prendido (botón/carril)': (sw.thumbColor!.resolve(_selected)!, sw.trackColor!.resolve(_selected)!),
        'interruptor prendido (carril/fondo)': (sw.trackColor!.resolve(_selected)!, bg),
        'radio elegido': (theme.radioTheme.fillColor!.resolve(_selected)!, bg),
        'casilla marcada (tilde)': (
          theme.checkboxTheme.checkColor!.resolve(_selected)!,
          theme.checkboxTheme.fillColor!.resolve(_selected)!,
        ),
      };
      for (final MapEntry(key: what, value: (fg, back)) in shapes.entries) {
        expect(contrast(fg, back), greaterThanOrEqualTo(3), reason: '$name: $what');
      }

      // La letra es siempre oscura: ahí lo elegido usa sus propios colores.
      final dark = KijiSelected.onDark;
      final lyricsBg = KijiPalette.nocturne.background;
      expect(contrast(dark.onFill, dark.fill), greaterThanOrEqualTo(4.5), reason: '$name: letra, elegido');
      expect(contrast(dark.muted, lyricsBg), greaterThanOrEqualTo(4.5), reason: '$name: letra, sin elegir');
    }
  });

  testWidgets('la pestaña y el chip elegidos se dibujan con el texto que contrasta', (tester) async {
    for (final MapEntry(key: name, value: (style, palette)) in _looks.entries) {
      _use(style, palette);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkWith(),
          home: Scaffold(
            body: Column(
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Canciones')),
                    ButtonSegment(value: 1, label: Text('Playlists')),
                  ],
                  selected: const {0},
                  showSelectedIcon: false,
                  onSelectionChanged: (_) {},
                ),
                ChoiceChip(label: const Text('Artistas'), selected: true, onSelected: (_) {}),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // El color con el que se dibuja el texto (el del TextSpan o el de alguno de sus hijos).
      Color textOf(String label) {
        final root = tester.renderObject<RenderParagraph>(find.text(label)).text;
        var color = root.style?.color;
        root.visitChildren((span) {
          color ??= span.style?.color;
          return color == null;
        });
        // Si el texto no trae color propio, es el que hereda (el del chip, por ejemplo).
        return color ?? DefaultTextStyle.of(tester.element(find.text(label))).style.color!;
      }

      final segmentFill = tester
          .widgetList<Material>(find.ancestor(of: find.text('Canciones'), matching: find.byType(Material)))
          .first
          .color!;
      expect(segmentFill, palette.violet, reason: '$name: relleno de la pestaña');
      expect(contrast(textOf('Canciones'), segmentFill), greaterThanOrEqualTo(4.5), reason: '$name: pestaña');
      expect(contrast(textOf('Artistas'), palette.violet), greaterThanOrEqualTo(4.5), reason: '$name: chip');
    }
  });
}
