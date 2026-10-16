// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivos de referencia: app/src/main/kotlin/.../lyrics/LyricsUtils.kt (formato LRC) y
// LyricsHelper.kt (orden de fuentes).

/// Una línea de una letra sincronizada.
class LyricLine {
  const LyricLine(this.time, this.text);

  final Duration time;
  final String text;

  @override
  bool operator ==(Object other) => other is LyricLine && other.time == time && other.text == text;

  @override
  int get hashCode => Object.hash(time, text);

  @override
  String toString() => '[$time] $text';
}

/// De dónde salió la letra (se muestra como crédito).
enum LyricsSource {
  embedded('Incluida en el archivo'),
  lrclib('LRCLIB');

  const LyricsSource(this.label);
  final String label;
}

/// Letra de una canción: sincronizada, en texto simple, instrumental, o
/// nada (no se encontró).
class Lyrics {
  const Lyrics({this.synced = const [], this.plain, this.instrumental = false, this.source});

  /// "No se encontró letra".
  static const none = Lyrics();

  final List<LyricLine> synced;
  final String? plain;
  final bool instrumental;
  final LyricsSource? source;

  bool get isSynced => synced.isNotEmpty;
  bool get isEmpty => synced.isEmpty && (plain == null || plain!.trim().isEmpty) && !instrumental;

  Map<String, dynamic> toJson() => {
        if (synced.isNotEmpty)
          'synced': [
            for (final line in synced) {'ms': line.time.inMilliseconds, 'text': line.text},
          ],
        if (plain != null) 'plain': plain,
        'instrumental': instrumental,
        if (source != null) 'source': source!.name,
      };

  factory Lyrics.fromJson(Map<String, dynamic> json) => Lyrics(
        synced: [
          for (final item in (json['synced'] as List<dynamic>? ?? const []))
            LyricLine(
              Duration(milliseconds: (item as Map<String, dynamic>)['ms'] as int),
              item['text'] as String,
            ),
        ],
        plain: json['plain'] as String?,
        instrumental: json['instrumental'] as bool? ?? false,
        source: LyricsSource.values.asNameMap()[json['source']],
      );
}

final _timeTag = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
final _offsetTag = RegExp(r'^\[offset:\s*([+-]?\d+)\]', caseSensitive: false);

/// Lee una letra en formato LRC (`[01:04.07] Around the world`).
/// - Una línea puede tener varias marcas de tiempo (estribillos repetidos).
/// - Se respeta `[offset:+/-ms]`.
/// - Se ignoran las etiquetas de datos (`[ar:...]`, `[ti:...]`) y las líneas sin tiempo.
List<LyricLine> parseLrc(String lrc) {
  var offset = Duration.zero;
  final lines = <LyricLine>[];
  for (final raw in lrc.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    final offsetMatch = _offsetTag.firstMatch(line);
    if (offsetMatch != null) {
      // Offset positivo = la letra aparece antes.
      offset = Duration(milliseconds: -int.parse(offsetMatch[1]!));
      continue;
    }
    final tags = _timeTag.allMatches(line).toList();
    if (tags.isEmpty) continue;
    final text = line.substring(tags.last.end).trim();
    for (final tag in tags) {
      final minutes = int.parse(tag[1]!);
      final seconds = int.parse(tag[2]!);
      final fraction = tag[3];
      // ".07" = 70 ms, ".5" = 500 ms, ".123" = 123 ms.
      final ms = fraction == null ? 0 : int.parse(fraction.padRight(3, '0').substring(0, 3));
      final time = Duration(minutes: minutes, seconds: seconds, milliseconds: ms) + offset;
      lines.add(LyricLine(time.isNegative ? Duration.zero : time, text));
    }
  }
  lines.sort((a, b) => a.time.compareTo(b.time));
  return lines;
}

/// Índice de la línea que corresponde a [position] (la última que ya
/// empezó), o -1 si todavía no empezó ninguna.
int currentLineIndex(List<LyricLine> lines, Duration position) {
  var low = 0;
  var high = lines.length - 1;
  var found = -1;
  while (low <= high) {
    final mid = (low + high) >> 1;
    if (lines[mid].time <= position) {
      found = mid;
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  return found;
}
