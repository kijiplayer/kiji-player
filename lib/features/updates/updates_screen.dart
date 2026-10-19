import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/kiji_tokens.dart';
import 'update_checker.dart';
import '../../version_label.dart';

/// "Hace 3 horas", "hace 2 días" (para la última consulta).
String agoText(DateTime when, DateTime now) {
  final d = now.difference(when);
  if (d.inMinutes < 1) return 'recién';
  if (d.inHours < 1) return 'hace ${d.inMinutes} min';
  if (d.inDays < 1) return 'hace ${d.inHours} ${d.inHours == 1 ? 'hora' : 'horas'}';
  return 'hace ${d.inDays} ${d.inDays == 1 ? 'día' : 'días'}';
}

/// Abre la página oficial de la versión (en el navegador). Kiji no baja nada.
Future<void> openReleasePage(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (error) {
    debugPrint('=== ACTUALIZACIONES: no se pudo abrir la página: $error ===');
  }
}

/// Novedades de una versión nueva, con el botón a la página oficial.
Future<void> showReleaseSheet(BuildContext context, Release release) => showModalBottomSheet<void>(
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
              Text('Kiji ${release.version}', style: KijiText.title(size: 22)),
              if (release.name != release.version && release.name != 'v${release.version}')
                Text(release.name, style: const TextStyle(color: KijiColors.muted)),
              const SizedBox(height: 12),
              Text(release.notes.isEmpty ? 'Esta versión no trae notas.' : release.notes),
              const SizedBox(height: 16),
              const Text(
                'Kiji nunca se actualiza solo ni baja nada: la descarga la haces tú desde la página '
                'oficial, si quieres.',
                style: TextStyle(color: KijiColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => openReleasePage(release.url),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Abrir la página oficial'),
              ),
            ],
          ),
        ),
      ),
    );

/// Fila de Configuración → Actualizaciones: estado y "Buscar ahora".
class UpdateStatusTile extends ConsumerWidget {
  const UpdateStatusTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(updateProvider);
    final last = update.lastCheck;
    final latest = update.latest;
    return ListTile(
      leading: Icon(
        latest == null ? Icons.verified_outlined : Icons.new_releases_outlined,
        color: latest == null ? KijiColors.muted : KijiColors.cyan,
      ),
      title: Text(latest == null ? 'Kiji $kijiVersionLabel' : 'Hay una versión nueva: ${latest.version}'),
      subtitle: Text([
        if (update.message != null) update.message!,
        last == null ? 'Todavía no se consultó.' : 'Última consulta: ${agoText(last, DateTime.now())}.',
      ].join(' ')),
      onTap: latest == null ? null : () => showReleaseSheet(context, latest),
      trailing: update.checking
          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : TextButton(
              onPressed: () => ref.read(updateProvider.notifier).checkNow(),
              child: const Text('Buscar ahora'),
            ),
    );
  }
}
