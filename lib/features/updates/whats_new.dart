import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../theme/kiji_tokens.dart';
import '../../version.dart';
import 'package:kiji_player/widgets/nocturne/kiji_sheet.dart';

/// Las notas de una versión en GitHub traen los dos idiomas: primero inglés y, después de
/// "## Español", español. Devuelve solo la parte de [languageCode], sin la tabla de
/// descargas (sumas SHA-256 y nombres de archivos, que en la app no ayudan) y en texto simple.
String releaseNotesFor(String body, String languageCode) {
  final text = body.replaceAll('\r\n', '\n');
  final split = RegExp(r'^#{1,3}\s*Español\s*$', multiLine: true).firstMatch(text);
  String part;
  if (split == null) {
    part = text;
  } else if (languageCode == 'es') {
    part = text.substring(split.end);
  } else {
    part = text.substring(0, split.start);
  }
  return plainNotes(part);
}

/// Markdown de las notas → texto para leer en la app: sin la tabla de descargas, sin
/// enlaces internos, sin `**`, viñetas "•" y títulos solos en su línea.
String plainNotes(String markdown) {
  final out = <String>[];
  var skipping = false;
  for (var line in markdown.split('\n')) {
    final heading = RegExp(r'^#{1,6}\s+(.*)$').firstMatch(line.trim());
    if (heading != null) {
      final title = heading.group(1)!.trim();
      // La sección de archivos para bajar, con sus sumas, queda en la página oficial.
      skipping = RegExp(r'^(Downloads|Descargas|Files|Archivos)$', caseSensitive: false).hasMatch(title);
      if (skipping) continue;
      if (out.isNotEmpty && out.last.isNotEmpty) out.add('');
      out.add(_inline(title));
      continue;
    }
    if (skipping) continue;
    line = line.trimRight();
    if (line.trim() == '---') continue;
    // "**English** · [Español](#español)": el selector de idioma de la página.
    if (RegExp(r'^\*\*\w+\*\*\s*·\s*\[').hasMatch(line.trim())) continue;
    if (line.trim().startsWith('|')) continue;
    final bullet = RegExp(r'^(\s*)[-*]\s+(.*)$').firstMatch(line);
    if (bullet != null) {
      out.add('${bullet.group(1)}• ${_inline(bullet.group(2)!)}');
      continue;
    }
    out.add(_inline(line));
  }
  // Sin líneas vacías repetidas ni al principio o al final.
  final compact = <String>[];
  for (final line in out) {
    if (line.trim().isEmpty && (compact.isEmpty || compact.last.trim().isEmpty)) continue;
    compact.add(line);
  }
  while (compact.isNotEmpty && compact.last.trim().isEmpty) {
    compact.removeLast();
  }
  return compact.join('\n');
}

String _inline(String text) => text
    .replaceAllMapped(RegExp(r'\[([^\]]+)\]\(([^)]+)\)'), (m) => m.group(1)!)
    .replaceAll(RegExp(r'\*\*|__'), '')
    .replaceAll('`', '');

/// Pantallas que aparecen solas al abrir Kiji, en orden.
enum StartupScreen { welcome, style, whatsNew }

/// Qué se muestra al abrir y en qué orden:
/// - Instalación nueva: la bienvenida y, si falta, la elección de estilo (nunca "Qué hay de nuevo").
/// - Después de actualizar: primero la elección de estilo (si nunca se eligió) y después, una sola
///   vez por versión, "Qué hay de nuevo".
/// - Si no cambió nada: ninguna.
List<StartupScreen> startupScreens({
  required bool freshInstall,
  required bool styleChosen,
  required String? lastSeenVersion,
}) => [
  if (freshInstall) StartupScreen.welcome,
  if (!styleChosen) StartupScreen.style,
  if (shouldShowWhatsNew(lastSeenVersion: lastSeenVersion, freshInstall: freshInstall)) StartupScreen.whatsNew,
];

/// ¿Se muestran las novedades al abrir? Solo después de actualizar: nunca a quien recién
/// instala (ve la bienvenida) ni dos veces la misma versión.
bool shouldShowWhatsNew({required String? lastSeenVersion, required bool freshInstall}) {
  if (freshInstall) return false;
  return lastSeenVersion != kijiVersion;
}

/// Novedades de esta versión, incluidas en la app (las mismas de la tienda de apps:
/// `fastlane/metadata/android/<idioma>/changelogs/<compilación>.txt`).
Future<String?> loadBundledWhatsNew(String languageCode, {AssetBundle? bundle, int build = kijiBuild}) async {
  final folder = languageCode == 'es' ? 'es-ES' : 'en-US'; // l10n-ignore
  try {
    final text = await (bundle ?? rootBundle).loadString('fastlane/metadata/android/$folder/changelogs/$build.txt');
    return text.trim().isEmpty ? null : text.trim();
  } catch (error) {
    debugPrint('=== NOVEDADES: no hay notas de la compilación $build ($folder): $error ===');
    return null;
  }
}

/// "Novedades de esta versión": hoja con lo nuevo, en el idioma de la app.
Future<void> showWhatsNewSheet(BuildContext context, String notes) => showKijiSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (sheet) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.8),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          Text(tx.novedadesDeEstaVersion, style: KijiText.title(size: 22)),
          Text(tx.kiji(kijiVersion), style: KijiText.mono(size: 12, color: KijiColors.cyan)),
          const SizedBox(height: 14),
          Text(notes, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 18),
          FilledButton(onPressed: () => Navigator.pop(sheet), child: Text(tx.listo)),
        ],
      ),
    ),
  ),
);
