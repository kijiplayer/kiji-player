// l10n-ignore-file: palabras para buscar (sinónimos en los dos idiomas), no textos de la interfaz.
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

/// Palabras que significan lo mismo, en español y en inglés (sin tildes). Buscar cualquiera
/// encuentra las opciones que usan otra: "dark" encuentra "Tema", "sleep" el temporizador y
/// "descargas" las opciones de "Download" con la app en inglés.
const settingSynonyms = <List<String>>[
  ['idioma', 'language', 'lengua', 'ingles', 'english', 'espanol', 'spanish'],
  ['tema', 'theme', 'oscuro', 'dark', 'claro', 'light', 'noche', 'night'],
  ['color', 'colour', 'acento', 'accent', 'colores', 'colors'],
  ['tipografia', 'fuente', 'font', 'typeface', 'typography'],
  ['tamano', 'size', 'grande', 'big', 'large', 'pequeno', 'chico', 'small'],
  ['letra', 'letras', 'lyrics', 'lyric', 'karaoke', 'lrc'],
  ['hora', 'time', 'reloj', 'clock', 'am', 'pm'],
  ['descarga', 'descargas', 'descargar', 'download', 'downloads', 'offline', 'bajar'],
  ['wifi', 'red', 'network', 'movil', 'mobile', 'datos', 'data'],
  ['temporizador', 'timer', 'sleep', 'dormir', 'apagado'],
  ['ecualizador', 'equalizer', 'eq', 'graves', 'bass', 'agudos', 'treble'],
  ['animacion', 'animaciones', 'animation', 'animations', 'movimiento', 'motion'],
  ['copia', 'copias', 'backup', 'backups', 'respaldo', 'restaurar', 'restore'],
  ['actualizacion', 'actualizaciones', 'update', 'updates', 'version', 'novedades', 'changelog'],
  ['privacidad', 'privacy', 'privado', 'private'],
  ['historial', 'history', 'recientes', 'recent'],
  ['gusta', 'like', 'likes', 'favoritas', 'favoritos', 'favorites', 'liked'],
  ['cuenta', 'account', 'login', 'sesion', 'google'],
  ['auriculares', 'audifonos', 'headphones', 'headset', 'bluetooth'],
  ['registro', 'registros', 'log', 'logs', 'informe', 'report', 'error', 'bug', 'fallas'],
  ['traduccion', 'traducir', 'translation', 'translate'],
  ['volumen', 'volume', 'silencio', 'mute', 'silenciar'],
  ['transicion', 'crossfade', 'fundido', 'mezcla', 'fade'],
  ['borrar', 'eliminar', 'delete', 'remove', 'limpiar', 'clear', 'vaciar'],
  ['espacio', 'almacenamiento', 'storage', 'space', 'disco', 'disk', 'cache'],
  ['bienvenida', 'welcome', 'tutorial'],
  ['creditos', 'credits', 'licencia', 'license', 'gpl'],
  ['cola', 'queue'],
  ['reproductor', 'player', 'reproduccion', 'playback', 'audio', 'sonido', 'sound'],
  ['apariencia', 'appearance', 'aspecto', 'look', 'personalizar', 'personalizacion', 'customize'],
];

/// La palabra buscada y sus sinónimos. Con 3 letras o más también vale el comienzo de una
/// palabra ("desc" → descargas, download…), para que encuentre mientras se escribe.
Set<String> _alternatives(String word) {
  final result = {word};
  for (final group in settingSynonyms) {
    final hit = group.any((term) => term == word || (word.length >= 3 && term.startsWith(word)));
    if (hit) result.addAll(group);
  }
  return result;
}

/// true si todas las palabras de [query] (o un sinónimo de cada una) aparecen en el título,
/// la descripción, la sección o las palabras clave de la opción.
bool settingMatches(
  String query, {
  required String title,
  String subtitle = '',
  String section = '',
  List<String> keywords = const [],
}) {
  final haystack = normalizeForSearch([title, subtitle, section, ...keywords].join(' '));
  final words = normalizeForSearch(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  // Los sinónimos cuentan solo como palabra (o su comienzo, si es largo): "am" no encuentra
  // "cambiar" ni "red" encuentra "reducir".
  final tokens = haystack.split(RegExp(r'[^a-z0-9]+'));
  bool hasWord(String term) => term.length < 4 ? tokens.contains(term) : tokens.any((t) => t.startsWith(term));
  return words.isNotEmpty && words.every((w) => haystack.contains(w) || _alternatives(w).any(hasWord));
}
