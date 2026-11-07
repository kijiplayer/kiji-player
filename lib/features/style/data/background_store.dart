import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Fondo propio: el archivo elegido se COPIA en `<datos de Kiji>/backgrounds/` (almacenamiento
/// privado de la app) y se usa desde ahí. Nunca se sube a ningún lado.
class BackgroundStore {
  BackgroundStore({Future<Directory> Function()? directory}) : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;

  static const imageExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif'];
  static const videoExtensions = ['mp4', 'webm', 'mov', 'm4v'];

  /// El video de fondo: con video_player (Android, iOS, macOS) o con media_kit, que en la PC trae
  /// la librería completa de mpv (Windows y Linux).
  static bool get videoSupported => !kIsWeb;

  /// En la PC el video va con media_kit (video_player no anda en Windows ni Linux).
  static bool get videoWithMediaKit => !kIsWeb && (Platform.isWindows || Platform.isLinux);

  Future<Directory> folder() async => Directory(p.join((await _directory()).path, 'backgrounds'));

  Future<File> fileFor(String name) async => File(p.join((await folder()).path, name));

  /// Copia [source] dentro de Kiji y devuelve el nombre nuevo (borra los otros fondos copiados).
  Future<String> keep(String source) async {
    final ext = p.extension(source).toLowerCase();
    final dir = await folder();
    await dir.create(recursive: true);
    final name = 'fondo-${DateTime.now().millisecondsSinceEpoch}$ext';
    final target = File(p.join(dir.path, name));
    final temp = File('${target.path}.part');
    await File(source).copy(temp.path);
    await temp.rename(target.path);
    await _removeAllBut(name);
    return name;
  }

  /// Fondos de cada canción ("Estilo de esta canción"), aparte del general.
  Future<Directory> trackFolder() async => Directory(p.join((await folder()).path, 'canciones'));

  /// Copia [source] como fondo de la canción [trackId] (borra el anterior de esa canción).
  Future<String> keepForTrack(String trackId, String source, {String? previous}) async {
    final ext = p.extension(source).toLowerCase();
    final dir = await trackFolder();
    await dir.create(recursive: true);
    final safe = trackId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final name = 'cancion-$safe-${DateTime.now().millisecondsSinceEpoch}$ext';
    final target = File(p.join(dir.path, name));
    final temp = File('${target.path}.part');
    await File(source).copy(temp.path);
    await temp.rename(target.path);
    await removeTrack(previous);
    return name;
  }

  Future<void> removeTrack(String? name) async {
    if (name == null) return;
    final file = File(p.join((await trackFolder()).path, name));
    try {
      if (await file.exists()) await file.delete();
    } catch (error) {
      debugPrint('=== FONDO: no se pudo borrar el fondo de una canción: $error ===');
    }
  }

  /// Borra los fondos copiados ("Quitar fondo").
  Future<void> removeAll() => _removeAllBut(null);

  Future<void> _removeAllBut(String? keep) async {
    final dir = await folder();
    if (!await dir.exists()) return;
    // Solo los generales (los de cada canción están en su carpeta, que no se toca aquí).
    await for (final entity in dir.list()) {
      if (entity is File && p.basename(entity.path) != keep) {
        try {
          await entity.delete();
        } catch (error) {
          debugPrint('=== FONDO: no se pudo borrar un fondo viejo: $error ===');
        }
      }
    }
  }

  /// Pregunta al usuario por un archivo (imagen/GIF o video). null si lo cancela.
  Future<String?> pick({required bool video}) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: video ? videoExtensions : imageExtensions,
    );
    final path = picked.firstOrNull?.path;
    return path;
  }

  /// Ahorro de batería del sistema (Android): el video de fondo se queda quieto.
  static Future<bool> powerSaving() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await const MethodChannel('kiji/battery').invokeMethod<bool>('powerSave') ?? false;
    } catch (error) {
      debugPrint('=== FONDO: no se pudo saber si hay ahorro de batería: $error ===');
      return false;
    }
  }
}

final backgroundStoreProvider = Provider<BackgroundStore>((ref) => BackgroundStore());

/// La carpeta de los fondos (para dibujarlos sin esperar).
final backgroundFolderProvider = FutureProvider<Directory>((ref) => ref.read(backgroundStoreProvider).folder());
