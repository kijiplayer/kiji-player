import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../providers/playback_provider.dart';
import '../../settings/data/settings_store.dart';
import '../../yt_music/presentation/collection_screens.dart';
import 'extractor_tester.dart';
import 'path_health.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Pruebas automáticas del extractor (Tarea Z8):
/// - al abrir Kiji, si pasaron más de 12 h desde la última;
/// - en PC, cada 12 h mientras está abierta;
/// - en Android, una vez por día con WorkManager (solo WiFi y batería no baja), cuyo resultado
///   se suma a la Salud al abrir.
/// Una canción de control por forma, sin datos del usuario. Solo avisa si fallan TODAS.
class ExtractorAutoTests {
  ExtractorAutoTests(this.ref);

  final Ref ref;
  static const interval = Duration(hours: 12);
  static const _channel = MethodChannel('kiji/innertubex');
  Timer? _timer;
  bool _running = false;

  Future<void> start() async {
    final settings = await ref.read(settingsProvider.notifier).loaded;
    final health = PathHealth.instance;
    await health.load();
    final enabled = settings.autoExtractorTests;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _channel.invokeMethod<void>('scheduleDailyTests', {'enabled': enabled});
      } on PlatformException catch (error) {
        debugPrint('=== SALUD: no se pudo programar la prueba diaria: ${error.code} ===');
      } on MissingPluginException {
        debugPrint('=== SALUD: sin canal del motor A ===');
      }
      await importBackgroundResults(health);
    }
    if (!enabled) return;
    final last = health.lastTestAt;
    if (last == null || DateTime.now().difference(last) > interval) {
      // Un rato después de abrir, para no demorar la primera canción.
      unawaited(Future<void>.delayed(const Duration(seconds: 30), run));
    }
    if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) {
      _timer = Timer.periodic(interval, (_) => run());
    }
  }

  void stop() => _timer?.cancel();

  Future<void> run() async {
    if (_running || !ref.read(settingsProvider).autoExtractorTests) return;
    _running = true;
    try {
      final results = await ExtractorTester(client: ref.read(ytMusicClientProvider)).runAll();
      if (results.isNotEmpty && results.every((r) => !r.ok) && !results.every((r) => r.reason == tx.sinConexion)) {
        ref.read(playbackNoticeProvider.notifier).state = PlaybackNotice(tx.ningunaFormaEstaPudiendoBajarCanciones);
      }
    } catch (error) {
      debugPrint('=== SALUD: la prueba automática falló: $error ===');
    } finally {
      _running = false;
    }
  }

  /// Suma a la Salud lo que probó WorkManager mientras Kiji estaba cerrada.
  @visibleForTesting
  static Future<int> importBackgroundResults(PathHealth health, {Future<Directory> Function()? directory}) async {
    try {
      final dir = await (directory ?? getApplicationSupportDirectory)();
      final file = File(p.join(dir.path, 'extractor_bg.json'));
      if (!await file.exists()) return 0;
      final json = jsonDecode(await file.readAsString());
      await file.delete();
      var count = 0;
      for (final r in (json['results'] as List? ?? const [])) {
        if (r is! Map) continue;
        final path = '${r['path']}';
        r['ok'] == true
            ? health.recordSuccess(path)
            : health.recordFormFailure(path, '${r['reason'] ?? tx.falloLaPruebaDiaria}');
        count++;
      }
      final at = json['at'];
      if (at is int) {
        final when = DateTime.fromMillisecondsSinceEpoch(at);
        if (health.lastTestAt == null || when.isAfter(health.lastTestAt!)) health.lastTestAt = when;
      }
      return count;
    } catch (error) {
      debugPrint('=== SALUD: no se pudo leer la prueba diaria: $error ===');
      return 0;
    }
  }
}

final extractorAutoTestsProvider = Provider<ExtractorAutoTests>((ref) {
  final tests = ExtractorAutoTests(ref);
  ref.onDispose(tests.stop);
  return tests;
});
