import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/extraction_failure.dart';
import '../domain/resolved_stream.dart';
import '../../settings/data/settings_store.dart';
import 'engines.dart';

/// Motor C (Tarea Z8): yt-dlp, solo en la PC y SOLO si el usuario lo aceptó. Se baja de las
/// releases oficiales de GitHub, se verifica con su `SHA2-256SUMS` y se busca actualización una
/// vez por semana. Nada se baja sin aviso.
class YtDlpEngine extends ExtractionEngine {
  YtDlpEngine({Dio? dio, Future<Directory> Function()? directory, this.accepted = _never})
      : _dio = dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(minutes: 3))),
        _directory = directory ?? getApplicationSupportDirectory;

  static bool _never() => false;

  /// Si el usuario aceptó usar yt-dlp (Configuración / Salud del Extractor).
  final bool Function() accepted;
  final Dio _dio;
  final Future<Directory> Function() _directory;

  static const releases = 'https://github.com/yt-dlp/yt-dlp/releases/latest/download';
  static const updateEvery = Duration(days: 7);

  /// Nombre del ejecutable oficial de esta plataforma.
  static String get assetName {
    if (Platform.isWindows) return 'yt-dlp.exe';
    if (Platform.isMacOS) return 'yt-dlp_macos';
    return 'yt-dlp_linux';
  }

  static bool get platformSupported => !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  @override
  EngineId get id => EngineId.c;

  @override
  bool get isSupported => platformSupported && accepted() && _installedSync;

  bool _installedSync = false;

  Future<File> binary() async => File(p.join((await _directory()).path, 'ytdlp', assetName));

  Future<bool> installed() async => _installedSync = await (await binary()).exists();

  /// Baja yt-dlp y verifica su huella. [onProgress] recibe bytes y total.
  Future<void> install({void Function(int done, int total)? onProgress}) async {
    final target = await binary();
    await target.parent.create(recursive: true);
    final sums = await _dio.get<String>('$releases/SHA2-256SUMS', options: Options(responseType: ResponseType.plain));
    final expected = expectedChecksum(sums.data ?? '', assetName);
    if (expected == null) throw StateError('No está la huella de $assetName en la release');
    final part = File('${target.path}.part');
    await _dio.download('$releases/$assetName', part.path, onReceiveProgress: onProgress);
    final actual = (await sha256.bind(part.openRead()).first).toString();
    if (actual != expected) {
      await part.delete();
      throw StateError('yt-dlp llegó dañado (su huella no coincide); no se instaló');
    }
    if (await target.exists()) await target.delete();
    await part.rename(target.path);
    if (!Platform.isWindows) await Process.run('chmod', ['+x', target.path]);
    await File(p.join(target.parent.path, 'instalado.txt')).writeAsString(DateTime.now().toIso8601String());
    _installedSync = true;
    debugPrint('=== MOTOR C: yt-dlp instalado y verificado ===');
  }

  /// Una vez por semana, si ya está instalado y aceptado: baja la versión nueva (verificada).
  Future<void> updateIfDue() async {
    if (!platformSupported || !accepted() || !await installed()) return;
    final stamp = File(p.join((await binary()).parent.path, 'instalado.txt'));
    final last = await stamp.exists() ? DateTime.tryParse(await stamp.readAsString()) : null;
    if (last != null && DateTime.now().difference(last) < updateEvery) return;
    try {
      await install();
    } catch (error) {
      debugPrint('=== MOTOR C: no se pudo actualizar yt-dlp: $error ===');
    }
  }

  Future<void> remove() async {
    final dir = (await binary()).parent;
    if (await dir.exists()) await dir.delete(recursive: true);
    _installedSync = false;
  }

  @override
  Future<EngineResult> resolve(String videoId, {bool lowQuality = false, Set<String> skip = const {}, List<String>? order}) async {
    if (!isSupported || skip.contains('YTDLP')) return const EngineResult.failed([]);
    try {
      final result = await Process.run(
        (await binary()).path,
        ['-J', '--no-playlist', '--no-warnings', '-f', lowQuality ? 'worstaudio' : 'bestaudio', 'https://www.youtube.com/watch?v=$videoId'],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      ).timeout(const Duration(seconds: 60));
      if (result.exitCode != 0) {
        final err = '${result.stderr}'.split('\n').firstWhere((l) => l.contains('ERROR'), orElse: () => '${result.stderr}');
        return EngineResult.failed([('YTDLP', classifyFailure(err.trim()))]);
      }
      return ytDlpResult(videoId, jsonDecode('${result.stdout}'));
    } on TimeoutException {
      return EngineResult.failed([('YTDLP', const ExtractionFailure(FailureScope.form, 'yt-dlp tardó demasiado'))]);
    } catch (error) {
      return EngineResult.failed([('YTDLP', ExtractionFailure(FailureScope.form, 'yt-dlp falló (${error.runtimeType})'))]);
    }
  }
}

/// La huella de [asset] en el archivo `SHA2-256SUMS` de la release.
@visibleForTesting
String? expectedChecksum(String sums, String asset) {
  for (final line in const LineSplitter().convert(sums)) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length == 2 && parts[1].replaceFirst('*', '') == asset) return parts[0].toLowerCase();
  }
  return null;
}

/// Convierte la salida `-J` de yt-dlp (con el formato ya elegido) en un [EngineResult].
@visibleForTesting
EngineResult ytDlpResult(String videoId, Object? json) {
  if (json is! Map) return EngineResult.failed([('YTDLP', const ExtractionFailure(FailureScope.form, 'yt-dlp respondió algo raro'))]);
  final formats = json['requested_formats'] as List? ?? [json];
  final f = formats.whereType<Map>().firstWhere((m) => m['url'] != null, orElse: () => const {});
  final url = f['url'] as String?;
  if (url == null) return EngineResult.failed([('YTDLP', const ExtractionFailure(FailureScope.form, 'yt-dlp no dio URL'))]);
  final headers = <String, String>{for (final e in ((f['http_headers'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}'};
  final ext = '${f['ext'] ?? ''}';
  final acodec = '${f['acodec'] ?? ''}';
  return EngineResult.ok(ResolvedStream(
    videoId: videoId,
    url: url,
    engine: EngineId.c,
    form: 'YTDLP',
    headers: headers,
    mime: ext == 'webm' ? 'audio/webm; codecs="$acodec"' : 'audio/mp4; codecs="$acodec"',
    kbps: (f['abr'] as num?)?.round(),
    contentLength: (f['filesize'] as num?)?.toInt(),
    isHls: '${f['protocol'] ?? ''}'.contains('m3u8'),
  ));
}

/// El motor C de la app: usa el ajuste "aceptado" y se revisa (instalado, actualización semanal)
/// al crearse.
final ytDlpEngineProvider = Provider<YtDlpEngine>((ref) {
  final engine = YtDlpEngine(accepted: () => ref.read(settingsProvider).ytDlpAccepted);
  if (YtDlpEngine.platformSupported) {
    unawaited(engine.installed().then((_) => engine.updateIfDue()));
  }
  return engine;
});
