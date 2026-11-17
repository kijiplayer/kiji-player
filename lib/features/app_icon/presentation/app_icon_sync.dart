import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/playback_provider.dart';
import '../../../theme/kiji_tokens.dart';
import '../../settings/data/settings_store.dart';
import '../data/app_icon_channel.dart';
import '../domain/app_icon.dart';

/// Pone el ícono que corresponde: con "Ícono a juego con el estilo", el del estilo y el acento; si
/// no, el de siempre. En Windows al momento. En Android, al salir de Kiji y sin música sonando
/// (nunca en medio de una canción: en algunos teléfonos el lanzador cierra la app un momento).
final appIconSyncProvider = Provider<void>((ref) {
  final changer = ref.watch(appIconChangerProvider);
  if (!changer.supported) return;

  String desired() {
    final s = ref.read(settingsProvider);
    if (!s.matchIconToStyle) return defaultAppIcon;
    return appIconFor(style: KijiStyle.parse(s.style), accent: s.accent, customAccent: s.customAccent);
  }

  final lifecycle = WidgetsBinding.instance.lifecycleState;
  var visible = lifecycle == null || lifecycle == AppLifecycleState.resumed || lifecycle == AppLifecycleState.inactive;
  String? pending;
  var applying = false;

  Future<void> tryApply() async {
    final want = pending;
    if (want == null || applying) return;
    if (changer.appliesOnExit && (visible || ref.read(playbackProvider).isPlaying)) return;
    applying = true;
    pending = null;
    try {
      if (await changer.current() != want) await changer.apply(want);
    } finally {
      applying = false;
    }
  }

  ref.listen(
    settingsProvider.select((s) => (s.matchIconToStyle, s.style, s.accent, s.customAccent)),
    (_, _) {
      pending = desired();
      unawaited(tryApply());
    },
    fireImmediately: true,
  );
  // Se pausó la música con Kiji ya cerrada: ahora sí.
  ref.listen(playbackProvider.select((p) => p.isPlaying), (_, playing) {
    if (!playing) unawaited(tryApply());
  });
  final listener = AppLifecycleListener(
    onHide: () {
      visible = false;
      unawaited(tryApply());
    },
    onShow: () => visible = true,
  );
  ref.onDispose(listener.dispose);
});
