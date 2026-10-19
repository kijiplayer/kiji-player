import 'package:flutter/material.dart';

import '../../../theme/kiji_tokens.dart';
import '../../../utils/byte_formatter.dart';
import '../data/error_reporter.dart';
import '../data/kiji_logs.dart';
import '../data/log_scrubber.dart';
import 'error_report_dialog.dart';

/// Configuración → Registros e informes (Tarea T3): leer el registro (ya sin datos personales),
/// descargar un informe o mandarlo al desarrollador, y borrar el registro.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ReportsScreen()));

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<(String, int)> _data = _load();

  Future<(String, int)> _load() async {
    final text = await KijiLogs.text();
    final size = KijiLogs.enabled ? await (await KijiLogs.file()).sizeBytes() : 0;
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final tail = lines.length > 300 ? lines.sublist(lines.length - 300) : lines;
    return (tail.map(scrubPersonalData).join('\n'), size);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar el registro?'),
        content: const Text('Se borra todo lo guardado. Si el registro está prendido, sigue anotando desde ahora.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Borrar')),
        ],
      ),
    );
    if (ok != true) return;
    await (await KijiLogs.file()).delete();
    if (mounted) setState(() => _data = _load());
  }

  @override
  Widget build(BuildContext context) {
    final recent = ErrorReporter.instance.recent.reversed.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Registros e informes')),
      body: FutureBuilder<(String, int)>(
        future: _data,
        builder: (context, snapshot) {
          final (text, size) = snapshot.data ?? ('', 0);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              Text(
                KijiLogs.enabled
                    ? 'El registro guardado ocupa ${formatBytes(size)}. No tiene tu nombre, tus cuentas, claves '
                        'ni direcciones de internet. Solo sale del dispositivo si tú lo mandas.'
                    : 'El registro guardado está apagado: solo se usa lo de esta sesión, que se borra al cerrar Kiji.',
                style: const TextStyle(color: KijiColors.muted, height: 1.4),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.send_rounded),
                label: const Text('Enviar al desarrollador'),
                onPressed: () => sendReportToDeveloper(context, recent.isEmpty ? null : recent.first),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.download_rounded),
                label: const Text('Descargar informe (.txt)'),
                onPressed: () => downloadReport(context, recent.isEmpty ? null : recent.first),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Borrar el registro'),
                onPressed: _delete,
              ),
              const SizedBox(height: 16),
              Text('ERRORES DE ESTA SESIÓN', style: KijiText.mono(size: 11, color: KijiColors.cyan)),
              const SizedBox(height: 8),
              if (recent.isEmpty)
                const Text('Ninguno. 🎉', style: TextStyle(color: KijiColors.muted))
              else
                for (final r in recent)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.error_outline_rounded),
                    title: Text(r.summary),
                    subtitle: Text('${r.where} · ${TimeOfDay.fromDateTime(r.at).format(context)}'),
                  ),
              const SizedBox(height: 16),
              Text('EL REGISTRO (LO ÚLTIMO, TAL COMO SE MANDA)', style: KijiText.mono(size: 11, color: KijiColors.cyan)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: KijiColors.surface,
                  borderRadius: BorderRadius.circular(KijiRadii.tile),
                ),
                child: SelectableText(
                  text.isEmpty ? 'Vacío.' : text,
                  style: KijiText.mono(size: 10, color: KijiColors.text),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
