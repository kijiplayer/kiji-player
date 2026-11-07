import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/features/style/data/kiji_theme.dart';

/// Un PNG mínimo (solo la firma y algo de relleno): para el tema alcanza con que sea una imagen.
final _png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3, 4]);

Uint8List _zip(Map<String, List<int>> files) {
  final archive = Archive();
  for (final e in files.entries) {
    archive.addFile(ArchiveFile(e.key, e.value.length, e.value));
  }
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}

List<int> _json(Map<String, Object?> m) => utf8.encode(jsonEncode(m));

Map<String, Object?> _good() => {
  'kiji_theme': 1,
  'style': 'graphite',
  'theme': 'dark',
  'accent': 'custom',
  'customAccent': '#ff9800',
  'font': 'newsreader',
  'backgroundBlur': 8,
  'backgroundOpacity': 0.5,
};

void main() {
  test('Un tema va y vuelve igual, con la imagen de fondo', () {
    final s = const AppSettings().copyWith(
      style: 'paper',
      accent: 'custom',
      customAccent: 0xFF2EE6A6,
      font: 'inter',
      backgroundBlur: 20,
      backgroundOpacity: 0.3,
    );
    final back = KijiTheme.decode(KijiTheme.fromSettings(s, imageName: 'fondo.png', imageBytes: _png).encode())!;
    expect((back.style, back.accent, back.customAccent, back.font, back.blur, back.opacity),
        ('paper', 'custom', 0xFF2EE6A6, 'inter', 20.0, 0.3));
    expect(back.imageBytes, _png);
    final applied = back.applyTo(const AppSettings());
    expect((applied.style, applied.customAccentColor?.toARGB32(), applied.font), ('paper', 0xFF2EE6A6, 'inter'));
  });

  test('Sin imagen también vale', () {
    final theme = KijiTheme.decode(_zip({'tema.json': _json(_good())}))!;
    expect(theme.imageBytes, isNull);
    expect(theme.style, 'graphite');
  });

  test('Lo que no es un tema válido se ignora (null), sin romper nada', () {
    Uint8List withJson(Map<String, Object?> change, {Map<String, List<int>> extra = const {}}) =>
        _zip({'tema.json': _json({..._good(), ...change}), ...extra});
    final bad = <String, Uint8List>{
      'basura': Uint8List.fromList(utf8.encode('esto no es un zip')),
      'sin tema.json': _zip({'otro.json': _json(_good())}),
      'otra versión': withJson({'kiji_theme': 99}),
      'estilo que no existe': withJson({'style': 'neon'}),
      'fuente que no está en la app': withJson({'font': 'comic-sans'}),
      'color mal escrito': withJson({'customAccent': 'rojo'}),
      'una ruta en el nombre': _zip({'tema.json': _json(_good()), '../fuera.png': _png}),
      'demasiados archivos': _zip({'tema.json': _json(_good()), 'a.png': _png, 'b.png': _png}),
      'un texto disfrazado de imagen': withJson({'background': 'fondo.png'}, extra: {'fondo.png': utf8.encode('hola')}),
      'un video no va': withJson({'background': 'fondo.mp4'}, extra: {'fondo.mp4': _png}),
      'falta la imagen que nombra': withJson({'background': 'fondo.png'}),
    };
    for (final MapEntry(key: why, value: bytes) in bad.entries) {
      expect(KijiTheme.decode(bytes), isNull, reason: why);
    }
  });

  test('Valores fuera de rango se acomodan', () {
    final theme = KijiTheme.decode(_zip({'tema.json': _json({..._good(), 'backgroundBlur': 500, 'backgroundOpacity': -1})}))!;
    expect(theme.blur, AppSettings.maxBackgroundBlur);
    expect(theme.opacity, 0.1);
  });
}
