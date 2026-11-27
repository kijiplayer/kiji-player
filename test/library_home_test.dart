import 'dart:async';

// Biblioteca 0.9 («una sola lista»): playlists a la vista, la música del dispositivo opcional,
// qué se ve lo elige el usuario y «Quitar descarga» en el menú de cada canción. Datos inventados.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/downloads/domain/downloaded_track.dart';
import 'package:kiji_player/features/local_library/presentation/library_home.dart';
import 'package:kiji_player/features/queue/presentation/track_actions.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/l10n/l10n.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/downloads_provider.dart';
import 'package:kiji_player/providers/playback_provider.dart';

class _Settings extends SettingsNotifier {
  _Settings(this.initial);
  final AppSettings initial;
  @override
  AppSettings build() => initial;
  @override
  Future<void> update(AppSettings Function(AppSettings) change) async => state = change(state);
}

final _download = DownloadedTrack(
  videoId: 'inventado1',
  title: 'Glass Harbor',
  artist: 'The Velvet Tides',
  coverColor: const Color(0xFF7C5CFF),
  fileName: 'inventado1.m4a',
  sizeBytes: 3000000,
  downloadedAt: DateTime(2026, 11, 26),
);

class _Downloads extends DownloadsNotifier {
  @override
  DownloadsState build() => DownloadsState(completed: {'inventado1': _download}, loaded: true);
}

class _Idle extends PlaybackNotifier {
  @override
  PlaybackState build() => const PlaybackState(
    track: null,
    isPlaying: false,
    position: Duration.zero,
    duration: Duration.zero,
    shuffleEnabled: false,
    isInitialized: false,
    queue: [],
    currentIndex: 0,
    repeatMode: PlaybackRepeatMode.off,
  );
}

void main() {
  setUp(() => setKijiLocale(const Locale('en')));
  tearDown(() => setKijiLocale(const Locale('es')));

  Future<ProviderContainer> pump(WidgetTester tester, AppSettings settings, {Widget? home}) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final c = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(() => _Settings(settings)),
        downloadsProvider.overrideWith(_Downloads.new),
        playbackProvider.overrideWith(_Idle.new),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(home: Scaffold(body: home ?? const LibraryHome())),
      ),
    );
    await tester.pumpAndSettle();
    return c;
  }

  testWidgets('Playlists a la vista y «Tu música» sin Artistas ni Álbumes de fábrica', (tester) async {
    await pump(tester, const AppSettings(phoneMusic: 'on'));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('library-entry-songs')), findsOneWidget);
    expect(find.byKey(const Key('library-entry-downloads')), findsOneWidget);
    expect(find.byKey(const Key('library-entry-folders')), findsOneWidget);
    expect(find.byKey(const Key('library-entry-artists')), findsNothing);
    expect(find.byKey(const Key('library-entry-albums')), findsNothing);
  });

  testWidgets('La primera vez pregunta por la música del dispositivo; «No» quita Carpetas', (tester) async {
    final c = await pump(tester, const AppSettings());
    expect(find.byKey(const Key('phone-music-question')), findsOneWidget);
    await tester.tap(find.byKey(const Key('phone-music-no')));
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).phoneMusic, 'off');
    expect(find.byKey(const Key('phone-music-question')), findsNothing);
    expect(find.byKey(const Key('library-entry-folders')), findsNothing, reason: 'sin música del dispositivo');
    expect(find.byKey(const Key('library-entry-downloads')), findsOneWidget, reason: 'lo de Kiji sigue');
  });

  testWidgets('«Qué ver en la Biblioteca»: prender Artistas la agrega', (tester) async {
    final c = await pump(tester, const AppSettings(phoneMusic: 'on'));
    await tester.tap(find.byKey(const Key('library-choose-entries')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('entries-artists')));
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).libraryEntries, contains('artists'));
    Navigator.of(tester.element(find.byKey(const Key('entries-artists')))).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library-entry-artists')), findsOneWidget);
  });

  testWidgets('El buscador de la Biblioteca encuentra lo descargado', (tester) async {
    await pump(tester, const AppSettings(phoneMusic: 'off'));
    await tester.enterText(find.byKey(const Key('list-search')), 'glass');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library-result-yt-inventado1')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('list-search')), 'nada que coincida');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('library-result-yt-inventado1')), findsNothing);
  });

  test('Los ajustes nuevos se guardan y vuelven', () {
    const s = AppSettings(phoneMusic: 'off', libraryEntries: ['songs', 'albums']);
    final back = AppSettings.fromJson(s.toJson());
    expect(back.phoneMusic, 'off');
    expect(back.libraryEntries, ['songs', 'albums']);
    expect(const AppSettings().phoneMusic, 'ask', reason: 'se pregunta la primera vez');
    expect(const AppSettings().libraryEntries, isNot(contains('artists')));
  });

  testWidgets('Menú de una canción descargada: «Remove download»; sin descargar: «Download»', (tester) async {
    late WidgetRef saved;
    await pump(
      tester,
      const AppSettings(),
      home: Consumer(
        builder: (context, ref, _) {
          saved = ref;
          return const SizedBox.expand();
        },
      ),
    );
    final context = tester.element(find.byType(SizedBox).last);
    unawaited(showTrackActions(context, saved, _download.toTrack()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('track-action-remove-download')), findsOneWidget);
    Navigator.of(tester.element(find.byKey(const Key('track-action-remove-download')))).pop();
    await tester.pumpAndSettle();

    const other = Track(
      id: 'yt-otra',
      title: 'Paper Lanterns',
      artist: 'Nadie Inventado',
      coverColor: Color(0xFF3DF5FF),
      audioUrl: '',
      source: TrackSource.youtube,
    );
    unawaited(showTrackActions(context, saved, other));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('track-action-download')), findsOneWidget);
  });
}
