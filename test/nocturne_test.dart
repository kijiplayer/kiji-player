import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/history/listening_history.dart';
import 'package:kiji_player/features/local_library/presentation/local_library_screen.dart';
import 'package:kiji_player/features/yt_music/presentation/search_screen.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/screens/home/inicio_tab.dart';
import 'package:kiji_player/screens/player/player_screen.dart';
import 'package:kiji_player/widgets/nocturne/breathing_play_button.dart';
import 'package:kiji_player/widgets/nocturne/waveform_progress.dart';

Track _t(String id, {String? artist, TrackSource source = TrackSource.youtube, String path = ''}) => Track(
      id: source == TrackSource.youtube ? 'yt-$id' : 'local-$id',
      title: id,
      artist: artist ?? 'Artista',
      coverColor: const Color(0xFF7C5CFF),
      audioUrl: path,
      source: source,
    );

void main() {
  group('Onda de progreso', () {
    test('La misma canción siempre tiene la misma onda', () {
      expect(waveformBars('yt-abc', 40), waveformBars('yt-abc', 40));
      expect(waveformBars('yt-abc', 40), isNot(waveformBars('yt-xyz', 40)));
    });

    test('Las barras quedan entre 0,12 y 1, y las puntas son más bajas', () {
      final bars = waveformBars('yt-abc', 60);
      expect(bars, hasLength(60));
      expect(bars.every((b) => b >= 0.12 && b <= 1.0), isTrue);
      final middle = bars.sublist(20, 40).reduce((a, b) => a + b) / 20;
      expect(bars.first, lessThan(middle));
    });

    testWidgets('Tocar la onda busca en ese punto', (tester) async {
      double? sought;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: WaveformProgress(seed: 'yt-abc', progress: 0, onSeek: (v) => sought = v),
            ),
          ),
        ),
      ));
      final box = tester.getRect(find.byType(WaveformProgress));
      await tester.tapAt(Offset(box.left + box.width * 0.75, box.center.dy));
      expect(sought, closeTo(0.75, 0.02));
    });
  });

  group('Botón play que respira', () {
    test('Solo respira mientras suena y sin "reducir animaciones"', () {
      expect(breathingShouldAnimate(isPlaying: true, reduceMotion: false), isTrue);
      expect(breathingShouldAnimate(isPlaying: true, reduceMotion: true), isFalse);
      expect(breathingShouldAnimate(isPlaying: false, reduceMotion: false), isFalse);
    });

    testWidgets('Con "reducir animaciones" la pantalla se queda quieta', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BreathingPlayButton(isPlaying: true, reduceMotion: true, onPressed: () {}),
        ),
      ));
      // Si el anillo se animara, esto nunca terminaría.
      await tester.pumpAndSettle();
      // Play que se transforma en pausa: sonando, el ícono queda en "pausa".
      final icon = tester.widget<AnimatedIcon>(find.byType(AnimatedIcon));
      expect(icon.icon, AnimatedIcons.play_pause);
      expect(icon.progress.value, 1);
      expect(find.bySemanticsLabel('Pausar'), findsOneWidget);
    });
  });

  test('Saludo según la hora', () {
    expect(greetingFor(DateTime(2026, 10, 16, 7)), 'Buenos días');
    expect(greetingFor(DateTime(2026, 10, 16, 15)), 'Buenas tardes');
    expect(greetingFor(DateTime(2026, 10, 16, 23)), 'Buenas noches');
    expect(greetingFor(DateTime(2026, 10, 16, 3)), 'Buenas noches');
  });

  test('"Reproduciendo desde"', () {
    expect(playingFromLabel(_t('a', source: TrackSource.local), downloaded: false), 'TU BIBLIOTECA');
    expect(playingFromLabel(_t('a'), downloaded: true), 'DESCARGADAS');
    expect(playingFromLabel(_t('a'), downloaded: false), 'YOUTUBE MUSIC');
  });

  group('Historial (calculado en el teléfono)', () {
    final t0 = DateTime(2026, 10, 16, 10);

    test('Escuchar de nuevo sube el contador y la pone primera', () {
      var entries = HistoryLogic.record(const [], _t('a'), t0);
      entries = HistoryLogic.record(entries, _t('b'), t0.add(const Duration(minutes: 1)));
      entries = HistoryLogic.record(entries, _t('a'), t0.add(const Duration(minutes: 2)));
      expect(entries.map((e) => e.track.title), ['a', 'b']);
      expect(entries.first.playCount, 2);
      expect(HistoryLogic.recent(entries).map((t) => t.title), ['a', 'b']);
    });

    test('"Para ti": las más escuchadas, sin la que suena', () {
      var entries = <HistoryEntry>[];
      for (final (i, id) in ['a', 'b', 'b', 'c', 'c', 'c'].indexed) {
        entries = HistoryLogic.record(entries, _t(id), t0.add(Duration(minutes: i)));
      }
      expect(HistoryLogic.forYou(entries).map((t) => t.title), ['c', 'b', 'a']);
      expect(HistoryLogic.forYou(entries, excludeId: 'yt-c').map((t) => t.title), ['b', 'a']);
    });

    test('Se recuerdan como máximo 100 canciones distintas', () {
      var entries = <HistoryEntry>[];
      for (var i = 0; i < 120; i++) {
        entries = HistoryLogic.record(entries, _t('t$i'), t0.add(Duration(seconds: i)));
      }
      expect(entries, hasLength(HistoryLogic.maxEntries));
      expect(entries.first.track.title, 't119');
    });

    test('El historial sobrevive a guardarse', () {
      final entry = HistoryLogic.record(const [], _t('a'), t0).single;
      final restored = HistoryEntry.fromJson(entry.toJson());
      expect(restored.track.id, 'yt-a');
      expect(restored.playCount, 1);
      expect(restored.lastPlayed, t0);
    });
  });

  test('Carpetas: agrupa las canciones locales por carpeta', () {
    final groups = groupByFolder([
      _t('1', source: TrackSource.local, path: '/m/Rock/a.mp3'),
      _t('2', source: TrackSource.local, path: '/m/Jazz/b.mp3'),
      _t('3', source: TrackSource.local, path: '/m/Rock/c.mp3'),
      _t('yt'), // las de YouTube no tienen carpeta
    ]);
    expect(groups.keys.map((k) => k.split('/').last), ['Jazz', 'Rock']);
    expect(groups.values.last, hasLength(2));
  });

  test('Mis archivos: busca por título, artista o álbum', () {
    final tracks = [_t('Luz', artist: 'Nova'), _t('Sombra', artist: 'Eco')];
    expect(filterMyFiles(tracks, 'NOVA').map((t) => t.title), ['Luz']);
    expect(filterMyFiles(tracks, 'som').map((t) => t.title), ['Sombra']);
    expect(filterMyFiles(tracks, '   '), isEmpty);
  });
}
