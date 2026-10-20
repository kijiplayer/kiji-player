/// Lectura segura de JSON ajeno (YouTube, servicios de letras): si la forma no es la esperada,
/// devuelve null en vez de lanzar un error de tipos.
library;

/// El valor en [path] dentro de [root]: claves de texto para mapas y números para listas.
/// null si algún paso no existe o no tiene la forma esperada.
Object? jsonAt(Object? root, List<Object> path) {
  var current = root;
  for (final key in path) {
    if (key is String && current is Map) {
      current = current[key];
    } else if (key is int && current is List && key >= 0 && key < current.length) {
      current = current[key];
    } else {
      return null;
    }
  }
  return current;
}

/// [jsonAt] cuando se espera una lista.
List<dynamic>? jsonListAt(Object? root, List<Object> path) {
  final value = jsonAt(root, path);
  return value is List ? value : null;
}

/// [jsonAt] cuando se espera un texto.
String? jsonStringAt(Object? root, List<Object> path) {
  final value = jsonAt(root, path);
  return value is String ? value : null;
}
