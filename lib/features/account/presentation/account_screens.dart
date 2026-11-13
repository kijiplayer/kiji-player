// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivos de referencia: ui/screens/LoginScreen.kt (iniciar sesión en una WebView y quedarse con
// las cookies de music.youtube.com) y ui/screens/settings/AccountSettingsScreen.kt.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/kiji_tokens.dart';
import '../../backup/presentation/backup_screen.dart' show describeDate;
import '../../../widgets/nocturne/glass.dart';
import '../../settings/data/settings_store.dart';
import '../data/yt_sync.dart';
import '../data/account_store.dart';
import '../domain/yt_session.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Advertencia que se muestra siempre antes de iniciar sesión.
String get accountWarning => tx.youtubePuedeLimitarOSuspenderCuentas;

/// Qué pasa con tu sesión (y qué no).
String get accountPrivacy => tx.tuSesionSeGuardaCifradaSolo;

/// Configuración → Cuenta: iniciar o cerrar sesión con Google (opcional).
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AccountScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(accountProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tx.cuenta)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Glass(
            blur: false,
            radius: KijiRadii.card,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      session == null ? Icons.person_outline_rounded : Icons.verified_user_rounded,
                      color: session == null ? KijiColors.muted : KijiColors.cyan,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        session == null
                            ? tx.sinSesion
                            : tx.sesionIniciada(session.name == null ? '' : ': ${session.name}'),
                        style: KijiText.title(size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  session == null
                      ? tx.kijiFuncionaSinCuenta
                      : tx.lasCancionesConRestriccionDeEdad,
                  style: TextStyle(color: KijiColors.muted, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Notice(icon: Icons.warning_amber_rounded, color: const Color(0xFFFFB84D), text: accountWarning),
          const SizedBox(height: 10),
          _Notice(icon: Icons.lock_outline_rounded, color: KijiColors.cyan, text: accountPrivacy),
          const SizedBox(height: 20),
          if (session == null)
            FilledButton.icon(
              icon: const Icon(Icons.login_rounded),
              label: Text(tx.iniciarSesionConGoogle),
              onPressed: () => signInToYouTubeMusic(context, ref),
            )
          else
            OutlinedButton.icon(
              icon: const Icon(Icons.logout_rounded),
              label: Text(tx.cerrarSesionYBorrarla),
              onPressed: () async {
                await ref.read(accountProvider.notifier).signOut();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tx.sesionCerradaYBorrada)));
                }
              },
            ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tx.ofrecerIniciarSesionCuandoUnaCancion),
            subtitle: Text(tx.comoMuchoUnaVezPorCancion),
            value: !ref.watch(settingsProvider.select((s) => s.accountPromptsOff)),
            onChanged: (v) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(accountPromptsOff: !v)),
          ),
          // Sincronizar (solo lectura), solo con la sesión iniciada. Apagado de fábrica.
          if (session != null) ...[
            SwitchListTile(
              key: const Key('account-yt-sync'),
              contentPadding: EdgeInsets.zero,
              title: Text(tx.sincronizarConYoutube),
              subtitle: Text(tx.sincronizarConYoutubeNota),
              value: ref.watch(settingsProvider.select((s) => s.ytSync)),
              onChanged: (v) async {
                await ref.read(settingsProvider.notifier).update((s) => s.copyWith(ytSync: v));
                if (v) {
                  await ref.read(ytSyncProvider.notifier).syncNow();
                } else {
                  await ref.read(ytSyncProvider.notifier).forget();
                }
              },
            ),
            if (ref.watch(settingsProvider.select((s) => s.ytSync)))
              Builder(
                builder: (context) {
                  final sync = ref.watch(ytSyncProvider);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.sync_rounded),
                    title: Text(
                      sync.syncedAt == null
                          ? tx.todaviaNoSeLeyoLaCuenta
                          : tx.deTuCuentaMeGustaYPlaylists(sync.liked.length, sync.playlists.length),
                    ),
                    trailing: sync.syncing
                        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : TextButton(
                            onPressed: () => ref.read(ytSyncProvider.notifier).syncNow(),
                            child: Text(tx.leerAhora),
                          ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
    ],
  );
}

/// Inicio de sesión de Google en una WebView, como en el navegador. Al llegar a YouTube Music,
/// Kiji se queda con la sesión (cifrada) y borra las cookies de la WebView.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  /// Devuelve true si se inició sesión.
  static Future<bool> open(BuildContext context) async =>
      await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const LoginScreen())) ?? false;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static final _start = WebUri(
    'https://accounts.google.com/ServiceLogin?continue=${Uri.encodeComponent('https://music.youtube.com')}',
  );
  bool _done = false;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Se empieza sin cookies: nada de otras sesiones de la WebView.
    CookieManager.instance().deleteAllCookies().whenComplete(() {
      if (mounted) setState(() => _ready = true);
    });
  }

  Future<void> _onPage(InAppWebViewController controller, WebUri? url) async {
    if (_done || url == null || !url.host.endsWith('music.youtube.com')) return;
    _done = true;
    try {
      final cookies = await CookieManager.instance().getCookies(url: WebUri('https://music.youtube.com'));
      final cookie = [for (final c in cookies) '${c.name}=${c.value}'].join('; ');
      final config = await controller.evaluateJavascript(
        source: 'JSON.stringify(window.yt && yt.config_ ? [yt.config_.VISITOR_DATA, yt.config_.DATASYNC_ID] : [])', // l10n-ignore
      );
      final values = config is String ? jsonDecode(config) : null;
      final session = YtSession(
        cookie: cookie,
        visitorData: values is List && values.isNotEmpty ? values[0] as String? : null,
        dataSyncId: values is List && values.length > 1 ? (values[1] as String?)?.split('||').first : null,
      );
      final ok = await ref.read(accountProvider.notifier).signIn(session);
      // La sesión ya está guardada (cifrada): la WebView no se queda con nada.
      await CookieManager.instance().deleteAllCookies();
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _done = false;
          _error = tx.noSePudoCompletarElInicio;
        });
      }
    } catch (error) {
      debugPrint('=== CUENTA: falló el inicio de sesión (${error.runtimeType}) ===');
      if (mounted) {
        setState(() {
          _done = false;
          _error = tx.noSePudoCompletarElInicio;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tx.iniciarSesionConGoogle)),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0x33FFB84D),
            padding: const EdgeInsets.all(12),
            child: Text(_error ?? accountWarning, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            child: !_ready
                ? const Center(child: CircularProgressIndicator())
                : InAppWebView(
                    initialUrlRequest: URLRequest(url: _start),
                    initialSettings: InAppWebViewSettings(javaScriptEnabled: true, incognito: false),
                    onLoadStop: _onPage,
                  ),
          ),
        ],
      ),
    );
  }
}

/// "Esta canción necesita una cuenta": explica y ofrece iniciar sesión, sin insistir.
/// Devuelve true si se inició sesión.
Future<bool> showAccountOfferDialog(BuildContext context, WidgetRef ref, AccountOffer offer) async {
  final choice = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.lock_person_outlined),
      title: Text(tx.estaCancionNecesitaUnaCuenta),
      content: Text(tx.youtubeMarcoConRestriccionDeEdad(offer.title, accountWarning)),
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, 'never'), child: Text(tx.noVolverAPreguntar)),
        TextButton(onPressed: () => Navigator.pop(context, 'no'), child: Text(tx.errorReportNoThanks)),
        FilledButton(onPressed: () => Navigator.pop(context, 'login'), child: Text(tx.iniciarSesion)),
      ],
    ),
  );
  if (choice == 'never') {
    await ref.read(settingsProvider.notifier).update((s) => s.copyWith(accountPromptsOff: true));
  }
  if (choice != 'login' || !context.mounted) return false;
  return signInToYouTubeMusic(context, ref);
}

/// Inicia sesión en YouTube Music (la pantalla de Google) y, la primera vez que sale bien, pregunta
/// una sola vez si activar la sincronización (con "Ahora no", queda apagada). Siempre opcional: sin
/// cuenta Kiji funciona igual. Devuelve true si se inició sesión.
Future<bool> signInToYouTubeMusic(BuildContext context, WidgetRef ref) async {
  final ok = await LoginScreen.open(context);
  if (!ok || !context.mounted) return ok;
  await offerSyncOnce(context, ref);
  return true;
}

/// La pregunta de una sola vez: "¿Sincronizar con YouTube Music?".
Future<void> offerSyncOnce(BuildContext context, WidgetRef ref) async {
  final settings = ref.read(settingsProvider);
  if (settings.ytSyncOffered || settings.ytSync) return;
  await ref.read(settingsProvider.notifier).update((s) => s.copyWith(ytSyncOffered: true));
  if (!context.mounted) return;
  final yes = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      icon: const Icon(Icons.sync_rounded),
      title: Text(tx.activarSincronizacionTitulo),
      content: Text(tx.activarSincronizacionNota),
      actions: [
        TextButton(key: const Key('yt-sync-offer-no'), onPressed: () => Navigator.pop(dialog, false), child: Text(tx.ahoraNo)),
        FilledButton(
          key: const Key('yt-sync-offer-yes'),
          onPressed: () => Navigator.pop(dialog, true),
          child: Text(tx.activarSincronizacion),
        ),
      ],
    ),
  );
  if (yes != true) return;
  await ref.read(settingsProvider.notifier).update((s) => s.copyWith(ytSync: true));
  unawaited(ref.read(ytSyncProvider.notifier).syncNow());
}

/// Biblioteca, sin sesión: "Conecta tu YouTube Music (opcional)". Discreta, y con "No mostrar más"
/// no vuelve.
class YtConnectCard extends ConsumerWidget {
  const YtConnectCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(accountProvider) != null || ref.watch(settingsProvider.select((s) => s.ytConnectCardHidden))) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Glass(
        key: const Key('yt-connect-card'),
        blur: false,
        radius: KijiRadii.card,
        padding: const EdgeInsets.fromLTRB(16, 12, 6, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.library_music_outlined, color: KijiColors.cyan, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(tx.conectaTuYoutubeMusic, style: KijiText.title(size: 15))),
                IconButton(
                  key: const Key('yt-connect-hide'),
                  tooltip: tx.noMostrarMas,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => ref.read(settingsProvider.notifier).update((s) => s.copyWith(ytConnectCardHidden: true)),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(tx.conectaTuYoutubeMusicNota, style: TextStyle(color: KijiColors.muted, fontSize: 13, height: 1.35)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  key: const Key('yt-connect-sign-in'),
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: Text(tx.iniciarSesionBoton),
                  onPressed: () => signInToYouTubeMusic(context, ref),
                ),
                TextButton(
                  onPressed: () => ref.read(settingsProvider.notifier).update((s) => s.copyWith(ytConnectCardHidden: true)),
                  child: Text(tx.noMostrarMas),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Configuración → Cuenta: el estado, con "Iniciar sesión" o "Cerrar sesión" a la mano (tocar la
/// fila abre los detalles: qué guarda Kiji y los avisos).
class AccountStatusTile extends ConsumerWidget {
  const AccountStatusTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(accountProvider);
    return ListTile(
      key: const Key('account-status'),
      leading: Icon(session == null ? Icons.person_outline_rounded : Icons.verified_user_rounded),
      title: Text(session == null ? tx.cuentaYoutubeMusic : tx.sesionIniciada(session.name == null ? '' : ': ${session.name}')),
      subtitle: Text(
        session == null
            ? tx.cuentaOpcionalNota
            : (YtSessionHolder.rejected ? tx.sesionVencidaVuelveAConectar : tx.sesionSoloEnEsteDispositivo),
      ),
      onTap: () => AccountScreen.open(context),
      trailing: session == null
          ? FilledButton(
              key: const Key('account-sign-in'),
              onPressed: () => signInToYouTubeMusic(context, ref),
              child: Text(tx.iniciarSesionBoton),
            )
          : OutlinedButton(
              key: const Key('account-sign-out'),
              onPressed: () async {
                await ref.read(accountProvider.notifier).signOut();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tx.sesionCerradaYBorrada)));
                }
              },
              child: Text(tx.cerrarSesionBoton),
            ),
    );
  }
}

/// Configuración → Cuenta: "Sincronizar con YouTube" (apagada de fábrica; sin sesión, deshabilitada).
class SyncSwitchTile extends ConsumerWidget {
  const SyncSwitchTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(accountProvider);
    return SwitchListTile(
      key: const Key('settings-yt-sync'),
      title: Text(tx.sincronizarConYoutube),
      subtitle: Text(session == null ? tx.iniciaSesionParaSincronizar : tx.sincronizarConYoutubeNota),
      value: session != null && ref.watch(settingsProvider.select((s) => s.ytSync)),
      onChanged: session == null
          ? null
          : (v) async {
              await ref.read(settingsProvider.notifier).update((s) => s.copyWith(ytSync: v, ytSyncOffered: true));
              if (v) {
                await ref.read(ytSyncProvider.notifier).syncNow();
              } else {
                await ref.read(ytSyncProvider.notifier).forget();
              }
            },
    );
  }
}

/// Configuración → Cuenta: cuándo fue la última sincronización y "Sincronizar ahora" (con sesión y
/// la sincronización prendida).
class SyncNowTile extends ConsumerWidget {
  const SyncNowTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(accountProvider) == null || !ref.watch(settingsProvider.select((s) => s.ytSync))) {
      return const SizedBox.shrink();
    }
    final sync = ref.watch(ytSyncProvider);
    final at = sync.syncedAt;
    return ListTile(
      key: const Key('settings-yt-sync-now'),
      leading: const Icon(Icons.sync_rounded),
      title: Text(at == null ? tx.todaviaNoSeSincronizo : tx.ultimaSincronizacion(describeDate(at, DateTime.now()))),
      subtitle: at == null ? null : Text(tx.deTuCuentaMeGustaYPlaylists(sync.liked.length, sync.playlists.length)),
      trailing: sync.syncing
          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : TextButton(onPressed: () => ref.read(ytSyncProvider.notifier).syncNow(), child: Text(tx.sincronizarAhora)),
    );
  }
}

