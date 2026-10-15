/// Cuánto espacio libre queda en el disco donde Kiji guarda sus archivos.
///
/// Es una interfaz porque cada plataforma lo pregunta distinto.
/// Las implementaciones están en `data/storage_info_*.dart`.
abstract interface class StorageInfo {
  /// Bytes libres en el volumen de [path], o null si la plataforma no lo
  /// informa (la UI muestra "espacio libre desconocido").
  Future<int?> freeBytes(String path);
}
