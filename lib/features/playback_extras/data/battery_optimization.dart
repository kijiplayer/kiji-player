import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../settings/data/settings_store.dart';

/// Optimización de batería de Android (canal `kiji/battery` en `KijiChannels.kt`). Con ella,
/// Android puede frenar a Kiji con la pantalla apagada y la música se corta. Kiji lo explica y
/// abre el pedido del sistema; nunca lo cambia sola. En la PC no existe.
class BatteryOptimization {
  static const _channel = MethodChannel('kiji/battery');

  static bool get applies => !kIsWeb && Platform.isAndroid;

  /// true si Android ya no frena a Kiji (o si no aplica).
  static Future<bool> isIgnoring() async {
    if (!applies) return true;
    try {
      return await _channel.invokeMethod<bool>('isIgnoring') ?? true;
    } catch (error) {
      debugPrint('=== BATERIA: no se pudo consultar: $error ===');
      return true;
    }
  }

  /// Abre el diálogo del sistema.
  static Future<void> request() async {
    try {
      await _channel.invokeMethod<void>('request');
    } catch (error) {
      debugPrint('=== BATERIA: no se pudo abrir el pedido: $error ===');
    }
  }
}

/// La primera vez que suena música, si Android puede frenar a Kiji, explica por qué conviene
/// permitirlo. Se pregunta una sola vez; después queda en Configuración → Reproductor y audio.
Future<void> offerBatteryExemptionOnce(BuildContext context, WidgetRef ref) async {
  if (!BatteryOptimization.applies || ref.read(settingsProvider).batteryAsked) return;
  await ref.read(settingsProvider.notifier).update((s) => s.copyWith(batteryAsked: true));
  if (await BatteryOptimization.isIgnoring() || !context.mounted) return;
  final allow = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.battery_saver_rounded),
      title: Text(tx.bateriaTitulo),
      content: Text(tx.bateriaExplicacion),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tx.ahoraNo)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tx.bateriaPermitir)),
      ],
    ),
  );
  debugPrint('=== BATERIA: aviso mostrado, ${allow == true ? 'acepta' : 'ahora no'} ===');
  if (allow == true) await BatteryOptimization.request();
}

/// Configuración → Reproductor y audio: estado actual y acceso al pedido del sistema.
class BatteryOptimizationTile extends StatefulWidget {
  const BatteryOptimizationTile({super.key});

  @override
  State<BatteryOptimizationTile> createState() => _BatteryOptimizationTileState();
}

class _BatteryOptimizationTileState extends State<BatteryOptimizationTile> {
  bool? _ignoring;
  // Al volver del diálogo del sistema, se vuelve a mirar.
  late final _lifecycle = AppLifecycleListener(onResume: _check);

  @override
  void initState() {
    super.initState();
    _lifecycle;
    _check();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final ignoring = await BatteryOptimization.isIgnoring();
    if (mounted) setState(() => _ignoring = ignoring);
  }

  @override
  Widget build(BuildContext context) {
    final ignoring = _ignoring ?? true;
    return ListTile(
      leading: Icon(ignoring ? Icons.battery_full_rounded : Icons.battery_saver_rounded),
      title: Text(tx.bateriaTitulo),
      subtitle: Text(ignoring ? tx.bateriaActiva : tx.bateriaPendiente),
      trailing: ignoring ? const Icon(Icons.check_rounded) : null,
      onTap: ignoring ? null : BatteryOptimization.request,
    );
  }
}
