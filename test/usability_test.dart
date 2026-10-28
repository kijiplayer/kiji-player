import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/settings/presentation/settings_screen.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/playback_provider.dart';
import 'package:kiji_player/widgets/global_mini_player.dart';
import 'package:kiji_player/widgets/mini_player.dart';

const _track = Track(
  id: 'local-1',
  title: 'Canción de prueba',
  artist: 'Artista inventado',
  coverColor: Color(0xFF7C5CFF),
  audioUrl: '/storage/emulated/0/Music/prueba.mp3',
  source: TrackSource.local,
);

class _Playing extends PlaybackNotifier {
  @override
  PlaybackState build() => const PlaybackState(
        track: _track,
        isPlaying: false,
        position: Duration.zero,
        duration: Duration(minutes: 3),
        shuffleEnabled: false,
        isInitialized: true,
        queue: [_track],
        currentIndex: 0,
        repeatMode: PlaybackRepeatMode.off,
      );
}

class _Empty extends PlaybackNotifier {
  @override
  PlaybackState build() => PlaybackState.initial();
}

Future<Directory> _noDisk() async => throw const FileSystemException('sin disco en el test');

Widget _app(MiniPlayerRouteObserver routes) => ProviderScope(
      overrides: [playbackProvider.overrideWith(_Playing.new)],
      child: MaterialApp(
        navigatorKey: kijiNavigatorKey,
        navigatorObservers: [routes],
        builder: (context, child) => GlobalMiniPlayer(observer: routes, child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    body: Column(
                      children: [
                        TextButton(
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) => const AlertDialog(content: Text('Un diálogo')),
                          ),
                          child: const Text('diálogo'),
                        ),
                        const Spacer(),
                        const Text('Fondo de la página'),
                      ],
                    ),
                  ),
                )),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  test('Cuándo se ve el mini-reproductor global', () {
    const page = RouteStackInfo(topPageName: 'playlist');
    expect(showGlobalMiniPlayer(hasTrack: true, routes: page, keyboardOpen: false), isTrue);
    expect(showGlobalMiniPlayer(hasTrack: false, routes: page, keyboardOpen: false), isFalse);
    expect(showGlobalMiniPlayer(hasTrack: true, routes: page, keyboardOpen: true), isFalse);
    expect(
      showGlobalMiniPlayer(
          hasTrack: true, routes: const RouteStackInfo(topPageName: 'playlist', popupOpen: true), keyboardOpen: false),
      isFalse,
    );
    for (final own in KijiRoutes.hideMiniPlayer) {
      expect(showGlobalMiniPlayer(hasTrack: true, routes: RouteStackInfo(topPageName: own), keyboardOpen: false),
          isFalse,
          reason: own);
    }
  });

  testWidgets('En otras pantallas se ve, no tapa el contenido y se esconde con un diálogo', (tester) async {
    final routes = MiniPlayerRouteObserver();
    await tester.pumpWidget(_app(routes));
    await tester.pumpAndSettle();
    // Inicio tiene el suyo: el global no aparece.
    expect(find.byType(MiniPlayer), findsNothing);

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.byType(MiniPlayer), findsOneWidget);
    final contentBottom = tester.getRect(find.text('Fondo de la página')).bottom;
    final miniTop = tester.getRect(find.byType(MiniPlayer)).top;
    expect(contentBottom, lessThanOrEqualTo(miniTop));

    await tester.tap(find.text('diálogo'));
    await tester.pumpAndSettle();
    expect(find.byType(MiniPlayer), findsNothing);

    Navigator.of(tester.element(find.text('Un diálogo'))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(MiniPlayer), findsOneWidget);
  });

  testWidgets('Transición suave: tocar la fila deja elegir la duración', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: [
      settingsProvider.overrideWith(() => SettingsNotifier(directory: _noDisk)),
      playbackProvider.overrideWith(_Empty.new),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pump();

    await tester.tap(find.text('Reproductor y audio'));
    await tester.pumpAndSettle();
    // Se toca el título (antes solo respondía el "No" chiquito de la derecha).
    await tester.tap(find.text('Transición suave entre canciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 segundos'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).crossfadeSeconds, 5);
    expect(find.text('5 s'), findsOneWidget);
  });
}
