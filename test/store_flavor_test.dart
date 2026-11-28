// Sabores de tienda (0.9, base de la 1.0). Se corre dos veces (la CI lo hace):
//   flutter test test/store_flavor_test.dart                            → «full», todo como siempre
//   flutter test --dart-define=KIJI_STORE=play test/store_flavor_test.dart → «play», sin descargas
//                                                                          ni cuenta de YouTube
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/account/presentation/account_screens.dart';
import 'package:kiji_player/features/downloads/presentation/download_button.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/store_flavor.dart';

const _yt = Track(
  id: 'yt-inventado',
  title: 'Glass Harbor',
  artist: 'The Velvet Tides',
  coverColor: Color(0xFF7C5CFF),
  audioUrl: '',
  source: TrackSource.youtube,
);

void main() {
  test('El sabor sale de --dart-define (de fábrica, «full»)', () {
    expect(kijiStore, anyOf('full', 'play'));
    expect(isPlayStore, kijiStore == 'play');
  });

  testWidgets('Descargar canciones de YouTube: en «full» sí, en «play» no', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: Scaffold(body: Center(child: DownloadButton(track: _yt))))),
    );
    await tester.pump();
    expect(find.byType(IconButton), isPlayStore ? findsNothing : findsOneWidget);
  });

  testWidgets('«Conecta tu YouTube Music»: en «play» no aparece', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: Scaffold(body: YtConnectCard()))));
    await tester.pump();
    if (isPlayStore) expect(find.byType(Padding), findsNothing);
  });
}
