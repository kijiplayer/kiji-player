import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/kiji_tokens.dart';
import '../../settings/data/settings_store.dart';
import '../../settings/domain/app_settings.dart';

import 'package:kiji_player/l10n/l10n.dart';
import 'package:kiji_player/widgets/nocturne/kiji_sheet.dart';

/// Una acción del menú ⋯ de la letra.
class LyricsMenuAction {
  const LyricsMenuAction({required this.icon, required this.label, required this.onTap, this.active = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Prendida (por ejemplo, la traducción): el ícono va con el degradado.
  final bool active;
}

/// Un grupo de acciones con su título.
class LyricsMenuGroup {
  const LyricsMenuGroup(this.title, this.actions);

  final String title;
  final List<LyricsMenuAction> actions;
}

/// ⋯ de la letra: hoja de vidrio con íconos grandes, agrupados, y el tamaño de la letra.
/// Al tocar una acción la hoja se cierra y después corre la acción.
Future<void> showLyricsMenuSheet(BuildContext context, {required List<LyricsMenuGroup> groups}) => showKijiSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black38,
  constraints: const BoxConstraints(maxWidth: 560),
  // La hoja dibuja su propia barrita (la del tema quedaría encima, doble).
  showDragHandle: false,
  builder: (_) => AlwaysDark(child: LyricsMenuSheet(groups: groups)),
);

class LyricsMenuSheet extends ConsumerWidget {
  const LyricsMenuSheet({super.key, required this.groups});

  final List<LyricsMenuGroup> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = ref.watch(settingsProvider.select((s) => s.lyricsSize));
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Material(
          color: const Color(0xCC0B0B12),
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            side: BorderSide(color: KijiPalette.nocturne.glassBorder),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
            child: SafeArea(
              top: false,
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final group in groups)
                    if (group.actions.isNotEmpty) ...[
                      _GroupTitle(group.title),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // Tres por fila (cuatro si hay lugar); los íconos siempre grandes.
                          final columns = constraints.maxWidth >= 480 ? 4 : 3;
                          final width = (constraints.maxWidth - 10 * (columns - 1)) / columns;
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final action in group.actions)
                                SizedBox(
                                  width: width,
                                  child: _ActionTile(action: action),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                    ],
                  _GroupTitle(tx.tamanoDeLasLetras),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: [
                      for (final option in AppSettings.lyricsSizes)
                        ButtonSegment(
                          value: option,
                          label: Text(lyricsSizeLabel(option), style: TextStyle(fontSize: 14 * lyricsScaleFor(option))),
                        ),
                    ],
                    selected: {size},
                    onSelectionChanged: (value) =>
                        ref.read(settingsProvider.notifier).update((s) => s.copyWith(lyricsSize: value.first)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Chico", "Normal" o "Grande".
String lyricsSizeLabel(String size) => switch (size) {
  'small' => tx.tamanoChico,
  'large' => tx.tamanoGrande,
  _ => tx.tamanoNormal,
};

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
    child: Text(text.toUpperCase(), style: KijiText.mono(size: 11, color: KijiPalette.nocturne.muted)),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});

  final LyricsMenuAction action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: action.active,
      child: Material(
        color: KijiPalette.nocturne.glassFill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KijiRadii.tile),
          side: BorderSide(
            color: action.active ? KijiColors.cyan.withValues(alpha: 0.5) : KijiPalette.nocturne.glassBorder,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.of(context).pop();
            action.onTap();
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: action.active ? KijiColors.accentGradientDiagonal : null,
                    color: action.active ? null : Colors.white.withValues(alpha: 0.08),
                  ),
                  child: Icon(action.icon, size: 28, color: action.active ? KijiColors.onAccent : Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  action.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, height: 1.2, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
