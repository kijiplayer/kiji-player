import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/appearance_provider.dart';
import '../../theme/kiji_tokens.dart';
import '../../widgets/global_mini_player.dart';
import '../../widgets/nocturne/aurora_background.dart';
import '../../widgets/nocturne/glass.dart';
import '../desktop/desktop_window.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Una novedad: ícono, título y una línea.
typedef WhatsNewItem = ({IconData icon, String title, String text});

/// Lo nuevo de la 0.7, en tarjetas cortas. Lo de la PC va al final y solo en la PC.
List<WhatsNewItem> whatsNewItems({required bool desktop}) => [
  (icon: Icons.palette_outlined, title: tx.nuevoEstilosTitulo, text: tx.nuevoEstilosTexto),
  (icon: Icons.graphic_eq_rounded, title: tx.nuevoOndaTitulo, text: tx.nuevoOndaTexto),
  (icon: Icons.lyrics_outlined, title: tx.nuevoLetrasTitulo, text: tx.nuevoLetrasTexto),
  (icon: Icons.bluetooth_audio_rounded, title: tx.nuevoBluetoothTitulo, text: tx.nuevoBluetoothTexto),
  (icon: Icons.shuffle_rounded, title: tx.nuevoAleatorioTitulo, text: tx.nuevoAleatorioTexto),
  (icon: Icons.manage_search_rounded, title: tx.nuevoBuscarPlaylistTitulo, text: tx.nuevoBuscarPlaylistTexto),
  (icon: Icons.emoji_events_outlined, title: tx.nuevoMasEscuchadasTitulo, text: tx.nuevoMasEscuchadasTexto),
  if (desktop) (icon: Icons.desktop_windows_outlined, title: tx.nuevoPcTitulo, text: tx.nuevoPcTexto),
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
                                tx.queHayDeNuevoSubtitulo,
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
