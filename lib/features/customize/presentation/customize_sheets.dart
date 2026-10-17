import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../models/track.dart';
import '../../../theme/kiji_tokens.dart';
import '../../../widgets/album_cover.dart';
import '../../playlists/domain/playlist.dart';
import '../../playlists/playlists_provider.dart';
import '../data/track_overrides.dart';
import 'pick_and_crop.dart';

/// Colores para elegir en una playlist.
const playlistColors = <Color>[
  Color(0xFF7C5CFF),
  Color(0xFF3DF5FF),
  Color(0xFFFF5C8A),
  Color(0xFFFFB84D),
  Color(0xFF4DFF91),
  Color(0xFF4D7CFF),
  Color(0xFFB04DFF),
  Color(0xFFFF6B4D),
];

void _say(BuildContext context, String message) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(message)));

/// "Personalizar" una canción (Tarea Z3): título, artista y foto que se
/// muestran en Kiji. El archivo de música no se toca.
Future<void> showCustomizeTrackSheet(BuildContext context, WidgetRef ref, Track track) {
  final overrides = ref.read(trackOverridesProvider);
  final current = overrides[track.id]?.applyTo(track) ?? track;
  final title = TextEditingController(text: current.title);
  final artist = TextEditingController(text: current.artist);
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(sheetContext).bottom),
      child: Consumer(
        builder: (context, ref, _) {
          final override = ref.watch(trackOverridesProvider)[track.id];
          final notifier = ref.read(trackOverridesProvider.notifier);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Personalizar canción', style: KijiText.title(size: 20)),
              const SizedBox(height: 4),
              const Text(
                'Solo cambia cómo se ve en Kiji. El archivo de música no se toca.',
                style: TextStyle(color: KijiColors.muted),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TrackArtwork(track: track, size: 72, radius: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final bytes = await pickAndCropImage(context);
                        if (bytes == null) return;
                        try {
                          await notifier.setCover(track, bytes);
                        } catch (error) {
                          messenger.showSnackBar(const SnackBar(content: Text('No se pudo usar esa imagen.')));
                        }
                      },
                      icon: const Icon(Icons.photo_outlined),
                      label: const Text('Cambiar foto'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: title,
                decoration: InputDecoration(labelText: 'Título', helperText: 'Original: ${track.title}'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: artist,
                decoration: InputDecoration(labelText: 'Artista', helperText: 'Original: ${track.artist}'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  notifier.setText(track, title: title.text, artist: artist.text);
                  Navigator.pop(sheetContext);
                  messenger.showSnackBar(const SnackBar(content: Text('Listo')));
                },
                child: const Text('Guardar'),
              ),
              if (override != null)
                TextButton.icon(
                  onPressed: () async {
                    await notifier.restoreOriginal(track);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                    messenger.showSnackBar(const SnackBar(content: Text('Volvió a como era')));
                  },
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('Restaurar original'),
                ),
            ],
          );
        },
      ),
    ),
  );
}

/// Carátula de una playlist: su foto propia, o su color, o la primera
/// canción, o el degradado de Kiji.
class PlaylistCover extends ConsumerWidget {
  const PlaylistCover({super.key, required this.playlist, this.size = 48, this.radius = 8});

  final Playlist playlist;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = playlist.colorValue == null ? KijiColors.violet : Color(playlist.colorValue!);
    final fallback = AlbumCover(color: color, size: size, borderRadius: radius, iconSize: size * 0.4);
    final cover = playlist.coverFile;
    final folder = ref.watch(coversFolderProvider).valueOrNull;
    if (cover != null && folder != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.file(
          File(p.join(folder.path, cover)),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
      );
    }
    if (playlist.colorValue != null || playlist.tracks.isEmpty) return fallback;
    return TrackArtwork(track: playlist.tracks.first, size: size, radius: radius);
  }
}

/// "Personalizar" una playlist (Tarea Z3): foto, nombre, descripción y color.
Future<void> showCustomizePlaylistSheet(BuildContext context, WidgetRef ref, Playlist playlist) {
  final name = TextEditingController(text: playlist.name);
  final description = TextEditingController(text: playlist.description ?? '');
  final messenger = ScaffoldMessenger.of(context);
  int? color = playlist.colorValue;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(sheetContext).bottom),
      child: Consumer(
        builder: (context, ref, _) {
          final current = ref.watch(playlistsProvider).where((pl) => pl.id == playlist.id).firstOrNull ?? playlist;
          final notifier = ref.read(playlistsProvider.notifier);
          final covers = ref.read(trackOverridesProvider.notifier).covers;
          return StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Personalizar playlist', style: KijiText.title(size: 20)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      PlaylistCover(playlist: current, size: 72, radius: 12),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final bytes = await pickAndCropImage(context);
                            if (bytes == null) return;
                            try {
                              final file = await covers.save('playlist-${playlist.id}', bytes);
                              final old = current.coverFile;
                              notifier.customize(playlist.id, coverFile: file);
                              await covers.delete(old);
                            } catch (error) {
                              messenger.showSnackBar(const SnackBar(content: Text('No se pudo usar esa imagen.')));
                            }
                          },
                          icon: const Icon(Icons.photo_outlined),
                          label: const Text('Cambiar foto'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: description,
                    maxLines: 3,
                    minLines: 1,
                    decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
                  ),
                  const SizedBox(height: 12),
                  Text('COLOR', style: KijiText.mono(size: 11)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final c in playlistColors)
                        GestureDetector(
                          onTap: () => setState(() => color = c.toARGB32()),
                          child: Container(
                            key: Key('color-${c.toARGB32()}'),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color == c.toARGB32() ? Colors.white : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      notifier.customize(
                        playlist.id,
                        name: name.text,
                        description: description.text,
                        colorValue: color,
                      );
                      Navigator.pop(sheetContext);
                      _say(context, 'Listo');
                    },
                    child: const Text('Guardar'),
                  ),
                  if (current.isCustomized)
                    TextButton.icon(
                      onPressed: () async {
                        final old = notifier.restoreOriginal(playlist.id);
                        await covers.delete(old);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        messenger.showSnackBar(const SnackBar(content: Text('Volvió a como era')));
                      },
                      icon: const Icon(Icons.restore_rounded),
                      label: Text('Restaurar original («${current.originalName ?? current.name}», sin foto ni color)'),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
