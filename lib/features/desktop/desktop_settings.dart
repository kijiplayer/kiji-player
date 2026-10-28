import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../../l10n/l10n.dart';
import '../../theme/kiji_tokens.dart';
import '../settings/data/settings_store.dart';
import '../settings/domain/app_settings.dart';
import 'desktop_hotkeys.dart';

/// Configuración → En la PC → Al cerrar la ventana.
class CloseActionTile extends ConsumerWidget {
  const CloseActionTile({super.key});

  static String label(String action) => switch (action) {
    'tray' => tx.alCerrarBandeja,
    'exit' => tx.alCerrarSalir,
    _ => tx.alCerrarPreguntar,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(settingsProvider.select((s) => s.closeAction));
    return ListTile(
      leading: const Icon(Icons.close_fullscreen_rounded),
      title: Text(tx.alCerrarLaVentana),
      subtitle: Text(label(action)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () async {
        final value = await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(tx.alCerrarLaVentana),
            children: [
              RadioGroup<String>(
                groupValue: action,
                onChanged: (value) => Navigator.pop(context, value),
                child: Column(
                  children: [
                    for (final option in AppSettings.closeActions)
                      RadioListTile<String>(value: option, title: Text(label(option))),
                  ],
                ),
              ),
            ],
          ),
        );
        if (value != null) {
          await ref.read(settingsProvider.notifier).update((s) => s.copyWith(closeAction: value));
        }
      },
    );
  }
}

/// Configuración → En la PC → un atajo global (tocar para cambiarlo).
class HotkeyTile extends ConsumerWidget {
  const HotkeyTile({super.key, required this.action});

  final HotkeyAction action;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ValueListenableBuilder(valueListenable: DesktopHotkeys.busy, builder: (context, _, _) => _build(context, ref));

  Widget _build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final hotKey = hotkeyFor(settings, action);
    final busy = settings.globalHotkeys && DesktopHotkeys.busy.value.contains(action);
    return ListTile(
      enabled: settings.globalHotkeys,
      contentPadding: const EdgeInsets.only(left: 56, right: 16),
      title: Text(action.label),
      // El atajo va abajo y no a la derecha: con letra grande, a la derecha no entra.
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(hotkeyLabel(hotKey), style: KijiText.mono(size: 13, color: KijiColors.cyan)),
          if (busy) Text(tx.atajoOcupado, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ),
      trailing: const Icon(Icons.edit_outlined, size: 18),
      onTap: () async {
        final recorded = await showDialog<HotKey>(
          context: context,
          builder: (_) => HotkeyRecorderDialog(action: action),
        );
        if (recorded == null) return;
        // El mismo atajo no puede hacer dos cosas.
        final taken = HotkeyAction.values.any(
          (other) => other != action && _same(hotkeyFor(settings, other), recorded),
        );
        if (taken) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tx.atajoEnUso)));
          }
          return;
        }
        await ref
            .read(settingsProvider.notifier)
            .update((s) => s.copyWith(hotkeys: {...s.hotkeys, action.name: recorded.toJson()}));
      },
    );
  }

  static bool _same(HotKey a, HotKey b) =>
      a.key == b.key &&
      {...?a.modifiers}.length == {...?b.modifiers}.length &&
      {...?a.modifiers}.containsAll({...?b.modifiers});
}

/// Escucha el teclado y devuelve la combinación que se presionó.
class HotkeyRecorderDialog extends StatefulWidget {
  const HotkeyRecorderDialog({super.key, required this.action});

  final HotkeyAction action;

  @override
  State<HotkeyRecorderDialog> createState() => _HotkeyRecorderDialogState();
}

class _HotkeyRecorderDialogState extends State<HotkeyRecorderDialog> {
  HotKey? _hotKey;
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.physicalKey;
    final modifiers = [
      for (final modifier in [HotKeyModifier.control, HotKeyModifier.alt, HotKeyModifier.shift, HotKeyModifier.meta])
        if (modifier.isModifierPressed) modifier,
    ];
    // Solo un modificador todavía: se espera la tecla.
    if (HotKeyModifier.values.any((m) => m.physicalKeys.contains(key))) return true;
    // Esc cierra el diálogo (no se graba).
    if (key == PhysicalKeyboardKey.escape && modifiers.isEmpty) return false;
    setState(() {
      _invalid = !isValidHotkey(key, modifiers);
      _hotKey = _invalid ? null : HotKey(identifier: widget.action.name, key: key, modifiers: modifiers);
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final hotKey = _hotKey;
    return AlertDialog(
      title: Text(widget.action.label),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tx.atajoGrabar),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
            decoration: BoxDecoration(
              color: KijiColors.surface,
              borderRadius: BorderRadius.circular(KijiRadii.tile),
              border: Border.all(
                color: _invalid ? Theme.of(context).colorScheme.error : KijiColors.cyan.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              hotKey == null ? '…' : hotkeyLabel(hotKey),
              textAlign: TextAlign.center,
              style: KijiText.mono(size: 18),
            ),
          ),
          if (_invalid) ...[
            const SizedBox(height: 8),
            Text(
              tx.atajoNecesitaModificador,
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          Text(tx.atajosAviso, style: TextStyle(color: KijiColors.muted, fontSize: 12)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tx.cancelar)),
        FilledButton(onPressed: hotKey == null ? null : () => Navigator.pop(context, hotKey), child: Text(tx.guardar)),
      ],
    );
  }
}
