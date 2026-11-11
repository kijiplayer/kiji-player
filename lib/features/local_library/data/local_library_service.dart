import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Una canción del MediaStore de Android (lo que da el sistema, sin leer el archivo).
@immutable
class MediaStoreSong {
  const MediaStoreSong({
    required this.id,
    required this.data,
    this.size = 0,
    this.dateAdded,
    this.dateModified,
    this.title,
    this.artist,
    this.album,
    this.track,
    this.duration,
    this.isMusic,
    this.genre,
  });

  final int id;

  /// Ruta del archivo.
  final String data;
  final int size;

  /// Segundos desde 1970 (como los da el MediaStore).
  final int? dateAdded;
  final int? dateModified;
  final String? title;
  final String? artist;
  final String? album;

  /// 1003 = disco 1, pista 3.
  final int? track;
  final int? duration;
  final bool? isMusic;
  final String? genre;

  /// "mp3", "m4a"… (de la ruta).
  String get fileExtension {
    final dot = data.lastIndexOf('.');
    return dot < 0 ? '' : data.substring(dot + 1).toLowerCase();
  }

  static MediaStoreSong? fromMap(Object? raw) {
    if (raw is! Map || raw['id'] is! int || raw['data'] is! String) return null;
    int? n(Object? v) => v is int ? v : null;
    String? s(Object? v) => v is String && v.isNotEmpty ? v : null;
    return MediaStoreSong(
      id: raw['id'] as int,
      data: raw['data'] as String,
      size: n(raw['size']) ?? 0,
      dateAdded: n(raw['dateAdded']),
      dateModified: n(raw['dateModified']),
      title: s(raw['title']),
      artist: s(raw['artist']),
      album: s(raw['album']),
      track: n(raw['track']),
      duration: n(raw['duration']),
      isMusic: raw['isMusic'] is bool ? raw['isMusic'] as bool : null,
      genre: s(raw['genre']),
    );
  }
}

/// La música del teléfono: el permiso (READ_MEDIA_AUDIO en Android 13+, almacenamiento antes) con
/// permission_handler y la lista del MediaStore por el canal propio `kiji/media`
/// (MediaLibrary.kt). Reemplaza a on_audio_query (sin mantenimiento desde 2023).
class LocalLibraryService {
  LocalLibraryService({MethodChannel? channel}) : _channel = channel ?? const MethodChannel('kiji/media');

  final MethodChannel _channel;

  /// `true` si ya hay permiso para leer la música.
  Future<bool> hasPermission() async {
    try {
      return await Permission.audio.isGranted || await Permission.storage.isGranted;
    } catch (error) {
      debugPrint('=== BIBLIOTECA: no se pudo saber el permiso: ${error.runtimeType} ===');
      return false;
    }
  }

  /// Pide el permiso (el diálogo del sistema). `true` si se concedió.
  Future<bool> requestPermission() async {
    try {
      if (await Permission.audio.request().isGranted) return true;
      // Android 12 o menos: el permiso de almacenamiento.
      return await Permission.storage.request().isGranted;
    } catch (error) {
      debugPrint('=== BIBLIOTECA: no se pudo pedir el permiso: ${error.runtimeType} ===');
      return false;
    }
  }

  /// Todas las canciones del MediaStore, por título.
  Future<List<MediaStoreSong>> fetchSongs() async {
    final raw = await _channel.invokeListMethod<Object?>('songs') ?? const []; // l10n-ignore
    return [for (final item in raw) ?MediaStoreSong.fromMap(item)];
  }
}
