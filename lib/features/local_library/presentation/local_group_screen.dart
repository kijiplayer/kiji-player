import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/track.dart';
import '../../../providers/playback_provider.dart';
import '../../../theme/app_theme.dart' show KijiSelected;
import '../../../theme/kiji_tokens.dart';
import '../../../utils/duration_formatter.dart';
import '../../../widgets/album_cover.dart';
import '../../customize/presentation/pick_and_crop.dart';
import '../../customize/presentation/track_text.dart';
import '../../../widgets/nocturne/kiji_sheet.dart';
import '../data/group_covers.dart';
import '../../queue/presentation/track_actions.dart';
import '../../selection/track_selection.dart';
import '../domain/local_groups.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Qué es un grupo de la música del equipo (cambia la cabecera y si se ven los números de pista).
enum LocalGroupKind { artist, album, folder }

/// Un artista, un álbum (con sus pistas en orden) o una carpeta: Reproducir, Aleatorio y sus
/// canciones, con la selección múltiple de siempre.
class LocalGroupScreen extends ConsumerStatefulWidget {
  const LocalGroupScreen({super.key, required this.group, required this.kind});

  final LocalGroup group;
  final LocalGroupKind kind;

  static Future<void> open(BuildContext context, LocalGroup group, LocalGroupKind kind) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LocalGroupScreen(group: group, kind: kind),
    ),
  );

  @override
  ConsumerState<LocalGroupScreen> createState() => _LocalGroupScreenState();
}

class _LocalGroupScreenState extends ConsumerState<LocalGroupScreen> {
  final _selection = TrackSelection();

  @override
  void initState() {
    super.initState();
    _selection.addListener(_onSelection);
  }

  void _onSelection() => setState(() {});

  @override
  void dispose() {
    _selection
      ..removeListener(_onSelection)
      ..dispose();
    super.dispose();
  }

  List<Track> get _tracks => widget.group.tracks;

  /// "Elegir portada" (o quitar la elegida) para este álbum o carpeta.
  Future<void> _chooseCover() async {
    final key = widget.group.key;
    final chosen = ref.read(groupCoversProvider).containsKey(key);
    final remove = chosen &&
        await showKijiSheet<bool>(
              context: context,
              builder: (sheet) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.add_photo_alternate_outlined),
                      title: Text(tx.elegirOtraPortada),
                      onTap: () => Navigator.pop(sheet, false),
                    ),
                    ListTile(
                      key: const Key('local-group-cover-clear'),
                      leading: const Icon(Icons.hide_image_outlined),
                      title: Text(tx.quitarLaPortadaElegida),
                      onTap: () => Navigator.pop(sheet, true),
                    ),
                  ],
                ),
              ),
            ) ==
            true;
    if (!mounted) return;
    if (remove) {
      await ref.read(groupCoversProvider.notifier).clear(key);
      return;
    }
    final bytes = await pickAndCropImage(context);
    if (bytes == null || !mounted) return;
    try {
      await ref.read(groupCoversProvider.notifier).set(key, bytes);
    } catch (error) {
      debugPrint('=== PORTADAS: no se pudo guardar la portada elegida: ${error.runtimeType} ===');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tx.noSePudoAbrirEsaImagen)));
    }
  }

  void _tap(int index) {
    final track = _tracks[index];
    if (_selection.tapWithKeys(track.id, track, [for (final t in _tracks) MapEntry(t.id, t)])) return;
    if (_selection.active) {
      _selection.toggle(track.id, track);
    } else {
      ref.read(playbackProvider.notifier).playQueue(_tracks, startIndex: index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final album = widget.kind == LocalGroupKind.album;
    final details = [
      if (group.subtitle case final s? when widget.kind != LocalGroupKind.folder) s,
      if (group.year case final y?) '$y',
      tx.nCanciones(group.tracks.length),
    ].join(' · ');
    return Scaffold(
      appBar: AppBar(
        title: Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          // Álbum o carpeta: elegir su portada con el selector de fotos del sistema (sin permisos).
          if (widget.kind != LocalGroupKind.artist)
            IconButton(
              key: const Key('local-group-cover'),
              tooltip: tx.elegirPortada,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              onPressed: _chooseCover,
            ),
        ],
      ),
      body: Stack(
        children: [
          ListView.builder(
            padding: const EdgeInsets.only(bottom: 180),
            itemCount: _tracks.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      TrackArtwork(track: group.cover, size: 112, radius: 12),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.name,
                              style: KijiText.title(size: 20),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(details, style: TextStyle(color: KijiColors.muted, fontSize: 13)),
                            if (widget.kind == LocalGroupKind.folder && group.subtitle != null)
                              Text(
                                group.subtitle!,
                                style: KijiText.mono(size: 10),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                FilledButton.icon(
                                  key: const Key('local-group-play'),
                                  onPressed: () => ref.read(playbackProvider.notifier).playQueue(_tracks),
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: Text(tx.reproducir),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      ref.read(playbackProvider.notifier).playQueue([..._tracks]..shuffle()),
                                  icon: const Icon(Icons.shuffle_rounded),
                                  label: Text(tx.aleatorio),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
              final index = i - 1;
              final track = _tracks[index];
              final selected = _selection.contains(track.id);
              return GestureDetector(
                onSecondaryTap: () => showTrackActions(context, ref, track),
                child: ListTile(
                  selected: selected,
                  selectedTileColor: KijiSelected.tile,
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selection.active) ...[SelectionCheck(selected: selected), const SizedBox(width: 10)],
                      // Un álbum muestra el número de pista; lo demás, la portada.
                      if (album)
                        SizedBox(
                          width: 28,
                          child: Text(
                            track.trackNumber == null ? '·' : '${track.trackNumber}',
                            textAlign: TextAlign.center,
                            style: KijiText.mono(size: 13),
                          ),
                        )
                      else
                        TrackArtwork(track: track, size: 44, radius: 8),
                    ],
                  ),
                  title: TrackTitleText(track, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    [if (!album || track.artist != group.subtitle) track.artist, if (!album) ?track.album].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: KijiColors.muted, fontSize: 12),
                  ),
                  trailing: track.durationMs > 0
                      ? Text(formatDuration(Duration(milliseconds: track.durationMs)), style: KijiText.mono(size: 11))
                      : null,
                  onTap: () => _tap(index),
                  onLongPress: () => _selection.toggle(track.id, track),
                ),
              );
            },
          ),
          if (_selection.active)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SelectionBar(selection: _selection, all: {for (final t in _tracks) t.id: t}),
            ),
        ],
      ),
    );
  }
}
