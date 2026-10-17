import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../features/customize/data/artwork_cache.dart';
import '../features/customize/data/track_overrides.dart';
import '../features/system_media/data/cover_art.dart';
import '../models/track.dart';

class AlbumCover extends StatelessWidget {
  const AlbumCover({
    super.key,
    required this.color,
    this.size = 48,
    this.borderRadius = 8,
    this.iconSize = 24,
  });

  final Color color;
  final double size;
  final double borderRadius;
  final double iconSize;

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
      child: Icon(
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
  });

  final Track track;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallback = AlbumCover(
      color: track.coverColor,
      size: size,
      borderRadius: radius,
      iconSize: size * 0.4,
    );
    Widget clip(Widget child) => ClipRRect(borderRadius: BorderRadius.circular(radius), child: child);
    Widget file(File f) => clip(Image.file(
          f,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ));

    final custom = ref.watch(trackOverridesProvider.select((all) => all[track.id]?.coverFile));
    final covers = ref.watch(coversFolderProvider).valueOrNull;
    if (custom != null && covers != null) return file(File(p.join(covers.path, custom)));

    final cache = ref.watch(artworkFolderProvider).valueOrNull;
    // Carátula incluida en el archivo, guardada al importar (Tarea Z3).
    if (track.source == TrackSource.local && cache != null) {
      final embedded = File(p.join(cache.path, artworkCacheName(ArtworkCache.fileKey(track.audioUrl))));
      if (embedded.existsSync()) return file(embedded);
    }
    final url = track.thumbnailUrl;
    if (url == null || !url.startsWith('http')) return fallback;
    if (cache != null) {
      final cached = File(p.join(cache.path, artworkCacheName(url)));
      if (cached.existsSync()) return file(cached);
    }
    return clip(Image.network(
      largerThumbnailUrl(url),
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
      frameBuilder: (context, child, frame, _) => frame == null ? fallback : child,
    ));
  }
}
