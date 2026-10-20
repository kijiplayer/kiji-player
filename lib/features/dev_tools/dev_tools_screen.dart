import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/downloads_provider.dart';
import '../../providers/playback_provider.dart';
import '../../theme/kiji_tokens.dart';
import '../../utils/app_log.dart';
import '../../utils/byte_formatter.dart';
import '../extractor/data/extractor_trace.dart';
import '../extractor/data/path_health.dart';
import '../reports/data/error_reporter.dart';
import '../settings/data/settings_store.dart';
import '../stream_cache/data/stream_cache.dart';
import '../yt_music/presentation/extractor_health_screen.dart';

/// Herramientas de desarrollo (Tarea T2), solo en Kiji Dev: registro en vivo, diagnóstico del
/// extractor, caché y descargas. Nada de esto sale del teléfono.
class DevToolsScreen extends StatelessWidget {
  const DevToolsScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DevToolsScreen()));

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Herramientas de Kiji Dev'),
          actions: [
            IconButton(
              tooltip: 'Probar el aviso de error',
              icon: const Icon(Icons.bug_report_outlined),
              // Tarea T3: muestra el aviso con sus tres opciones (una vez por sesión).
              onPressed: () => ErrorReporter.instance
                  .capture(StateError('error de prueba de Kiji Dev'), StackTrace.current, where: 'prueba'),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Registro'),
              Tab(text: 'Extractor'),
              Tab(text: 'Caché'),
              Tab(text: 'Descargas'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_LiveLog(), _ExtractorTab(), _CacheTab(), _DownloadsTab()],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Registro en vivo
// ---------------------------------------------------------------------------

class _LiveLog extends StatefulWidget {
  const _LiveLog();

  @override
  State<_LiveLog> createState() => _LiveLogState();
}

class _LiveLogState extends State<_LiveLog> {
  final _filter = TextEditingController();
  final _scroll = ScrollController();
  late List<LogLine> _lines = AppLog.lines;
  StreamSubscription<LogLine>? _sub;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _sub = AppLog.stream.listen((_) {
      if (_paused || !mounted) return;
      setState(() => _lines = AppLog.lines);
      _followEnd();
    });
    _followEnd();
  }

  void _followEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _filter.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _filter.text.trim().toLowerCase();
    final visible = query.isEmpty ? _lines : _lines.where((l) => l.text.toLowerCase().contains(query)).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _filter,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Filtrar (EXTRACTOR, MEZCLA, CACHE…)',
                    prefixIcon: Icon(Icons.filter_list_rounded),
                  ),
                ),
              ),
              IconButton(
                tooltip: _paused ? 'Seguir en vivo' : 'Pausar',
                icon: Icon(_paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                onPressed: () => setState(() {
                  _paused = !_paused;
                  if (!_paused) {
                    _lines = AppLog.lines;
                    _followEnd();
                  }
                }),
              ),
              IconButton(
                tooltip: 'Copiar lo que se ve',
                icon: const Icon(Icons.copy_rounded),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: visible.join('\n')));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('${visible.length} líneas copiadas')));
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? const Center(child: Text('Todavía no hay nada.', style: TextStyle(color: KijiColors.muted)))
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    final line = visible[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: SelectableText.rich(
                        TextSpan(children: [
                          TextSpan(text: '${line.time} ', style: KijiText.mono(size: 10)),
                          TextSpan(
                            text: line.text,
                            style: KijiText.mono(size: 11, color: _colorFor(line.text)),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  static Color _colorFor(String text) {
    final upper = text.toUpperCase();
    if (upper.contains('ERROR') || upper.contains('FALL')) return const Color(0xFFFF7A7A);
    if (upper.contains('EXTRACTOR')) return KijiColors.cyan;
    return KijiColors.text;
  }
}

// ---------------------------------------------------------------------------
// Extractor
// ---------------------------------------------------------------------------

class _ExtractorTab extends ConsumerWidget {
  const _ExtractorTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final notifier = ref.read(playbackProvider.notifier);
    return ListenableBuilder(
      listenable: Listenable.merge([ExtractorTrace.instance, PathHealth.instance]),
      builder: (context, _) {
        final entries = ExtractorTrace.instance.entries;
        final paths = PathHealth.instance.all.entries.toList()
          ..sort((a, b) => PathHealth.instance.score(b.key).compareTo(PathHealth.instance.score(a.key)));
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            const _Heading('Ahora suena'),
            _KeyValue('Canción', playback.track?.title ?? '—'),
            _KeyValue('Video', playback.track?.youtubeVideoId ?? '—'),
            _KeyValue(
                'Audio',
                notifier.debugCurrentStream ??
                    notifier.debugCurrentPath ??
                    (playback.track == null ? '—' : 'de la caché, una descarga o un archivo (sin YouTube)')),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.health_and_safety_outlined),
              label: const Text('Abrir Salud del Extractor'),
              onPressed: () => ExtractorHealthScreen.open(context),
            ),
            _Heading('Últimas búsquedas (${entries.length})'),
            if (entries.isEmpty) const Text('Ninguna desde que se abrió Kiji.', style: TextStyle(color: KijiColors.muted)),
            for (final e in entries)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                leading: Icon(e.ok ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                    color: e.ok ? KijiColors.cyan : const Color(0xFFFF7A7A)),
                title: Text(e.result, style: KijiText.mono(size: 12, color: KijiColors.text)),
                subtitle: Text(
                  '${e.videoId} · ${e.elapsed.inMilliseconds} ms · ${LogLine(e.at, '').time}'
                  '${e.failures.isEmpty ? '' : ' · ${e.failures.length} fallas antes'}',
                  style: KijiText.mono(size: 10),
                ),
                children: [
                  for (final (path, reason) in e.failures)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 40, bottom: 4),
                        child: Text('$path → $reason', style: KijiText.mono(size: 10)),
                      ),
                    ),
                ],
              ),
            _Heading('Caminos (${paths.length})'),
            for (final entry in paths)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text(entry.key, style: KijiText.mono(size: 11, color: KijiColors.text))),
                    Text(
                      '✓${entry.value.ok} ✗${entry.value.fail} · ${PathHealth.instance.score(entry.key).toStringAsFixed(2)}',
                      style: KijiText.mono(size: 11),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Caché
// ---------------------------------------------------------------------------

class _CacheTab extends ConsumerStatefulWidget {
  const _CacheTab();

  @override
  ConsumerState<_CacheTab> createState() => _CacheTabState();
}

class _CacheTabState extends ConsumerState<_CacheTab> {
  final _cache = StreamCache();
  late Future<_CacheInfo> _info = _load();

  Future<_CacheInfo> _load() async {
    final dir = await _cache.directory();
    final files = <FileSystemEntity>[];
    await for (final entity in dir.list()) {
      if (entity is File) files.add(entity);
    }
    final stats = [for (final f in files) (f.uri.pathSegments.last, await f.stat())];
    stats.sort((a, b) => b.$2.modified.compareTo(a.$2.modified));
    return _CacheInfo(dir.path, stats);
  }

  @override
  Widget build(BuildContext context) {
    final limit = ref.watch(settingsProvider.select((s) => s.streamCacheLimitBytes));
    return FutureBuilder<_CacheInfo>(
      future: _info,
      builder: (context, snapshot) {
        final info = snapshot.data;
        if (info == null) return const Center(child: CircularProgressIndicator());
        final total = info.files.fold<int>(0, (sum, f) => sum + f.$2.size);
        final partial = info.files.where((f) => f.$1.endsWith('.part')).length;
        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _info = _load());
            await _info;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _KeyValue('Ocupa', '${formatBytes(total)} de ${formatBytes(limit)}'),
              _KeyValue('Archivos', '${info.files.length - partial} enteros, $partial a medias'),
              _KeyValue('Carpeta', info.path),
              const _Heading('Archivos (el más nuevo primero)'),
              for (final (name, stat) in info.files)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(child: Text(name, style: KijiText.mono(size: 11, color: KijiColors.text))),
                      Text(formatBytes(stat.size), style: KijiText.mono(size: 11)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CacheInfo {
  const _CacheInfo(this.path, this.files);
  final String path;
  final List<(String, FileStat)> files;
}

// ---------------------------------------------------------------------------
// Descargas
// ---------------------------------------------------------------------------

class _DownloadsTab extends ConsumerWidget {
  const _DownloadsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(downloadsProvider);
    final active = state.active.values.toList();
    String percent(double? p) => p == null ? '' : ' ${(p * 100).round()} %';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _KeyValue('Descargadas', '${state.completed.length} (${formatBytes(state.usedBytes)})'),
        _KeyValue('En curso', '${active.where((d) => d.status == ActiveDownloadStatus.downloading).length}'),
        _KeyValue('En espera', '${active.where((d) => d.status == ActiveDownloadStatus.queued).length}'),
        _KeyValue('Con error', '${active.where((d) => d.status == ActiveDownloadStatus.failed).length}'),
        _KeyValue('Solo con WiFi', state.settings.wifiOnly ? 'sí' : 'no'),
        _KeyValue('Límite', state.settings.limitBytes == null ? 'sin límite' : formatBytes(state.settings.limitBytes!)),
        _KeyValue('Carpeta', state.directoryPath ?? '—'),
        const _Heading('Cola de descargas'),
        if (active.isEmpty) const Text('Vacía.', style: TextStyle(color: KijiColors.muted)),
        for (final d in active)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${d.status.name}${percent(d.progress)} · ${d.track.youtubeVideoId ?? d.track.id}'
              '${d.errorMessage == null ? '' : '\n  → ${d.errorMessage}'}',
              style: KijiText.mono(size: 11, color: KijiColors.text),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(text.toUpperCase(), style: KijiText.mono(size: 11, color: KijiColors.cyan)),
      );
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Text(label, style: const TextStyle(color: KijiColors.muted))),
            Expanded(child: SelectableText(value, style: KijiText.mono(size: 12, color: KijiColors.text))),
          ],
        ),
      );
}
