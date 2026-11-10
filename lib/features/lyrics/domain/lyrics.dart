import 'dart:math';

import 'package:kiji_player/l10n/l10n.dart';

// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivos de referencia: app/src/main/kotlin/.../lyrics/LyricsUtils.kt (formato LRC) y
// LyricsHelper.kt (orden de fuentes).

/// Una palabra o sílaba con su tiempo, cuando la fuente lo trae (nunca se inventa).
class LyricWord {
  const LyricWord(this.start, this.text, [this.end]);

  final Duration start;

  /// Cuándo termina (null: cuando empieza la siguiente, o con la línea).
  final Duration? end;

  /// Tal como va en la línea (con el espacio de después, si lo tiene).
  final String text;

  Map<String, dynamic> toJson() => {'ms': start.inMilliseconds, 'end': ?end?.inMilliseconds, 't': text};

  static LyricWord? fromJson(Object? json) {
    if (json is! Map) return null;
    final ms = json['ms'], text = json['t'], end = json['end'];
    if (ms is! int || text is! String) return null;
    return LyricWord(Duration(milliseconds: ms), text, end is int ? Duration(milliseconds: end) : null);
  }
}

/// Una línea de una letra sincronizada.
class LyricLine {
  const LyricLine(this.time, this.text, {this.words = const []});

  final Duration time;
  final String text;

  /// Palabra por palabra (o sílaba por sílaba), si la fuente trae esos tiempos; si no, vacía y la
  /// línea se resalta entera.
  final List<LyricWord> words;

  bool get hasWords => words.isNotEmpty;

  @override
  bool operator ==(Object other) => other is LyricLine && other.time == time && other.text == text;

  @override
  int get hashCode => Object.hash(time, text);

  @override
  String toString() => '[$time] $text';
}

/// De dónde salió la letra (se muestra como crédito). El orden es el orden
/// en que se buscan: primero la del archivo, después LRCLIB y
/// después las fuentes de Echo, en su orden (`LyricsProviderRegistry.kt`), menos SimpMusic
/// (su API es solo para su app).
enum LyricsSource {
  embedded,
  imported,
  lrclib,
  youlyplus,
  paxsenix,
  unison,
  betterlyrics,
  kugou,
  youtubeSubtitles,
  youtubeMusic;

  String get label => switch (this) {
    LyricsSource.embedded => tx.incluidaEnElArchivo,
    LyricsSource.imported => tx.importadaPorTi,
    LyricsSource.lrclib => 'LRCLIB',
    LyricsSource.youlyplus => 'YouLyPlus', // l10n-ignore
    LyricsSource.paxsenix => 'PaxSenix', // l10n-ignore
    LyricsSource.unison => 'Unison', // l10n-ignore
    LyricsSource.betterlyrics => 'Better Lyrics', // l10n-ignore
    LyricsSource.kugou => 'KuGou', // l10n-ignore
    LyricsSource.youtubeSubtitles => tx.subtitulosDeYoutube,
    LyricsSource.youtubeMusic => 'YouTube Music', // l10n-ignore
  };

  /// Las que se buscan por internet (se pueden apagar en Configuración).
  static const online = [lrclib, youlyplus, paxsenix, unison, betterlyrics, kugou, youtubeSubtitles, youtubeMusic];
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

  /// Trae tiempos por palabra (karaoke palabra por palabra).
  bool get hasWordTiming => synced.any((line) => line.hasWords);
  bool get isEmpty => synced.isEmpty && (plain == null || plain!.trim().isEmpty) && !instrumental;

  Map<String, dynamic> toJson() => {
    if (synced.isNotEmpty)
      'synced': [
        for (final line in synced)
          {
            'ms': line.time.inMilliseconds,
            'text': line.text,
            if (line.hasWords) 'words': [for (final word in line.words) word.toJson()],
          },
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
          words: [for (final w in (item['words'] as List<dynamic>? ?? const [])) ?LyricWord.fromJson(w)],
        ),
    ],
    plain: json['plain'] as String?,
    instrumental: json['instrumental'] as bool? ?? false,
    source: LyricsSource.values.asNameMap()[json['source']],
  );
}

final _timeTag = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');

/// Marcas por palabra (`<00:12.34>`, LRC "enhanced") y de coro de fondo (`{bg}`) que traen
/// algunas fuentes: el texto sale sin ellas y los tiempos van a [LyricLine.words].
final _wordTag = RegExp(r'<(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?>');

Duration _tagTime(String minutes, String seconds, String? fraction) => Duration(
  minutes: int.parse(minutes),
  seconds: int.parse(seconds),
  // ".07" = 70 ms, ".5" = 500 ms, ".123" = 123 ms.
  milliseconds: fraction == null ? 0 : int.parse(fraction.padRight(3, '0').substring(0, 3)),
);

/// Las palabras de una línea con marcas `<mm:ss.xx>`: cada marca empieza una palabra que llega
/// hasta la marca siguiente (una marca al final, sin texto, marca el fin de la última).
List<LyricWord> _enhancedWords(String text, Duration offset) {
  final tags = _wordTag.allMatches(text).toList();
  if (tags.isEmpty) return const [];
  final words = <LyricWord>[];
  for (var i = 0; i < tags.length; i++) {
    final start = _tagTime(tags[i][1]!, tags[i][2]!, tags[i][3]) + offset;
    final segment = text
        .substring(tags[i].end, i + 1 < tags.length ? tags[i + 1].start : text.length)
        .replaceAll('{bg}', '');
    final nextStart = i + 1 < tags.length ? _tagTime(tags[i + 1][1]!, tags[i + 1][2]!, tags[i + 1][3]) + offset : null;
    if (segment.trim().isEmpty) {
      // Solo espacio: se suma a la palabra anterior (el fin de la última va en la marca).
      if (words.isNotEmpty) {
        final last = words.removeLast();
        words.add(LyricWord(last.start, last.text + segment, last.end ?? start));
      }
      continue;
    }
    words.add(LyricWord(start.isNegative ? Duration.zero : start, segment, nextStart));
  }
  return words;
}

/// Tiempos por palabra que tengan sentido para una línea que empieza en [lineStart]: en orden y
/// cerca de la línea. Si no, ninguno (se resalta la línea entera, como siempre).
List<LyricWord> sanitizeWords(List<LyricWord> words, Duration lineStart) {
  if (words.every((w) => w.text.trim().isEmpty)) return const [];
  const tolerance = Duration(seconds: 2);
  var previous = lineStart - tolerance;
  for (final word in words) {
    if (word.start < previous || word.start > lineStart + const Duration(minutes: 1)) return const [];
    if (word.end != null && word.end! < word.start) return const [];
    previous = word.start;
  }
  return words;
}
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
    final rawText = line.substring(tags.last.end);
    final text = rawText.replaceAll(_wordTag, '').replaceAll('{bg}', '').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    for (final tag in tags) {
      final time = _tagTime(tag[1]!, tag[2]!, tag[3]) + offset;
      final start = time.isNegative ? Duration.zero : time;
      // Tiempos por palabra solo si la línea suena una vez (con varias marcas serían de una sola).
      final words = tags.length == 1 ? sanitizeWords(_enhancedWords(rawText, offset), start) : const <LyricWord>[];
      lines.add(LyricLine(start, text, words: words));
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

/// Una letra a partir de texto: sincronizada si tiene marcas LRC, si no,
/// texto simple. Vacía o sin palabras = null.
Lyrics? lyricsFromText(String? text, LyricsSource source) {
  final clean = text?.trim();
  if (clean == null || clean.isEmpty) return null;
  final synced = parseLrc(clean);
  if (synced.where((l) => l.text.isNotEmpty).isNotEmpty) return Lyrics(synced: synced, source: source);
  if (_timeTag.hasMatch(clean)) return null; // solo marcas, sin texto
  return Lyrics(plain: clean, source: source);
}

/// Tiempo de TTML: "12.345s", "1:02.5", "00:01:02.500".
Duration? _ttmlTime(String? value) {
  if (value == null || value.isEmpty) return null;
  final v = value.trim();
  if (v.endsWith('s')) {
    final seconds = double.tryParse(v.substring(0, v.length - 1));
    return seconds == null ? null : Duration(milliseconds: (seconds * 1000).round());
  }
  final parts = v.split(':');
  var seconds = 0.0;
  for (final part in parts) {
    final n = double.tryParse(part);
    if (n == null) return null;
    seconds = seconds * 60 + n;
  }
  return Duration(milliseconds: (seconds * 1000).round());
}

String _unescape(String text) =>
    text.replaceAll('&amp;', '&').replaceAll('&apos;', "'").replaceAll('&quot;', '"').replaceAll('&lt;', '<').replaceAll('&gt;', '>');

/// Lee una letra TTML (Better Lyrics, PaxSenix): una línea por cada `<p begin="…">`, con el texto
/// sin etiquetas. Si la línea trae `<span begin end>` por palabra o sílaba, también esos tiempos.
List<LyricLine> parseTtml(String ttml) {
  final lines = <LyricLine>[];
  final spanTag = RegExp(r'<span\b([^>]*)>([^<]*)</span>');
  for (final match in RegExp(r'<p\b([^>]*)>(.*?)</p>', dotAll: true).allMatches(ttml)) {
    final begin = RegExp(r'begin="([^"]+)"').firstMatch(match[1]!)?.group(1);
    final time = _ttmlTime(begin);
    if (time == null) continue;
    // Sin el coro de fondo (va aparte, más chico, en las apps que lo muestran).
    final body = match[2]!.replaceAll(RegExp(r'<span[^>]*ttm:role="x-bg"[^>]*>.*?</span>\s*</span>|<span[^>]*ttm:role="x-bg"[^>]*>.*?</span>', dotAll: true), '');
    final text = _unescape(body.replaceAll(RegExp(r'<[^>]+>'), '')).replaceAll(RegExp(r'\s+'), ' ').trim();
    final words = <LyricWord>[];
    var cursor = 0;
    for (final span in spanTag.allMatches(body)) {
      // Lo que hay entre una palabra y la siguiente (un espacio) va con la anterior.
      final gap = body.substring(cursor, span.start).replaceAll(RegExp(r'<[^>]+>'), '');
      if (gap.isNotEmpty && words.isNotEmpty) {
        final last = words.removeLast();
        words.add(LyricWord(last.start, last.text + (gap.trim().isEmpty ? ' ' : _unescape(gap)), last.end));
      }
      cursor = span.end;
      final start = _ttmlTime(RegExp(r'begin="([^"]+)"').firstMatch(span[1]!)?.group(1));
      final end = _ttmlTime(RegExp(r'end="([^"]+)"').firstMatch(span[1]!)?.group(1));
      if (start == null || span[2]!.isEmpty) continue;
      words.add(LyricWord(start, _unescape(span[2]!), end));
    }
    lines.add(LyricLine(time, text, words: sanitizeWords(words, time)));
  }
  lines.sort((a, b) => a.time.compareTo(b.time));
  return lines;
}

/// Cuántos caracteres de [line] ya sonaron en [position] (con fracción): lo que el karaoke pinta.
/// Con tiempos por palabra se siguen esos; si no, la línea se llena de forma pareja hasta [next]
/// (la línea siguiente), con un tope para que una pausa larga (un solo de guitarra) no la deje
/// llenándose despacio.
double sungCharacters(LyricLine line, Duration position, {Duration? next}) {
  final total = line.text.length;
  if (total == 0 || position <= line.time) return 0;
  if (line.hasWords) {
    var cursor = 0;
    for (var i = 0; i < line.words.length; i++) {
      final word = line.words[i];
      final piece = word.text.trim();
      final at = piece.isEmpty ? cursor : line.text.indexOf(piece, cursor);
      final start = at < 0 ? cursor : at;
      final end = word.end ??
          (i + 1 < line.words.length ? line.words[i + 1].start : null) ??
          next ??
          word.start + const Duration(milliseconds: 600);
      if (position < word.start) return start.toDouble();
      if (position < end && end > word.start) {
        final t = (position - word.start).inMicroseconds / (end - word.start).inMicroseconds;
        return start + piece.length * t;
      }
      cursor = start + piece.length;
    }
    return total.toDouble();
  }
  final cap = Duration(milliseconds: max(3000, total * 120));
  var span = next == null ? cap : next - line.time;
  if (span > cap) span = cap;
  if (span <= Duration.zero) return total.toDouble();
  return (total * (position - line.time).inMicroseconds / span.inMicroseconds).clamp(0, total).toDouble();
}

String _lrcTag(Duration time) {
  String two(int n) => n.toString().padLeft(2, '0');
  final ms = time.inMilliseconds;
  return '${two(ms ~/ 60000)}:${two((ms ~/ 1000) % 60)}.${two((ms % 1000) ~/ 10)}';
}

/// La letra como archivo `.lrc`, para guardarla junto a una descarga (otros reproductores también
/// lo leen). Con tiempos por palabra, en formato "enhanced". La fuente va en una etiqueta propia.
String lyricsToLrc(Lyrics lyrics) {
  final out = StringBuffer();
  if (lyrics.source != null) out.writeln('[kiji-source:${lyrics.source!.name}]');
  if (lyrics.instrumental) {
    out.writeln('[kiji-instrumental]');
  } else if (lyrics.isSynced) {
    for (final line in lyrics.synced) {
      out.write('[${_lrcTag(line.time)}]');
      if (line.hasWords) {
        for (final word in line.words) {
          out.write('<${_lrcTag(word.start)}>${word.text}');
        }
        final end = line.words.last.end;
        if (end != null) out.write('<${_lrcTag(end)}>');
      } else {
        out.write(line.text);
      }
      out.writeln();
    }
  } else if (lyrics.plain != null) {
    out.write(lyrics.plain);
  }
  return out.toString();
}

/// Lee un `.lrc` escrito por [lyricsToLrc] (o cualquier `.lrc`): null si no tiene letra.
Lyrics? lyricsFromLrcFile(String text, {LyricsSource fallback = LyricsSource.imported}) {
  final sourceName = RegExp(r'^\[kiji-source:([a-zA-Z]+)\]', multiLine: true).firstMatch(text)?.group(1);
  final source = LyricsSource.values.asNameMap()[sourceName] ?? fallback;
  if (text.contains('[kiji-instrumental]')) return Lyrics(instrumental: true, source: source);
  final body = text.split('\n').where((l) => !l.trimLeft().startsWith('[kiji-')).join('\n');
  return lyricsFromText(body, source);
}

/// ¿La letra sincronizada corresponde a esta canción de [duration]? Se descartan las que no
/// encajan con el audio (otra versión, una en vivo, una corrida):
/// - la última línea empieza después del final (con un margen de 3 s);
/// - está corrida: la primera línea con texto empieza pasado el 60 % de la canción (y después de
///   los 30 s: una intro larga es normal);
/// - las líneas no están en orden, o una palabra cae fuera de la canción.
/// Sin duración conocida (0) no se puede comprobar: se acepta. Las de texto simple no se miran.
bool syncMatches(Lyrics lyrics, Duration duration) {
  if (!lyrics.isSynced || duration <= Duration.zero) return true;
  final end = duration + const Duration(seconds: 3);
  final lines = lyrics.synced;
  final withText = lines.where((l) => l.text.trim().isNotEmpty).toList();
  if (withText.isEmpty) return false;
  if (withText.last.time > end) return false;
  if (withText.first.time > duration * 0.6 && withText.first.time > const Duration(seconds: 30)) return false;
  for (var i = 1; i < lines.length; i++) {
    if (lines[i].time < lines[i - 1].time) return false;
  }
  for (final line in lines) {
    for (final word in line.words) {
      if (word.start > end || (word.end != null && word.end! > end + const Duration(seconds: 2))) return false;
    }
  }
  return true;
}

extension LyricsUnsynced on Lyrics {
  /// La misma letra sin tiempos (cuando la sincronización no encaja con la canción).
  Lyrics get unsynced => isSynced
      ? Lyrics(plain: [for (final l in synced) l.text].where((t) => t.isNotEmpty).join('\n'), source: source)
      : this;
}
