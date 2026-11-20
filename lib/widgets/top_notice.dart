import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/kiji_tokens.dart';

OverlayEntry? _current;
Timer? _hide;

/// Un aviso corto arriba de la pantalla (debajo de la barra de estado), para no tapar los
/// controles de abajo del reproductor como un SnackBar. Dura [duration], se cierra deslizándolo
/// hacia arriba o a los costados, y [onAction] se llama con el Navigator raíz guardado antes (no
/// depende del `context` de quien lo mostró, que puede ya no existir).
void showTopNotice(
  BuildContext context, {
  required String message,
  String? actionLabel,
  void Function(NavigatorState navigator)? onAction,
  Duration duration = const Duration(milliseconds: 2500),
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final navigator = Navigator.of(context, rootNavigator: true);
  hideTopNotice();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _TopNotice(
      message: message,
      actionLabel: actionLabel,
      onAction: onAction == null
          ? null
          : () {
              hideTopNotice();
              onAction(navigator);
            },
      onDismissed: () {
        if (identical(_current, entry)) hideTopNotice();
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
  _hide = Timer(duration, hideTopNotice);
}

/// Quita el aviso que esté a la vista.
void hideTopNotice() {
  _hide?.cancel();
  _hide = null;
  final entry = _current;
  _current = null;
  if (entry != null && entry.mounted) entry.remove();
}

class _TopNotice extends StatelessWidget {
  const _TopNotice({required this.message, required this.onDismissed, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 8;
    final still = KijiEffects.still(context);
    final card = Material(
      key: const Key('top-notice'),
      color: KijiColors.surface,
      elevation: 6,
      borderRadius: BorderRadius.circular(KijiRadii.card),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(message, style: TextStyle(color: KijiColors.text)),
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(key: const Key('top-notice-action'), onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: SafeArea(
        top: false,
        bottom: false,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: still ? 1 : 0, end: 1),
          duration: KijiMotion.normal,
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, -24 * (1 - t)), child: child),
          ),
          // Hacia arriba o a los costados lo cierra.
          child: Dismissible(
            key: UniqueKey(),
            direction: DismissDirection.horizontal,
            onDismissed: (_) => onDismissed(),
            child: GestureDetector(
              onVerticalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) < -200) onDismissed();
              },
              child: card,
            ),
          ),
        ),
      ),
    );
  }
}
