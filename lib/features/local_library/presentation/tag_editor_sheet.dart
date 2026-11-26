import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/track.dart';
import '../../../providers/local_library_provider.dart';
import '../../../theme/kiji_tokens.dart';
import '../../customize/presentation/customize_sheets.dart' show showCustomizeTrackSheet;
import '../../customize/presentation/pick_and_crop.dart';
import '../data/tag_editor.dart';

import 'package:kiji_player/l10n/l10n.dart';
import 'package:kiji_player/widgets/nocturne/kiji_sheet.dart';

/// «Editar etiquetas» de una canción del dispositivo: título, artista, álbum y portada, escritos en
/// el archivo (con copia y comprobación: si algo falla, el archivo queda como estaba).
Future<void> showTagEditorSheet(BuildContext context, WidgetRef ref, Track track) => showKijiSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _TagEditorSheet(track: track),
);

class _TagEditorSheet extends ConsumerStatefulWidget {
  const _TagEditorSheet({required this.track});

  final Track track;

  @override
  ConsumerState<_TagEditorSheet> createState() => _TagEditorSheetState();
}

class _TagEditorSheetState extends ConsumerState<_TagEditorSheet> {
  late final _title = TextEditingController(text: widget.track.title);
  late final _artist = TextEditingController(text: widget.track.artist);
  late final _album = TextEditingController(text: widget.track.album ?? '');
  Uint8List? _cover;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    _album.dispose();
    super.dispose();
  }

  String? _changed(TextEditingController c, String? before) {
    final text = c.text.trim();
    return text.isEmpty || text == (before ?? '') ? null : text;
  }

  Future<void> _save() async {
    final track = widget.track;
    final changes = TagChanges(
      title: _changed(_title, track.title),
      artist: _changed(_artist, track.artist),
      album: _changed(_album, track.album),
      cover: _cover,
    );
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final result = await writeTags(track.audioUrl, changes);
    if (result == TagEditResult.saved) ref.invalidate(localTracksProvider);
    if (!mounted) return;
    setState(() => _saving = false);
    final message = switch (result) {
      TagEditResult.saved => tx.etiquetasGuardadas,
      TagEditResult.unsupported => tx.etiquetasFormatoNoSoportado,
      TagEditResult.notAllowed => tx.etiquetasNoPermitido,
      TagEditResult.failed => tx.etiquetasNoSePudo,
    };
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          // Si el sistema no deja cambiar el archivo, se puede cambiar cómo se ve solo en Kiji.
          action: result == TagEditResult.notAllowed
              ? SnackBarAction(
                  label: tx.personalizar2,
                  onPressed: () {
                    final context = navigator.context;
                    if (context.mounted) showCustomizeTrackSheet(context, ref, track);
                  },
                )
              : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final supported = canEditTags(widget.track.audioUrl);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tx.editarEtiquetas, style: KijiText.title(size: 20)),
              const SizedBox(height: 4),
              Text(
                supported ? tx.editarEtiquetasNota : tx.etiquetasFormatoNoSoportado,
                style: TextStyle(color: KijiColors.muted),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('tag-title'),
                controller: _title,
                enabled: supported,
                decoration: InputDecoration(labelText: tx.titulo),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('tag-artist'),
                controller: _artist,
                enabled: supported,
                decoration: InputDecoration(labelText: tx.artista),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('tag-album'),
                controller: _album,
                enabled: supported,
                decoration: InputDecoration(labelText: tx.album),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const Key('tag-cover'),
                icon: Icon(_cover == null ? Icons.add_photo_alternate_outlined : Icons.check_rounded),
                label: Text(_cover == null ? tx.elegirPortada : tx.portadaElegida),
                onPressed: !supported
                    ? null
                    : () async {
                        final bytes = await pickAndCropImage(context);
                        if (bytes != null && mounted) setState(() => _cover = bytes);
                      },
              ),
              const SizedBox(height: 14),
              FilledButton(
                key: const Key('tag-save'),
                onPressed: !supported || _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(tx.guardar),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
