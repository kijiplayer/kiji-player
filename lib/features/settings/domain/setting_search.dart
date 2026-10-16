// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivo de referencia: app/src/main/kotlin/.../ui/screens/settings/SearchableSettings.kt
// (buscador de opciones dentro de Configuración).

/// Texto en minúsculas y sin tildes, para buscar "animacion" y encontrar
/// "Reducir animaciones".
String normalizeForSearch(String text) {
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const to = 'aaaaaeeeeiiiiooooouuuunc';
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    final i = from.indexOf(char);
    buffer.write(i == -1 ? char : to[i]);
  }
  return buffer.toString();
}

/// true si todas las palabras de [query] aparecen en el título, la
/// descripción, la sección o las palabras clave de la opción.
bool settingMatches(
  String query, {
  required String title,
  String subtitle = '',
  String section = '',
  List<String> keywords = const [],
}) {
  final haystack = normalizeForSearch([title, subtitle, section, ...keywords].join(' '));
  final words = normalizeForSearch(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  return words.isNotEmpty && words.every(haystack.contains);
}
