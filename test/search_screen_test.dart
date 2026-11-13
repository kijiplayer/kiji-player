import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/yt_music/data/ytm_browse_parser.dart';
import 'package:kiji_player/features/yt_music/data/ytm_client.dart';
import 'package:kiji_player/features/yt_music/presentation/search_screen.dart';

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

void main() {
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
}
