import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/performance/device_performance.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/theme/kiji_tokens.dart';
import 'package:kiji_player/widgets/nocturne/aurora_background.dart';
import 'package:kiji_player/widgets/nocturne/micro_motion.dart';

void main() {
  tearDown(() {
    KijiEffects.rich = false;
    KijiEffects.calm = false;
  });

  Widget app(Widget child, {bool disableAnimations = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: child),
    ),
  );

  testWidgets('La aurora se mueve mientras suena y queda quieta en pausa', (tester) async {
    const colors = [Colors.red, Colors.blue];
    await tester.pumpWidget(app(const AuroraBackground(colors: colors)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(app(const AuroraBackground(colors: colors, moving: false)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('Al cambiar de canción, la aurora pasa a los colores nuevos y se detiene si está quieta', (tester) async {
    await tester.pumpWidget(app(const AuroraBackground(colors: [Colors.red], moving: false)));
    await tester.pumpWidget(app(const AuroraBackground(colors: [Colors.green], moving: false)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue, reason: 'mezcla los colores');
    await tester.pump(const Duration(seconds: 2));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('Con "Reducir animaciones" (de Kiji o del sistema) la aurora no se mueve', (tester) async {
    await tester.pumpWidget(app(const AuroraBackground(colors: [Colors.red]), disableAnimations: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isFalse);

    KijiEffects.calm = true;
    await tester.pumpWidget(app(const AuroraBackground(colors: [Colors.red], key: ValueKey('otra'))));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isFalse);
  });

  test('La aurora se dibuja chica y se estira (más grande en alto rendimiento)', () {
    expect(AuroraBackground.renderWidth(rich: false), lessThan(AuroraBackground.renderWidth(rich: true)));
    expect(AuroraBackground.renderWidth(rich: true), lessThanOrEqualTo(256));
  });

  testWidgets('La aurora dibuja en modo normal y en alto rendimiento sin errores', (tester) async {
    await tester.pumpWidget(app(const AuroraBackground(colors: [Colors.red, Colors.teal], moving: false)));
    expect(find.byType(AuroraBackground), findsOneWidget);
    KijiEffects.rich = true;
    await tester.pumpWidget(app(const AuroraBackground(colors: [Colors.red], key: ValueKey('rica'))));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  });

  testWidgets('El corazón late al marcar "me gusta" (y no al quitarlo)', (tester) async {
    await tester.pumpWidget(app(const LikeHeart(liked: false)));
    await tester.pumpWidget(app(const LikeHeart(liked: true)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

    await tester.pumpWidget(app(const LikeHeart(liked: false)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
  });

  testWidgets('El "pop" de un ícono no anima con "Reducir animaciones"', (tester) async {
    Widget pop(bool on) => PopSwitcher(child: Icon(on ? Icons.repeat_one : Icons.repeat, key: ValueKey(on)));
    await tester.pumpWidget(app(pop(false)));
    await tester.pumpWidget(app(pop(true)));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(Icon), findsNWidgets(2), reason: 'el viejo se va mientras entra el nuevo');
    await tester.pumpAndSettle();

    KijiEffects.calm = true;
    await tester.pumpWidget(app(pop(false)));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(Icon), findsOneWidget);
  });

  test('Modo alto rendimiento: apagado de fábrica y se guarda', () {
    expect(const AppSettings().highPerformance, isFalse);
    final back = AppSettings.fromJson(const AppSettings(highPerformance: true).toJson());
    expect(back.highPerformance, isTrue);
    expect(AppSettings.fromJson({'highPerformance': 'sí'}).highPerformance, isFalse);
  });

  test('Gama baja: Android lo marca, menos de 4 GB o 4 núcleos o menos', () {
    const gb = 1024 * 1024 * 1024;
    expect(const DeviceInfo(totalRamBytes: 8 * gb, cores: 8).lowEnd, isFalse);
    expect(const DeviceInfo(totalRamBytes: 3 * gb, cores: 8).lowEnd, isTrue);
    expect(const DeviceInfo(totalRamBytes: 8 * gb, cores: 4).lowEnd, isTrue);
    expect(const DeviceInfo(lowRam: true, totalRamBytes: 8 * gb, cores: 8).lowEnd, isTrue);
    expect(const DeviceInfo(cores: 16).lowEnd, isFalse, reason: 'sin saber la RAM, solo cuentan los núcleos');
  });
}
