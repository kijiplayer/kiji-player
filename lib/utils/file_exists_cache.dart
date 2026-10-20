import 'dart:io';

/// "¿Existe este archivo?" sin preguntarle al disco en cada redibujo de una lista.
/// Lo que existe se recuerda (si después se borra, la imagen cae a su respaldo); lo que no existe
/// se vuelve a mirar pasado [recheckMissingAfter], por si se guardó después (carátulas que se
/// bajan al importar).
class FileExistsCache {
  FileExistsCache({
    this.recheckMissingAfter = const Duration(seconds: 20),
    this.maxEntries = 4000,
    bool Function(String path)? exists,
    DateTime Function()? clock,
  }) : _exists = exists ?? ((path) => File(path).existsSync()),
       _clock = clock ?? DateTime.now;

  final Duration recheckMissingAfter;
  final int maxEntries;
  final bool Function(String path) _exists;
  final DateTime Function() _clock;

  final Set<String> _present = {};
  final Map<String, DateTime> _missingSince = {};

  bool exists(String path) {
    if (_present.contains(path)) return true;
    final missing = _missingSince[path];
    if (missing != null && _clock().difference(missing) < recheckMissingAfter) return false;
    if (_present.length + _missingSince.length >= maxEntries) {
      _present.clear();
      _missingSince.clear();
    }
    if (_exists(path)) {
      _missingSince.remove(path);
      _present.add(path);
      return true;
    }
    _missingSince[path] = _clock();
    return false;
  }
}

/// El de la app (carátulas de las listas).
final fileExistsCache = FileExistsCache();
