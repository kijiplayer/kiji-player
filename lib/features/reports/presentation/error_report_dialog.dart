import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../utils/save_text_file.dart';
import '../../../l10n/l10n.dart';
import '../data/error_report.dart';
import '../data/kiji_logs.dart';

/// Abre GitHub con el informe ya escrito; el usuario lo revisa allá y decide si lo manda.
Future<void> sendReportToDeveloper(BuildContext context, ErrorReport? report) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = githubIssueUri(report, log: await KijiLogs.text());
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok) messenger.showSnackBar(SnackBar(content: Text(tx.noSePudoAbrirElNavegador)));
}

/// Guarda el informe en un .txt donde el usuario elija.
Future<void> downloadReport(BuildContext context, ErrorReport? report) async {
  final text = buildReportText(report, log: await KijiLogs.text(), logLines: 400);
  final stamp = DateTime.now().toIso8601String().substring(0, 16).replaceAll(':', '-');
  if (!context.mounted) return;
  await saveTextFile(context, 'informe-kiji-$stamp.txt', text, dialogTitle: tx.guardarInforme);
}

/// "Algo falló": las tres opciones de la Tarea T3. Nunca se manda nada sin que el usuario elija.
Future<void> showErrorReportDialog(BuildContext context, ErrorReport report) {
  final t = tr(context);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.bug_report_outlined),
      title: Text(t.errorReportTitle),
      content: Text(t.errorReportBody(report.summary)),
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: 4,
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(t.errorReportNoThanks)),
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            downloadReport(context, report);
          },
          child: Text(t.errorReportDownload),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            sendReportToDeveloper(context, report);
          },
          child: Text(t.errorReportSend),
        ),
      ],
    ),
  );
}
