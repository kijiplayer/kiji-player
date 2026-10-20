import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/kiji_tokens.dart';
import '../../extractor/data/extractor_tester.dart';
import '../../extractor/data/path_health.dart';
import '../../extractor/data/ytdlp_engine.dart';
import '../../settings/data/settings_store.dart';
import '../../extractor/domain/resolved_stream.dart';
import '../data/yt_clients.dart';
import 'collection_screens.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// "Hace 5 min", "hace 3 h", "hace 2 días".
String agoShort(DateTime? when, DateTime now) {
  if (when == null) return 'nunca';
  final d = now.difference(when);
  if (d.inMinutes < 1) return tx.recien;
  if (d.inHours < 1) return tx.haceMin(d.inMinutes);
  if (d.inDays < 1) return tx.haceH(d.inHours);
  return tx.haceNDias(d.inDays);
}

/// Salud del Extractor 2.0: resumen simple arriba, caminos agrupados por motor, las
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
      await tester.runAll(
        onResult: (r) {
          if (mounted) setState(() => _results.add(r));
        },
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tx.saludDelExtractor)),
      body: ListenableBuilder(
        listenable: _health,
        builder: (context, _) {
          final now = DateTime.now();
          final all = _health.all;
          final working = all.entries.where((e) => e.value.working).length;
          final summary = _results.isNotEmpty
              ? healthSummary(_results)
              : working == 0
              ? (all.isEmpty ? tx.todaviaNoSeProbo : tx.cancionesNormalesNingunaFormaFuncionaAho)
              : tx.cancionesNormalesFormas(working);
          final aPaths = all.keys.where((k) => k.startsWith('A/')).toList()..sort();
          final bForms = [
            for (final c in ytPlayerClients)
              if (!c.isRetired) c.label,
          ];
          final retired = [
            for (final c in ytPlayerClients)
              if (c.isRetired) c,
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Text(summary, style: KijiText.title(size: 18)),
              const SizedBox(height: 4),
              Text(ageSummary, style: const TextStyle(color: KijiColors.muted)),
              const SizedBox(height: 4),
              Text(
                tx.ultimaPruebaAutomaticaSePruebaCon(agoShort(_health.lastTestAt, now), controlVideos.length),
                style: const TextStyle(color: KijiColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _running ? null : _runAll,
                icon: _running
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.play_circle_outline_rounded),
                label: Text(_running ? tx.probando : tx.probarTodasLasFormasAhora),
              ),
              if (aPaths.isNotEmpty || _results.any((r) => r.path.startsWith('A/'))) ...[
                const _EngineHeader(EngineId.a),
                for (final path in {
                  ...aPaths,
                  for (final r in _results)
                    if (r.path.startsWith('A/')) r.path,
                })
                  _PathTile(path: path, record: all[path], result: _resultFor(path), now: now),
              ],
              const _EngineHeader(EngineId.b),
              for (final form in _health.order('B', bForms))
                _PathTile(
                  path: 'B/$form',
                  record: all['B/$form'],
                  result: _resultFor('B/$form'),
                  note: clientByLabel(form)?.note,
                  now: now,
                ),
              if (YtDlpEngine.platformSupported) const _YtDlpCard(),
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(tx.formasRetiradasYoutubeYaNoLas(retired.length)),
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
            ? tx.anduvoCon(result!.control, result!.elapsed.inMilliseconds)
            : tx.falloCon(result!.control, result!.reason)
      else if (record == null)
        tx.sinProbarTodavia
      else ...[
        tx.ultimaVezQueAnduvo(agoShort(record!.lastOk, now)),
        if (record!.lastFail != null && (record!.lastOk == null || record!.lastFail!.isAfter(record!.lastOk!)))
          tx.ultimoProblema(record!.lastReason),
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

/// Motor C en la PC: yt-dlp, opcional y solo si se acepta.
class _YtDlpCard extends ConsumerStatefulWidget {
  const _YtDlpCard();

  @override
  ConsumerState<_YtDlpCard> createState() => _YtDlpCardState();
}

class _YtDlpCardState extends ConsumerState<_YtDlpCard> {
  bool? _installed;
  double? _progress;
  String? _message;

  @override
  void initState() {
    super.initState();
    ref.read(ytDlpEngineProvider).installed().then((v) {
      if (mounted) setState(() => _installed = v);
    });
  }

  Future<void> _install() async {
    final engine = ref.read(ytDlpEngineProvider);
    setState(() {
      _progress = 0;
      _message = null;
    });
    try {
      await engine.install(
        onProgress: (done, total) {
          if (mounted && total > 0) setState(() => _progress = done / total);
        },
      );
      await ref.read(settingsProvider.notifier).update((s) => s.copyWith(ytDlpAccepted: true));
      setState(() {
        _installed = true;
        _message = tx.ytDlpListo;
      });
    } catch (error) {
      setState(() => _message = tx.noSePudoInstalar(error));
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accepted = ref.watch(settingsProvider).ytDlpAccepted;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(EngineId.c.label.toUpperCase(), style: KijiText.mono(size: 11)),
          const SizedBox(height: 6),
          Text(tx.opcionalYSoloEnLaPc, style: const TextStyle(color: KijiColors.muted, fontSize: 13)),
          const SizedBox(height: 8),
          if (_progress != null)
            LinearProgressIndicator(value: _progress)
          else if (_installed == true && accepted)
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text(tx.instalado)),
                TextButton(
                  onPressed: () async {
                    await ref.read(ytDlpEngineProvider).remove();
                    await ref.read(settingsProvider.notifier).update((s) => s.copyWith(ytDlpAccepted: false));
                    setState(() => _installed = false);
                  },
                  child: Text(tx.quitarYtDlp),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              onPressed: _install,
              icon: const Icon(Icons.download_rounded),
              label: Text(tx.bajarYUsarYtDlp18),
            ),
          if (_message != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_message!)),
        ],
      ),
    );
  }
}
