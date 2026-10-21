import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/track.dart';
import '../../providers/downloads_provider.dart';
import '../../providers/playback_provider.dart';
import '../../theme/kiji_tokens.dart';
import '../../widgets/nocturne/glass.dart';
import '../downloads/data/auto_downloads.dart';
import '../playlists/presentation/playlist_screens.dart';
import '../queue/presentation/track_actions.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Canciones elegidas en una lista (selección múltiple). Cada lista decide la clave de cada
/// fila: el id de la canción o, en una playlist, su lugar.
class TrackSelection extends ChangeNotifier {
  final _tracks = <String, Track>{};

  bool get active => _tracks.isNotEmpty;
  int get length => _tracks.length;
  Set<String> get keys => _tracks.keys.toSet();

  /// En el orden en que se eligieron.
  List<Track> get tracks => _tracks.values.toList();

  bool contains(String key) => _tracks.containsKey(key);

  void toggle(String key, Track track) {
    if (_tracks.remove(key) == null) _tracks[key] = track;
    notifyListeners();
  }

  /// "Seleccionar todas" (y, si ya estaban todas, ninguna).
  void toggleAll(Map<String, Track> all) {
    if (all.keys.every(_tracks.containsKey)) {
      _tracks.clear();
    } else {
      _tracks.addAll(all);
    }
    notifyListeners();
  }

  void clear() {
    if (_tracks.isEmpty) return;
    _tracks.clear();
    notifyListeners();
  }
}

/// "Quitar" de cada lista: de la playlist, borrar descargas…
class SelectionRemoveAction {
  const SelectionRemoveAction({required this.label, required this.icon, required this.onRemove});

  final String label;
  final IconData icon;

  /// Recibe las claves elegidas y las canciones; la lista hace lo suyo (con deshacer o con
  /// confirmación).
  final Future<void> Function(Set<String> keys, List<Track> tracks) onRemove;
}

/// Casilla al principio de cada fila mientras se elige.
class SelectionCheck extends StatelessWidget {
  const SelectionCheck({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: KijiMotion.fast,
    width: 26,
    height: 26,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: selected ? KijiColors.accentGradientDiagonal : null,
      border: selected ? null : Border.all(color: KijiColors.muted, width: 1.5),
    ),
    child: selected ? Icon(Icons.check_rounded, size: 18, color: KijiColors.onAccent) : null,
  );
}

/// Barra de la selección múltiple: cuántas, todas, y las acciones (playlist, descargar, cola,
/// quitar). Se muestra arriba de la lista mientras haya alguna elegida.
class SelectionBar extends ConsumerWidget {
  const SelectionBar({super.key, required this.selection, required this.all, this.remove});

  final TrackSelection selection;

  /// Todas las filas visibles, para "Seleccionar todas".
  final Map<String, Track> all;
  final SelectionRemoveAction? remove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListenableBuilder(
      listenable: selection,
      builder: (context, _) {
        if (!selection.active) return const SizedBox.shrink();
        final tracks = selection.tracks;
        void say(String message) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));

        Future<void> done(Future<void> Function() action) async {
          await action();
          selection.clear();
        }

        final actions = <_BarAction>[
          _BarAction(Icons.library_add_rounded, tx.seleccionAPlaylist, () async {
            await showAddToPlaylistSheet(context, ref, tracks);
            selection.clear();
          }),
          _BarAction(Icons.download_rounded, tx.seleccionDescargar, () => downloadSelection(context, ref, selection)),
          _BarAction(
            Icons.playlist_play_rounded,
            tx.seleccionAContinuacion,
            () => done(() async {
              // Si no sonaba nada, empiezan a sonar ya (igual que con una sola): se avisa eso.
              final idle = ref.read(playbackProvider).track == null;
              await ref.read(playbackProvider.notifier).playNextAll(tracks);
              say(idle ? tx.nEmpiezanASonar(tracks.length) : tx.nSuenanDespues(tracks.length));
            }),
          ),
          _BarAction(
            Icons.playlist_add_rounded,
            tx.seleccionAlFinal,
            () => done(() async {
              final idle = ref.read(playbackProvider).track == null;
              await ref.read(playbackProvider.notifier).addAllToQueue(tracks);
              say(idle ? tx.nEmpiezanASonar(tracks.length) : tx.nAlFinalDeLaCola(tracks.length));
            }),
          ),
          if (remove case final remove?)
            _BarAction(remove.icon, remove.label, () async {
              await remove.onRemove(selection.keys, tracks);
              selection.clear();
            }),
          // Con una sola, el resto del menú de siempre (personalizar, compartir…).
          if (tracks.length == 1)
            _BarAction(Icons.more_horiz_rounded, tx.seleccionMas, () async {
              final track = tracks.single;
              selection.clear();
              await showTrackActions(context, ref, track);
            }),
        ];

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Glass(
            radius: KijiRadii.tile,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: tx.quitarSeleccion,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: selection.clear,
                      ),
                      Expanded(
                        child: Text(
                          tx.nSeleccionadas(selection.length),
                          style: KijiText.title(size: 17),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: tx.seleccionarTodas,
                        icon: Icon(
                          all.keys.every(selection.contains) ? Icons.deselect_rounded : Icons.select_all_rounded,
                        ),
                        onPressed: () => selection.toggleAll(all),
                      ),
                    ],
                  ),
                  // Los botones se reparten el ancho; si no entran ni a 64 px, se desplazan.
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = (constraints.maxWidth / actions.length).clamp(64.0, 96.0);
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [for (final a in actions) _BarButton(action: a, width: width)]),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Descargar las elegidas: se confirma (cuántas, y cuántas se saltean) y van a la cola de
/// descargas automáticas, que respeta "solo con WiFi" y el espacio.
Future<void> downloadSelection(BuildContext context, WidgetRef ref, TrackSelection selection) async {
  final downloads = ref.read(downloadsProvider);
  final tracks = selection.tracks;
  final toDownload = [
    for (final track in tracks)
      if (track.youtubeVideoId case final id?)
        if (!downloads.completed.containsKey(id)) track,
  ];
  final messenger = ScaffoldMessenger.of(context);
  if (toDownload.isEmpty) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(tx.nadaParaDescargar)));
    selection.clear();
    return;
  }
  final skipped = tracks.length - toDownload.length;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(tx.descargarNCanciones(toDownload.length)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tx.descargarNCancionesTexto),
          if (skipped > 0) ...[
            const SizedBox(height: 10),
            Text(tx.nSeSaltean(skipped), style: TextStyle(color: KijiColors.muted)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(tx.cancelar)),
        FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(tx.descargar)),
      ],
    ),
  );
  if (ok != true) return;
  ref.read(autoDownloadsProvider.notifier).enqueue(toDownload);
  selection.clear();
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(tx.nPorBajarse(toDownload.length))));
}

/// Borrar las descargas elegidas (solo el audio guardado en Kiji), con confirmación.
Future<void> deleteSelectedDownloads(BuildContext context, WidgetRef ref, List<Track> tracks) async {
  final completed = ref.read(downloadsProvider).completed;
  final ids = [
    for (final t in tracks)
      if (t.youtubeVideoId case final id? when completed.containsKey(id)) id,
  ];
  if (ids.isEmpty) return;
  final messenger = ScaffoldMessenger.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(tx.borrarNDescargas(ids.length)),
      content: Text(tx.borrarNDescargasTexto),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(tx.cancelar)),
        FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(tx.borrar)),
      ],
    ),
  );
  if (ok != true) return;
  final notifier = ref.read(downloadsProvider.notifier);
  for (final id in ids) {
    await notifier.delete(id);
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(tx.nDescargasBorradas(ids.length))));
}

class _BarAction {
  const _BarAction(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final Future<void> Function() onTap;
}

class _BarButton extends StatelessWidget {
  const _BarButton({required this.action, required this.width});

  final _BarAction action;
  final double width;

  /// Tamaño de letra para que la palabra más larga ("continuación") entre entera en [width]:
  /// 12 px si entra; si no, lo justo, y nunca menos de 9.
  double _fontSize(BuildContext context) {
    const base = 12.0;
    final scaler = MediaQuery.textScalerOf(context);
    var widest = 0.0;
    for (final word in action.label.split(' ')) {
      final painter = TextPainter(
        text: TextSpan(text: word, style: DefaultTextStyle.of(context).style.copyWith(fontSize: base)),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    final room = width - 12;
    return widest <= room ? base : (base * room / widest).clamp(9.0, base);
  }

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: action.onTap,
    child: SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          children: [
            Icon(action.icon, size: 26, color: KijiColors.cyan),
            const SizedBox(height: 4),
            Text(
              action.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: _fontSize(context), height: 1.15),
            ),
          ],
        ),
      ),
    ),
  );
}
