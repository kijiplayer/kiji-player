import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/lyrics/data/screen_mode_impl.dart';
import 'package:kiji_player/features/lyrics/domain/screen_mode.dart';
import 'package:kiji_player/features/lyrics/presentation/lyrics_fullscreen.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/playback_provider.dart';
import 'package:kiji_player/screens/player/player_screen.dart';
import 'package:kiji_player/theme/kiji_tokens.dart';

class _Mode implements ScreenMode {
  final calls = <bool>[];
  @override
  Future<void> setFullScreen(bool on) async => calls.add(on);
}

class _Playback extends PlaybackNotifier {
  @override
  PlaybackState build() => const PlaybackState(
    track: Track(
      id: 'yt-inventada',
      title: 'Un título inventado bastante largo',
      artist: 'Grupo Inventado',
      coverColor: Color(0xFF3A6EA5),
      audioUrl: '',
      source: TrackSource.youtube,
    ),
    isPlaying: false,
    position: Duration(seconds: 40),
    duration: Duration(minutes: 3),
    shuffleEnabled: false,
    isInitialized: true,
    queue: [],
    currentIndex: 0,
    repeatMode: PlaybackRepeatMode.off,
  );
}

Future<Directory> _noDisk() async => throw const FileSystemException('sin disco en el test');

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Size size, {
  String mode = 'normal',
  bool full = false,
  bool labels = true,
  ScreenMode? screen,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: [
    playbackProvider.overrideWith(_Playback.new),
    settingsProvider.overrideWith(() => SettingsNotifier(directory: _noDisk)),
    screenModeProvider.overrideWithValue(screen ?? _Mode()),
  ]);
  addTearDown(container.dispose);
  await container.read(settingsProvider.notifier).update((s) => s.copyWith(playerMode: mode, playerButtonLabels: labels));
  container.read(playerFullscreenProvider.notifier).state = full;
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: PlayerScreen()),
  ));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return container;
}

void main() {
  tearDown(() {
    KijiLook.style = KijiStyle.nocturne;
    KijiColors.palette = KijiPalette.nocturne;
  });

  for (final style in KijiStyle.values) {
    for (final (mode, full) in [('normal', false), ('compact', false), ('normal', true)]) {
      for (final size in const [Size(360, 560), Size(420, 860), Size(800, 500), Size(1440, 900)]) {
        final name = full ? 'pantalla completa' : mode;
        testWidgets('Reproductor $name en ${style.name}, ${size.width.toInt()}×${size.height.toInt()}: sin desbordes', (
          tester,
        ) async {
          KijiLook.style = style;
          KijiColors.palette = KijiPalette.forStyle(style);
          final errors = <String>[];
          final previous = FlutterError.onError;
          FlutterError.onError = (d) => errors.add(d.exceptionAsString().split('\n').first);
          addTearDown(() => FlutterError.onError = previous);
          await _pump(tester, size, mode: mode, full: full);
          FlutterError.onError = previous;
          expect(errors, isEmpty);
          expect(find.byType(ProgressPlayButton), findsOneWidget, reason: 'el play, siempre a la vista');
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }

  testWidgets('Pantalla completa: desde el ⋯, las barras se esconden solas y Esc sale', (tester) async {
    final screen = _Mode();
    final container = await _pump(tester, const Size(1280, 800), screen: screen);
    await tester.tap(find.byTooltip('Más opciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('player-fullscreen')));
    await tester.pumpAndSettle();
    expect(screen.calls, [true]);
    expect(container.read(playerFullscreenProvider), isTrue);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    final top = tester.widget<AnimatedOpacity>(
      find.ancestor(of: find.byKey(const Key('player-fullscreen-exit')), matching: find.byType(AnimatedOpacity)).first,
    );
    expect(top.opacity, 0, reason: 'la barra de arriba se escondió');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(screen.calls, [true, false]);
  });

  testWidgets('Compacto: la portada chica va al lado del título y se recuerda', (tester) async {
    final container = await _pump(tester, const Size(800, 500), mode: 'compact');
    expect(container.read(settingsProvider).playerMode, 'compact');
    final cover = tester.getRect(find.byType(Hero).first);
    final title = tester.getRect(find.text('Un título inventado bastante largo'));
    expect(cover.height, lessThanOrEqualTo(132));
    expect(title.left, greaterThan(cover.right), reason: 'el título, a la derecha de la portada');
  });

  testWidgets('Botones de abajo: con su nombre de fábrica; apagado, solo íconos con tooltip', (tester) async {
    await _pump(tester, const Size(420, 860));
    for (final name in ['Letra', 'Cola', 'Sonido', 'Temporizador', 'Momento']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(find.bySemanticsLabel('Guardar este momento'), findsOneWidget, reason: 'el nombre completo, para lectores');
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, const Size(420, 860), labels: false);
    expect(find.text('Temporizador'), findsNothing);
    expect(find.byTooltip('Cola'), findsOneWidget);
    expect(find.bySemanticsLabel('Cola'), findsOneWidget);
  });

  testWidgets('Ventana ancha: el reproductor va en una columna centrada', (tester) async {
    await _pump(tester, const Size(1920, 1000));
    final column = tester.getRect(find.byKey(const Key('player-column')));
    expect(column.width, lessThanOrEqualTo(KijiSizes.playerMaxWidth));
    expect(column.center.dx, closeTo(960, 1));
  });

  testWidgets('La portada se aleja apenas en pausa; con "reducir animaciones", quieta', (tester) async {
    final container = await _pump(tester, const Size(420, 860));
    expect(tester.widget<AnimatedScale>(find.byKey(const Key('player-cover-scale'))).scale, 0.95);
    await container.read(settingsProvider.notifier).update((s) => s.copyWith(reduceMotion: true));
    await tester.pump();
    expect(find.byKey(const Key('player-cover-scale')), findsNothing);
  });
}
