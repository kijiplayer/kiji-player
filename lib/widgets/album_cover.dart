import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../features/customize/data/artwork_cache.dart';
import '../features/customize/data/track_overrides.dart';
import '../features/system_media/data/cover_art.dart';
import '../models/track.dart';
import '../providers/downloads_provider.dart';
import 'kiji_logo.dart';
import '../features/downloads/presentation/download_status.dart';

class AlbumCover extends StatelessWidget {
  const AlbumCover({
    super.key,
    required this.color,
    this.size = 48,
    this.borderRadius = 8,
    this.iconSize = 24,
    this.logo = false,
  });

  final Color color;
  final double size;
  final double borderRadius;
  final double iconSize;

  /// El logo de Kiji en lugar de la nota (respaldo de una canción sin portada).
  final bool logo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            Color.lerp(color, Colors.black, 0.45)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: size * 0.16,
            offset: Offset(0, size * 0.04),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: logo
          ? Opacity(opacity: 0.85, child: KijiLogo(size: size * 0.5))
          : Icon(
              Icons.music_note_rounded,
              color: Colors.white70,
              size: iconSize,
            ),
    );
  }
}

/// Carátula de una canción: la foto propia si el usuario eligió una
/// (Tarea Z3); si no, la imagen real (YouTube, en tamaño grande; guardada
/// en el dispositivo si se importó) y, si no hay o no carga (sin red), el
/// degradado de su color.
class TrackArtwork extends ConsumerWidget {
  const TrackArtwork({
    super.key,
    required this.track,
    this.size = 48,
    this.radius = 8,
    this.showDownloadState = true,
  });

  final Track track;
  final double size;
  final double radius;

  /// En las listas (carátulas chicas) se ve el estado de descarga (Tarea T4).
  final bool showDownloadState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final art = _artwork(ref);
    final videoId = track.youtubeVideoId;
    if (!showDownloadState || videoId == null || size > 72) return art;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [art, DownloadStateOverlay(videoId: videoId, size: size)],
      ),
    );
  }

  Widget _artwork(WidgetRef ref) {
    final fallback = AlbumCover(
      color: track.coverColor,
      size: size,
      borderRadius: radius,
      iconSize: size * 0.4,
      logo: true,
    );
    final image = trackImageProvider(ref, track);
    if (image == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image(
        image: image,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
        frameBuilder: image is NetworkImage ? (context, child, frame, _) => frame == null ? fallback : child : null,
      ),
    );
  }
}

/// La imagen de la carátula de [track], en este orden: la foto elegida por el
/// usuario, la incluida en el archivo, la descargada junto al audio (sirve sin
/// conexión), la guardada en caché, la de internet y, para YouTube sin miniatura
/// (descargas, importadas, radio), la del video por su id.
/// null si no tiene (se usa el degradado de su color). También la usa el
/// reproductor para sacar el color real del halo (Tarea Z6).
ImageProvider? trackImageProvider(WidgetRef ref, Track track) {
  final custom = ref.watch(trackOverridesProvider.select((all) => all[track.id]?.coverFile));
  final covers = ref.watch(coversFolderProvider).valueOrNull;
  if (custom != null && covers != null) return FileImage(File(p.join(covers.path, custom)));

  final cache = ref.watch(artworkFolderProvider).valueOrNull;
  // Carátula incluida en el archivo, guardada al importar (Tarea Z3).
  if (track.source == TrackSource.local && cache != null) {
    final embedded = File(p.join(cache.path, artworkCacheName(ArtworkCache.fileKey(track.audioUrl))));
    if (embedded.existsSync()) return FileImage(embedded);
  }
  final videoId = track.youtubeVideoId;
  if (videoId != null) {
    final downloaded = ref.watch(downloadsProvider.select((s) {
      final thumb = s.completed[videoId]?.thumbnailFileName;
      return thumb == null || s.directoryPath == null ? null : p.join(s.directoryPath!, thumb);
    }));
    if (downloaded != null) return FileImage(File(downloaded));
  }
  final url = track.thumbnailUrl;
  if (url == null || !url.startsWith('http')) {
    return videoId == null ? null : NetworkImage(youtubeThumbnailUrl(videoId));
  }
  if (cache != null) {
    final cached = File(p.join(cache.path, artworkCacheName(url)));
    if (cached.existsSync()) return FileImage(cached);
  }
  return NetworkImage(largerThumbnailUrl(url));
}
