import 'package:kiji_player/l10n/l10n.dart';

/// Lo que se puede sacar del subtítulo de un resultado de YouTube Music,
/// que viene todo junto: "Canción • Daft Punk • Discovery • 5:20" o
/// "Vídeo • Will Clarke • 927 visualizaciones • 4:01".
class ParsedSubtitle {
  const ParsedSubtitle({this.artist, this.album, this.durationMs});

  /// null si el subtítulo no nombra a nadie (p. ej. "Canción • 4:40" dentro
  /// de la tarjeta de un artista: ahí el artista es el título de la tarjeta).
  final String? artist;
  final String? album;
  final int? durationMs;
}

const _separator = ' • ';

/// Tipos de resultado que YouTube antepone al artista (pedimos con `hl=es`,
/// pero dejamos también los nombres en inglés por si cambia el idioma).
const _resultTypes = {
  'canción', 'vídeo', 'video', 'episodio', 'pódcast', 'podcast', 'álbum', 'sencillo', 'ep', // l10n-ignore
  'artista', 'perfil', 'lista de reproducción', // l10n-ignore
  'song', 'episode', 'album', 'single', 'artist', 'profile', 'playlist',
};

final _durationPattern = RegExp(r'^\d{1,2}(:\d{2}){1,2}$');
final _playsPattern =
    RegExp(r'(visualizaciones|reproducciones|views|plays|oyentes|listeners)$', caseSensitive: false);

bool _isNoise(String segment) =>
    _resultTypes.contains(segment.toLowerCase()) ||
    _durationPattern.hasMatch(segment) ||
    _playsPattern.hasMatch(segment);

String get unknownArtist => tx.artistaDesconocido;

/// Saca el artista: sin el tipo ("Canción"), sin visualizaciones y sin
/// duración. "Canción • Daft Punk • Discovery • 5:20" → "Daft Punk".
/// Devuelve null si no queda nada ("Canción • 4:40").
String? extractArtist(String text) {
  final segments = text.split(_separator).map((s) => s.trim()).where((s) => s.isNotEmpty);
  return segments.where((s) => !_isNoise(s)).firstOrNull;
}

/// Igual que [extractArtist], para limpiar textos ya guardados: si no queda
/// nadie, "Artista desconocido".
String cleanArtistText(String text) => extractArtist(text) ?? unknownArtist;

/// Interpreta los `runs` del subtítulo. Usa el tipo de página de cada run
/// (artista o álbum) cuando YouTube lo informa, y el texto si no.
ParsedSubtitle parseSubtitleRuns(List<dynamic> runs) {
  final text = runs.map((run) => (run as Map)['text'] ?? '').join();
  final segments = text.split(_separator).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  String? album;
  for (final run in runs.whereType<Map>()) {
    final pageType = (((run['navigationEndpoint'] as Map?)?['browseEndpoint'] as Map?)?[
            'browseEndpointContextSupportedConfigs'] as Map?)?['browseEndpointContextMusicConfig']
        ?['pageType'];
    if (pageType == 'MUSIC_PAGE_TYPE_ALBUM') album = run['text'] as String?;
  }

  final durationText = segments.where(_durationPattern.hasMatch).lastOrNull;
  return ParsedSubtitle(
    artist: extractArtist(text),
    album: album,
    durationMs: durationText == null ? null : _parseDuration(durationText),
  );
}

int _parseDuration(String text) {
  var seconds = 0;
  for (final part in text.split(':')) {
    seconds = seconds * 60 + int.parse(part);
  }
  return seconds * 1000;
}
