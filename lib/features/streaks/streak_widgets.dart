import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../providers/appearance_provider.dart';
import '../../theme/kiji_tokens.dart';
import '../../widgets/kiji_logo.dart';
import '../../widgets/nocturne/glass.dart';
import '../../widgets/top_notice.dart';
import '../lyrics/presentation/lyrics_share.dart' show renderToPng;
import '../settings/data/settings_store.dart';
import '../share_cards/now_playing_card.dart' show kijiCardUrl;
import 'streaks.dart';
import '../../utils/share_image.dart';

/// El ícono de cada logro (de menos a más).
IconData streakBadgeIcon(int days) => switch (days) {
  <= 3 => Icons.local_fire_department_rounded,
  <= 7 => Icons.whatshot_rounded,
  <= 14 => Icons.bolt_rounded,
  <= 30 => Icons.star_rounded,
  <= 100 => Icons.emoji_events_rounded,
  _ => Icons.workspace_premium_rounded,
};

/// Lunes (o el primer día de la semana del idioma) de la semana de [now].
DateTime _weekStart(BuildContext context, DateTime now) {
  final first = MaterialLocalizations.of(context).firstDayOfWeekIndex; // 0 = domingo
  final today = DateTime(now.year, now.month, now.day);
  final back = (today.weekday % 7 - first) % 7;
  return DateTime(today.year, today.month, today.day - back);
}

/// El fuego de la racha, que titila apenas (quieto con «reducir animaciones»).
class AnimatedStreakFire extends ConsumerStatefulWidget {
  const AnimatedStreakFire({super.key, this.size = 44, this.lit = true});

  final double size;
  final bool lit;

  @override
  ConsumerState<AnimatedStreakFire> createState() => _AnimatedStreakFireState();
}

class _AnimatedStreakFireState extends ConsumerState<AnimatedStreakFire> with SingleTickerProviderStateMixin {
  late final _flicker = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void dispose() {
    _flicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context, ref) || !widget.lit;
    if (still && _flicker.isAnimating) _flicker.stop();
    if (!still && !_flicker.isAnimating) _flicker.repeat();
    final color = widget.lit ? KijiColors.violet : KijiColors.muted;
    final icon = ExcludeSemantics(
      child: ShaderMask(
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: widget.lit ? [KijiColors.violet, KijiColors.cyan] : [color, color],
        ).createShader(rect),
        child: Icon(Icons.local_fire_department_rounded, size: widget.size, color: Colors.white),
      ),
    );
    if (still) return icon;
    return AnimatedBuilder(
      animation: _flicker,
      builder: (context, child) {
        final t = _flicker.value * 2 * math.pi;
        return Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.identity()
            ..scaleByDouble(1 + 0.04 * math.sin(t * 2), 1 + 0.07 * math.sin(t * 3 + 1), 1, 1)
            ..rotateZ(0.04 * math.sin(t)),
          child: child,
        );
      },
      child: icon,
    );
  }
}

/// Los días de esta semana, con un punto encendido si sonó música.
class StreakWeek extends ConsumerWidget {
  const StreakWeek({super.key, required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(streaksProvider.select((s) => s.days));
    final start = _weekStart(context, now);
    final narrow = MaterialLocalizations.of(context).narrowWeekdays; // empieza en domingo
    final today = dayKey(now);
    final week = [for (var i = 0; i < 7; i++) DateTime(start.year, start.month, start.day + i)];
    final lit = week.where((d) => days.contains(dayKey(d))).length;
    return Semantics(
      label: tx.rachaSemana(lit),
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final d in week)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(narrow[d.weekday % 7], style: KijiText.mono(size: 11, color: KijiColors.muted)),
                const SizedBox(height: 6),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: days.contains(dayKey(d)) ? KijiColors.accentGradient : null,
                    color: days.contains(dayKey(d)) ? null : KijiColors.surfaceHigh,
                    border: dayKey(d) == today ? Border.all(color: KijiColors.text, width: 1.5) : null,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// La tarjeta de la racha, arriba de Inicio (0.9): fuego, días seguidos, la mejor racha y la
/// semana. Al tocarla, la pantalla de la racha. Se puede ocultar.
class StreakCard extends ConsumerWidget {
  const StreakCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(settingsProvider.select((s) => s.streakCard))) return const SizedBox.shrink();
    final now = DateTime.now();
    final current = ref.watch(currentStreakProvider);
    final best = ref.watch(streaksProvider.select((s) => s.best));
    return Glass(
      key: const Key('streak-card'),
      radius: KijiRadii.card,
      child: InkWell(
        onTap: () => StreakScreen.open(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedStreakFire(lit: current > 0),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      label: current == 0 ? tx.rachaEmpezar : '${tx.rachaDias(current)}. ${tx.rachaMejor(best)}',
                      excludeSemantics: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (current == 0)
                            Text(tx.rachaEmpezar, style: KijiText.title(size: 16))
                          else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text('$current', style: KijiText.display(size: 40)),
                                const SizedBox(width: 8),
                                Flexible(child: Text(tx.rachaDiasSeguidos(current), style: KijiText.title(size: 16))),
                              ],
                            ),
                          if (best > 0)
                            Text(tx.rachaMejor(best), style: TextStyle(color: KijiColors.muted, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<int>(
                    tooltip: tx.masOpciones,
                    icon: Icon(Icons.more_vert_rounded, color: KijiColors.muted),
                    onSelected: (_) {
                      ref.read(settingsProvider.notifier).update((s) => s.copyWith(streakCard: false));
                      showTopNotice(
                        context,
                        message: tx.rachaOcultada,
                        actionLabel: tx.deshacer,
                        onAction: (_) =>
                            ref.read(settingsProvider.notifier).update((s) => s.copyWith(streakCard: true)),
                      );
                    },
                    itemBuilder: (_) => [PopupMenuItem(value: 0, child: Text(tx.rachaOcultar))],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: StreakWeek(now: now),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La pantalla de la racha: el mes, la mejor racha, los logros y compartirla.
class StreakScreen extends ConsumerStatefulWidget {
  const StreakScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const StreakScreen()));

  @override
  ConsumerState<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends ConsumerState<StreakScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(streaksProvider);
    final current = ref.watch(currentStreakProvider);
    final now = DateTime.now();
    final loc = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tx.rachaTitulo)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            children: [
              AnimatedStreakFire(size: 56, lit: current > 0),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$current', style: KijiText.display(size: 48)),
                    Text(tx.rachaDiasSeguidos(current), style: KijiText.title(size: 16)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${data.best}', style: KijiText.display(size: 28)),
                  Text(tx.rachaMejorTitulo, style: TextStyle(color: KijiColors.muted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // El mes, con sus días encendidos.
          Row(
            children: [
              IconButton(
                tooltip: tx.mesAnterior,
                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(loc.formatMonthYear(_month), textAlign: TextAlign.center, style: KijiText.title(size: 17)),
              ),
              IconButton(
                tooltip: tx.mesSiguiente,
                onPressed: _month.year == now.year && _month.month == now.month
                    ? null
                    : () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          _MonthGrid(month: _month, days: data.days, today: now),
          const SizedBox(height: 24),
          Text(tx.rachaLogros, style: KijiText.title(size: 18)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final m in streakMilestones)
                _Badge(
                  days: m,
                  earnedOn: data.achievements[m],
                  missing: math.max(0, m - current),
                  // Un logro ganado se puede compartir (0.9).
                  onShare: data.achievements[m] == null
                      ? null
                      : () => StreakShareScreen.open(context, current: current, best: data.best, milestone: m),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('streak-share'),
            onPressed: () => StreakShareScreen.open(context, current: current, best: data.best),
            icon: const Icon(Icons.ios_share_rounded),
            label: Text(tx.rachaCompartir),
          ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.days, required this.today});

  final DateTime month;
  final Set<String> days;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final first = loc.firstDayOfWeekIndex;
    final lead = (DateTime(month.year, month.month).weekday % 7 - first) % 7;
    final count = DateUtils.getDaysInMonth(month.year, month.month);
    final todayKey = dayKey(today);
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    loc.narrowWeekdays[(first + i) % 7],
                    style: KijiText.mono(size: 11, color: KijiColors.muted),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: [
            for (var i = 0; i < lead; i++) const SizedBox.shrink(),
            for (var d = 1; d <= count; d++)
              Builder(
                builder: (context) {
                  final key = dayKey(DateTime(month.year, month.month, d));
                  final on = days.contains(key);
                  return Semantics(
                    label: '$d${on ? ' · ${tx.rachaDiaEscuchado}' : ''}',
                    excludeSemantics: true,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: on ? KijiColors.accentGradient : null,
                        border: key == todayKey ? Border.all(color: KijiColors.text, width: 1.5) : null,
                      ),
                      child: Text(
                        '$d',
                        style: TextStyle(
                          color: on ? KijiColors.onAccent : KijiColors.muted,
                          fontWeight: on ? FontWeight.w700 : null,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.days, required this.earnedOn, required this.missing, this.onShare});

  final int days;
  final String? earnedOn;
  final int missing;

  /// Compartir este logro (solo si se ganó).
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final earned = earnedOn != null;
    final date = earned ? DateTime.tryParse(earnedOn!) : null;
    final detail = earned
        ? tx.rachaLogroGanado(date == null ? earnedOn! : MaterialLocalizations.of(context).formatShortDate(date))
        : tx.rachaLogroFalta(missing);
    return Semantics(
      label: '${tx.rachaLogroDias(days)}. $detail',
      button: onShare != null,
      hint: onShare == null ? null : tx.rachaCompartirLogro,
      excludeSemantics: true,
      child: InkWell(
        key: Key('streak-badge-$days'),
        borderRadius: BorderRadius.circular(16),
        onTap: onShare,
        child: SizedBox(
          width: 104,
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: earned ? KijiColors.accentGradient : null,
                  color: earned ? null : KijiColors.surfaceHigh,
                ),
                child: Icon(streakBadgeIcon(days), size: 32, color: earned ? KijiColors.onAccent : KijiColors.muted),
              ),
              const SizedBox(height: 6),
              Text(tx.rachaLogroDias(days), style: KijiText.title(size: 14)),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: TextStyle(color: KijiColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compartir la racha (o un logro): la tarjeta a la vista y el botón (como las frases).
class StreakShareScreen extends StatefulWidget {
  const StreakShareScreen({super.key, required this.current, required this.best, this.milestone});

  final int current;
  final int best;

  /// Un logro (días); null = la racha de hoy.
  final int? milestone;

  static Future<void> open(BuildContext context, {required int current, required int best, int? milestone}) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StreakShareScreen(current: current, best: best, milestone: milestone),
        ),
      );

  @override
  State<StreakShareScreen> createState() => _StreakShareScreenState();
}

class _StreakShareScreenState extends State<StreakShareScreen> {
  final _key = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    final file = await renderToPng(_key, widget.milestone == null ? 'kiji-racha' : 'kiji-logro');
    if (!mounted) return;
    setState(() => _sharing = false);
    await KijiShare.shareImage(
      context,
      file,
      name: widget.milestone == null ? 'kiji-racha' : 'kiji-logro',
      text: widget.milestone == null ? tx.rachaDias(widget.current) : tx.rachaLogroNuevo(widget.milestone!),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.milestone == null ? tx.rachaCompartir : tx.rachaCompartirLogro)),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: FittedBox(
                  child: RepaintBoundary(
                    key: _key,
                    child: StreakShareImage(current: widget.current, best: widget.best, milestone: widget.milestone),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('streak-share-image'),
                onPressed: _sharing ? null : _share,
                icon: const Icon(Icons.ios_share_rounded),
                label: Text(tx.compartirImagen),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// La tarjeta para compartir la racha (con el logo de Kiji).
class StreakShareImage extends StatelessWidget {
  const StreakShareImage({super.key, required this.current, required this.best, this.milestone});

  final int current;
  final int best;

  /// Un logro (días): se muestra su insignia en vez del fuego.
  final int? milestone;

  @override
  Widget build(BuildContext context) {
    final muted = Colors.white.withValues(alpha: 0.72);
    return SizedBox(
      width: 360,
      height: 640,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A1F5C), Color(0xFF0B0B14), Color(0xFF0E3440)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 48, 28, 20),
          child: Column(
            children: [
              const Spacer(),
              ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xFF7C5CFF), Color(0xFF22D3EE)],
                ).createShader(rect),
                child: Icon(
                  milestone == null ? Icons.local_fire_department_rounded : streakBadgeIcon(milestone!),
                  size: 120,
                  color: Colors.white,
                ),
              ),
              Text(
                '${milestone ?? current}',
                style: KijiText.display(size: 96).copyWith(color: Colors.white, height: 1),
              ),
              Text(
                tx.rachaDiasSeguidos(milestone ?? current),
                style: KijiText.title(size: 22).copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                milestone == null ? tx.rachaMejor(best) : tx.rachaLogroTitulo,
                style: TextStyle(color: muted, fontSize: 15),
              ),
              const Spacer(),
              Row(
                children: [
                  const KijiLogo(size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(kijiCardUrl, style: KijiText.mono(size: 11, color: muted)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Festeja un logro recién ganado (una vez): la insignia que aparece, sin sonido y sin
/// notificaciones. Con «reducir animaciones», quieta. Se va sola a los 2,5 s o al tocarla.
Future<void> showStreakCelebration(BuildContext context, int days, {required bool calm}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  var open = true;
  unawaited(
    Future<void>.delayed(const Duration(milliseconds: 2500), () {
      if (open && navigator.mounted) navigator.pop();
    }),
  );
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: tx.cerrar,
    barrierColor: Colors.black54,
    transitionDuration: calm ? Duration.zero : const Duration(milliseconds: 450),
    pageBuilder: (context, _, _) => Center(
      child: Semantics(
        liveRegion: true,
        label: tx.rachaLogroNuevo(days),
        child: Column(
          key: const Key('streak-celebration'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: KijiColors.accentGradient),
              child: Icon(streakBadgeIcon(days), size: 64, color: KijiColors.onAccent),
            ),
            const SizedBox(height: 16),
            Material(
              type: MaterialType.transparency,
              child: Text(
                tx.rachaLogroNuevo(days),
                textAlign: TextAlign.center,
                style: KijiText.title(size: 22).copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    ),
    transitionBuilder: (context, animation, _, child) => ScaleTransition(
      scale: CurvedAnimation(parent: animation, curve: Curves.elasticOut),
      child: FadeTransition(opacity: animation, child: child),
    ),
  );
  open = false;
}
