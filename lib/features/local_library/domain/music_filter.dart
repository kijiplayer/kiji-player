import 'local_exclusions.dart';

/// Un audio del teléfono, con lo que hace falta para decidir si es música.
class AudioCandidate {
  const AudioCandidate({required this.path, this.artist, this.isMusic, this.isRecording, this.durationMs});

  final String path;
  final String? artist;

  /// Lo que dice Android (null: no se sabe).
  final bool? isMusic;
  final bool? isRecording;
  final int? durationMs;

  bool get hasArtist {
    final a = artist?.trim().toLowerCase() ?? '';
    return a.isNotEmpty && a != '<unknown>' && a != 'unknown';
  }

  /// La carpeta donde está (la ruta sin el nombre del archivo).
  String get folder {
    final normalized = path.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    return slash <= 0 ? '/' : normalized.substring(0, slash);
  }
}

/// Por qué un audio quedó afuera de la Biblioteca.
enum MusicSkip {
  /// Android no lo marca como música, dura menos de 30 s, o está en Ringtones, Notifications o
  /// Alarms.
  system,

  /// Grabaciones y audios de mensajería (Recordings, Voice Recorder, Call, WhatsApp, Telegram…).
  voice,

  /// Su carpeta está oculta en "Carpetas de música".
  hiddenFolder,

  /// Un audio suelto sin artista en una carpeta de descargas o de otras apps (Download, Documents,
  /// TikTok…): una voz de ElevenLabs, un audio de TikTok. La música bajada trae su artista.
  untagged,
}

/// Una carpeta con audios, para "Carpetas de música".
class MusicFolder {
  const MusicFolder({required this.path, required this.total, required this.withArtist, required this.shown});

  final String path;
  final int total;
  final int withArtist;

  /// Se muestra en la Biblioteca (lo eligió la persona o, si no, el valor inicial).
  final bool shown;

  String get name {
    final slash = path.lastIndexOf('/');
    return slash < 0 ? path : path.substring(slash + 1);
  }

  /// Valor inicial: se muestra si la mayoría de sus audios tiene artista (la música bajada trae sus
  /// datos; las grabaciones y los audios sueltos, no).
  static bool shownByDefault({required int total, required int withArtist}) => withArtist * 2 > total;
}

/// Lo que quedó y lo que no.
class MusicFilterResult {
  const MusicFilterResult({required this.kept, required this.skipped, required this.folders});

  /// Los audios que van a la Biblioteca (índices de la lista de entrada).
  final List<int> kept;
  final Map<MusicSkip, int> skipped;

  /// Todas las carpetas con audios que pasaron las reglas fijas (para "Carpetas de música").
  final List<MusicFolder> folders;

  int get totalSkipped => skipped.values.fold(0, (a, b) => a + b);
}

/// Duración mínima de una canción.
const minMusicDurationMs = 30 * 1000;

/// Carpetas de sonidos del sistema (nunca son música).
const _systemFolders = {'ringtones', 'notifications', 'alarms'};

/// Carpetas donde cae de todo (descargas, documentos, lo que guardan otras apps): ahí solo cuenta
/// como música lo que tiene artista, salvo que la persona haya elegido mostrar la carpeta.
const looseFolders = {
  'download', 'downloads', 'documents', 'dcim', 'movies', 'pictures', 'bluetooth', // l10n-ignore
  'tiktok', 'capcut', 'instagram', 'snapchat', 'elevenlabs', 'screenrecorder', // l10n-ignore
};

bool _isLoose(String folder) => looseFolders.contains(folder.substring(folder.lastIndexOf('/') + 1).toLowerCase());

/// Decide qué audios del teléfono son música:
/// 1. lo que Android marca como música y dura 30 s o más;
/// 2. fuera las carpetas que nunca son música ([exclusions]: grabaciones, voz, mensajería, y los
///    sonidos del sistema);
/// 3. cada carpeta que queda, mostrada u oculta según [choices] (o, si no se eligió, según si la
///    mayoría de sus audios tiene artista);
/// 4. en las carpetas de descargas y de otras apps ([looseFolders]) que no se eligieron a mano,
///    solo los audios con artista.
/// Ocultar no borra nada.
MusicFilterResult filterMusic(
  List<AudioCandidate> audios, {
  LocalExclusions exclusions = LocalExclusions.defaults,
  Map<String, bool> choices = const {},
}) {
  final skipped = {for (final r in MusicSkip.values) r: 0};
  final passing = <int>[];
  for (final (i, audio) in audios.indexed) {
    final duration = audio.durationMs ?? 0;
    final segments = audio.folder.toLowerCase().split('/');
    if (audio.isMusic == false ||
        (duration > 0 && duration < minMusicDurationMs) ||
        segments.any(_systemFolders.contains)) {
      skipped[MusicSkip.system] = skipped[MusicSkip.system]! + 1;
    } else if (audio.isRecording == true || exclusions.excludes(audio.path)) {
      skipped[MusicSkip.voice] = skipped[MusicSkip.voice]! + 1;
    } else {
      passing.add(i);
    }
  }
  final stats = <String, ({int total, int withArtist})>{};
  for (final i in passing) {
    final audio = audios[i];
    final s = stats[audio.folder] ?? (total: 0, withArtist: 0);
    stats[audio.folder] = (total: s.total + 1, withArtist: s.withArtist + (audio.hasArtist ? 1 : 0));
  }
  final folders = [
    for (final MapEntry(key: path, value: s) in stats.entries)
      MusicFolder(
        path: path,
        total: s.total,
        withArtist: s.withArtist,
        shown: choices[path] ?? MusicFolder.shownByDefault(total: s.total, withArtist: s.withArtist),
      ),
  ]..sort((a, b) => b.total.compareTo(a.total));
  final shown = {for (final f in folders) f.path: f.shown};
  final kept = <int>[];
  for (final i in passing) {
    final audio = audios[i];
    if (!(shown[audio.folder] ?? true)) {
      skipped[MusicSkip.hiddenFolder] = skipped[MusicSkip.hiddenFolder]! + 1;
    } else if (choices[audio.folder] == null && _isLoose(audio.folder) && !audio.hasArtist) {
      skipped[MusicSkip.untagged] = skipped[MusicSkip.untagged]! + 1;
    } else {
      kept.add(i);
    }
  }
  return MusicFilterResult(kept: kept, skipped: skipped, folders: folders);
}
