import '../../../models/track.dart';

/// Biblioteca → Canciones: qué se muestra ([filter]: 'all', 'downloaded' o 'local') y en qué
/// orden ([sort]: 'recent' —lo último que se agregó primero: la fecha de la descarga, la de
/// MediaStore en Android o la del archivo en la PC; sin fecha, al final—, 'title', 'artist' o
/// 'duration').
List<Track> arrangeLibrarySongs(List<Track> songs, {String sort = 'recent', String filter = 'all'}) {
  final shown = switch (filter) {
    'downloaded' => [
      for (final t in songs)
        if (t.source == TrackSource.youtube) t,
    ],
    'local' => [
      for (final t in songs)
        if (t.source == TrackSource.local) t,
    ],
    _ => [...songs],
  };
  String key(String s) => _fold(s.trim().toLowerCase());
  int byTitle(Track a, Track b) => key(a.title).compareTo(key(b.title));
  switch (sort) {
    case 'recent':
      // Estable: entre las que no tienen fecha queda el orden de antes.
      final indexed = [for (final (i, t) in shown.indexed) (i, t)];
      indexed.sort((a, b) {
        final da = a.$2.addedAtMs, db = b.$2.addedAtMs;
        if (da == null || db == null) {
          if (da != db) return da == null ? 1 : -1;
          return a.$1.compareTo(b.$1);
        }
        return db != da ? db.compareTo(da) : a.$1.compareTo(b.$1);
      });
      shown
        ..clear()
        ..addAll([for (final e in indexed) e.$2]);
    case 'title':
      shown.sort(byTitle);
    case 'artist':
      shown.sort((a, b) {
        final c = key(a.artist).compareTo(key(b.artist));
        return c != 0 ? c : byTitle(a, b);
      });
    case 'duration':
      // Las de duración desconocida (0) al final.
      shown.sort((a, b) {
        if ((a.durationMs <= 0) != (b.durationMs <= 0)) return a.durationMs <= 0 ? 1 : -1;
        return a.durationMs.compareTo(b.durationMs);
      });
  }
  return shown;
}

/// "Ángel" junto a "angel": sin tildes para ordenar.
String _fold(String s) {
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñç'; // l10n-ignore
  const to = 'aaaaaeeeeiiiiooooouuuunc';
  final out = StringBuffer();
  for (final rune in s.runes) {
    final c = String.fromCharCode(rune);
    final i = from.indexOf(c);
    out.write(i < 0 ? c : to[i]);
  }
  return out.toString();
}
