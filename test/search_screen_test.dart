import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/yt_music/data/ytm_browse_parser.dart';
import 'package:kiji_player/features/yt_music/data/ytm_client.dart';
import 'package:kiji_player/features/recommendations/data/search_history.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/features/yt_music/presentation/search_screen.dart';
import 'package:kiji_player/l10n/l10n.dart';

/// YouTube Music de mentira: páginas de [pageSize] canciones inventadas, con marca para la siguiente.
class _FakeClient extends YtMusicClient {
  _FakeClient({this.pageSize = 3});

  final int pageSize;
  final requested = <String?>[];

  @override
  Future<YtSearchPage<YtMusicSearchResult>> searchSongsPage(
    String query, {
    bool songsOnly = true,
    String? continuation,
  }) async {
    requested.add(continuation);
    final page = continuation == null ? 1 : int.parse(continuation);
    return YtSearchPage([
      for (var i = 1; i <= pageSize; i++)
        YtMusicSearchResult(videoId: 'p${page}c$i', title: 'Canción $page.$i', artist: 'Grupo Inventado'),
    ], page < 3 ? '${page + 1}' : null);
  }

  @override
  Future<YtTopResult?> searchTop(String query) async => null;

  @override
  Future<YtSearchPage<YtCollection>> searchCollectionsPage(
    String query,
    YtCollectionKind kind, {
    String? continuation,
  }) async => const YtSearchPage([], null);
}

/// Artistas, álbumes y playlists tardan (no llegan hasta que se suelte [slow]).
class _SlowCollections extends _FakeClient {
  final slow = Completer<void>();

  @override
  Future<YtSearchPage<YtCollection>> searchCollectionsPage(
    String query,
    YtCollectionKind kind, {
    String? continuation,
  }) async {
    await slow.future;
    return const YtSearchPage([], null);
  }
}

class _Settings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
  @override
  Future<void> update(AppSettings Function(AppSettings) change) async => state = change(state);
}

void main() {
  testWidgets('Recientes: se pueden dejar de guardar (se borran y no se muestran más)', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final dir = Directory.systemTemp.createTempSync('kiji_busquedas');
    addTearDown(() => dir.deleteSync(recursive: true));
    final c = ProviderContainer(overrides: [
      settingsProvider.overrideWith(_Settings.new),
      searchHistoryProvider.overrideWith(() => SearchHistoryNotifier(directory: () async => dir.path)),
    ]);
    addTearDown(c.dispose);
    c.read(searchHistoryProvider.notifier).add('búsqueda inventada');
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(home: Scaffold(body: SearchScreen(client: _FakeClient()))),
    ));
    await tester.pump();
    expect(find.text('búsqueda inventada'), findsOneWidget);

    await tester.tap(find.byKey(const Key('search-history-off')));
    await tester.pump();
    expect(find.text('búsqueda inventada'), findsNothing);
    expect(c.read(searchHistoryProvider), isEmpty, reason: 'se borran');
    expect(c.read(settingsProvider).searchHistoryOn, isFalse);

    // Una búsqueda nueva no se guarda.
    await tester.enterText(find.byType(TextField), 'otra búsqueda');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(c.read(searchHistoryProvider), isEmpty);
  });

  testWidgets('Todo: las canciones aparecen sin esperar a artistas, álbumes y playlists', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = _SlowCollections();
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: Scaffold(body: SearchScreen(client: client))),
    ));
    await tester.enterText(find.byType(TextField), 'algo inventado');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Canción 1.1'), findsOneWidget, reason: 'sin esperar a lo que tarda');
    client.slow.complete();
    await tester.pumpAndSettle();
    expect(find.text('Canción 1.1'), findsOneWidget);
  });

  testWidgets('Si la primera página no llena la pantalla, pide la siguiente sola', (tester) async {
    tester.view.physicalSize = const Size(800, 2400); // ventana muy alta
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = _FakeClient();
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: Scaffold(body: SearchScreen(client: client))),
    ));
    await tester.tap(find.text('Canciones'));
    await tester.enterText(find.byType(TextField), 'algo inventado');
    await tester.pump(const Duration(milliseconds: 600)); // la espera mientras se escribe
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Tres páginas de 3 entran en la pantalla: se pidieron todas sin mover la lista, y no más.
    expect(client.requested, [null, '2', '3']);
    expect(find.text('Canción 3.3'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('Si la página llena la pantalla, espera a que se baje', (tester) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = _FakeClient(pageSize: 20); // la primera página sobra de largo
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: Scaffold(body: SearchScreen(client: client))),
    ));
    await tester.tap(find.text('Canciones'));
    await tester.enterText(find.byType(TextField), 'algo inventado');
    await tester.pump(const Duration(milliseconds: 600));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(client.requested, [null]);
    await tester.pumpAndSettle();
  });

  // Multibúsqueda (0.9): lo elegido se mantiene al buscar otra cosa.
  testWidgets('Lo elegido se mantiene al buscar otra cosa', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [settingsProvider.overrideWith(_Settings.new)],
      child: MaterialApp(home: Scaffold(body: SearchScreen(client: _FakeClient()))),
    ));
    await tester.enterText(find.byType(TextField), 'primera búsqueda');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Canción 1.1'));
    await tester.pumpAndSettle();
    expect(find.text(tx.nSeleccionadas(1)), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'segunda búsqueda');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text(tx.nSeleccionadas(1)), findsOneWidget, reason: 'sigue elegida');
  });
}