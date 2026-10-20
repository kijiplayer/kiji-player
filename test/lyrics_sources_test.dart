import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/lyrics/data/lrclib_client.dart';
import 'package:kiji_player/features/lyrics/data/lyrics_repository.dart';
import 'package:kiji_player/features/lyrics/data/lyrics_sources.dart';
import 'package:kiji_player/features/lyrics/domain/lyrics.dart';
import 'package:kiji_player/features/lyrics/lyrics_provider.dart';
import 'package:kiji_player/features/lyrics/presentation/lyrics_sources_sheet.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';

/// Fuente falsa con letra inventada (nunca letras reales).
class _Fake implements LyricsFetcher {
  _Fake(this.source, this.answer);

  @override
  final LyricsSource source;
  final Lyrics? Function() answer;
  int calls = 0;

  @override
  Future<Lyrics?> fetch(LyricsRequest request) async {
    calls++;
    return answer();
  }
}

const LyricsRequest _req = (id: 'yt-abc', title: 'Tema inventado', artist: 'Nadie', album: null, durationMs: 1000, localPath: null);

Lyrics _plain(LyricsSource s) => Lyrics(plain: 'Línea inventada uno\nLínea inventada dos', source: s);
Lyrics _synced(LyricsSource s) => Lyrics(synced: parseLrc('[00:01.00] Línea inventada'), source: s);

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('kiji_c3'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('El orden de las fuentes se guarda y las nuevas van al final', () {
    final order = lyricsOrderFrom(['kugou', 'lrclib', 'desconocida']);
    expect(order.take(2), [LyricsSource.kugou, LyricsSource.lrclib]);
    expect(order.length, LyricsSource.online.length);
    final back = AppSettings.fromJson(const AppSettings().copyWith(lyricsSourceOrder: order).toJson());
    expect(back.lyricsSourceOrder, order);
  });

  test('Se busca en el orden que eligió el usuario', () async {
    final lrclib = _Fake(LyricsSource.lrclib, () => _plain(LyricsSource.lrclib));
    final kugou = _Fake(LyricsSource.kugou, () => _synced(LyricsSource.kugou));
    final repo = LyricsRepository(fetchers: [lrclib, kugou], baseDirectory: () async => dir);
    final lyrics = await repo.get(_req, order: [LyricsSource.kugou, LyricsSource.lrclib]);
    expect(lyrics.source, LyricsSource.kugou);
    expect(lrclib.calls, 0, reason: 'la primera del orden ya la tenía');
  });

  test('Comparar: cada fuente dice si la tiene y si está sincronizada; elegir la guarda', () async {
    final repo = LyricsRepository(
      fetchers: [
        _Fake(LyricsSource.lrclib, () => _plain(LyricsSource.lrclib)),
        _Fake(LyricsSource.kugou, () => _synced(LyricsSource.kugou)),
        _Fake(LyricsSource.paxsenix, () => null),
        _Fake(LyricsSource.unison, () => throw const LyricsUnavailableException('sin conexión')),
        _Fake(LyricsSource.youlyplus, () => _plain(LyricsSource.youlyplus)),
      ],
      baseDirectory: () async => dir,
    );
    final results = {
      for (final p in await repo.probe(_req, disabled: {LyricsSource.youlyplus}).toList()) p.source: p.state,
    };
    expect(results, {
      LyricsSource.lrclib: LyricsProbeState.plain,
      LyricsSource.kugou: LyricsProbeState.synced,
      LyricsSource.paxsenix: LyricsProbeState.none,
      LyricsSource.unison: LyricsProbeState.failed,
      LyricsSource.youlyplus: LyricsProbeState.off,
    });

    await repo.choose(_req.id, _synced(LyricsSource.kugou));
    final again = LyricsRepository(fetchers: [], baseDirectory: () async => dir);
    expect((await again.get(_req)).source, LyricsSource.kugou, reason: 'la elegida queda guardada');
  });

  // D1: la hoja tenía ListTile sobre un Container con color (sin Material) y Flutter avisaba un
  // error en cada fila; el aviso de "Algo falló" tapaba la lista y se veían pocas fuentes.
  testWidgets('La hoja de fuentes se abre sin errores y muestra siempre las 8', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final repo = LyricsRepository(
      fetchers: [for (final s in LyricsSource.online) _Fake(s, () => s == LyricsSource.lrclib ? _plain(s) : null)],
      baseDirectory: () async => dir,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        lyricsRepositoryProvider.overrideWithValue(repo),
        settingsProvider.overrideWith(() => SettingsNotifier(directory: () async => dir)),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showLyricsSourcesSheet(
              context,
              _req,
              current: LyricsSource.lrclib,
              onSearchByHand: () {},
              onImport: () {},
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final s in LyricsSource.online) {
      expect(find.text(s.label), findsOneWidget, reason: s.label);
    }
    expect(find.text('Es la que ves ahora'), findsOneWidget);
  });
}
