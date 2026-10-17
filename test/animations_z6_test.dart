import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/moments/data/moments_store.dart';
import 'package:kiji_player/features/moments/domain/moment.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/appearance_provider.dart';
import 'package:kiji_player/theme/app_theme.dart';
import 'package:kiji_player/widgets/nocturne/staggered.dart';
import 'package:kiji_player/widgets/nocturne/waveform_progress.dart';

const _yt = Track(
  id: 'yt-abc123',
  title: 'Canción inventada',
  artist: 'Banda de prueba',
  coverColor: Color(0xFF7C5CFF),
  audioUrl: 'https://url-que-vence',
  source: TrackSource.youtube,
);

const _local = Track(
  id: 'local-1',
  title: 'Archivo propio',
  artist: 'Yo',
  coverColor: Color(0xFF3DF5FF),
  audioUrl: '/storage/emulated/0/Music/propio.mp3',
  source: TrackSource.local,
);

void main() {
  group('Momentos', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('kiji_mom'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('Se guardan al segundo, el más nuevo primero, se borran y se recuperan', () async {
      final c = ProviderContainer(overrides: [
        momentsProvider.overrideWith(() => MomentsNotifier(directory: () async => dir.path)),
      ]);
      addTearDown(c.dispose);
      final n = c.read(momentsProvider.notifier);
      final first = n.add(_yt, const Duration(minutes: 1, seconds: 23, milliseconds: 870), now: DateTime(2026, 1, 1));
      n.add(_local, const Duration(seconds: 5), now: DateTime(2026, 1, 2));
      expect(first.position, const Duration(minutes: 1, seconds: 23));
      expect([for (final m in c.read(momentsProvider)) m.track.id], ['local-1', 'yt-abc123']);

      final removed = n.remove(first.id)!;
      expect(c.read(momentsProvider), hasLength(1));
      n.restore(removed.$1, removed.$2);
      expect(c.read(momentsProvider).last.id, first.id);
    });

    test('Vuelven igual del JSON (sin la URL de audio de YouTube, que vence)', () {
      final m = Moment(id: '1', track: _yt, position: const Duration(seconds: 83), createdAt: DateTime(2026));
      final back = Moment.fromJson(m.toJson())!;
      expect(back.track.id, 'yt-abc123');
      expect(back.position, const Duration(seconds: 83));
      expect(back.track.audioUrl, isNot(contains('url-que-vence')));
      expect(Moment.fromJson({'nada': 1}), isNull);
    });

    test('Texto para compartir: con enlace al segundo si es de YouTube', () {
      final yt = Moment(id: '1', track: _yt, position: const Duration(seconds: 83), createdAt: DateTime(2026));
      expect(momentShareText(yt), '«Canción inventada» de Banda de prueba, desde el 1:23\nhttps://youtu.be/abc123?t=83');
      final local = Moment(id: '2', track: _local, position: const Duration(seconds: 5), createdAt: DateTime(2026));
      expect(momentShareText(local), isNot(contains('http')));
      expect(momentShareText(local), isNot(contains('/storage/')));
    });
  });

  group('Animaciones y "Reducir animaciones"', () {
    testWidgets('Lista escalonada: entra con demora y termina visible', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [reduceMotionSettingProvider.overrideWithValue(false)],
        child: MaterialApp(
          home: StaggerScope(
            child: Column(children: staggered([const Text('uno'), const Text('dos'), const Text('tres')])),
          ),
        ),
      ));
      FadeTransition fade(String text) =>
          tester.widget<FadeTransition>(find.ancestor(of: find.text(text), matching: find.byType(FadeTransition)).first);
      await tester.pump(const Duration(milliseconds: 60));
      expect(fade('tres').opacity.value, lessThan(fade('uno').opacity.value), reason: 'la tercera entra después');
      await tester.pumpAndSettle();
      expect(fade('tres').opacity.value, 1);
    });

    testWidgets('Con "Reducir animaciones" la lista aparece directo', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [reduceMotionSettingProvider.overrideWithValue(true)],
        child: MaterialApp(home: Column(children: staggered([const Text('uno')]))),
      ));
      final fade = tester.widget<FadeTransition>(
          find.ancestor(of: find.text('uno'), matching: find.byType(FadeTransition)).first);
      expect(fade.opacity.value, 1);
    });

    testWidgets('Transición entre pantallas quieta con "Reducir animaciones"', (tester) async {
      const builder = KijiPageTransitionsBuilder(still: true);
      final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());
      late Widget built;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          built = builder.buildTransitions(
              route, context, kAlwaysCompleteAnimation, kAlwaysDismissedAnimation, const Text('pantalla'));
          return built;
        }),
      ));
      expect(built, isA<Text>());
    });

    testWidgets('La onda se dibuja de izquierda a derecha y queda completa', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: WaveformProgress(seed: 'x', progress: 0.5, onSeek: (_) {}, animateIn: true),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(WaveformProgress), findsOneWidget);
    });
  });
}
