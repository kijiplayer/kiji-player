import 'package:on_audio_query/on_audio_query.dart';

/// Envuelve `on_audio_query` para aislar el resto de la app del paquete
/// de terceros (Clean Architecture: solo esta capa `data/` lo conoce).
class LocalLibraryService {
  LocalLibraryService() : _query = OnAudioQuery();

  final OnAudioQuery _query;

  /// `true` si ya tenemos permiso de lectura de audio (Android 13+:
  /// READ_MEDIA_AUDIO; versiones previas: READ_EXTERNAL_STORAGE).
  Future<bool> hasPermission() => _query.permissionsStatus();

  /// Dispara el diálogo nativo de permisos. Devuelve `true` si se concedió.
  Future<bool> requestPermission() => _query.permissionsRequest();

  /// Lista todas las canciones del dispositivo, ordenadas por título.
  Future<List<SongModel>> fetchSongs() {
    return _query.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
  }
}
