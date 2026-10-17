import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Nombre de archivo estable para una URL (FNV-1a de 64 bits en hex).
String artworkCacheName(String url) {
  var hash = 0xcbf29ce484222325;
  for (final byte in utf8.encode(url)) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return '${hash.toUnsigned(64).toRadixString(16).padLeft(16, '0')}.img';
}

/// Carátulas guardadas en el dispositivo (Tarea Z3): las de lo importado se
/// bajan una vez y después se ven sin internet. Es caché: se puede borrar y
/// no va en la copia de seguridad.
class ArtworkCache {
  ArtworkCache({Future<Directory> Function()? directory, Dio? dio})
      : _directory = directory ?? getApplicationSupportDirectory,
        _dio = dio ?? Dio(BaseOptions(receiveTimeout: const Duration(seconds: 20)));

  final Future<Directory> Function() _directory;
  final Dio _dio;

  Future<Directory> folder() async => Directory(p.join((await _directory()).path, 'artwork'));

  /// Clave de la carátula incluida en un archivo de música local.
  static String fileKey(String path) => 'file:$path';

  /// Guarda una carátula ya en memoria (por ejemplo, la incluida en un
  /// archivo de música) bajo [key].
  Future<void> saveBytes(String key, List<int> bytes) async {
    final dir = await folder();
    await dir.create(recursive: true);
    final target = File(p.join(dir.path, artworkCacheName(key)));
    final temp = File('${target.path}.part');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(target.path);
  }

  /// Baja las que falten, de a [concurrency] a la vez. Devuelve cuántas bajó.
  Future<int> download(Iterable<String> urls, {int concurrency = 4}) async {
    final dir = await folder();
    await dir.create(recursive: true);
    final pending = [
      for (final url in urls.toSet())
        if (url.startsWith('http') && !File(p.join(dir.path, artworkCacheName(url))).existsSync()) url,
    ];
    var done = 0;
    var next = 0;
    Future<void> worker() async {
      while (next < pending.length) {
        final url = pending[next++];
        try {
          final response = await _dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
          final bytes = response.data;
          if (bytes != null && bytes.isNotEmpty) {
            final target = File(p.join(dir.path, artworkCacheName(url)));
            final temp = File('${target.path}.part');
            await temp.writeAsBytes(bytes, flush: true);
            await temp.rename(target.path);
            done++;
          }
        } catch (error) {
          debugPrint('=== CARATULAS: no se pudo bajar una carátula: $error ===');
        }
      }
    }

    await Future.wait([for (var i = 0; i < concurrency; i++) worker()]);
    if (pending.isNotEmpty) debugPrint('=== CARATULAS: guardadas $done de ${pending.length} ===');
    return done;
  }
}

final artworkCacheProvider = Provider<ArtworkCache>((ref) => ArtworkCache());

final artworkFolderProvider = FutureProvider<Directory>((ref) => ref.read(artworkCacheProvider).folder());
