// "Momento guardado": el aviso va arriba (no tapa los controles), dura poco, se cierra deslizándolo,
// y "Ver" abre los Momentos aunque la hoja ya se haya cerrado (antes: "Null check operator used on
// a null value" en _NewMomentSheetState._save).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/moments/data/moments_store.dart';
import 'package:kiji_player/features/moments/presentation/moment_marks.dart';
import 'package:kiji_player/features/moments/presentation/moments_screen.dart';
import 'package:kiji_player/l10n/l10n.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/playback_provider.dart';

const _track = Track(
  id: 'local-1',
  title: 'Canción Inventada',
  artist: 'Artista Inventado',
  coverColor: Color(0xFF7C5CFF),
  audioUrl: '/storage/emulated/0/Music/test.mp3',
  source: TrackSource.local,
);

class _Playing extends PlaybackNotifier {
  @override
  PlaybackState build() => const PlaybackState(
    track: _track,
    isPlaying: true,
    position: Duration(seconds: 42),
    duration: Duration(minutes: 3),
    shuffleEnabled: false,
    isInitialized: true,
    queue: [_track],
    currentIndex: 0,
    repeatMode: PlaybackRepeatMode.off,
  );
}

void main() {
  late Directory dir;
  setUp(() {
    setKijiLocale(const Locale('en'));
    dir = Directory.systemTemp.createTempSync('kiji_momentos');
  });
  tearDown(() {
    setKijiLocale(const Locale('es'));
    dir.deleteSync(recursive: true);
  });

  Future<void> openAndSave(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playbackProvider.overrideWith(_Playing.new),
          momentsProvider.overrideWith(() => MomentsNotifier(directory: () async => dir.path)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) =>
                  TextButton(onPressed: () => showNewMomentSheet(context, ref), child: const Text('momento')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('momento'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.bookmark_add_rounded));
    await tester.pumpAndSettle();
  }

  testWidgets('El aviso va arriba y «View» abre los Momentos sin error', (tester) async {
    await openAndSave(tester);
    final notice = find.byKey(const Key('top-notice'));
    expect(notice, findsOneWidget);
    expect(tester.getRect(notice).bottom, lessThan(2340 / 3 / 2), reason: 'arriba: no tapa los controles');
    await tester.tap(find.byKey(const Key('top-notice-action')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(MomentsScreen), findsOneWidget);
    expect(notice, findsNothing);
  });

  testWidgets('Dura lo suficiente para tocar «View» (6 s) y después se va solo', (tester) async {
    await openAndSave(tester);
    expect(find.byKey(const Key('top-notice')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const Key('top-notice')), findsOneWidget, reason: 'a los 3 s sigue ahí');
    await tester.pump(const Duration(seconds: 3, milliseconds: 100));
    expect(find.byKey(const Key('top-notice')), findsNothing);
  });

  testWidgets('Con momentos guardados, la hoja del reproductor los abre («See your moments»)', (tester) async {
    await openAndSave(tester);
    await tester.pump(const Duration(seconds: 7)); // el aviso ya se fue
    await tester.tap(find.text('momento'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-moments')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(MomentsScreen), findsOneWidget);
  });

  testWidgets('Se cierra deslizándolo a un costado', (tester) async {
    await openAndSave(tester);
    await tester.fling(find.byKey(const Key('top-notice')), const Offset(300, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('top-notice')), findsNothing);
  });
}
