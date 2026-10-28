import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:kiji_player/features/desktop/desktop_hotkeys.dart';
import 'package:kiji_player/features/desktop/desktop_settings.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';

void main() {
  test('La ✕ y los atajos globales se guardan y un valor raro vuelve al de fábrica', () {
    final hotKey = HotKey(
      identifier: 'next',
      key: PhysicalKeyboardKey.keyN,
      modifiers: const [HotKeyModifier.control, HotKeyModifier.shift],
    );
    final settings = const AppSettings().copyWith(
      closeAction: 'tray',
      globalHotkeys: true,
      hotkeys: {'next': hotKey.toJson()},
    );
    final back = AppSettings.fromJson(settings.toJson());
    expect(back.closeAction, 'tray');
    expect(back.globalHotkeys, isTrue);
    expect(hotkeyLabel(hotkeyFor(back, HotkeyAction.next)), 'Ctrl + Shift + N');

    final odd = AppSettings.fromJson({'closeAction': 'volar', 'globalHotkeys': 'sí', 'hotkeys': 'nada'});
    expect(odd.closeAction, 'ask');
    expect(odd.globalHotkeys, isFalse);
    expect(odd.hotkeys, isEmpty);
  });

  test('Sin atajo guardado (o uno dañado) se usa el de fábrica', () {
    const settings = AppSettings(
      hotkeys: {
        'previous': {'key': 'roto'},
      },
    );
    expect(hotkeyLabel(hotkeyFor(settings, HotkeyAction.playPause)), 'Ctrl + Alt + P');
    expect(hotkeyLabel(hotkeyFor(settings, HotkeyAction.previous)), 'Ctrl + Alt + ←');
  });

  test('Un atajo global necesita un modificador (o ser una tecla F)', () {
    expect(isValidHotkey(PhysicalKeyboardKey.keyK, const []), isFalse);
    expect(isValidHotkey(PhysicalKeyboardKey.keyK, const [HotKeyModifier.alt]), isTrue);
    expect(isValidHotkey(PhysicalKeyboardKey.f9, const []), isTrue);
    expect(isValidHotkey(PhysicalKeyboardKey.digit0, const [HotKeyModifier.control]), isTrue);
    // Una tecla fuera de la lista (sin código de Windows conocido) no se acepta.
    expect(isValidHotkey(PhysicalKeyboardKey.numLock, const [HotKeyModifier.control]), isFalse);
  });

  testWidgets('Grabar un atajo: Ctrl + Alt + 7 se puede guardar; una letra sola no', (tester) async {
    HotKey? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => saved = await showDialog<HotKey>(
              context: context,
              builder: (_) => const HotkeyRecorderDialog(action: HotkeyAction.next),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ, physicalKey: PhysicalKeyboardKey.keyQ);
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit7, physicalKey: PhysicalKeyboardKey.digit7);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(find.text('Ctrl + Alt + 7'), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(hotkeyLabel(saved!), 'Ctrl + Alt + 7');
  });
}
