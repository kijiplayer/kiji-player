import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../l10n/l10n.dart';

/// Ícono de Kiji en la bandeja del sistema (PC): un clic abre la ventana; el menú tiene
/// abrir, play/pausa, siguiente y salir. Solo aparece mientras Kiji está en la bandeja, así no
/// queda un ícono de más con la ventana abierta.
class DesktopTray with TrayListener, WindowListener {
  DesktopTray({required this.onPlayPause, required this.onNext, required this.onExit});

  final Future<void> Function() onPlayPause;
  final Future<void> Function() onNext;
  final Future<void> Function() onExit;

  bool _shown = false;
  bool _playing = false;
  String _tooltip = 'Kiji Player'; // l10n-ignore

  static const _iconPath = 'assets/tray/kiji.ico';

  /// Oculta la ventana y deja a Kiji en la bandeja.
  Future<void> hideToTray() async {
    try {
      if (!_shown) {
        await trayManager.setIcon(_iconPath);
        trayManager.addListener(this);
        windowManager.addListener(this);
        _shown = true;
      }
      await _refresh();
      await windowManager.hide();
      debugPrint('=== BANDEJA: Kiji sigue en la bandeja ===');
    } catch (error) {
      // Sin bandeja no se esconde la ventana: si no, Kiji quedaría invisible y sin forma de volver.
      debugPrint('=== BANDEJA: no se pudo poner el ícono: $error; se minimiza ===');
      await windowManager.minimize();
    }
  }

  /// Vuelve a mostrar la ventana (el ícono se quita cuando aparece).
  Future<void> show() async {
    await windowManager.show();
    await windowManager.focus();
  }

  /// La ventana volvió (desde la bandeja o abriendo Kiji otra vez): se quita el ícono.
  @override
  void onWindowEvent(String eventName) {
    if (eventName == 'show') unawaited(_removeIcon());
  }

  Future<void> _removeIcon() async {
    if (!_shown) return;
    _shown = false;
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    try {
      await trayManager.destroy();
    } catch (error) {
      debugPrint('=== BANDEJA: no se pudo quitar el ícono: $error ===');
    }
  }

  /// La canción y si suena: el texto al pasar el mouse y la opción de play/pausa del menú.
  void update({required bool playing, String? title, String? artist}) {
    final tooltip = title == null ? 'Kiji Player' : 'Kiji · $title${artist == null ? '' : ' — $artist'}'; // l10n-ignore
    if (playing == _playing && tooltip == _tooltip) return;
    _playing = playing;
    // La bandeja de Windows corta el texto en 127 caracteres.
    _tooltip = tooltip.length > 120 ? '${tooltip.substring(0, 119)}…' : tooltip;
    if (_shown) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    try {
      await trayManager.setToolTip(_tooltip);
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: 'open', label: tx.bandejaAbrir),
            MenuItem.separator(),
            MenuItem(key: 'playPause', label: _playing ? tx.pausar : tx.reproducir),
            MenuItem(key: 'next', label: tx.siguiente),
            MenuItem.separator(),
            MenuItem(key: 'exit', label: tx.bandejaSalir),
          ],
        ),
      );
    } catch (error) {
      debugPrint('=== BANDEJA: no se pudo actualizar el menú: $error ===');
    }
  }

  @override
  void onTrayIconMouseDown() => unawaited(show());

  @override
  void onTrayIconRightMouseDown() => unawaited(trayManager.popUpContextMenu());

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    debugPrint('=== BANDEJA: ${menuItem.key} ===');
    unawaited(switch (menuItem.key) {
      'open' => show(),
      'playPause' => onPlayPause(),
      'next' => onNext(),
      'exit' => onExit(),
      _ => Future<void>.value(),
    });
  }
}
