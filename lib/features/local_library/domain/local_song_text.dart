/// Lo que los archivos traen en vez de un dato (`<unknown>`, "Unknown"…): se trata como vacío.
const unknownMarkers = {'<unknown>', 'unknown', 'unknown artist', 'unknown album', '-'}; // l10n-ignore

/// Título (y, si el nombre es "Artista - Título", el artista) a partir del nombre de un archivo
/// sin etiquetas, limpio: sin la extensión, sin "01 - " ni "1-03." delante, sin guiones bajos ni
/// espacios de más.
({String title, String? artist}) titleFromFileName(String fileName) {
  var name = fileName;
  final dot = name.lastIndexOf('.');
  if (dot > 0) name = name.substring(0, dot);
  name = name.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  // Número de pista delante: "01 - ", "12. ", "1-03 ", "(03) ", "Track 03 - ", "03 ". Un número
  // sin separador ni cero delante es parte del título ("99 Luftballons").
  for (final pattern in [
    RegExp(r'^(track\s*)?[\(\[]?\d{1,3}[\)\]]?\s*[-.–)]\s+', caseSensitive: false),
    RegExp(r'^\d{1,2}[-.]\d{1,3}\s+'),
    RegExp(r'^(track\s*)?0\d{1,2}\s+', caseSensitive: false),
  ]) {
    final stripped = name.replaceFirst(pattern, '');
    if (stripped != name && stripped.trim().isNotEmpty) {
      name = stripped.trim();
      break;
    }
  }
  String? artist;
  final parts = name.split(RegExp(r'\s+[-–]\s+'));
  if (parts.length >= 2 && parts.first.trim().isNotEmpty && parts.skip(1).join(' - ').trim().isNotEmpty) {
    artist = parts.first.trim();
    name = parts.skip(1).join(' - ').trim();
  }
  if (name.isEmpty) name = fileName;
  return (title: name, artist: artist);
}
