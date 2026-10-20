import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/kiji_tokens.dart';
import 'update_checker.dart';
import '../../version_label.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// "Hace 3 horas", "hace 2 días" (para la última consulta).
String agoText(DateTime when, DateTime now) {
  final d = now.difference(when);
  if (d.inMinutes < 1) return tx.recien;
  if (d.inHours < 1) return tx.haceMin(d.inMinutes);
  if (d.inDays < 1) return tx.haceNHoras(d.inHours);
  return tx.haceNDias(d.inDays);
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
          Text(tx.kiji(release.version), style: KijiText.title(size: 22)),
          if (release.name != release.version && release.name != 'v${release.version}')
            Text(release.name, style: const TextStyle(color: KijiColors.muted)),
          const SizedBox(height: 12),
          Text(release.notes.isEmpty ? tx.estaVersionNoTraeNotas : release.notes),
          const SizedBox(height: 16),
          Text(tx.kijiNuncaSeActualizaSoloNi, style: const TextStyle(color: KijiColors.muted, fontSize: 13)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => openReleasePage(release.url),
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(tx.abrirLaPaginaOficial),
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
      title: Text(latest == null ? 'Kiji $kijiVersionLabel' : tx.hayUnaVersionNueva(latest.version)), // l10n-ignore
      subtitle: Text(
        [
          if (update.message != null) update.message!,
          last == null ? tx.todaviaNoSeConsulto : tx.ultimaConsulta(agoText(last, DateTime.now())),
        ].join(' '),
      ),
      onTap: latest == null ? null : () => showReleaseSheet(context, latest),
      trailing: update.checking
          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
          // Ícono y no texto: con letra grande, un botón con texto no entra al lado.
          : IconButton(
              onPressed: () => ref.read(updateProvider.notifier).checkNow(),
              icon: const Icon(Icons.refresh_rounded),
              tooltip: tx.buscarAhora2,
            ),
    );
  }
}
