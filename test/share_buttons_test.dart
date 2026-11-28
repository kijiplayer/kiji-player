// Compartir en la 0.9: cada botón dibuja la imagen y abre el panel de compartir; en la PC sin
// panel, la guarda y avisa dónde. Datos inventados; el panel es de mentira.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/quotes/quote_card.dart';
import 'package:kiji_player/features/quotes/quotes.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/share_cards/now_playing_card.dart';
import 'package:kiji_player/features/streaks/streak_widgets.dart';
import 'package:kiji_player/features/streaks/streaks.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/theme/app_theme.dart';
import 'package:kiji_player/utils/share_image.dart';
import 'package:share_plus/share_plus.dart';

Future<Directory> _noDisk() async => throw const FileSystemException('sin disco en el test');

const _track = Track(
  id: 'yt-inventado01',
  title: 'Glass Harbor',
  artist: 'The Velvet Tides',
  coverColor: Color(0xFF7C5CFF),
  audioUrl: '',
  source: TrackSource.youtube,
);

class _Streaks extends StreaksNotifier {
  @override
  StreakData build() {
    final now = DateTime.now();
    return StreakData(
      days: {for (var i = 0; i < 8; i++) dayKey(DateTime(now.year, now.month, now.day - i))},
      best: 8,
      achievements: {3: dayKey(now), 7: dayKey(now)},
    );
  }
}

Widget _app(Widget home) => ProviderScope(
  overrides: [
    settingsProvider.overrideWith(() => SettingsNotifier(directory: _noDisk)),
    streaksProvider.overrideWith(_Streaks.new),
    currentQuoteProvider.overrideWithValue(
      const Quote(id: 'inventada', author: 'Autora Inventada', source: 'Libro Inventado', es: 'Una frase.', en: 'A quote.'),
    ),
  ],
  child: MaterialApp(theme: AppTheme.darkWith(), home: home),
);

void main() {
  late List<ShareParams> shared;
  final temp = Directory.systemTemp.createTempSync('kiji_compartir');
  setUp(() {
    shared = [];
    KijiShare.tempFolder = () async => temp;
    KijiShare.share = (params) async {
      shared.add(params);
      return const ShareResult('ok', ShareResultStatus.success);
    };
    KijiShare.isDesktop = () => false;
  });
  tearDown(() {
    KijiShare.share = SharePlus.instance.share;
    KijiShare.isDesktop = () => Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  });

  /// Toca el botón y espera a que la imagen se dibuje y llegue al panel.
  Future<void> tapAndShare(WidgetTester tester, Finder button) async {
    await tester.runAsync(() async {
      await tester.tap(button);
      for (var i = 0; i < 100 && shared.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await tester.pump();
      }
    });
    await tester.pump();
    expect(shared, hasLength(1), reason: 'el panel de compartir se abrió');
    final file = File(shared.single.files!.single.path);
    expect(file.existsSync() && file.lengthSync() > 1000, isTrue, reason: 'con la imagen dibujada');
  }

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
  }

  testWidgets('Racha: «Compartir tu racha» abre la vista previa y el panel', (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(_app(const StreakScreen()));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('streak-share')));
    await tester.tap(find.byKey(const Key('streak-share')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tapAndShare(tester, find.byKey(const Key('streak-share-image')));
  });

  testWidgets('Logro: tocar un logro ganado lo comparte; uno sin ganar, no', (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(_app(const StreakScreen()));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('streak-badge-30')));
    await tester.tap(find.byKey(const Key('streak-badge-30')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(StreakShareScreen), findsNothing, reason: 'el de 30 días no se ganó');
    await tester.ensureVisible(find.byKey(const Key('streak-badge-7')));
    await tester.tap(find.byKey(const Key('streak-badge-7')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(StreakShareScreen), findsOneWidget);
    await tapAndShare(tester, find.byKey(const Key('streak-share-image')));
  });

  testWidgets('Tarjeta de canción: «Compartir imagen» abre el panel', (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(_app(Builder(
      builder: (context) => Scaffold(
        body: Center(child: TextButton(onPressed: () => showShareCardScreen(context, _track), child: const Text('abrir'))),
      ),
    )));
    await tester.tap(find.text('abrir'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final button = find.widgetWithText(FilledButton, 'Compartir imagen');
    await tester.ensureVisible(button);
    await tapAndShare(tester, button);
  });

  testWidgets('Frase del día: compartir abre la vista previa y el panel', (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(_app(const Scaffold(body: SingleChildScrollView(child: DailyQuoteCard()))));
    await tester.pump();
    await tester.tap(find.byTooltip('Compartir la frase'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tapAndShare(tester, find.byKey(const Key('quote-share')));
  });

  testWidgets('PC sin panel: la imagen se guarda y se avisa dónde', (tester) async {
    final folder = Directory.systemTemp.createTempSync('kiji_guardadas');
    addTearDown(() => folder.deleteSync(recursive: true));
    KijiShare.isDesktop = () => true;
    KijiShare.share = (params) async => throw UnimplementedError('sin panel');
    KijiShare.savedFolder = () async => folder;
    final image = File('${folder.path}/fuente.png')..writeAsBytesSync(List.filled(2000, 7));
    await tester.pumpWidget(_app(Builder(
      builder: (context) => Scaffold(
        body: TextButton(onPressed: () => KijiShare.shareImage(context, image, name: 'kiji-racha'), child: const Text('x')),
      ),
    )));
    await tester.runAsync(() async {
      await tester.tap(find.text('x'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    final saved = folder.listSync().whereType<File>().where((f) => f.path.contains('kiji-racha-')).toList();
    expect(saved, hasLength(1));
    expect(find.textContaining('Imagen guardada en'), findsOneWidget);
    expect(find.text('Abrir carpeta'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('Si la imagen no se pudo preparar, se avisa (antes no pasaba nada)', (tester) async {
    await tester.pumpWidget(_app(Builder(
      builder: (context) => Scaffold(
        body: TextButton(onPressed: () => KijiShare.shareImage(context, null, name: 'kiji-racha'), child: const Text('x')),
      ),
    )));
    await tester.tap(find.text('x'));
    await tester.pump();
    expect(find.text('No se pudo preparar la imagen. Prueba de nuevo.'), findsOneWidget);
    expect(shared, isEmpty);
    await tester.pump(const Duration(seconds: 10));
  });
}
