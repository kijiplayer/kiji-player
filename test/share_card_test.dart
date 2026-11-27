// Tarjetas para compartir (0.9): tres estilos y tres formatos, con el logo y la página de Kiji.
// Nunca llevan letras. Canción inventada.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/share_cards/now_playing_card.dart';
import 'package:kiji_player/l10n/l10n.dart';
import 'package:kiji_player/models/track.dart';

const _track = Track(
  id: 'local-tarjeta',
  title: 'The Extraordinarily Long Goodbye Under Neon Rain (Extended Version)',
  artist: 'Glass Harbor',
  coverColor: Color(0xFF3D6BFF),
  audioUrl: '/musica/inventada.mp3',
  source: TrackSource.local,
);

void main() {
  setUp(() => setKijiLocale(const Locale('en')));
  tearDown(() => setKijiLocale(const Locale('es')));

  for (final style in ShareCardStyle.values) {
    for (final format in ShareCardFormat.values) {
      testWidgets('${style.name} en ${format.name}: entra sin desbordes, con el título y la página', (tester) async {
        tester.view.physicalSize = const Size(1200, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Center(child: NowPlayingCard(track: _track, style: style, format: format)),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'sin desbordes');
        expect(tester.getSize(find.byType(NowPlayingCard)), Size(format.width, format.height));
        expect(find.textContaining('Glass Harbor'), findsWidgets);
        expect(find.text(kijiCardUrl), findsOneWidget);
      });
    }
  }
}
