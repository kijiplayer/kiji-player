import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../../l10n/l10n.dart';
import '../settings/domain/app_settings.dart';

/// Lo que se puede hacer con un atajo global.
enum HotkeyAction {
  playPause,
  next,
  previous;

  String get label => switch (this) {
    HotkeyAction.playPause => tx.atajoPlayPausa,
    HotkeyAction.next => tx.atajoSiguiente,
    HotkeyAction.previous => tx.atajoAnterior,
  };

  /// Los de fábrica: Ctrl + Alt + P / → / ←. (Ctrl + Alt + Espacio lo suelen tomar otros programas.)
  HotKey get fallback => HotKey(
    identifier: name,
    key: switch (this) {
      HotkeyAction.playPause => PhysicalKeyboardKey.keyP,
      HotkeyAction.next => PhysicalKeyboardKey.arrowRight,
      HotkeyAction.previous => PhysicalKeyboardKey.arrowLeft,
    },
    modifiers: const [HotKeyModifier.control, HotKeyModifier.alt],
  );
}

/// Teclas que se pueden usar en un atajo global. Una lista cerrada: cada una tiene su código de
/// Windows (una tecla rara sin código haría fallar al plugin).
final hotkeyKeys = <PhysicalKeyboardKey>{
  for (final key in [
    PhysicalKeyboardKey.keyA,
    PhysicalKeyboardKey.keyB,
    PhysicalKeyboardKey.keyC,
    PhysicalKeyboardKey.keyD,
    PhysicalKeyboardKey.keyE,
    PhysicalKeyboardKey.keyF,
    PhysicalKeyboardKey.keyG,
    PhysicalKeyboardKey.keyH,
    PhysicalKeyboardKey.keyI,
    PhysicalKeyboardKey.keyJ,
    PhysicalKeyboardKey.keyK,
    PhysicalKeyboardKey.keyL,
    PhysicalKeyboardKey.keyM,
    PhysicalKeyboardKey.keyN,
    PhysicalKeyboardKey.keyO,
    PhysicalKeyboardKey.keyP,
    PhysicalKeyboardKey.keyQ,
    PhysicalKeyboardKey.keyR,
    PhysicalKeyboardKey.keyS,
    PhysicalKeyboardKey.keyT,
    PhysicalKeyboardKey.keyU,
    PhysicalKeyboardKey.keyV,
    PhysicalKeyboardKey.keyW,
    PhysicalKeyboardKey.keyX,
    PhysicalKeyboardKey.keyY,
    PhysicalKeyboardKey.keyZ,
    PhysicalKeyboardKey.digit0,
    PhysicalKeyboardKey.digit1,
    PhysicalKeyboardKey.digit2,
    PhysicalKeyboardKey.digit3,
    PhysicalKeyboardKey.digit4,
    PhysicalKeyboardKey.digit5,
    PhysicalKeyboardKey.digit6,
    PhysicalKeyboardKey.digit7,
    PhysicalKeyboardKey.digit8,
    PhysicalKeyboardKey.digit9,
    PhysicalKeyboardKey.f1,
    PhysicalKeyboardKey.f2,
    PhysicalKeyboardKey.f3,
    PhysicalKeyboardKey.f4,
    PhysicalKeyboardKey.f5,
    PhysicalKeyboardKey.f6,
    PhysicalKeyboardKey.f7,
    PhysicalKeyboardKey.f8,
    PhysicalKeyboardKey.f9,
    PhysicalKeyboardKey.f10,
    PhysicalKeyboardKey.f11,
    PhysicalKeyboardKey.f12,
    PhysicalKeyboardKey.space,
    PhysicalKeyboardKey.arrowLeft,
    PhysicalKeyboardKey.arrowRight,
    PhysicalKeyboardKey.arrowUp,
    PhysicalKeyboardKey.arrowDown,
  ])
    key,
};

bool _isFunctionKey(PhysicalKeyboardKey key) =>
    key.usbHidUsage >= PhysicalKeyboardKey.f1.usbHidUsage && key.usbHidUsage <= PhysicalKeyboardKey.f12.usbHidUsage;

/// ¿Sirve como atajo global? Tiene que llevar Ctrl, Alt, Shift o Win, o ser una tecla F: si no,
/// Kiji le robaría esa tecla a todos los demás programas.
bool isValidHotkey(PhysicalKeyboardKey key, List<HotKeyModifier> modifiers) =>
    hotkeyKeys.contains(key) && (modifiers.isNotEmpty || _isFunctionKey(key));

/// El atajo de [action] según la configuración (o el de fábrica).
HotKey hotkeyFor(AppSettings settings, HotkeyAction action) {
  final json = settings.hotkeys[action.name];
  if (json != null) {
    try {
      final saved = HotKey.fromJson(json);
      if (saved.key is PhysicalKeyboardKey && hotkeyKeys.contains(saved.key)) {
        return HotKey(identifier: action.name, key: saved.key, modifiers: saved.modifiers);
      }
    } catch (error) {
      debugPrint('=== ATAJOS: atajo guardado inválido para ${action.name}: $error ===');
    }
  }
  return action.fallback;
}

/// "Ctrl + Alt + Espacio".
String hotkeyLabel(HotKey hotKey) {
  final names = [
    for (final modifier in hotKey.modifiers ?? const <HotKeyModifier>[])
      switch (modifier) {
        HotKeyModifier.control => 'Ctrl', // l10n-ignore
        HotKeyModifier.alt => 'Alt', // l10n-ignore
        HotKeyModifier.shift => 'Shift', // l10n-ignore
        HotKeyModifier.meta => 'Win', // l10n-ignore
        _ => modifier.name,
      },
    _keyName(hotKey.key as PhysicalKeyboardKey),
  ];
  return names.join(' + ');
}

String _keyName(PhysicalKeyboardKey key) {
  if (key == PhysicalKeyboardKey.space) return tx.teclaEspacio;
  if (key == PhysicalKeyboardKey.arrowLeft) return '←';
  if (key == PhysicalKeyboardKey.arrowRight) return '→';
  if (key == PhysicalKeyboardKey.arrowUp) return '↑';
  if (key == PhysicalKeyboardKey.arrowDown) return '↓';
  // Los nombres de las teclas se arman a mano: `debugName` no existe en la versión publicada.
  final usage = key.usbHidUsage;
  final a = PhysicalKeyboardKey.keyA.usbHidUsage;
  final digit1 = PhysicalKeyboardKey.digit1.usbHidUsage;
  final f1 = PhysicalKeyboardKey.f1.usbHidUsage;
  if (usage >= a && usage < a + 26) return String.fromCharCode(0x41 + usage - a);
  if (usage >= digit1 && usage < digit1 + 10) return '${(usage - digit1 + 1) % 10}';
  if (usage >= f1 && usage < f1 + 12) return 'F${usage - f1 + 1}';
  return '?';
}

/// Código de tecla de Windows (VK_*) de las teclas de [hotkeyKeys].
int? _virtualKey(PhysicalKeyboardKey key) {
  final usage = key.usbHidUsage;
  final a = PhysicalKeyboardKey.keyA.usbHidUsage;
  final digit1 = PhysicalKeyboardKey.digit1.usbHidUsage;
  final f1 = PhysicalKeyboardKey.f1.usbHidUsage;
  if (usage >= a && usage < a + 26) return 0x41 + usage - a;
  if (usage >= digit1 && usage < digit1 + 10) return 0x30 + (usage - digit1 + 1) % 10;
  if (usage >= f1 && usage < f1 + 12) return 0x70 + usage - f1;
  return switch (key) {
    PhysicalKeyboardKey.space => 0x20,
    PhysicalKeyboardKey.arrowLeft => 0x25,
    PhysicalKeyboardKey.arrowUp => 0x26,
    PhysicalKeyboardKey.arrowRight => 0x27,
    PhysicalKeyboardKey.arrowDown => 0x28,
    _ => null,
  };
}

/// Windows: ¿otro programa ya usa este atajo? Se prueba registrarlo un instante (el plugin no avisa
/// cuando no puede). En otros sistemas, no se sabe: false.
bool _takenByOtherProgram(HotKey hotKey) {
  if (!Platform.isWindows) return false;
  final vk = _virtualKey(hotKey.key as PhysicalKeyboardKey);
  if (vk == null) return false;
  var modifiers = 0x4000; // MOD_NOREPEAT
  for (final modifier in hotKey.modifiers ?? const <HotKeyModifier>[]) {
    modifiers |= switch (modifier) {
      HotKeyModifier.alt => 0x1,
      HotKeyModifier.control => 0x2,
      HotKeyModifier.shift => 0x4,
      HotKeyModifier.meta => 0x8,
      _ => 0,
    };
  }
  try {
    final user32 = DynamicLibrary.open('user32.dll');
    final register = user32
        .lookupFunction<Int32 Function(IntPtr, Int32, Uint32, Uint32), int Function(int, int, int, int)>(
          'RegisterHotKey', // l10n-ignore
        );
    final unregister = user32.lookupFunction<Int32 Function(IntPtr, Int32), int Function(int, int)>(
      'UnregisterHotKey', // l10n-ignore
    );
    const probeId = 0x4B4A;
    if (register(0, probeId, modifiers, vk) == 0) return true;
    unregister(0, probeId);
  } catch (error) {
    debugPrint('=== ATAJOS: no se pudo comprobar ${hotkeyLabel(hotKey)}: $error ===');
  }
  return false;
}

/// Registra en el sistema los atajos globales (o los quita si están apagados).
class DesktopHotkeys {
  DesktopHotkeys({required this.onAction});

  final Future<void> Function(HotkeyAction action) onAction;

  /// Los atajos que no se pudieron registrar porque otro programa ya los usa (se muestran en
  /// Configuración).
  static final busy = ValueNotifier<Set<HotkeyAction>>(const {});

  String? _applied;

  Future<void> apply(AppSettings settings) async {
    final keys = {for (final action in HotkeyAction.values) action: hotkeyFor(settings, action)};
    final signature = settings.globalHotkeys
        ? [for (final entry in keys.entries) '${entry.key.name}=${entry.value.toJson()}'].join(';')
        : 'apagados';
    if (signature == _applied) return;
    _applied = signature;
    try {
      await hotKeyManager.unregisterAll();
      if (!settings.globalHotkeys) {
        busy.value = const {};
        debugPrint('=== ATAJOS: globales apagados ===');
        return;
      }
      final taken = {
        for (final MapEntry(key: action, value: hotKey) in keys.entries)
          if (_takenByOtherProgram(hotKey)) action,
      };
      busy.value = taken;
      for (final MapEntry(key: action, value: hotKey) in keys.entries) {
        if (taken.contains(action)) {
          debugPrint('=== ATAJOS: ${hotkeyLabel(hotKey)} ya lo usa otro programa ===');
          continue;
        }
        await hotKeyManager.register(
          hotKey,
          keyDownHandler: (_) {
            debugPrint('=== ATAJOS: global ${action.name} ===');
            onAction(action).catchError((Object error) => debugPrint('=== ATAJOS: ${action.name} falló: $error ==='));
          },
        );
      }
      debugPrint(
        '=== ATAJOS: globales registrados: '
        '${[for (final e in keys.entries)
          if (!taken.contains(e.key)) hotkeyLabel(e.value)].join(', ')} ===',
      );
    } catch (error) {
      debugPrint('=== ATAJOS: no se pudieron registrar: $error ===');
    }
  }
}
