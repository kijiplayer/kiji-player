// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivos de referencia: ui/screens/LoginScreen.kt (iniciar sesión en una WebView y quedarse con
// las cookies de music.youtube.com) y ui/screens/settings/AccountSettingsScreen.kt.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/kiji_tokens.dart';
import '../../../widgets/nocturne/glass.dart';
import '../../settings/data/settings_store.dart';
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
                  style: const TextStyle(color: KijiColors.muted, height: 1.4),
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
              onPressed: () => LoginScreen.open(context),
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
  return LoginScreen.open(context);
}
