import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../data/extractor_health.dart';

/// "Salud del Extractor" (Tarea D): qué forma de pedir el audio a YouTube
/// está funcionando hoy, en palabras simples. Todo se calcula y se guarda en
/// el teléfono.
class ExtractorHealthScreen extends StatefulWidget {
  const ExtractorHealthScreen({super.key, this.health});

  /// Para tests; si es null usa el registro global.
  final ExtractorHealth? health;

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ExtractorHealthScreen()),
      );

  @override
  State<ExtractorHealthScreen> createState() => _ExtractorHealthScreenState();
}

class _ExtractorHealthScreenState extends State<ExtractorHealthScreen> {
  ExtractorHealth get _health => widget.health ?? ExtractorHealth.instance;

  @override
  void initState() {
    super.initState();
    _health.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Salud del Extractor')),
      body: ListenableBuilder(
        listenable: _health,
        builder: (context, _) {
          final all = _health.all;
          final working = [
            for (final entry in all.entries)
              if (entry.value.working) _friendlyName(entry.key),
          ];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                working.isEmpty
                    ? all.values.every((h) => h.neverUsed)
                        ? 'Todavía no se reprodujo nada de YouTube en este teléfono.'
                        : 'Ahora mismo ninguna forma está funcionando. Kiji sigue probando sola '
                            'y, mientras tanto, tus descargas suenan igual.'
                    : 'Hoy YouTube funciona con: ${working.join(', ')}.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Kiji pide el audio a YouTube de varias formas, en orden. Si una deja de '
                'funcionar, prueba la siguiente sin que tengas que hacer nada.',
                style: TextStyle(color: AppColors.onSurfaceMuted),
              ),
              const SizedBox(height: 16),
              for (final entry in all.entries)
                Card(
                  color: AppColors.surfaceContainer,
                  child: ListTile(
                    leading: Icon(
                      entry.value.neverUsed
                          ? Icons.radio_button_unchecked_rounded
                          : entry.value.working
                              ? Icons.check_circle_rounded
                              : Icons.warning_amber_rounded,
                      color: entry.value.neverUsed
                          ? AppColors.onSurfaceMuted
                          : entry.value.working
                              ? Colors.greenAccent
                              : Colors.orangeAccent,
                    ),
                    title: Text(_friendlyName(entry.key)),
                    subtitle: Text(describeHealth(entry.value, DateTime.now())),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

String _friendlyName(String client) => switch (client) {
      'VISIONOS' => 'Forma 1 (VISIONOS)',
      'ANDROID_VR' => 'Forma 2 (ANDROID_VR)',
      'WEB_REMIX' => 'Forma 3, de respaldo (web)',
      _ => client,
    };

/// Estado de un cliente en una frase: "Funcionando (hace 5 min)".
String describeHealth(ClientHealth health, DateTime now) {
  if (health.neverUsed) return 'Sin usar todavía';
  if (health.working) return 'Funcionando (${_ago(health.lastSuccess!, now)})';
  return 'Falló ${_ago(health.lastFailure!, now)}: ${health.lastFailureReason ?? 'sin detalle'}';
}

String _ago(DateTime time, DateTime now) {
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return 'hace un momento';
  if (diff.inHours < 1) return 'hace ${diff.inMinutes} min';
  if (diff.inDays < 1) return 'hace ${diff.inHours} h';
  return 'hace ${diff.inDays} ${diff.inDays == 1 ? 'día' : 'días'}';
}
