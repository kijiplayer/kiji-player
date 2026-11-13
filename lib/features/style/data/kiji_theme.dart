import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

import '../../settings/domain/app_settings.dart';

/// Un tema de Kiji compartible (`.kiji`): un ZIP con `tema.json` y, si se quiere, la imagen de
/// fondo. Solo datos (nunca código): al importarlo se revisa todo y lo que no sea válido se ignora.
class KijiTheme {
  const KijiTheme({
    required this.style,
    required this.theme,
    required this.accent,
    required this.font,
    required this.blur,
    required this.opacity,
    this.customAccent,
    this.imageName,
    this.imageBytes,
  });

  static const version = 1;
  static const fileName = 'tema.json';

  /// Tope de la imagen de fondo dentro del tema.
  static const maxImageBytes = 15 * 1024 * 1024;
  static const imageExtensions = ['.png', '.jpg', '.jpeg', '.webp', '.gif'];

  final String style;
  final String theme;
  final String accent;
  final int? customAccent;
  final String font;
  final double blur;
  final double opacity;

  /// La imagen de fondo (opcional; los videos no van en un tema).
  final String? imageName;
  final Uint8List? imageBytes;

  factory KijiTheme.fromSettings(AppSettings s, {String? imageName, Uint8List? imageBytes}) => KijiTheme(
    style: s.style,
    theme: s.theme,
    accent: s.accent,
    customAccent: s.customAccentColor?.toARGB32(),
    font: s.font,
    blur: s.backgroundBlur,
    opacity: s.backgroundOpacity,
    imageName: imageName,
    imageBytes: imageBytes,
  );

  /// Los ajustes con este tema aplicado (el fondo se copia aparte).
  AppSettings applyTo(AppSettings s) => s.copyWith(
    style: style,
    theme: theme,
    accent: accent,
    customAccent: customAccent,
    font: font,
    backgroundBlur: blur,
    backgroundOpacity: opacity,
  );

  Map<String, dynamic> toJson() => {
    'kiji_theme': version,
    'style': style,
    'theme': theme,
    'accent': accent,
    if (customAccent != null) 'customAccent': '#${(customAccent! & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
    'font': font,
    'backgroundBlur': blur,
    'backgroundOpacity': opacity,
    'background': ?imageName,
  };

  /// El archivo `.kiji`.
  Uint8List encode() {
    final archive = Archive();
    final json = utf8.encode(const JsonEncoder.withIndent('  ').convert(toJson()));
    archive.addFile(ArchiveFile(fileName, json.length, json));
    if (imageName != null && imageBytes != null) {
      archive.addFile(ArchiveFile(imageName!, imageBytes!.length, imageBytes!));
    }
    return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
  }

  /// Lee un `.kiji`. null si no es un tema válido (cualquier problema: se ignora, sin avisos técnicos).
  static KijiTheme? decode(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      // Solo el tema y como mucho una imagen; nada de carpetas ni rutas.
      if (archive.files.length > 2 || archive.files.any((f) => !f.isFile || f.name.contains(RegExp(r'[\\/]')))) {
        return null;
      }
      final jsonFile = archive.findFile(fileName);
      if (jsonFile == null || jsonFile.size > 64 * 1024) return null;
      final json = jsonDecode(utf8.decode(jsonFile.content));
      if (json is! Map || json['kiji_theme'] != version) return null;
      String? pick(String key, List<String> allowed) => allowed.contains(json[key]) ? json[key] as String : null;
      final style = pick('style', AppSettings.styles);
      final theme = pick('theme', AppSettings.themes);
      final font = pick('font', AppSettings.fonts);
      final accentName = json['accent'];
      final customHex = json['customAccent'];
      final custom = customHex is String && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(customHex)
          ? 0xFF000000 | int.parse(customHex.substring(1), radix: 16)
          : null;
      final accent = accentName == AppSettings.customAccentName && custom != null
          ? AppSettings.customAccentName
          : (AppSettings.accents.contains(accentName) ? accentName as String : null);
      final blur = json['backgroundBlur'], opacity = json['backgroundOpacity'];
      if (style == null || theme == null || font == null || accent == null || blur is! num || opacity is! num) {
        return null;
      }
      String? imageName;
      Uint8List? imageBytes;
      final background = json['background'];
      if (background is String) {
        final image = archive.findFile(background);
        final ext = background.contains('.') ? background.substring(background.lastIndexOf('.')).toLowerCase() : '';
        if (image == null || !imageExtensions.contains(ext) || image.size > maxImageBytes) return null;
        final content = Uint8List.fromList(image.content);
        if (!_looksLikeImage(content)) return null;
        imageName = background;
        imageBytes = content;
      }
      return KijiTheme(
        style: style,
        theme: theme,
        accent: accent,
        customAccent: accent == AppSettings.customAccentName ? custom : null,
        font: font,
        blur: blur.toDouble().clamp(0, AppSettings.maxBackgroundBlur),
        opacity: opacity.toDouble().clamp(0.1, 1),
        imageName: imageName,
        imageBytes: imageBytes,
      );
    } catch (error) {
      debugPrint('=== TEMA: el archivo no es un tema de Kiji: ${error.runtimeType} ===');
      return null;
    }
  }

  /// PNG, JPEG, WebP o GIF por sus primeros bytes (una imagen de verdad, no otra cosa renombrada).
  static bool _looksLikeImage(Uint8List b) {
    bool starts(List<int> sig) => b.length >= sig.length && List.generate(sig.length, (i) => b[i]).join() == sig.join();
    return starts(const [0x89, 0x50, 0x4E, 0x47]) || // PNG
        starts(const [0xFF, 0xD8, 0xFF]) || // JPEG
        starts(const [0x47, 0x49, 0x46, 0x38]) || // GIF
        (starts(const [0x52, 0x49, 0x46, 0x46]) && b.length > 12 && String.fromCharCodes(b.sublist(8, 12)) == 'WEBP');
  }
}
