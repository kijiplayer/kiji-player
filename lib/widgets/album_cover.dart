import 'package:flutter/material.dart';

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

/// Carátula de una canción: la imagen real si hay (YouTube, en tamaño
/// grande) y, si no hay o no carga (sin red), el degradado de su color.
class TrackArtwork extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final fallback = AlbumCover(
      color: track.coverColor,
      size: size,
      borderRadius: radius,
      iconSize: size * 0.4,
    );
    final url = track.thumbnailUrl;
    if (url == null || !url.startsWith('http')) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        largerThumbnailUrl(url),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
        frameBuilder: (context, child, frame, _) => frame == null ? fallback : child,
      ),
    );
  }
}
