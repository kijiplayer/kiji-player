import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../providers/playback_provider.dart';
import '../../widgets/global_mini_player.dart';
import '../settings/data/settings_store.dart';
import 'desktop_hotkeys.dart';
import 'desktop_tray.dart';
import 'desktop_window.dart';

/// PC: la ✕ (bandeja o salir), el ícono de la bandeja y los atajos globales. Se llama una vez,
/// desde KijiApp.
void watchDesktop(WidgetRef ref) {
  if (!DesktopWindow.isDesktop) return;
  final window = DesktopWindow.instance;
  final tray = DesktopTray(
    onPlayPause: () => ref.read(playbackProvider.notifier).togglePlayPause(),
    onNext: () => ref.read(playbackProvider.notifier).nextTrack(),
    onExit: window.exit,
  );

  window.onCloseRequested = () async {
    var action = ref.read(settingsProvider).closeAction;
    if (action == 'ask') {
      final choice = await _askCloseAction();
      // Se cerró el aviso sin elegir: no pasa nada.
      if (choice == null) return true;
      action = choice;
      await ref.read(settingsProvider.notifier).update((s) => s.copyWith(closeAction: choice));
    }
    if (action != 'tray') return false;
    await tray.hideToTray();
    return true;
  };

  ref.listenManual(
    playbackProvider.select((p) => (p.isPlaying, p.track?.title, p.track?.artist)),
    (_, now) => tray.update(playing: now.$1, title: now.$2, artist: now.$3),
    fireImmediately: true,
  );

  final hotkeys = DesktopHotkeys(
    onAction: (action) {
      final player = ref.read(playbackProvider.notifier);
      return switch (action) {
        HotkeyAction.playPause => player.togglePlayPause(),
        HotkeyAction.next => player.nextTrack(),
        HotkeyAction.previous => player.previousTrack(),
      };
    },
  );
  ref.listenManual(
    settingsProvider.select((s) => (s.globalHotkeys, s.hotkeys)),
    (_, _) => unawaited(hotkeys.apply(ref.read(settingsProvider))),
    fireImmediately: true,
  );
}

/// La primera vez que se toca la ✕: ¿bandeja o salir? (Cero Sorpresas: que la música siga sonando
/// con la ventana cerrada no puede pasar sin avisar.)
Future<String?> _askCloseAction() async {
  final context = kijiNavigatorKey.currentContext;
  if (context == null || !context.mounted) return 'exit';
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.close_fullscreen_rounded),
      title: Text(tx.cerrarDialogoTitulo),
      content: Text(tx.cerrarDialogoTexto),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, 'exit'), child: Text(tx.alCerrarSalir)),
        FilledButton(onPressed: () => Navigator.pop(context, 'tray'), child: Text(tx.alCerrarBandeja)),
      ],
    ),
  );
}
