// «Liquid Glass real» (0.9): opcional, apagado de fábrica, y solo si el equipo puede.
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/widgets/nocturne/liquid_glass_pro.dart';

void main() {
  tearDown(() {
    LiquidGlassPro.debugSetBlock(null);
    LiquidGlassPro.active.value = false;
  });

  test('Apagado de fábrica', () {
    expect(const AppSettings().liquidGlassPro, isFalse);
  });

  test('Si el teléfono no puede (sin shaders o de 32 bits), no se prende', () {
    for (final block in [LiquidGlassProBlock.noShaders, LiquidGlassProBlock.arm32]) {
      LiquidGlassPro.debugSetBlock(block);
      LiquidGlassPro.setOn(true);
      expect(LiquidGlassPro.active.value, isFalse, reason: '$block');
    }
  });

  test('Prendido en un equipo que puede; apagado vuelve al vidrio de siempre', () {
    LiquidGlassPro.debugSetBlock(LiquidGlassProBlock.none);
    LiquidGlassPro.setOn(true);
    expect(LiquidGlassPro.active.value, isTrue);
    LiquidGlassPro.setOn(false);
    expect(LiquidGlassPro.active.value, isFalse);
  });

  test('Se guarda en los ajustes', () {
    final json = const AppSettings(liquidGlassPro: true).toJson();
    expect(AppSettings.fromJson(json).liquidGlassPro, isTrue);
  });
}
