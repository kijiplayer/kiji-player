/// Lo que está en el dispositivo pero no es música: notas de voz y audios de los chats, y las
/// grabaciones. "Carpetas excluidas" en Configuración (el usuario quita o agrega).
///
/// Cada carpeta puede ser un nombre ("WhatsApp": cualquier carpeta que se llame así, con todo lo
/// que tenga adentro) o una ruta completa ("/storage/emulated/0/Podcasts": esa carpeta). Además,
/// los archivos con nombre de nota de voz de WhatsApp (AUD-…-WA…, PTT-…-WA…) nunca son música.
class LocalExclusions {
  const LocalExclusions(this.folders);

  final List<String> folders;

  /// De fábrica: WhatsApp (también Business), Telegram y las grabadoras.
  static const defaultFolders = [
    'com.whatsapp', // l10n-ignore
    'com.whatsapp.w4b', // l10n-ignore
    'WhatsApp', // l10n-ignore
    'WhatsApp Business', // l10n-ignore
    'Telegram', // l10n-ignore
    'org.telegram.messenger', // l10n-ignore
    'Recordings', // l10n-ignore
    'Call recordings', // l10n-ignore
    'Voice Recorder', // l10n-ignore
    'Sound recorder', // l10n-ignore
    'Grabaciones', // l10n-ignore
  ];

  static const defaults = LocalExclusions(defaultFolders);

  /// "AUD-20240102-WA0003.opus", "PTT-20240102-WA0001.opus" (y los .m4a/.aac de los audios).
  static final _chatAudio = RegExp(r'^(AUD|PTT)-\d{8}-WA\d+', caseSensitive: false);

  /// true si [path] no va en la música.
  bool excludes(String path) {
    final normalized = path.replaceAll('\\', '/');
    final lower = normalized.toLowerCase();
    final slash = normalized.lastIndexOf('/');
    if (_chatAudio.hasMatch(normalized.substring(slash + 1))) return true;
    final folderSegments = slash < 0 ? const <String>[] : lower.substring(0, slash).split('/');
    for (final raw in folders) {
      final folder = raw.trim().replaceAll('\\', '/').toLowerCase();
      if (folder.isEmpty) continue;
      if (folder.contains('/')) {
        final prefix = folder.endsWith('/') ? folder : '$folder/';
        if (lower.startsWith(prefix)) return true;
      } else if (folderSegments.contains(folder)) {
        return true;
      }
    }
    return false;
  }

  /// Para saber si cambió (y volver a leer la música).
  String get key => folders.join('\n');
}
