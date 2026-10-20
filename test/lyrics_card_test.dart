import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/downloads/presentation/download_status.dart';
import 'package:kiji_player/features/lyrics/presentation/lyrics_share.dart';
import 'package:kiji_player/models/track.dart';

const _track = Track(
  id: 'yt-abcdefghijk',
  title: 'Tema inventado con un nombre bastante largo',
  artist: 'Artista inventado',
  coverColor: Color(0xFF7C5CFF),
  audioUrl: '',
  source: TrackSource.youtube,
);

// Líneas inventadas (nunca letras reales).
const _lines = [
  'Primera línea inventada para probar la tarjeta',
  'Segunda línea, un poco más larga, para ver que nada se corte',
  'Tercera',
];
const _translations = ['First made-up line', 'Second made-up line, a bit longer', 'Third'];

void main() {
  testWidgets('Todos los formatos, fondos y textos se dibujan sin desbordarse y sin la ✓ de descarga', (tester) async {
    for (final format in CardFormat.values) {
      for (final background in CardBackground.values) {
        for (final text in CardText.values) {
          await tester.pumpWidget(ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Center(
                  child: FittedBox(
                    child: LyricsCard(
                      track: _track,
                      lines: _lines,
                      translations: _translations,
                      format: format,
                      background: background,
                      text: text,
                    ),
                  ),
                ),
              ),
            ),
          ));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '$format $background $text');
          expect(find.byType(DownloadStateOverlay), findsNothing);
          if (format != CardFormat.minimal) {
            final size = tester.getSize(find.byType(LyricsCard));
            expect(size.width / size.height, closeTo(format.width / format.height!, 0.01));
          }
        }
      }
    }
  });

  testWidgets('"Ambas": cada línea con su traducción debajo; sin logo, no hay logo', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        home: LyricsCard(
          track: _track,
          lines: _lines,
          translations: _translations,
          text: CardText.both,
          showLogo: false,
        ),
      ),
    ));
    await tester.pump();
    expect(find.text(_lines.first), findsOneWidget);
    expect(find.text(_translations.first), findsOneWidget);
    expect(find.text('KIJI PLAYER'), findsNothing);
  });
}
