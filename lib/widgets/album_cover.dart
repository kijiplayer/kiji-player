import 'package:flutter/material.dart';

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
