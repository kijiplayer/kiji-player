// Rachas (0.9): la tarjeta de Inicio, la pantalla de la racha y el festejo. Datos inventados.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/streaks/streak_widgets.dart';
import 'package:kiji_player/features/streaks/streaks.dart';
import 'package:kiji_player/theme/app_theme.dart';

Future<Directory> _noDisk() async => throw const FileSystemException('sin disco en el test');

class _Streaks extends StreaksNotifier {
  _Streaks(this.initial);
  final StreakData initial;
  @override
  StreakData build() => initial;
}

Widget _app(StreakData data, Widget home) => ProviderScope(
  overrides: [
    settingsProvider.overrideWith(() => SettingsNotifier(directory: _noDisk)),
    streaksProvider.overrideWith(() => _Streaks(data)),
  ],
  child: MaterialApp(theme: AppTheme.darkWith(), home: home),
);

void main() {
  final now = DateTime.now();
  final days = {for (var i = 0; i < 8; i++) dayKey(DateTime(now.year, now.month, now.day - i))};
  final data = StreakData(days: days, best: 12, achievements: {3: dayKey(now), 7: dayKey(now)});

  testWidgets('Tarjeta: días seguidos, mejor racha y la semana; al tocarla, la pantalla con logros', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(data, const Scaffold(body: SingleChildScrollView(child: StreakCard()))));
    await tester.pump();
    expect(find.text('8'), findsOneWidget);
    expect(find.text('Mejor racha: 12 días'), findsOneWidget);
    expect(find.byType(StreakWeek), findsOneWidget);
    await tester.tap(find.byKey(const Key('streak-card')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Tu racha'), findsOneWidget);
    expect(find.text('Logros'), findsOneWidget);
    for (final m in streakMilestones) {
      expect(find.text(m == 1 ? '1 día' : '$m días'), findsWidgets);
    }
    expect(find.byKey(const Key('streak-share')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sin racha, la tarjeta invita a empezar', (tester) async {
    await tester.pumpWidget(_app(const StreakData(), const Scaffold(body: SingleChildScrollView(child: StreakCard()))));
    await tester.pump();
    expect(find.text('Escucha algo hoy y empieza tu racha'), findsOneWidget);
  });

  testWidgets('El festejo aparece y se va solo', (tester) async {
    await tester.pumpWidget(_app(data, Scaffold(
      body: Builder(builder: (context) => TextButton(onPressed: () => showStreakCelebration(context, 7, calm: true), child: const Text('x'))),
    )));
    await tester.tap(find.text('x'));
    await tester.pump();
    expect(find.byKey(const Key('streak-celebration')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.byKey(const Key('streak-celebration')), findsNothing);
  });
}
