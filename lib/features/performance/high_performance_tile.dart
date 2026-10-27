import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../settings/data/settings_store.dart';
import 'device_performance.dart';

/// Configuración → Apariencia → Modo alto rendimiento. En un equipo de gama baja lo dice y pide
/// confirmar antes de prenderlo.
class HighPerformanceTile extends ConsumerWidget {
  const HighPerformanceTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(settingsProvider.select((s) => s.highPerformance));
    final device = ref.watch(deviceInfoProvider).value;
    final lowEnd = device?.lowEnd ?? false;
    final hz = device?.maxRefresh.round() ?? 60;
    return SwitchListTile(
      secondary: const Icon(Icons.speed_rounded),
      title: Text(tx.modoAltoRendimiento),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tx.modoAltoRendimientoDescripcion),
          if (hz > 60) Text(tx.modoAltoRendimientoPantalla(hz)),
          if (lowEnd)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                tx.modoAltoRendimientoGamaBaja,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      value: on,
      onChanged: (value) async {
        if (value && lowEnd) {
          final sure = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(tx.modoAltoRendimientoConfirmar),
              content: Text(tx.modoAltoRendimientoConfirmarTexto),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tx.cancelar)),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tx.prenderIgual)),
              ],
            ),
          );
          if (sure != true) return;
        }
        await ref.read(settingsProvider.notifier).update((s) => s.copyWith(highPerformance: value));
      },
    );
  }
}
