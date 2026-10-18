import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/kiji_tokens.dart';
import '../../extractor/data/extractor_tester.dart';
import '../../extractor/data/path_health.dart';
import '../../extractor/domain/resolved_stream.dart';
import '../data/yt_clients.dart';
import 'collection_screens.dart';

/// "Hace 5 min", "hace 3 h", "hace 2 días".
String agoShort(DateTime? when, DateTime now) {
  if (when == null) return 'nunca';
  final d = now.difference(when);
  if (d.inMinutes < 1) return 'recién';
  if (d.inHours < 1) return 'hace ${d.inMinutes} min';
  if (d.inDays < 1) return 'hace ${d.inHours} h';
  return 'hace ${d.inDays} ${d.inDays == 1 ? 'día' : 'días'}';
}

/// Salud del Extractor 2.0 (Tarea Z8): resumen simple arriba, caminos agrupados por motor, las
/// formas retiradas aparte. Las pruebas usan canciones de CONTROL fijas, nunca tu historial.
class ExtractorHealthScreen extends ConsumerStatefulWidget {
  const ExtractorHealthScreen({super.key, this.health, this.tester});

  /// Para tests; si son null usa los globales.
  final PathHealth? health;
  final ExtractorTester? tester;

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ExtractorHealthScreen()));

  @override
  ConsumerState<ExtractorHealthScreen> createState() => _ExtractorHealthScreenState();
}

class _ExtractorHealthScreenState extends ConsumerState<ExtractorHealthScreen> {
  PathHealth get _health => widget.health ?? PathHealth.instance;
  final List<PathTestResult> _results = [];
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _health.load();
  }

  Future<void> _runAll() async {
    setState(() {
      _running = true;
      _results.clear();
    });
    final tester = widget.tester ?? ExtractorTester(client: ref.read(ytMusicClientProvider), health: _health);
    try {
      await tester.runAll(onResult: (r) {
        if (mounted) setState(() => _results.add(r));
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Salud del Extractor')),
      body: ListenableBuilder(
        listenable: _health,
        builder: (context, _) {
          final now = DateTime.now();
          final all = _health.all;
          final working = all.entries.where((e) => e.value.working).length;
          final summary = _results.isNotEmpty
              ? healthSummary(_results)
              : working == 0
                  ? (all.isEmpty ? 'Todavía no se probó.' : 'Canciones normales: ✗ ninguna forma funciona ahora')
                  : 'Canciones normales: ✓ $working ${working == 1 ? 'forma funcionando' : 'formas funcionando'}';
          final aPaths = all.keys.where((k) => k.startsWith('A/')).toList()..sort();
          final bForms = [for (final c in ytPlayerClients) if (!c.isRetired) c.label];
          final retired = [for (final c in ytPlayerClients) if (c.isRetired) c];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Text(summary, style: KijiText.title(size: 18)),
              const SizedBox(height: 4),
              const Text(ageSummary, style: TextStyle(color: KijiColors.muted)),
              const SizedBox(height: 4),
              Text(
                'Última prueba automática: ${agoShort(_health.lastTestAt, now)}. Se prueba con '
                '${controlVideos.length} canciones de control, nunca con tu historial; la prueba pide '
                'el último byte del audio para descubrir las formas que cortan al minuto.',
                style: const TextStyle(color: KijiColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _running ? null : _runAll,
                icon: _running
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.play_circle_outline_rounded),
                label: Text(_running ? 'Probando…' : 'Probar todas las formas ahora'),
              ),
              if (aPaths.isNotEmpty || _results.any((r) => r.path.startsWith('A/'))) ...[
                _EngineHeader(EngineId.a),
                for (final path in {...aPaths, for (final r in _results) if (r.path.startsWith('A/')) r.path})
                  _PathTile(path: path, record: all[path], result: _resultFor(path), now: now),
              ],
              _EngineHeader(EngineId.b),
              for (final form in _health.order('B', bForms))
                _PathTile(
                  path: 'B/$form',
                  record: all['B/$form'],
                  result: _resultFor('B/$form'),
                  note: clientByLabel(form)?.note,
                  now: now,
                ),
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('Formas retiradas (YouTube ya no las permite) · ${retired.length}'),
                children: [
                  for (final c in retired)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.block_rounded, color: KijiColors.muted),
                      title: Text(c.label),
                      subtitle: Text(c.retired!),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  PathTestResult? _resultFor(String path) {
    for (final r in _results) {
      if (r.path == path) return r;
    }
    return null;
  }
}

class _EngineHeader extends StatelessWidget {
  const _EngineHeader(this.engine);
  final EngineId engine;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 4),
        child: Text(engine.label.toUpperCase(), style: KijiText.mono(size: 11)),
      );
}

class _PathTile extends StatelessWidget {
  const _PathTile({required this.path, required this.record, required this.now, this.result, this.note});

  final String path;
  final PathRecord? record;
  final PathTestResult? result;
  final String? note;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final ok = result?.ok ?? record?.working;
    final color = ok == null ? KijiColors.muted : (ok ? Colors.greenAccent : Colors.orangeAccent);
    final lines = <String>[
      if (result != null)
        result!.ok
            ? 'Anduvo con ${result!.control} (${result!.elapsed.inMilliseconds} ms)'
            : 'Falló con ${result!.control}: ${result!.reason}'
      else if (record == null)
        'Sin probar todavía'
      else ...[
        'Última vez que anduvo: ${agoShort(record!.lastOk, now)}',
        if (record!.lastFail != null && (record!.lastOk == null || record!.lastFail!.isAfter(record!.lastOk!)))
          'Último problema: ${record!.lastReason}',
      ],
      ?note,
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.circle, size: 12, color: color),
      title: Text(path.substring(2)),
      subtitle: Text(lines.join('\n')),
    );
  }
}
