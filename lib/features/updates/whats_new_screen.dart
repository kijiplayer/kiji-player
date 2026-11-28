import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/appearance_provider.dart';
import '../../theme/kiji_tokens.dart';
import '../../widgets/global_mini_player.dart';
import '../../widgets/nocturne/aurora_background.dart';
import '../../widgets/nocturne/glass.dart';
import '../../store_flavor.dart';
import '../desktop/desktop_window.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Una novedad: ícono, título y una línea.
typedef WhatsNewItem = ({IconData icon, String title, String text});

/// Lo nuevo de la 0.9, en tarjetas cortas y con lo más importante primero. El ecualizador de 10
/// bandas es lo nuevo de Android (la PC ya lo tenía); lo de la PC va al final y solo en la PC. En el
/// sabor «play», sin YouTube Music ni descargas.
List<WhatsNewItem> whatsNewItems({required bool desktop}) => [
  (icon: Icons.library_music_outlined, title: tx.novedades09BibliotecaTitulo, text: tx.novedades09BibliotecaTexto),
  if (!isPlayStore)
    (icon: Icons.sync_rounded, title: tx.novedades09YoutubeTitulo, text: tx.novedades09YoutubeTexto),
  if (!desktop)
    (icon: Icons.equalizer_rounded, title: tx.novedades09EcualizadorTitulo, text: tx.novedades09EcualizadorTexto),
  (
    icon: Icons.speed_rounded,
    title: tx.novedades09RapidaTitulo,
    text: desktop ? tx.novedades09RapidaPcTexto : tx.novedades09RapidaTexto,
  ),
  (icon: Icons.local_fire_department_rounded, title: tx.novedades09RachasTitulo, text: tx.novedades09RachasTexto),
  (icon: Icons.water_drop_outlined, title: tx.novedades09LiquidTitulo, text: tx.novedades09LiquidTexto),
  (icon: Icons.ios_share_rounded, title: tx.novedades09TarjetasTitulo, text: tx.novedades09TarjetasTexto),
  (icon: Icons.fast_forward_rounded, title: tx.novedades09SponsorTitulo, text: tx.novedades09SponsorTexto),
  if (!isPlayStore && !desktop)
    (icon: Icons.download_for_offline_outlined, title: tx.novedades09PlaylistTitulo, text: tx.novedades09PlaylistTexto),
  if (desktop) (icon: Icons.desktop_windows_outlined, title: tx.novedades09PcTitulo, text: tx.novedades09PcTexto),
];

/// "Qué hay de nuevo": una sola vez después de actualizar (nunca en una instalación nueva, que
/// ya tiene la bienvenida) y cuando se quiera desde Configuración → Acerca de. Las tarjetas entran
/// según el estilo (Nocturne: suben con la aurora detrás; Grafito: con un resorte; Papel: aparecen
/// de a una, como tinta) y, con "Reducir animaciones", aparecen quietas.
class WhatsNewScreen extends ConsumerWidget {
  const WhatsNewScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    PageRouteBuilder<void>(
      settings: const RouteSettings(name: KijiRoutes.whatsNew),
      transitionDuration: KijiMotion.emphasized,
      reverseTransitionDuration: KijiMotion.normal,
      pageBuilder: (_, _, _) => const WhatsNewScreen(),
      transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calm = reduceMotion(context, ref);
    final items = whatsNewItems(desktop: DesktopWindow.isDesktop);
    return Scaffold(
      backgroundColor: KijiColors.background,
      body: Stack(
        children: [
          if (KijiLook.nocturne)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 360,
              child: IgnorePointer(
                child: AuroraBackground(
                  colors: [KijiColors.violet, KijiColors.cyan],
                  moving: !calm,
                  intensity: 0.6,
                  fadeOut: true,
                ),
              ),
            ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, box) {
                // Dos columnas de tarjetas cuando hay lugar (PC, tablet).
                final columns = box.maxWidth >= 760 ? 2 : 1;
                final width = min(box.maxWidth, 880.0);
                final cardWidth = (width - 48 - 12 * (columns - 1)) / columns;
                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(horizontal: (box.maxWidth - width) / 2 + 24, vertical: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CardIn(
                              index: 0,
                              calm: calm,
                              child: Text(tx.queHayDeNuevo, style: KijiText.title(size: 32)),
                            ),
                            const SizedBox(height: 6),
                            _CardIn(
                              index: 0,
                              calm: calm,
                              child: Text(
                                tx.novedades09Subtitulo,
                                style: TextStyle(color: KijiColors.muted, fontSize: 16),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (final (i, item) in items.indexed)
                                  SizedBox(
                                    width: cardWidth,
                                    child: _CardIn(
                                      index: i + 1,
                                      calm: calm,
                                      child: _NewsCard(item: item),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        (box.maxWidth - width) / 2 + 24,
                        8,
                        (box.maxWidth - width) / 2 + 24,
                        20,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const Key('whats-new-start'),
                          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(tx.empezar, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item});

  final WhatsNewItem item;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Glass(
        blur: false,
        radius: KijiRadii.tile,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: KijiColors.violet.withValues(alpha: KijiColors.palette.isLight ? 0.10 : 0.16),
              ),
              child: Icon(item.icon, color: KijiColors.cyan),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: KijiText.title(size: 17, weight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(item.text, style: TextStyle(color: KijiColors.muted, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Entrada de cada tarjeta, una después de la otra, a la manera de cada estilo.
class _CardIn extends StatefulWidget {
  const _CardIn({required this.index, required this.calm, required this.child});

  final int index;
  final bool calm;
  final Widget child;

  @override
  State<_CardIn> createState() => _CardInState();
}

class _CardInState extends State<_CardIn> with SingleTickerProviderStateMixin {
  // Papel va más despacio (aparece de a una); Grafito, con resorte; Nocturne, suben.
  static Duration get _each =>
      KijiLook.style == KijiStyle.paper ? const Duration(milliseconds: 520) : const Duration(milliseconds: 460);
  static const _gap = Duration(milliseconds: 70);

  late final Duration _delay = _gap * widget.index;
  late final AnimationController _c = AnimationController(vsync: this, duration: _delay + _each);

  @override
  void initState() {
    super.initState();
    widget.calm ? _c.value = 1 : _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.calm) return widget.child;
    final start = _delay.inMicroseconds / _c.duration!.inMicroseconds;
    final curve = switch (KijiLook.style) {
      KijiStyle.graphite => KijiMotion.spring,
      KijiStyle.paper => Curves.easeOut,
      KijiStyle.nocturne => Curves.easeOutCubic,
    };
    final t = CurvedAnimation(
      parent: _c,
      curve: Interval(start, 1, curve: curve),
    );
    return AnimatedBuilder(
      animation: t,
      builder: (context, child) {
        final v = t.value;
        final moved = switch (KijiLook.style) {
          // Papel: casi quieta, como tinta que aparece.
          KijiStyle.paper => Transform.translate(offset: Offset(0, 6 * (1 - v)), child: child),
          KijiStyle.graphite => Transform.translate(offset: Offset(0, 28 * (1 - v)), child: child),
          KijiStyle.nocturne => Transform.translate(
            offset: Offset(0, 22 * (1 - v)),
            child: Transform.scale(scale: 0.96 + 0.04 * v, child: child),
          ),
        };
        return Opacity(opacity: v.clamp(0.0, 1.0), child: moved);
      },
      child: widget.child,
    );
  }
}
