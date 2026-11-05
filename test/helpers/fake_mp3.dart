import 'dart:convert';
import 'dart:typed_data';

/// Un PNG mínimo (la firma y algo de relleno) para las portadas inventadas.
final fakePng = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 9, 8, 7, 6, 5, 4, 3, 2, 1]);

/// MP3 mínimo con una etiqueta ID3v2.3 (los datos que se pasen) y dos cuadros MPEG válidos
/// (128 kbps, 44,1 kHz) para que el lector lo reconozca como audio. Datos inventados.
Uint8List fakeMp3({
  String? title,
  String? artist,
  String? album,
  String? albumArtist,
  String? year,
  String? track,
  String? disc,
  String? genre,
  Uint8List? cover,
}) {
  List<int> frame(String id, List<int> body) {
    final size = body.length;
    return [
      ...ascii.encode(id),
      (size >> 24) & 0xFF, (size >> 16) & 0xFF, (size >> 8) & 0xFF, size & 0xFF,
      0, 0,
      ...body,
    ];
  }

  List<int> text(String id, String? value) => value == null ? const [] : frame(id, [0, ...latin1.encode(value)]);

  final frames = [
    ...text('TIT2', title),
    ...text('TPE1', artist),
    ...text('TALB', album),
    ...text('TPE2', albumArtist),
    ...text('TYER', year),
    ...text('TRCK', track),
    ...text('TPOS', disc),
    ...text('TCON', genre),
    // APIC: codificación, tipo MIME, tipo de imagen (3 = portada de frente), descripción y bytes.
    if (cover != null) ...frame('APIC', [0, ...ascii.encode('image/png'), 0, 3, 0, ...cover]),
  ];
  final size = frames.length;
  final header = [
    ...ascii.encode('ID3'), 3, 0, 0,
    // Tamaño "synchsafe" (7 bits por byte).
    (size >> 21) & 0x7F, (size >> 14) & 0x7F, (size >> 7) & 0x7F, size & 0x7F,
  ];
  final mpegFrame = [0xFF, 0xFB, 0x90, 0x64, ...List.filled(413, 0)];
  return Uint8List.fromList([...header, ...frames, ...mpegFrame, ...mpegFrame]);
}
