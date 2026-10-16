import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pestañas principales de Kiji.
enum ShellTab { home, search, library }

/// Pestaña visible. Compartida por el diseño de celular (píldora inferior)
/// y el de PC (barra lateral), y por el atajo Ctrl K.
final shellTabProvider = StateProvider<ShellTab>((ref) => ShellTab.home);

/// Foco del buscador, para que Ctrl K lo active desde cualquier lado.
final searchFocusProvider = Provider<FocusNode>((ref) {
  final node = FocusNode(debugLabel: 'buscador');
  ref.onDispose(node.dispose);
  return node;
});
