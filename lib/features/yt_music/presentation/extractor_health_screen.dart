import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/track.dart';
import '../../../theme/app_colors.dart';
import '../../history/listening_history.dart';
import '../data/extractor_health.dart';
import '../data/playback_probe.dart';
import '../data/yt_clients.dart';
import '../data/ytm_client.dart';

/// Canciones de prueba si todavía no escuchaste nada de YouTube.
const _fallbackTestSongs = ['BSTsnWoslP4', '4D7u5KF7SP8', 'sWft4cMiwXQ'];

/// Resultado de "Probar todas las formas ahora" para una forma.
class FormCheck {
  const FormCheck({
    required this.ok,
    required this.total,
    this.plays,
    this.reason,
    this.elapsed = Duration.zero,
  });
  final int ok;
  final int total;

  /// Si se reprodujo de verdad (null si no se llegó a probar).
  final bool? plays;

  /// Error exacto del primer intento fallido.
  final String? reason;
  final Duration elapsed;
}

/// Prueba una forma con [videoIds]. Se separa para poder probarlo.
typedef FormTester = Future<StreamAttempt> Function(String videoId, YtPlayerClient client);

/// Reproduce una forma que resolvió; devuelve el motivo si no suena.
typedef PlayChecker = Future<String?> Function(StreamAttempt attempt, YtPlayerClient client);

/// "Salud del Extractor" (Tareas D y Z1): qué forma de pedir el audio a
/// YouTube está funcionando hoy, en palabras simples, y un botón para probar
/// todas ahora. Todo se calcula y se guarda en el teléfono.
class ExtractorHealthScreen extends ConsumerStatefulWidget {
  const ExtractorHealthScreen({super.key, this.health, this.tester, this.playChecker});

  /// Para tests; si es null usa el registro global.
  final ExtractorHealth? health;
  final FormTester? tester;
  final PlayChecker? playChecker;

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ExtractorHealthScreen()));

  @override
  ConsumerState<ExtractorHealthScreen> createState() => _ExtractorHealthScreenState();
}

class _ExtractorHealthScreenState extends ConsumerState<ExtractorHealthScreen> {
  ExtractorHealth get _health => widget.health ?? ExtractorHealth.instance;
  final Map<String, FormCheck> _checks = {};
  String? _testing;
  bool _running = false;
  YtMusicClient? _client;

  @override
  void initState() {
    super.initState();
    _health.load();
  }

  /// Hasta 3 canciones de YouTube de tu historial (no salen del teléfono:
  /// solo se le pide a YouTube su audio, como al reproducirlas).
  List<String> _testSongs() {
    final ids = <String>[];
    for (final entry in ref.read(listeningHistoryProvider)) {
      final id = entry.track.source == TrackSource.youtube ? entry.track.youtubeVideoId : null;
      if (id != null && !ids.contains(id)) ids.add(id);
      if (ids.length == 3) break;
    }
    for (final id in _fallbackTestSongs) {
      if (ids.length < 3 && !ids.contains(id)) ids.add(id);
    }
    return ids;
  }

  Future<void> _testAll() async {
    final songs = _testSongs();
    final tester = widget.tester ?? (id, client) => (_client ??= YtMusicClient()).tryClient(id, client);
    final playChecker = widget.playChecker ?? checkPlays;
    setState(() {
      _running = true;
      _checks.clear();
    });
    for (final client in ytPlayerClients) {
      if (!mounted) return;
      setState(() => _testing = client.label);
      var ok = 0;
      bool? plays;
      String? reason;
      final watch = Stopwatch()..start();
      for (final id in songs) {
        final attempt = await tester(id, client);
        if (attempt.ok) {
          ok++;
          // Con la primera canción que resuelve, se escucha (en silencio).
          if (plays == null) {
            final problem = await playChecker(attempt, client);
            plays = problem == null;
            reason ??= problem;
          }
        } else {
          reason ??= attempt.reason;
        }
      }
      final elapsed = watch.elapsed;
      if (!mounted) return;
      setState(
        () => _checks[client.label] = FormCheck(
          ok: ok,
          total: songs.length,
          plays: plays,
          reason: reason,
          elapsed: elapsed,
        ),
      );
      debugPrint('=== EXTRACTOR prueba: ${client.label} ${describeCheck(_checks[client.label]!)} ===');
    }
    if (mounted) {
      setState(() {
        _running = false;
        _testing = null;
      });
    }
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
              if (entry.value.working) friendlyFormName(entry.key),
          ];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                _checks.isNotEmpty && !_running
                    ? testSummary(_checks)
                    : working.isEmpty
                    ? all.values.every((h) => h.neverUsed)
                          ? 'Todavía no se reprodujo nada de YouTube en este dispositivo.'
                          : 'Ahora mismo ninguna forma está funcionando. Kiji sigue probando sola '
                                'y, mientras tanto, tus descargas suenan igual.'
                    : 'Hoy YouTube funciona con: ${working.join(', ')}.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Kiji pide el audio a YouTube de varias formas, en orden. Si una deja de '
                'funcionar, prueba la siguiente sin que tengas que hacer nada. Antes de usar una, '
                'verifica que el audio baje entero (algunas solo dejan el primer minuto).',
                style: TextStyle(color: AppColors.onSurfaceMuted),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _running ? null : _testAll,
                icon: _running
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.play_circle_outline_rounded),
                label: Text(
                  _running
                      ? 'Probando ${_testing == null ? '' : friendlyFormName(_testing!)}…'
                      : 'Probar todas las formas ahora',
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Prueba cada forma con 3 canciones (de tu historial, si hay) y escucha una en '
                'silencio, del principio y del final. Solo se le pide a YouTube el audio, como al '
                'reproducir; tu música sigue sonando.',
                style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              for (final client in ytPlayerClients)
                Card(
                  color: AppColors.surfaceContainer,
                  child: ListTile(
                    leading: _icon(all[client.label] ?? const ClientHealth(), _checks[client.label]),
                    title: Text(friendlyFormName(client.label)),
                    subtitle: Text(
                      [
                        if (_checks[client.label] != null) describeCheck(_checks[client.label]!),
                        describeHealth(all[client.label] ?? const ClientHealth(), DateTime.now()),
                        ?client.note,
                      ].join('\n'),
                    ),
                    isThreeLine: true,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _icon(ClientHealth health, FormCheck? check) {
    final working = check != null ? check.ok > 0 && check.plays != false : health.working;
    final unknown = check == null && health.neverUsed;
    return Icon(
      unknown
          ? Icons.radio_button_unchecked_rounded
          : working
          ? Icons.check_circle_rounded
          : Icons.warning_amber_rounded,
      color: unknown
          ? AppColors.onSurfaceMuted
          : working
          ? Colors.greenAccent
          : Colors.orangeAccent,
    );
  }
}

/// "Forma 3 (TVHTML5)".
String friendlyFormName(String label) {
  final index = ytPlayerClients.indexWhere((c) => c.label == label);
  return index < 0 ? label : 'Forma ${index + 1} ($label)';
}

/// Resumen de "Probar todas las formas ahora".
String testSummary(Map<String, FormCheck> checks) {
  final good = [
    for (final entry in checks.entries)
      if (entry.value.ok > 0 && entry.value.plays != false) friendlyFormName(entry.key),
  ];
  if (good.isEmpty) {
    return 'En la prueba no funcionó ninguna forma. Mientras tanto, tus descargas suenan igual.';
  }
  return 'En la prueba funcionan ${good.length} de ${checks.length} formas: ${good.join(', ')}.';
}

/// Resultado de la prueba en una frase.
String describeCheck(FormCheck check) {
  final seconds = (check.elapsed.inMilliseconds / 1000).toStringAsFixed(1);
  if (check.plays == false) return 'Prueba: resolvió pero no suena — ${check.reason ?? 'sin detalle'}';
  if (check.ok == check.total) {
    return 'Prueba: ${check.ok} de ${check.total} canciones bien'
        '${check.plays == true ? ' y suena entera' : ''} ($seconds s)';
  }
  if (check.ok == 0) return 'Prueba: falló — ${check.reason ?? 'sin detalle'}';
  return 'Prueba: ${check.ok} de ${check.total} bien; falló: ${check.reason ?? 'sin detalle'}';
}

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
