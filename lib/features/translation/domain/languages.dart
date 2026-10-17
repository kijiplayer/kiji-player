/// Idiomas que se ofrecen para traducir (los que tiene Firefox Translations),
/// con su nombre en español.
const translationLanguages = <String, String>{
  'es': 'Español',
  'en': 'Inglés',
  'pt': 'Portugués',
  'fr': 'Francés',
  'it': 'Italiano',
  'de': 'Alemán',
  'nl': 'Neerlandés',
  'ca': 'Catalán',
  'pl': 'Polaco',
  'ru': 'Ruso',
  'uk': 'Ucraniano',
  'tr': 'Turco',
  'ar': 'Árabe',
  'he': 'Hebreo',
  'hi': 'Hindi',
  'ja': 'Japonés',
  'ko': 'Coreano',
  'zh-Hans': 'Chino (simplificado)',
  'zh-Hant': 'Chino (tradicional)',
  'id': 'Indonesio',
  'vi': 'Vietnamita',
  'th': 'Tailandés',
  'sv': 'Sueco',
  'da': 'Danés',
  'nb': 'Noruego',
  'fi': 'Finés',
  'el': 'Griego',
  'cs': 'Checo',
  'ro': 'Rumano',
  'hu': 'Húngaro',
};

String languageName(String code) => translationLanguages[code] ?? code;

/// Palabras muy frecuentes de cada idioma con alfabeto latino.
const _stopwords = <String, List<String>>{
  'en': ['the', 'and', 'you', 'i', 'to', 'my', 'me', 'it', 'is', 'in', 'of', 'your', 'that', 'on', 'love', 'don\'t', 'we', 'be'],
  'es': ['que', 'de', 'el', 'la', 'y', 'en', 'no', 'me', 'te', 'mi', 'tu', 'lo', 'los', 'por', 'con', 'una', 'yo', 'es', 'amor'],
  'pt': ['que', 'de', 'eu', 'você', 'não', 'o', 'a', 'e', 'é', 'um', 'uma', 'meu', 'minha', 'com', 'pra', 'para', 'mais', 'te', 'amor'],
  'fr': ['je', 'tu', 'le', 'la', 'les', 'et', 'de', 'des', 'un', 'une', 'pas', 'que', 'qui', 'mon', 'ma', 'est', 'dans', 'moi', 'toi'],
  'it': ['che', 'di', 'il', 'la', 'e', 'non', 'un', 'una', 'mi', 'ti', 'io', 'tu', 'per', 'con', 'sono', 'è', 'del', 'amore'],
  'de': ['ich', 'du', 'und', 'die', 'der', 'das', 'nicht', 'ist', 'ein', 'eine', 'mich', 'dich', 'mit', 'es', 'wir', 'zu', 'auf'],
  'nl': ['ik', 'je', 'de', 'het', 'een', 'en', 'niet', 'van', 'is', 'mijn', 'jij', 'wij', 'met', 'voor', 'op', 'dat'],
  'tr': ['bir', 've', 'bu', 'ben', 'sen', 'ne', 'çok', 'için', 'gibi', 'de', 'da', 'mi', 'var', 'yok', 'beni', 'seni'],
};

/// Idioma más probable de [lines] (código de [translationLanguages]), o null
/// si no se puede saber. Simple: primero por alfabeto y después por palabras
/// frecuentes. El usuario lo puede cambiar.
String? detectLanguage(Iterable<String> lines) {
  final text = lines.join('\n');
  if (text.trim().isEmpty) return null;
  final counts = <String, int>{};
  void add(String key) => counts[key] = (counts[key] ?? 0) + 1;
  for (final rune in text.runes) {
    if (rune >= 0x3040 && rune <= 0x30FF) {
      add('ja');
    } else if (rune >= 0xAC00 && rune <= 0xD7AF) {
      add('ko');
    } else if (rune >= 0x4E00 && rune <= 0x9FFF) {
      add('zh');
    } else if (rune >= 0x0400 && rune <= 0x04FF) {
      add('cyr');
    } else if (rune >= 0x0600 && rune <= 0x06FF) {
      add('ar');
    } else if (rune >= 0x0590 && rune <= 0x05FF) {
      add('he');
    } else if (rune >= 0x0900 && rune <= 0x097F) {
      add('hi');
    } else if (rune >= 0x0E00 && rune <= 0x0E7F) {
      add('th');
    } else if (rune >= 0x0370 && rune <= 0x03FF) {
      add('el');
    } else if ((rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A) || (rune >= 0xC0 && rune <= 0x24F)) {
      add('latin');
    }
  }
  final total = counts.values.fold(0, (a, b) => a + b);
  if (total == 0) return null;
  // Japonés: kana (aunque tenga kanji).
  if ((counts['ja'] ?? 0) > total * 0.1) return 'ja';
  final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  switch (top) {
    case 'ko' || 'ar' || 'he' || 'hi' || 'th' || 'el':
      return top;
    case 'zh':
      return 'zh-Hans';
    case 'cyr':
      // Ucraniano tiene letras propias.
      return RegExp('[іїєґ]', caseSensitive: false).hasMatch(text) ? 'uk' : 'ru';
  }
  // Alfabeto latino: por palabras frecuentes.
  final words = text.toLowerCase().split(RegExp(r"[^\p{L}']+", unicode: true)).where((w) => w.isNotEmpty);
  final scores = <String, int>{};
  for (final word in words) {
    for (final entry in _stopwords.entries) {
      if (entry.value.contains(word)) scores[entry.key] = (scores[entry.key] ?? 0) + 1;
    }
  }
  if (scores.isEmpty) return null;
  // Señales propias del español frente al portugués ("ñ", "¿", "¡").
  if (RegExp('[ñ¿¡]').hasMatch(text)) scores['es'] = (scores['es'] ?? 0) + 5;
  if (RegExp('[ãõç]').hasMatch(text)) scores['pt'] = (scores['pt'] ?? 0) + 5;
  return scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}
