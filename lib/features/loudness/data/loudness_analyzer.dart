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
  Future<Uint8List?> analyze(String path);
}

/// Android: MediaExtractor + MediaCodec en `KijiChannels.kt` (canal `kiji/loudness`).
class AndroidLoudnessAnalyzer implements LoudnessAnalyzer {
  static const _channel = MethodChannel('kiji/loudness');

  @override
  Future<Uint8List?> analyze(String path) =>
      _channel.invokeMethod<Uint8List>('analyze', {'path': path, 'stepMs': Loudness.defaultStepMs});
}

/// PC: libmpv (el mismo de la reproducción, con ffmpeg: lee .webm/Opus, .m4a, .mp3, .flac…) vuelca
/// el audio a un WAV mono de 8 kHz sin sonar (`ao=pcm`), y Dart calcula el volumen.
class MpvLoudnessAnalyzer implements LoudnessAnalyzer {
  MpvLoudnessAnalyzer({Future<Directory> Function()? tempDirectory})
      : _tempDirectory = tempDirectory ?? getTemporaryDirectory;

  static const _sampleRate = 8000;
  final Future<Directory> Function() _tempDirectory;

  @override
  Future<Uint8List?> analyze(String path) async {
    final wav = File(p.join((await _tempDirectory()).path, 'kiji_loudness_${DateTime.now().microsecondsSinceEpoch}.wav'));
    final player = mk.Player(configuration: const mk.PlayerConfiguration(title: 'Kiji (análisis)', logLevel: mk.MPVLogLevel.error));
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
      await done.timeout(const Duration(minutes: 2));
      // Al cerrar, mpv termina de escribir el WAV.
      await player.dispose();
      closed = true;
      final bytes = await wav.readAsBytes();
      return await compute(_envelopeFromWav, bytes);
    } finally {
      if (!closed) unawaited(player.dispose().catchError((Object e) => debugPrint('=== ONDA: no se pudo cerrar mpv: $e ===')));
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

/// Volumen de la canción que suena, analizado una vez y guardado en `<soporte>/loudness/`.
/// null mientras no hay archivo o si no se pudo analizar.
final loudnessProvider = FutureProvider.autoDispose.family<Loudness?, String>((ref, trackId) async {
  final track = ref.read(playbackProvider).track;
  final analyzer = ref.read(loudnessAnalyzerProvider);
  if (track == null || track.id != trackId || analyzer == null) return null;

  final dir = Directory(p.join((await getApplicationSupportDirectory()).path, 'loudness'));
  // shortcut: la caché va por id; si un archivo local se reemplaza por otro con el mismo id, queda la onda vieja.
  final cached = File(p.join(dir.path, '${trackId.replaceAll(RegExp(r'[^\w-]'), '_')}.bin'));
  try {
    if (await cached.exists()) return Loudness(await cached.readAsBytes());
    final path = await localAudioPathFor(ref, track);
    if (path == null) return null;
    final watch = Stopwatch()..start();
    final levels = await analyzer.analyze(path);
    if (levels == null || levels.isEmpty) return null;
    debugPrint('=== ONDA: "${track.title}" analizada en ${watch.elapsedMilliseconds} ms (${levels.length} valores) ===');
    await dir.create(recursive: true);
    await cached.writeAsBytes(levels, flush: true);
    return Loudness(levels);
  } catch (error) {
    debugPrint('=== ONDA: no se pudo analizar "${track.title}": $error ===');
    return null;
  }
});
