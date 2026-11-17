import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/app_icon/data/app_icon_channel.dart';
import 'package:kiji_player/features/app_icon/domain/app_icon.dart';
import 'package:kiji_player/features/app_icon/presentation/app_icon_sync.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/providers/playback_provider.dart';
import 'package:kiji_player/theme/kiji_tokens.dart';

class _Changer extends AppIconChanger {
  _Changer({required this.appliesOnExit});
  @override
  final bool appliesOnExit;
  String icon = defaultAppIcon;
  final applied = <String>[];
  @override
  bool get supported => true;
  @override
  Future<String> current() async => icon;
  @override
  Future<bool> apply(String variant) async {
    applied.add(variant);
    icon = variant;
    return true;
  }
}

class _Settings extends SettingsNotifier {
  _Settings(this.initial);
  final AppSettings initial;
  @override
  AppSettings build() => initial;
  @override
  Future<void> update(AppSettings Function(AppSettings) change) async => state = change(state);
}

class _Playback extends PlaybackNotifier {
  _Playback(this.playing);
  final bool playing;
  @override
  PlaybackState build() => PlaybackState(
    track: null,
    isPlaying: playing,
    position: Duration.zero,
    duration: Duration.zero,
    shuffleEnabled: false,
    isInitialized: false,
    queue: const [],
    currentIndex: 0,
    repeatMode: PlaybackRepeatMode.off,
  );
  void setPlaying(bool value) => state = state.copyWith(isPlaying: value);
}

void main() {
  test('Cada estilo tiene su ícono; Nocturne, uno por acento (un acento propio, el más parecido)', () {
    expect(appIconFor(style: KijiStyle.graphite, accent: 'ember'), 'graphite');
    expect(appIconFor(style: KijiStyle.paper, accent: 'nocturne'), 'paper');
    for (final accent in KijiPalette.accents.keys) {
      expect(appIconFor(style: KijiStyle.nocturne, accent: accent), accent);
      expect(appIconVariants, contains(accent));
    }
    // Un naranja propio → "ember"; un gris → el de siempre de Nocturne.
    expect(appIconFor(style: KijiStyle.nocturne, accent: 'custom', customAccent: 0xFFFF8040), 'ember');
    expect(nearestAccent(const Color(0xFF808080)), 'nocturne');
  });

  testWidgets('Android: el ícono cambia al salir de Kiji y sin música, nunca en medio de una canción', (tester) async {
    final changer = _Changer(appliesOnExit: true);
    late _Playback playback;
    final c = ProviderContainer(overrides: [
      appIconChangerProvider.overrideWithValue(changer),
      settingsProvider.overrideWith(() => _Settings(const AppSettings(matchIconToStyle: true, style: 'graphite'))),
      playbackProvider.overrideWith(() => playback = _Playback(true)),
    ]);
    addTearDown(c.dispose);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    c.read(appIconSyncProvider);
    await tester.pump();
    expect(changer.applied, isEmpty, reason: 'con Kiji a la vista, no');
    // Sale de Kiji, pero suena música: tampoco.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(changer.applied, isEmpty, reason: 'sonando, no');
    // Se pausa con Kiji cerrada: ahora sí.
    playback.setPlaying(false);
    await tester.pump();
    expect(changer.applied, ['graphite']);
    // Apagar la opción vuelve al de siempre (también al salir).
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await c.read(settingsProvider.notifier).update((s) => s.copyWith(matchIconToStyle: false));
    await tester.pump();
    expect(changer.applied, ['graphite']);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(changer.applied, ['graphite', defaultAppIcon]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('Windows: al momento', (tester) async {
    final changer = _Changer(appliesOnExit: false);
    final c = ProviderContainer(overrides: [
      appIconChangerProvider.overrideWithValue(changer),
      settingsProvider.overrideWith(() => _Settings(const AppSettings(matchIconToStyle: true, style: 'paper'))),
      playbackProvider.overrideWith(() => _Playback(true)),
    ]);
    addTearDown(c.dispose);
    c.read(appIconSyncProvider);
    await tester.pump();
    expect(changer.applied, ['paper']);
    await c.read(settingsProvider.notifier).update((s) => s.copyWith(style: 'graphite'));
    await tester.pump();
    expect(changer.applied, ['paper', 'graphite']);
  });

  test('Apagado de fábrica', () => expect(const AppSettings().matchIconToStyle, isFalse));
}
