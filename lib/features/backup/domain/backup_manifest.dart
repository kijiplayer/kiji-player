// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivos de referencia: ui/screens/settings/BackupAndRestore.kt y
// viewmodels/BackupRestoreViewModel.kt (copia en un archivo y restaurar). El formato,
// la copia diaria y la vista previa son propios de Kiji.

import '../../dev_tools/dev_build.dart';

/// Cuántas cosas trae una copia (para la vista previa).
class BackupCounts {
  const BackupCounts({this.playlists = 0, this.likes = 0, this.history = 0, this.downloads = 0, this.covers = 0});

  final int playlists;
  final int likes;
  final int history;

  /// Canciones de la lista de descargas (el audio no va en la copia).
  final int downloads;

  /// Carátulas personalizadas.
  final int covers;

  Map<String, dynamic> toJson() => {
    'playlists': playlists,
    'likes': likes,
    'history': history,
    'downloads': downloads,
    'covers': covers,
  };

  factory BackupCounts.fromJson(Object? json) {
    int read(String key) => json is Map && json[key] is int ? json[key] as int : 0;
    return BackupCounts(
      playlists: read('playlists'),
      likes: read('likes'),
      history: read('history'),
      downloads: read('downloads'),
      covers: read('covers'),
    );
  }
}

/// `manifest.json` dentro de cada copia.
class BackupManifest {
  const BackupManifest({
    required this.createdAt,
    required this.platform,
    required this.files,
    this.counts = const BackupCounts(),
    this.reason = 'manual',
  });

  static const app = 'Kiji'; // l10n-ignore
  static const version = 1;

  final DateTime createdAt;

  /// android, windows… (de dónde viene la copia).
  final String platform;
  final List<String> files;
  final BackupCounts counts;

  /// diaria, manual o antes-de-restaurar.
  final String reason;

  Map<String, dynamic> toJson() => {
    'app': app,
    // De qué app sale la copia (Kiji o Kiji Dev): solo informativo.
    'flavor': isDevBuild ? 'dev' : 'prod',
    'version': version,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'platform': platform,
    'reason': reason,
    'files': files,
    'counts': counts.toJson(),
  };

  /// null si no es una copia de Kiji o es de una versión que no se entiende.
  static BackupManifest? tryParse(Object? json) {
    if (json is! Map || json['app'] != app) return null;
    final version = json['version'];
    if (version is! int || version > BackupManifest.version) return null;
    final created = DateTime.tryParse('${json['createdAt']}');
    if (created == null) return null;
    final files = json['files'];
    return BackupManifest(
      createdAt: created.toLocal(),
      platform: '${json['platform'] ?? '?'}',
      reason: '${json['reason'] ?? 'manual'}',
      files: files is List ? [for (final f in files) '$f'] : const [],
      counts: BackupCounts.fromJson(json['counts']),
    );
  }
}

/// Cada cuánto se hace la copia automática.
const autoBackupInterval = Duration(days: 1);

/// Cuántas copias se guardan (las más viejas se borran).
const backupsToKeep = 7;

final _namePattern = RegExp(r'^kiji-copia-(\d{4})-(\d{2})-(\d{2})-(\d{2})(\d{2})(\d{2})(-[a-z-]+)?\.zip$');

String _two(int n) => n.toString().padLeft(2, '0');

/// `kiji-copia-2026-10-16-083005.zip` (con `-antes-de-restaurar` si toca).
String backupFileName(DateTime when, {String? suffix}) =>
    'kiji-copia-${when.year}-${_two(when.month)}-${_two(when.day)}-'
    '${_two(when.hour)}${_two(when.minute)}${_two(when.second)}${suffix == null ? '' : '-$suffix'}.zip';

/// Fecha de una copia por su nombre, o null si no es una copia de Kiji.
DateTime? backupDateFromName(String name) {
  final m = _namePattern.firstMatch(name);
  if (m == null) return null;
  int g(int i) => int.parse(m.group(i)!);
  return DateTime(g(1), g(2), g(3), g(4), g(5), g(6));
}

/// Toca hacer la copia automática si nunca se hizo o pasó un día.
bool shouldAutoBackup(DateTime? lastBackup, DateTime now) =>
    lastBackup == null || now.difference(lastBackup) >= autoBackupInterval;

/// Copias que sobran: de las de Kiji, todas menos las [keep] más nuevas. Los
/// demás archivos de la carpeta no se tocan nunca.
List<String> backupsToDelete(Iterable<String> names, {int keep = backupsToKeep}) {
  final ours = [
    for (final name in names)
      if (backupDateFromName(name) != null) name,
  ]..sort((a, b) => backupDateFromName(b)!.compareTo(backupDateFromName(a)!));
  return ours.length <= keep ? const [] : ours.sublist(keep);
}
