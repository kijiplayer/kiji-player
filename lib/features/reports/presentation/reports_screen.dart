import 'package:flutter/material.dart';

import '../../../theme/kiji_tokens.dart';
import '../../../utils/byte_formatter.dart';
import '../data/error_reporter.dart';
import '../data/kiji_logs.dart';
import '../data/log_scrubber.dart';
import 'error_report_dialog.dart';

import 'package:kiji_player/l10n/l10n.dart';

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
        title: Text(tx.borrarElRegistro),
        content: Text(tx.seBorraTodoLoGuardadoSi),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tx.cancelar)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tx.borrar)),
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
      appBar: AppBar(title: Text(tx.registrosEInformes)),
      body: FutureBuilder<(String, int)>(
        future: _data,
        builder: (context, snapshot) {
          final (text, size) = snapshot.data ?? ('', 0);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              Text(
                KijiLogs.enabled
                    ? tx.elRegistroGuardadoOcupa(formatBytes(size))
                    : tx.elRegistroGuardadoEstaApagadoSolo,
                style: const TextStyle(color: KijiColors.muted, height: 1.4),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.send_rounded),
                label: Text(tx.errorReportSend),
                onPressed: () => sendReportToDeveloper(context, recent.isEmpty ? null : recent.first),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.download_rounded),
                label: Text(tx.errorReportDownload),
                onPressed: () => downloadReport(context, recent.isEmpty ? null : recent.first),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(tx.borrarElRegistro2),
                onPressed: _delete,
              ),
              const SizedBox(height: 16),
              Text(tx.erroresDeEstaSesion, style: KijiText.mono(size: 11, color: KijiColors.cyan)),
              const SizedBox(height: 8),
              if (recent.isEmpty)
                Text(tx.ninguno, style: const TextStyle(color: KijiColors.muted))
              else
                for (final r in recent)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.error_outline_rounded),
                    title: Text(r.summary),
                    subtitle: Text('${r.where} · ${TimeOfDay.fromDateTime(r.at).format(context)}'),
                  ),
              const SizedBox(height: 16),
              Text(tx.elRegistroLoUltimoTalComo, style: KijiText.mono(size: 11, color: KijiColors.cyan)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: KijiColors.surface,
                  borderRadius: BorderRadius.circular(KijiRadii.tile),
                ),
                child: SelectableText(
                  text.isEmpty ? tx.vacio : text,
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
