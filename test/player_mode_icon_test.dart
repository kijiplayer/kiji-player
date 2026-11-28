// Aleatorio y repetir (0.9): se ven prendidos y apagados en todos los estilos y acentos (3:1 o más
// contra el fondo) y «prendido» se nota sin depender del color: lleva un punto debajo.
//
// Capturas de cada combinación (estilo × acento, apagado y prendido):
//   flutter test test/player_mode_icon_test.dart --dart-define=KIJI_CAPTURAS=build/capturas_modo
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/screens/player/player_screen.dart';
import 'package:kiji_player/theme/app_theme.dart';
import 'package:kiji_player/theme/kiji_tokens.dart';

import 'style_test.dart' show contrast;

const _captures = String.fromEnvironment('KIJI_CAPTURAS');

/// Todos los estilos con cada tema y acento, y acentos propios difíciles (igual que
/// selected_contrast_test.dart).
final _looks = <String, (KijiStyle, KijiPalette)>{
  for (final theme in ['dark', 'darker', 'light'])
    for (final accent in KijiPalette.accents.keys)
      'nocturne-$theme-$accent': (KijiStyle.nocturne, KijiPalette.resolve(theme: theme, accent: accent)),
  'grafito': (KijiStyle.graphite, KijiPalette.graphite),
  'papel': (KijiStyle.paper, KijiPalette.paper),
  for (final style in KijiStyle.values)
    for (final (name, color) in const [
      ('amarillo', Color(0xFFFFEB3B)),
      ('rojo', Color(0xFFE53935)),
      ('marino', Color(0xFF0B1A3A)),
      ('blanco', Color(0xFFFFFFFF)),
      ('negro', Color(0xFF000000)),
      ('gris', Color(0xFF808080)),
      ('marron', Color(0xFF6D4C41)),
    ])
      '${style.name}-propio-$name': (style, KijiPalette.forStyle(style, custom: color)),
};

void _use(KijiStyle style, KijiPalette palette) {
  KijiLook.style = style;
  KijiColors.palette = palette;
}

/// La fila tal como queda en el reproductor: botón compacto con el tamaño de ícono de siempre.
Widget _row({required bool on}) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    for (final icon in [Icons.shuffle_rounded, Icons.repeat_rounded, Icons.repeat_one_rounded])
      IconButton(
        onPressed: () {},
        isSelected: on,
        iconSize: 30 * 0.85,
        visualDensity: VisualDensity.compact,
        icon: PlayerModeIcon(icon, on: on, size: 30 * 0.85),
      ),
  ],
);

void main() {
  tearDown(() => _use(KijiStyle.nocturne, KijiPalette.nocturne));

  test('prendido y apagado se leen contra el fondo (3:1) en todos los estilos y acentos', () {
    for (final MapEntry(key: name, value: (style, palette)) in _looks.entries) {
      _use(style, palette);
      for (final bg in [palette.background, palette.surface]) {
        expect(contrast(PlayerModeIcon.colorFor(on: false), bg), greaterThanOrEqualTo(3), reason: '$name, apagado');
        expect(
          contrast(PlayerModeIcon.colorFor(on: true), PlayerModeIcon.backdropOn(bg)),
          greaterThanOrEqualTo(3),
          reason: '$name, prendido (sobre su círculo)',
        );
      }
    }
  });

  testWidgets('prendido lleva un punto; apagado, no, y el ícono no se mueve', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkWith(),
        home: Scaffold(
          body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [_row(on: false), _row(on: true)]),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull, reason: 'sin desbordes dentro del botón');
    expect(find.byKey(const Key('player-mode-dot')), findsNWidgets(3));
    final off = tester.getCenter(find.byIcon(Icons.shuffle_rounded).first);
    final on = tester.getCenter(find.byIcon(Icons.shuffle_rounded).last);
    expect(off.dx, closeTo(on.dx, 0.01));
    final offSize = tester.getSize(find.byType(PlayerModeIcon).first);
    final onSize = tester.getSize(find.byType(PlayerModeIcon).last);
    expect(offSize, onSize, reason: 'mismo lugar prendido y apagado');
  });

  testWidgets('lectores de pantalla: el botón dice si está prendido', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkWith(),
        home: Scaffold(body: Center(child: _row(on: true))),
      ),
    );
    expect(
      tester.getSemantics(find.byType(IconButton).first),
      matchesSemantics(
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasSelectedState: true,
        isSelected: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    handle.dispose();
  });

  if (_captures.isNotEmpty) {
    testWidgets('capturas de cada combinación', (tester) async {
      final font = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(File(_materialIcons()).readAsBytesSync())));
      await font.load();
      Directory(_captures).createSync(recursive: true);
      tester.view.physicalSize = const Size(420, 150);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final MapEntry(key: name, value: (style, palette)) in _looks.entries) {
        _use(style, palette);
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkWith(),
            home: RepaintBoundary(
              key: key,
              child: ColoredBox(
                color: palette.background,
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [_row(on: false), _row(on: true)]),
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          File('$_captures/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
        });
      }
    });
  }
}

/// La fuente de íconos que trae el SDK de Flutter (en los tests no se carga sola).
String _materialIcons() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT']!;
  return '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf';
}
