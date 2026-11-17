// Teléfono en horizontal (800 × 360 dp): las hojas de abajo no se desbordan; si no entran, se desplazan.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/customize/presentation/customize_sheets.dart';
import 'package:kiji_player/features/moments/presentation/moment_marks.dart';
import 'package:kiji_player/features/queue/presentation/track_actions.dart';
import 'package:kiji_player/l10n/l10n.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/playback_provider.dart';

const _track = Track(
  id: 'local-1',
  title: 'A Fairly Long Invented Song Title For Testing',
  artist: 'An Invented Artist With A Long Name',
  coverColor: Color(0xFF7C5CFF),
  audioUrl: '/storage/emulated/0/Music/test.mp3',
  source: TrackSource.local,
);

class _Playing extends PlaybackNotifier {
  @override
  PlaybackState build() => const PlaybackState(
    track: _track,
    isPlaying: false,
    position: Duration(minutes: 1),
    duration: Duration(minutes: 3),
    shuffleEnabled: false,
    isInitialized: true,
    queue: [_track],
    currentIndex: 0,
    repeatMode: PlaybackRepeatMode.off,
  );
}

void main() {
  final sheets = <String, void Function(BuildContext, WidgetRef)>{
    'acciones de la canción': (context, ref) => showTrackActions(context, ref, _track),
    'personalizar canción': (context, ref) => showCustomizeTrackSheet(context, ref, _track),
    'nuevo momento': showNewMomentSheet,
  };

  for (final MapEntry(key: name, value: open) in sheets.entries) {
    for (final language in ['es', 'en']) {
      testWidgets('Hoja "$name" en horizontal ($language): no se desborda', (tester) async {
        setKijiLocale(Locale(language));
        tester.view.physicalSize = const Size(2400, 1080);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(ProviderScope(
          overrides: [playbackProvider.overrideWith(_Playing.new)],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(onPressed: () => open(context, ref), child: const Text('abrir')),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('abrir'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(BottomSheet), findsOneWidget);
      });
    }
  }
}
