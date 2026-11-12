// l10n-ignore-file: textos técnicos (no se muestran en la interfaz).
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../models/track.dart';
import '../../../providers/downloads_provider.dart';
import '../../../providers/playback_provider.dart';
import '../../stream_cache/data/stream_cache.dart';
import '../domain/loudness.dart';

/// Saca el volumen de un archivo de audio que ya está en el dispositivo. Sin micrófono ni el
/// Visualizer de Android: se decodifica el archivo.
abstract class LoudnessAnalyzer {
  /// null si se canceló ([cancel]) o no hay audio.
  Future<Uint8List?> analyze(String path);

  /// Corta el análisis en curso (cambió la canción).
  Future<void> cancel();
}

/// Android: MediaExtractor + MediaCodec en `KijiChannels.kt` (canal `kiji/loudness`).
class AndroidLoudnessAnalyzer implements LoudnessAnalyzer {
  static const _channel = MethodChannel('kiji/loudness');

  @override
  Future<Uint8List?> analyze(String path) async {
    try {
      return await _channel.invokeMethod<Uint8List>('analyze', {'path': path, 'stepMs': Loudness.defaultStepMs});
    } on PlatformException catch (error) {
      if (error.code == 'cancelada') return null;
      rethrow;
    }
  }

  @override
  Future<void> cancel() => _channel.invokeMethod<void>('cancel');
}

/// PC: libmpv (el mismo de la reproducción, con ffmpeg: lee .webm/Opus, .m4a, .mp3, .flac…) vuelca
/// el audio a un WAV mono de 8 kHz sin sonar (`ao=pcm`), y Dart calcula el volumen.
class MpvLoudnessAnalyzer implements LoudnessAnalyzer {
  MpvLoudnessAnalyzer({Future<Directory> Function()? tempDirectory})
      : _tempDirectory = tempDirectory ?? getTemporaryDirectory;

  static const _sampleRate = 8000;
  final Future<Directory> Function() _tempDirectory;

  /// El mpv del análisis en curso (cerrarlo lo corta).
  mk.Player? _player;
  bool _cancelled = false;
  Completer<void>? _cancelSignal;

  @override
  Future<void> cancel() async {
    _cancelled = true;
    final signal = _cancelSignal;
    if (signal != null && !signal.isCompleted) signal.complete();
    final player = _player;
    _player = null;
    if (player != null) await player.dispose();
  }

  @override
  Future<Uint8List?> analyze(String path) async {
    _cancelled = false;
    final signal = _cancelSignal = Completer<void>();
    final wav = File(p.join((await _tempDirectory()).path, 'kiji_loudness_${DateTime.now().microsecondsSinceEpoch}.wav'));
    final player = mk.Player(configuration: const mk.PlayerConfiguration(title: 'Kiji (análisis)', logLevel: mk.MPVLogLevel.error));
    _player = player;
    var closed = false;
    try {
      final mpv = player.platform as mk.NativePlayer;
      for (final (key, value) in [
        ('vid', 'no'),
        ('ao', 'pcm'),
        ('ao-pcm-file', wav.path),
        ('ao-pcm-waveheader', 'yes'),
        ('audio-channels', 'mono'),
        ('audio-samplerate', '$_sampleRate'),
        ('audio-format', 's16'),
        ('volume', '100'),
      ]) {
        await mpv.setProperty(key, value);
      }
      final done = player.stream.completed.firstWhere((completed) => completed);
      await player.open(mk.Media(Uri.file(path).toString()));
      // Lo que pase primero: terminó, o se pidió otra canción.
      await Future.any([done, signal.future]).timeout(const Duration(minutes: 2));
      if (_cancelled) return null;
      // Al cerrar, mpv termina de escribir el WAV.
      _player = null;
      await player.dispose();
      closed = true;
      final bytes = await wav.readAsBytes();
      return await compute(_envelopeFromWav, bytes);
    } catch (error) {
      // Cerrado por [cancel] (otra canción): no es un error.
      if (_cancelled) return null;
      rethrow;
    } finally {
      if (identical(_player, player)) _player = null;
      if (!closed && !_cancelled) {
        unawaited(player.dispose().catchError((Object e) => debugPrint('=== ONDA: no se pudo cerrar mpv: ${e.runtimeType} ===')));
      }
      if (await wav.exists()) await wav.delete();
    }
  }
}

/// WAV de 16 bits mono (cabecera de 44 bytes que escribe mpv) a la envolvente.
Uint8List _envelopeFromWav(Uint8List bytes) {
  if (bytes.length <= 44) return Uint8List(0);
  final data = ByteData.sublistView(bytes, 44);
  final samples = Int16List(data.lengthInBytes ~/ 2);
  for (var i = 0; i < samples.length; i++) {
    samples[i] = data.getInt16(i * 2, Endian.little);
  }
  return envelopeFromPcm16(samples, MpvLoudnessAnalyzer._sampleRate);
}

final loudnessAnalyzerProvider = Provider<LoudnessAnalyzer?>((ref) {
  if (kIsWeb) return null;
  if (Platform.isAndroid) return AndroidLoudnessAnalyzer();
  if (Platform.isWindows || Platform.isLinux) return MpvLoudnessAnalyzer();
  return null;
});

/// El archivo en el dispositivo de [track]: descarga, caché completa o archivo local. null si solo
/// se puede escuchar por streaming (entonces la onda queda como siempre).
Future<String?> localAudioPathFor(Ref ref, Track track) async {
  final videoId = track.youtubeVideoId;
  if (videoId == null) return await File(track.audioUrl).exists() ? track.audioUrl : null;
  final downloaded = await ref.read(downloadsRepositoryProvider).fileFor(videoId);
  if (downloaded != null) return downloaded.path;
  return (await StreamCache().completeFile(videoId))?.path;
}

/// Una canción por vez: pedir otra corta la que se estaba analizando (y las que esperaban ya no
/// se analizan). Así, al pasar canciones rápido, solo se analiza la que suena.
class LoudnessJobs {
  LoudnessJobs(this._analyzer);

  final LoudnessAnalyzer _analyzer;
  String? _current;
  Future<void> _tail = Future.value();

  /// La que se está analizando (o esperando).
  String? get current => _current;

  Future<Uint8List?> analyze(String trackId, String path) {
    final previous = _current;
    _current = trackId;
    if (previous != null && previous != trackId) unawaited(_cancelNative());
    final run = _tail.then((_) async {
      // Mientras esperaba, se pidió otra: esta ya no hace falta.
      if (_current != trackId) return null;
      final levels = await _analyzer.analyze(path);
      return _current == trackId ? levels : null;
    });
    _tail = run.then<void>(
      (_) {},
      onError: (Object error) => debugPrint('=== ONDA: un análisis falló (${error.runtimeType}) ==='),
    );
    return run.whenComplete(() {
      if (_current == trackId) _current = null;
    });
  }

  /// Ya nadie muestra la onda de [trackId] (cambió la canción): se corta su análisis.
  void cancel(String trackId) {
    if (_current != trackId) return;
    _current = null;
    unawaited(_cancelNative());
  }

  Future<void> _cancelNative() async {
    try {
      await _analyzer.cancel();
    } catch (error) {
      debugPrint('=== ONDA: no se pudo cortar el análisis (${error.runtimeType}) ===');
    }
  }
}

final loudnessJobsProvider = Provider<LoudnessJobs?>((ref) {
  final analyzer = ref.watch(loudnessAnalyzerProvider);
  return analyzer == null ? null : LoudnessJobs(analyzer);
});

/// Volumen de la canción que suena, analizado una vez y guardado en `<soporte>/loudness/`.
/// null mientras no hay archivo o si no se pudo analizar. Solo la que suena, una por vez: al
/// cambiar de canción se corta el análisis de la anterior.
final loudnessProvider = FutureProvider.autoDispose.family<Loudness?, String>((ref, trackId) async {
  final track = ref.read(playbackProvider).track;
  final jobs = ref.read(loudnessJobsProvider);
  if (track == null || track.id != trackId || jobs == null) return null;
  ref.onDispose(() => jobs.cancel(trackId));

  final dir = Directory(p.join((await getApplicationSupportDirectory()).path, 'loudness'));
  // shortcut: la caché va por id; si un archivo local se reemplaza por otro con el mismo id, queda la onda vieja.
  final cached = File(p.join(dir.path, '${trackId.replaceAll(RegExp(r'[^\w-]'), '_')}.bin'));
  try {
    if (await cached.exists()) return Loudness(await cached.readAsBytes());
    final path = await localAudioPathFor(ref, track);
    if (path == null) return null;
    final watch = Stopwatch()..start();
    final levels = await jobs.analyze(trackId, path);
    if (levels == null || levels.isEmpty) return null;
    debugPrint('=== ONDA: canción analizada en ${watch.elapsedMilliseconds} ms (${levels.length} valores) ===');
    await dir.create(recursive: true);
    await cached.writeAsBytes(levels, flush: true);
    return Loudness(levels);
  } catch (error) {
    debugPrint('=== ONDA: no se pudo analizar la canción: ${error.runtimeType} ===');
    return null;
  }
});
