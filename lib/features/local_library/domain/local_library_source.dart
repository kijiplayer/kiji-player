import '../../../models/track.dart';

/// De dónde sale la música guardada en el dispositivo.
///
/// Es una interfaz: en Android se lee del MediaStore
/// (`on_audio_query`, que no existe en PC); en Windows/Linux, de las carpetas
/// que elige el usuario. Implementaciones en `data/`.
abstract interface class LocalLibrarySource {
  /// true si la música sale de carpetas elegidas por el usuario (PC). La
  /// pantalla muestra entonces "Elegir carpeta" en vez de pedir un permiso.
  bool get usesFolders;

  /// Carpetas elegidas (vacío si [usesFolders] es false).
  Future<List<String>> folders();

  /// true si ya se puede leer la música (permiso concedido o, en PC, al
  /// menos una carpeta elegida).
  Future<bool> hasAccess();

  /// Pide acceso: el permiso del sistema en Android, o elegir una carpeta en
  /// PC. Devuelve true si quedó con acceso.
  Future<bool> requestAccess();

  /// Deja de leer [folder] (solo PC). No borra ningún archivo.
  Future<void> removeFolder(String folder);

  /// Las canciones, ordenadas por título.
  Future<List<Track>> loadTracks();
}
