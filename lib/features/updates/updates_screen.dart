import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/kiji_tokens.dart';
import '../../utils/byte_formatter.dart';
import '../dev_tools/dev_build.dart';
import 'app_update.dart';
import 'domain/update_assets.dart';
import 'update_checker.dart';
import 'whats_new.dart';
import '../../version_label.dart';

import 'package:kiji_player/l10n/l10n.dart';
import 'package:kiji_player/widgets/nocturne/kiji_sheet.dart';

/// "Hace 3 horas", "hace 2 días" (para la última consulta).
String agoText(DateTime when, DateTime now) {
  final d = now.difference(when);
  if (d.inMinutes < 1) return tx.recien;
  if (d.inHours < 1) return tx.haceMin(d.inMinutes);
  if (d.inDays < 1) return tx.haceNHoras(d.inHours);
  return tx.haceNDias(d.inDays);
}

/// La página oficial de Kiji (descargas y novedades).
const kijiOfficialPage = 'https://kijiplayer.github.io/kiji-player'; // l10n-ignore

/// Abre la página oficial de Kiji en el navegador. Solo abre el enlace: no manda nada.
Future<void> openOfficialPage() => openReleasePage(kijiOfficialPage);

/// Abre la página oficial de la versión (en el navegador).
Future<void> openReleasePage(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (error) {
    debugPrint('=== ACTUALIZACIONES: no se pudo abrir la página: $error ===');
  }
}

/// Novedades de una versión nueva, con "Actualizar" (Android y Windows) y la página oficial.
/// [source] solo cambia en Kiji Dev, para probar con una versión servida desde la PC.
Future<void> showReleaseSheet(BuildContext context, Release release, {UpdateSource source = UpdateSource.official}) =>
    showKijiSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.8),
          child: ReleaseSheet(release: release, source: source),
        ),
      ),
    );

class ReleaseSheet extends ConsumerStatefulWidget {
  const ReleaseSheet({super.key, required this.release, this.source = UpdateSource.official});

  final Release release;
  final UpdateSource source;

  @override
  ConsumerState<ReleaseSheet> createState() => _ReleaseSheetState();
}

class _ReleaseSheetState extends ConsumerState<ReleaseSheet> {
  late final Future<ReleaseAsset?> _asset;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _asset = ref.read(appUpdateProvider.notifier).assetFor(widget.release, widget.source);
    // De vuelta de los ajustes de Android: si ya dio el permiso, se instala.
    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(ref.read(appUpdateProvider.notifier).resumeAfterPermission()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final release = widget.release;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        Text(tx.kiji(release.version), style: KijiText.title(size: 22)),
        if (release.name != release.version && release.name != 'v${release.version}')
          Text(release.name, style: TextStyle(color: KijiColors.muted)),
        const SizedBox(height: 12),
        Builder(
          builder: (_) {
            // Solo la parte en el idioma de la app (las notas de GitHub traen inglés y español).
            final notes = releaseNotesFor(release.notes, kijiLanguage);
            return Text(notes.isEmpty ? tx.estaVersionNoTraeNotas : notes, style: const TextStyle(height: 1.45));
          },
        ),
        const SizedBox(height: 16),
        FutureBuilder<ReleaseAsset?>(
          future: _asset,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) return const LinearProgressIndicator();
            return UpdateActions(release: release, source: widget.source, asset: snapshot.data);
          },
        ),
      ],
    );
  }
}

/// Botón "Actualizar" y lo que pasa después (datos móviles, progreso, permiso, errores). Siempre
/// queda "Descargar desde la página".
class UpdateActions extends ConsumerWidget {
  const UpdateActions({super.key, required this.release, required this.source, required this.asset});

  final Release release;
  final UpdateSource source;

  /// El archivo para este equipo; null: solo la página (Kiji Dev, Linux, una copia suelta en la PC).
  final ReleaseAsset? asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(appUpdateProvider.notifier);
    final all = ref.watch(appUpdateProvider);
    // El estado es de esta versión (otra que se haya probado antes no cuenta).
    final update = all.version == release.version ? all : const AppUpdateState();
    final muted = TextStyle(color: KijiColors.muted, fontSize: 13, height: 1.4);
    final asset = this.asset;
    if (asset == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isDevBuild && !source.test) ...[Text(tx.kijiDevNoSeActualiza, style: muted), const SizedBox(height: 8)],
          FilledButton.icon(
            key: const Key('update-open-page'),
            onPressed: () => openReleasePage(release.url),
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(tx.abrirLaPaginaOficial),
          ),
        ],
      );
    }
    final size = formatBytes(asset.size);
    final children = <Widget>[];
    switch (update.phase) {
      case AppUpdatePhase.idle:
        children.addAll([
          FilledButton.icon(
            key: const Key('update-start'),
            onPressed: () => notifier.start(release, source: source),
            icon: const Icon(Icons.system_update_alt_rounded),
            label: Text(tx.actualizarConTamano(size)),
          ),
          TextButton.icon(
            key: const Key('update-whats-new'),
            onPressed: openOfficialPage,
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(tx.verQueHayDeNuevo),
          ),
          const SizedBox(height: 8),
          Text(tx.actualizarComoFunciona, style: muted),
        ]);
      case AppUpdatePhase.askMobileData:
        children.addAll([
          Text(tx.noEstasConWifi, style: KijiText.title(size: 16)),
          const SizedBox(height: 4),
          Text(tx.bajarConDatosMoviles(size), style: const TextStyle(height: 1.4)),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('update-mobile-data'),
            onPressed: notifier.useMobileData,
            child: Text(tx.usarDatosMoviles),
          ),
          TextButton(onPressed: notifier.reset, child: Text(tx.esperarAlWifi)),
        ]);
      case AppUpdatePhase.downloading:
        children.addAll([
          LinearProgressIndicator(value: update.progress),
          const SizedBox(height: 8),
          Text(tx.bajandoDe(formatBytes(update.received), formatBytes(update.total)), style: muted),
          const SizedBox(height: 8),
          OutlinedButton(key: const Key('update-cancel'), onPressed: notifier.cancel, child: Text(tx.cancelar)),
        ]);
      case AppUpdatePhase.verifying:
        children.addAll([
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(tx.comprobandoElArchivo, style: muted),
        ]);
      case AppUpdatePhase.needsPermission:
        // Antes de mandar a los ajustes, por qué se pide.
        children.addAll([
          Text(tx.unPermisoParaInstalar, style: KijiText.title(size: 16)),
          const SizedBox(height: 4),
          Text(tx.permisoInstalarExplicacion, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('update-permission'),
            onPressed: notifier.openPermission,
            icon: const Icon(Icons.settings_outlined),
            label: Text(tx.irALosAjustes),
          ),
          TextButton(onPressed: notifier.resumeAfterPermission, child: Text(tx.yaLoPermiti)),
        ]);
      case AppUpdatePhase.readyToInstall:
        children.addAll([
          Text(tx.listoParaInstalarEnPc, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('update-install'),
            onPressed: notifier.install,
            icon: const Icon(Icons.restart_alt_rounded),
            label: Text(tx.instalarYVolverAAbrir),
          ),
        ]);
      case AppUpdatePhase.installing:
        children.addAll([
          Text(tx.seAbrioElInstalador, style: muted),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: notifier.install, child: Text(tx.abrirElInstalador)),
        ]);
      case AppUpdatePhase.failed:
        children.addAll([
          Text(
            switch (update.failure) {
              AppUpdateFailure.noAsset => tx.actualizacionSinArchivo,
              AppUpdateFailure.noChecksum => tx.actualizacionSinSuma,
              AppUpdateFailure.checksum => tx.actualizacionSumaDistinta,
              AppUpdateFailure.signer => tx.actualizacionFirmaDistinta,
              AppUpdateFailure.install => tx.actualizacionNoSeInstalo,
              AppUpdateFailure.download || null => tx.actualizacionNoSeBajo,
            },
            key: const Key('update-error'),
            style: const TextStyle(height: 1.4),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: notifier.reset, child: Text(tx.reintentar)),
        ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...children,
        const SizedBox(height: 4),
        // Si algo falla (o la persona prefiere), como antes: la página oficial.
        TextButton.icon(
          key: const Key('update-open-page'),
          onPressed: () => openReleasePage(release.url),
          icon: const Icon(Icons.open_in_new_rounded),
          label: Text(tx.descargarDesdeLaPagina),
        ),
      ],
    );
  }
}

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
