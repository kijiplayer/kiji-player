// El interruptor de «Modo alto rendimiento» aparece para los lectores de pantalla: con su nombre,
// su estado (prendido/apagado) y que se puede tocar.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/performance/device_performance.dart';
import 'package:kiji_player/features/performance/high_performance_tile.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/l10n/l10n.dart';

class _Settings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings(highPerformance: true);
  @override
  Future<void> update(AppSettings Function(AppSettings) change) async => state = change(state);
}

void main() {
  testWidgets('Alto rendimiento: lo ve un lector de pantalla', (tester) async {
    setKijiLocale(const Locale('en'));
    addTearDown(() => setKijiLocale(const Locale('es')));
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_Settings.new),
          deviceInfoProvider.overrideWith((ref) async => const DeviceInfo(maxRefresh: 120, cores: 8, totalRamBytes: 8000000000)),
        ],
        child: MaterialApp(home: Scaffold(body: ListView(children: const [HighPerformanceTile()]))),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp('High performance mode')),
      findsOneWidget,
    );
    final node = tester.getSemantics(find.bySemanticsLabel(RegExp("High performance mode")));
    final data = node.getSemanticsData();
    expect(data.toString(), contains('isToggled'), reason: 'se lee "prendido"');
    expect(data.toString(), contains('hasToggledState'));
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });
}
