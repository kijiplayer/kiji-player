import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../providers/appearance_provider.dart';
import '../../../providers/downloads_provider.dart';
import '../../../theme/kiji_tokens.dart';
import '../../../widgets/nocturne/glass.dart';
import '../../settings/data/settings_store.dart';
import '../../settings/domain/app_settings.dart';
import '../../translation/domain/languages.dart';
import '../data/welcome_store.dart';
import 'kiji_notes_logo.dart';

/// Bienvenida para quien recién instala Kiji (diseño Nocturne): 5 pantallas, "Saltar" en todas.
/// Se muestra sola una única vez (ver [WelcomeStore]); después, desde Acerca de.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key, this.store, this.playSound = true});

  /// Dónde se anota que ya se vio (en las pruebas, una carpeta temporal).
  final WelcomeStore? store;

  /// Las 5 notas al abrir (en las pruebas, sin sonido).
  final bool playSound;

  static Future<void> open(BuildContext context, {bool instant = false}) => Navigator.of(context).push(
    PageRouteBuilder<void>(
      fullscreenDialog: true,
      transitionDuration: instant ? Duration.zero : KijiMotion.emphasized,
      pageBuilder: (_, _, _) => const WelcomeScreen(),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
    ),
  );

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  static const _pages = 5;
  final _controller = PageController();
  int _page = 0;
  late bool _muted = !widget.playSound;

  Future<void> _finish() async {
    await (widget.store ?? WelcomeStore()).markSeen();
    if (mounted) Navigator.of(context).pop();
  }

  void _next() {
    if (_page == _pages - 1) {
      _finish();
      return;
    }
    _controller.nextPage(duration: KijiMotion.normal, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context, ref);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        backgroundColor: KijiColors.background,
        body: Stack(
          children: [
            const Positioned.fill(child: _Glow()),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                    child: Row(
                      children: [
                        if (_page == 0)
                          IconButton(
                            tooltip: _muted ? tx.bienvenidaActivarSonido : tx.bienvenidaSilenciar,
                            icon: Icon(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
                            color: KijiColors.muted,
                            onPressed: () => setState(() => _muted = !_muted),
                          ),
                        const Spacer(),
                        TextButton(onPressed: _finish, child: Text(tx.bienvenidaSaltar)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _controller,
                      onPageChanged: (page) => setState(() => _page = page),
                      children: [
                        _HelloPage(muted: _muted, still: still),
                        const _WhatPage(),
                        const _StoryPage(),
                        const _OptionsPage(),
                        const _PrivacyPage(),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                    child: Row(
                      children: [
                        _Dots(count: _pages, current: _page),
                        const SizedBox(width: 12),
                        // Con letra muy grande, el texto del botón se achica un poco en vez de cortarse.
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _GradientButton(
                              label: _page == _pages - 1 ? tx.bienvenidaEmpezar : tx.bienvenidaSiguiente,
                              onPressed: _next,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un brillo violeta y otro cian de fondo, como en el reproductor.
class _Glow extends StatelessWidget {
  const _Glow();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.9, -0.8),
          radius: 1.1,
          colors: [Color(0x407C5CFF), Color(0x0007070C)],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(1, 0.9),
            radius: 1.0,
            colors: [Color(0x303DF5FF), Color(0x0007070C)],
          ),
        ),
      ),
    );
  }
}

/// Una pantalla de la bienvenida: con scroll por si la letra es grande.
class _Page extends StatelessWidget {
  const _Page({required this.children, this.center = false});

  final List<Widget> children;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
                crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- 1 · Hola ---------------------------------------------------------------------------------

class _HelloPage extends ConsumerStatefulWidget {
  const _HelloPage({required this.muted, required this.still});

  final bool muted;
  final bool still;

  @override
  ConsumerState<_HelloPage> createState() => _HelloPageState();
}

class _HelloPageState extends ConsumerState<_HelloPage> {
  static const _greetings = ['Hola', 'Hello']; // l10n-ignore
  int _greeting = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (!widget.still) {
      _timer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
        if (mounted) setState(() => _greeting = 1 - _greeting);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final setting = ref.watch(settingsProvider.select((s) => s.language));
    final phone = resolveKijiLocale('system', WidgetsBinding.instance.platformDispatcher.locale).languageCode;
    final current = setting == 'system' ? phone : setting;
    Future<void> choose(String language) => ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(language: language == phone ? 'system' : language));

    return _Page(
      center: true,
      children: [
        KijiNotesLogo(muted: widget.muted, reduceMotion: widget.still),
        const SizedBox(height: 28),
        Semantics(
          liveRegion: false,
          label: tx.bienvenidaHola,
          excludeSemantics: true,
          child: AnimatedSwitcher(
            duration: KijiMotion.emphasized,
            child: GradientText(
              _greetings[_greeting],
              key: ValueKey(_greeting),
              style: KijiText.title(size: 44),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          tx.bienvenidaSoyKiji,
          textAlign: TextAlign.center,
          style: const TextStyle(color: KijiColors.muted, fontSize: 16, height: 1.4),
        ),
        const SizedBox(height: 28),
        Text(tx.bienvenidaEligeTuIdioma.toUpperCase(), style: KijiText.mono(size: 11)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (final (code, name) in [('es', 'Español'), ('en', 'English')]) // l10n-ignore
              ChoiceChip(
                label: Text(name),
                selected: current == code,
                onSelected: (_) => choose(code),
                selectedColor: KijiColors.violet.withValues(alpha: 0.35),
                side: const BorderSide(color: KijiColors.glassBorder),
              ),
          ],
        ),
      ],
    );
  }
}

// --- 2 · Qué es Kiji --------------------------------------------------------------------------

class _WhatPage extends StatelessWidget {
  const _WhatPage();

  @override
  Widget build(BuildContext context) {
    return _Page(
      children: [
        Text(tx.bienvenidaQueEsKiji, style: KijiText.title(size: 30)),
        const SizedBox(height: 8),
        Text(tx.bienvenidaQueEsKijiNota, style: const TextStyle(color: KijiColors.muted, height: 1.4)),
        const SizedBox(height: 20),
        _Card(icon: Icons.shield_outlined, title: tx.bienvenidaTarjeta1Titulo, text: tx.bienvenidaTarjeta1Texto),
        _Card(icon: Icons.library_music_outlined, title: tx.bienvenidaTarjeta2Titulo, text: tx.bienvenidaTarjeta2Texto),
        _Card(icon: Icons.lyrics_outlined, title: tx.bienvenidaTarjeta3Titulo, text: tx.bienvenidaTarjeta3Texto),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Glass(
        blur: false,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => KijiColors.accentGradientDiagonal.createShader(bounds),
              child: Icon(icon, size: 30, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: KijiText.title(size: 17)),
                  const SizedBox(height: 4),
                  Text(text, style: const TextStyle(color: KijiColors.muted, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 3 · La historia (BORRADOR: el texto está en revisión) -------------------------------------

class _StoryPage extends StatelessWidget {
  const _StoryPage();

  @override
  Widget build(BuildContext context) {
    return _Page(
      children: [
        Row(
          children: [
            Flexible(child: Text(tx.bienvenidaHistoriaTitulo, style: KijiText.title(size: 30))),
            const SizedBox(width: 10),
            // Se quita cuando se apruebe el texto.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: KijiColors.cyan.withValues(alpha: 0.6)),
                borderRadius: BorderRadius.circular(KijiRadii.pill),
              ),
              child: Text(tx.bienvenidaBorrador, style: KijiText.mono(size: 10, color: KijiColors.cyan)),
            ),
          ],
        ),
        const SizedBox(height: 18),
        for (final paragraph in [
          tx.bienvenidaHistoria1,
          tx.bienvenidaHistoria2,
          tx.bienvenidaHistoria3,
          tx.bienvenidaHistoria4,
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(paragraph, style: const TextStyle(fontSize: 16, height: 1.5)),
          ),
      ],
    );
  }
}

// --- 4 · Opcional -----------------------------------------------------------------------------

class _OptionsPage extends ConsumerWidget {
  const _OptionsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final update = ref.read(settingsProvider.notifier).update;
    final wifiOnly = ref.watch(downloadsProvider.select((d) => d.settings.wifiOnly));
    return _Page(
      children: [
        Text(tx.bienvenidaAjustaATuGusto, style: KijiText.title(size: 30)),
        const SizedBox(height: 8),
        Text(tx.bienvenidaOpcionalNota, style: const TextStyle(color: KijiColors.muted, height: 1.4)),
        const SizedBox(height: 18),
        Glass(
          blur: false,
          radius: KijiRadii.tile,
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.translate_rounded),
                  title: Text(tx.bienvenidaTraducirLetrasAl),
                  subtitle: Text(languageName(settings.translationTarget)),
                  trailing: const Icon(Icons.expand_more_rounded),
                  onTap: () async {
                    final value = await showDialog<String>(
                      context: context,
                      builder: (context) => SimpleDialog(
                        title: Text(tx.bienvenidaTraducirLetrasAl),
                        children: [
                          for (final entry in translationLanguages.entries)
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(context, entry.key),
                              child: Text(entry.value),
                            ),
                        ],
                      ),
                    );
                    if (value != null) await update((s) => s.copyWith(translationTarget: value));
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.high_quality_outlined),
                  title: Text(tx.bienvenidaCalidad),
                  subtitle: Text(settings.dataSaver ? tx.bienvenidaCalidadAhorro : tx.bienvenidaCalidadMejor),
                  value: !settings.dataSaver,
                  onChanged: (best) => update((s) => s.copyWith(dataSaver: !best)),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.wifi_rounded),
                  title: Text(tx.bienvenidaAhorroDeDatos),
                  subtitle: Text(tx.bienvenidaAhorroDeDatosTexto),
                  value: wifiOnly,
                  onChanged: ref.read(downloadsProvider.notifier).setWifiOnly,
                ),
                ListTile(
                  leading: const Icon(Icons.swap_horiz_rounded),
                  title: Text(tx.transicionSuave),
                  subtitle: Text(
                    settings.crossfadeSeconds == 0 ? tx.apagada : tx.nSegundos(settings.crossfadeSeconds),
                  ),
                  trailing: const Icon(Icons.expand_more_rounded),
                  onTap: () async {
                    final value = await showDialog<int>(
                      context: context,
                      builder: (context) => SimpleDialog(
                        title: Text(tx.transicionSuave),
                        children: [
                          for (final option in AppSettings.crossfadeOptions)
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(context, option),
                              child: Text(option == 0 ? tx.apagada : tx.nSegundos(option)),
                            ),
                        ],
                      ),
                    );
                    if (value != null) await update((s) => s.copyWith(crossfadeSeconds: value));
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(tx.bienvenidaSeCambiaEnConfiguracion, style: KijiText.mono(size: 11)),
      ],
    );
  }
}

// --- 5 · Privacidad ---------------------------------------------------------------------------

class _PrivacyPage extends StatelessWidget {
  const _PrivacyPage();

  @override
  Widget build(BuildContext context) {
    return _Page(
      center: true,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => KijiColors.accentGradientDiagonal.createShader(bounds),
          child: const Icon(Icons.shield_rounded, size: 88, color: Colors.white),
        ),
        const SizedBox(height: 24),
        GradientText(tx.bienvenidaKijiNoRecopilaNada, style: KijiText.title(size: 30)),
        const SizedBox(height: 14),
        Text(
          tx.bienvenidaPrivacidadTexto,
          textAlign: TextAlign.center,
          style: const TextStyle(color: KijiColors.muted, fontSize: 16, height: 1.5),
        ),
      ],
    );
  }
}

// --- Piezas -----------------------------------------------------------------------------------

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tx.bienvenidaPaginaDe(current + 1, count),
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: KijiMotion.fast,
              margin: const EdgeInsets.only(right: 6),
              width: i == current ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(KijiRadii.pill),
                gradient: i == current ? KijiColors.accentGradient : null,
                color: i == current ? null : KijiColors.waveRest,
              ),
            ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: KijiColors.accentGradient,
          borderRadius: BorderRadius.all(Radius.circular(KijiRadii.pill)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            customBorder: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(color: KijiColors.onAccent, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
