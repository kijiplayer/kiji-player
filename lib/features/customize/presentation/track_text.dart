import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/track.dart';
import '../data/track_overrides.dart';

/// La canción como se muestra: con el título y el artista que eligió el
/// usuario, si cambió alguno.
Track displayTrack(WidgetRef ref, Track track) {
  final override = ref.watch(trackOverridesProvider.select((all) => all[track.id]));
  return override == null ? track : override.applyTo(track);
}

/// Título de la canción, respetando el que eligió el usuario.
class TrackTitleText extends ConsumerWidget {
  const TrackTitleText(this.track, {super.key, this.style, this.maxLines, this.overflow, this.textAlign});

  final Track track;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Text(
        displayTrack(ref, track).title,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
      );
}

/// Artista de la canción, respetando el que eligió el usuario.
class TrackArtistText extends ConsumerWidget {
  const TrackArtistText(this.track, {super.key, this.style, this.maxLines, this.overflow, this.textAlign});

  final Track track;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Text(
        displayTrack(ref, track).artist,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
      );
}
