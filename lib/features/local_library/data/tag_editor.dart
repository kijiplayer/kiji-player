import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Formatos en los que Kiji puede escribir etiquetas.
const tagWritableExtensions = {'.mp3', '.m4a', '.mp4', '.flac', '.wav'}; // l10n-ignore

bool canEditTags(String path) => tagWritableExtensions.contains(p.extension(path).toLowerCase());

/// Qué cambiar (null: dejarlo como está).
class TagChanges {
  const TagChanges({this.title, this.artist, this.album, this.cover, this.coverMime = 'image/jpeg'});

  final String? title;
  final String? artist;
  final String? album;
  final Uint8List? cover;
  final String coverMime;

  bool get isEmpty => title == null && artist == null && album == null && cover == null;
}

enum TagEditResult {
  /// Listo: el archivo tiene las etiquetas nuevas.
  saved,

  /// Este formato no se puede escribir (OGG, Opus…).
  unsupported,

  /// El sistema no deja cambiar el archivo (en Android 11+, los de otras apps).
  notAllowed,

  /// Algo salió mal al escribir o al comprobar: el original quedó como estaba.
  failed,
}

/// Escribe las etiquetas sin arriesgar el archivo: primero en una copia en la misma carpeta, la
/// vuelve a leer para comprobarla y recién ahí la pone en lugar del original (un solo paso). Si
/// algo falla, el original no se toca y la copia se borra.
Future<TagEditResult> writeTags(String path, TagChanges changes) async {
  if (changes.isEmpty) return TagEditResult.saved;
  if (!canEditTags(path)) return TagEditResult.unsupported;
  final original = File(path);
  final copy = File('$path.kiji-tmp');
  try {
    try {
      await original.copy(copy.path);
    } on FileSystemException catch (error) {
      debugPrint('=== ETIQUETAS: no se puede escribir en esa carpeta (${error.osError?.errorCode}) ===');
      return TagEditResult.notAllowed;
    }
    updateMetadata(copy, (metadata) {
      if (changes.title case final t?) metadata.setTitle(t);
      if (changes.artist case final a?) metadata.setArtist(a);
      if (changes.album case final a?) metadata.setAlbum(a);
      if (changes.cover case final c?) metadata.setPictures([Picture(c, changes.coverMime, PictureType.coverFront)]);
    });
    // Comprobar la copia antes de reemplazar: que se lea y tenga lo pedido.
    final check = readMetadata(copy, getImage: false);
    final ok =
        (changes.title == null || check.title == changes.title) &&
        (changes.artist == null || check.artist == changes.artist) &&
        (changes.album == null || check.album == changes.album);
    if (!ok) {
      debugPrint('=== ETIQUETAS: la copia no quedó bien; el original no se tocó ===');
      return TagEditResult.failed;
    }
    try {
      await copy.rename(path);
    } on FileSystemException catch (error) {
      debugPrint('=== ETIQUETAS: el sistema no deja reemplazar el archivo (${error.osError?.errorCode}) ===');
      return TagEditResult.notAllowed;
    }
    debugPrint('=== ETIQUETAS: guardadas ===');
    return TagEditResult.saved;
  } catch (error) {
    debugPrint('=== ETIQUETAS: no se pudieron escribir (${error.runtimeType}); el original no se tocó ===');
    return TagEditResult.failed;
  } finally {
    try {
      if (await copy.exists()) await copy.delete();
    } catch (error) {
      debugPrint('=== ETIQUETAS: no se pudo borrar la copia temporal (${error.runtimeType}) ===');
    }
  }
}
