import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../providers/local_library_provider.dart';
import '../../../theme/kiji_tokens.dart';
import '../../../widgets/nocturne/glass.dart';
import '../../playlists/playlists_provider.dart';
import '../data/import_parsers.dart';
import '../data/import_service.dart';
import '../../../utils/save_text_file.dart';
import '../data/playlist_export.dart';
import '../domain/import_matcher.dart';
import '../domain/imported.dart';

import 'package:kiji_player/l10n/l10n.dart';

enum _Step { idle, reading, searching, preview, done }

/// Configuración → Copia de seguridad → "Importar desde otra app".
/// Cero Sorpresas: vista previa antes de importar, nunca se sobrescribe ni
/// se borra nada, resumen al final y se puede deshacer la importación entera.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ImportScreen()));

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  _Step _step = _Step.idle;
  String? _fileName;
  String? _error;
  int _done = 0;
  int _total = 0;
  ImportPlan? _plan;
  ImportRecord? _record;

  Future<void> _pickAndRead() async {
    final files = await FilePicker.pickFiles(
      dialogTitle: tx.eligeElArchivoDeLaOtra,
      // "backup" no es un tipo conocido en Android: se acepta cualquiera y se
      // valida al leerlo.
      type: FileType.any,
    );
    if (files.isEmpty || !mounted) return;
    final file = files.first;
    setState(() {
      _step = _Step.reading;
      _fileName = file.name;
      _error = null;
      _plan = null;
      _record = null;
    });
    try {
      final bundle = await parseImportBytes(
        await file.readAsBytes(),
        file.name,
        tempDir: await getTemporaryDirectory(),
        baseDir: file.path == null ? null : _parentOf(file.path!),
      );
      if (bundle.isEmpty) throw ImportFormatException(tx.elArchivoNoTieneCancionesPara);
      if (!mounted) return;
      setState(() => _step = _Step.searching);
      final local = await ref.read(localTracksProvider.future);
      final plan = await prepareImport(
        bundle,
        ImportMatcher(local: local, online: YtMusicLookup()),
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() {
            _done = done;
            _total = total;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _step = _Step.preview;
      });
    } on ImportFormatException catch (error) {
      if (mounted) _fail(error.message);
    } catch (error) {
      debugPrint('=== IMPORTAR: error inesperado: $error ===');
      if (mounted) _fail(tx.noSePudoLeerElArchivo);
    }
  }

  void _fail(String message) => setState(() {
    _step = _Step.idle;
    _error = message;
  });

  String _parentOf(String path) {
    final i = path.replaceAll('\\', '/').lastIndexOf('/');
    return i <= 0 ? path : path.substring(0, i);
  }

  void _apply() {
    final plan = _plan;
    if (plan == null) return;
    final record = ref.read(importsProvider.notifier).apply(plan);
    setState(() {
      _record = record;
      _step = _Step.done;
    });
  }

  void _undo(ImportRecord record) {
    ref.read(importsProvider.notifier).undo(record);
    if (_record?.id == record.id) setState(() => _step = _Step.idle);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tx.importacionDeshechaSeQuitoTodoLo)));
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(importsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tx.importarYExportar)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Text(tx.traeTusPlaylistsMeGustaE, style: const TextStyle(color: KijiColors.muted)),
          const SizedBox(height: 16),
          ..._stepWidgets(),
          if (history.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(tx.importacionesAnteriores, style: KijiText.mono(size: 11)),
            for (final record in history)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(record.source),
                subtitle: Text(
                  tx.playlistsSinEncontrar(_date(record.date), record.playlistIds.length, record.missing.length),
                  style: const TextStyle(color: KijiColors.muted),
                ),
                trailing: TextButton(onPressed: () => _confirmUndo(record), child: Text(tx.deshacer)),
              ),
          ],
          const SizedBox(height: 28),
          const _ExportSection(),
        ],
      ),
    );
  }

  List<Widget> _stepWidgets() {
    switch (_step) {
      case _Step.idle:
        return [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
            ),
          FilledButton.icon(
            onPressed: _pickAndRead,
            icon: const Icon(Icons.file_open_outlined),
            label: Text(tx.elegirArchivo),
          ),
        ];
      case _Step.reading:
        return [Text(tx.leyendo(_fileName)), const SizedBox(height: 8), const LinearProgressIndicator()];
      case _Step.searching:
        return [
          Text(tx.buscandoLasCancionesEnKijiDe(_done, _total)),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: _total == 0 ? null : _done / _total),
        ];
      case _Step.preview:
        final plan = _plan!;
        return [
          GradientBorder(
            fill: KijiColors.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.vistaPrevia(plan.bundle.source.toUpperCase()), style: KijiText.mono(size: 10)),
                  const SizedBox(height: 8),
                  Text(previewText(plan), style: KijiText.title(size: 17, weight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  for (final pl in plan.bundle.playlists.take(8))
                    Text(
                      '• ${pl.name} (${pl.songs.where((s) => plan.resolved.containsKey(s.key)).length})',
                      style: const TextStyle(color: KijiColors.muted),
                    ),
                  if (plan.bundle.playlists.length > 8)
                    Text(tx.yMas(plan.bundle.playlists.length - 8), style: const TextStyle(color: KijiColors.muted)),
                  const SizedBox(height: 8),
                  Text(tx.siYaTienesUnaPlaylistCon, style: const TextStyle(color: KijiColors.muted, fontSize: 12)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    children: [
                      FilledButton(onPressed: plan.isEmpty ? null : _apply, child: Text(tx.importar2)),
                      TextButton(onPressed: () => setState(() => _step = _Step.idle), child: Text(tx.cancelar)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ];
      case _Step.done:
        final record = _record!;
        return [
          Glass(
            blur: false,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.listo, style: KijiText.title(size: 20)),
                const SizedBox(height: 6),
                Text(
                  tx.playlistsCreadasMeGustaYCanciones(
                    record.playlistIds.length,
                    record.likedIds.length,
                    record.historyIds.length,
                  ),
                ),
                if (record.missing.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(tx.sinEncontrar(record.missing.length)),
                    children: [
                      for (final m in record.missing)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('• $m', style: const TextStyle(color: KijiColors.muted)),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _confirmUndo(record),
                  icon: const Icon(Icons.undo_rounded),
                  label: Text(tx.deshacerLaImportacion),
                ),
              ],
            ),
          ),
        ];
    }
  }

  Future<void> _confirmUndo(ImportRecord record) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tx.deshacerLaImportacion2),
        content: Text(tx.seQuitanLasPlaylistsMeGusta),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tx.cancelar)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tx.deshacer)),
        ],
      ),
    );
    if (ok == true) _undo(record);
  }

  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Exportar las playlists de Kiji a .m3u8 y .csv.
class _ExportSection extends ConsumerWidget {
  const _ExportSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tx.exportarTusPlaylists, style: KijiText.mono(size: 11)),
        if (playlists.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(tx.todaviaNoTienesPlaylists, style: const TextStyle(color: KijiColors.muted)),
          ),
        for (final playlist in playlists)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(playlist.name),
            subtitle: Text(tx.nCanciones(playlist.tracks.length), style: const TextStyle(color: KijiColors.muted)),
            trailing: Wrap(
              spacing: 4,
              children: [
                TextButton(
                  onPressed: () => saveTextFile(context, exportFileName(playlist.name, 'm3u8'), exportM3u8(playlist)),
                  child: const Text('.m3u8'),
                ),
                TextButton(
                  onPressed: () => saveTextFile(context, exportFileName(playlist.name, 'csv'), exportCsv(playlist)),
                  child: const Text('.csv'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
