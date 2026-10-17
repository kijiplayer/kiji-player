// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivo de referencia: ui/component/LyricsV2.kt (línea actual resaltada, avance solo, tocar
// una línea para ir a ese momento) y ui/menu/LyricsMenu.kt (buscar a mano, desfase).

import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/track.dart';
import '../../../providers/appearance_provider.dart';
import '../../../providers/playback_provider.dart';
import '../../../theme/kiji_tokens.dart';
import '../../../widgets/global_mini_player.dart';
import '../../../widgets/nocturne/glass.dart';
import '../../customize/presentation/track_text.dart';
import '../../settings/data/settings_store.dart';
import '../data/lrclib_client.dart';
import '../data/lyrics_repository.dart';
import '../domain/lyrics.dart';
import '../lyrics_provider.dart';
import '../../translation/presentation/translated_lyrics.dart';
import 'lyrics_share.dart';

/// Desfase que se está ajustando ahora (null = no se está ajustando).
final _adjustingOffsetProvider = StateProvider.autoDispose<bool>((ref) => false);

/// Letra de la canción que suena (Tareas I y Z4).
class LyricsScreen extends ConsumerWidget {
  const LyricsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: KijiRoutes.lyrics),
          builder: (_) => const LyricsScreen(),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(playbackProvider.select((p) => p.track));
    if (track == null) {
      return const Scaffold(body: Center(child: Text('Elige una canción')));
    }
    final request = _requestFor(ref, track);
    final lyrics = ref.watch(lyricsProvider(request));

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [track.coverColor.withValues(alpha: 0.35), KijiColors.background],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _Header(track: track, request: request, lyrics: lyrics.valueOrNull),
                Expanded(
                  child: lyrics.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, _) => _Message(
                      icon: Icons.cloud_off_rounded,
                      text: error is LyricsUnavailableException
                          ? 'No se pudo buscar la letra (${error.reason}). Probá de nuevo en un rato.'
                          : 'No se pudo buscar la letra.',
                      actionLabel: 'Reintentar',
                      onAction: () => ref.invalidate(lyricsProvider(request)),
                    ),
                    data: (value) {
                      if (value.instrumental) {
                        return const _Message(icon: Icons.piano_rounded, text: 'Instrumental ♪');
                      }
                      if (value.isEmpty) {
                        return _Message(
                          icon: Icons.lyrics_outlined,
                          text: 'No encontramos la letra de esta canción en ninguna fuente.',
                          actionLabel: 'Buscar a mano',
                          onAction: () => searchLyricsManually(context, ref, request),
                        );
                      }
                      Widget body(List<String?>? translations) => value.isSynced
                          ? SyncedLyricsView(
                              lines: value.synced,
                              track: track,
                              trackId: request.id,
                              translations: translations,
                            )
                          : PlainLyricsView(text: value.plain!, track: track, translations: translations);
                      final translating = ref.watch(lyricsTranslationOnProvider);
                      return Column(
                        children: [
                          const _OffsetBar(),
                          Expanded(
                            child: translating
                                ? TranslatedLyrics(
                                    trackId: request.id,
                                    lines: value.isSynced
                                        ? [for (final l in value.synced) l.text]
                                        : value.plain!.split('\n'),
                                    builder: body,
                                  )
                                : body(null),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'LETRA: ${value.source?.label.toUpperCase() ?? ''}',
                              style: KijiText.mono(size: 10),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// La duración real (si ya se sabe) ayuda a las fuentes a elegir la versión
/// correcta.
LyricsRequest _requestFor(WidgetRef ref, Track track) {
  final knownDuration = ref.read(playbackProvider).duration.inMilliseconds;
  return lyricsRequestFor(
    knownDuration > 0 && track.durationMs == 0 ? track.copyWith(durationMs: knownDuration) : track,
  );
}

void _say(BuildContext context, String message) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(message)));

/// "Buscar a mano": otro título o artista, en todas las fuentes.
Future<void> searchLyricsManually(BuildContext context, WidgetRef ref, LyricsRequest request) async {
  final title = TextEditingController(text: request.title);
  final artist = TextEditingController(text: request.artist);
  final go = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Buscar la letra a mano'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Título')),
          TextField(controller: artist, decoration: const InputDecoration(labelText: 'Artista')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Buscar')),
      ],
    ),
  );
  if (go != true || !context.mounted) return;
  _say(context, 'Buscando en todas las fuentes…');
  try {
    final found = await ref.read(lyricsRepositoryProvider).search(
          (
            id: request.id,
            title: title.text.trim(),
            artist: artist.text.trim(),
            album: null,
            durationMs: request.durationMs,
            localPath: null,
          ),
          disabled: ref.read(settingsProvider).disabledLyricsSources,
        );
    if (!context.mounted) return;
    if (found.isEmpty) {
      _say(context, 'Tampoco se encontró con esos datos.');
    } else {
      ref.invalidate(lyricsProvider(request));
      ref.invalidate(lyricsOffsetProvider(request.id));
      _say(context, 'Encontrada en ${found.source?.label ?? 'una fuente'}.');
    }
  } on LyricsUnavailableException catch (error) {
    if (context.mounted) _say(context, 'No se pudo buscar (${error.reason}).');
  }
}

/// "Importar un .lrc" para la canción que suena.
Future<void> importLrc(BuildContext context, WidgetRef ref, LyricsRequest request) async {
  final picked = await FilePicker.pickFiles(dialogTitle: 'Elegí un archivo .lrc', type: FileType.any);
  if (picked.isEmpty || !context.mounted) return;
  try {
    final text = utf8.decode(await picked.first.readAsBytes(), allowMalformed: true);
    await ref.read(lyricsRepositoryProvider).importText(request.id, text);
    ref.invalidate(lyricsProvider(request));
    ref.invalidate(lyricsOffsetProvider(request.id));
    if (context.mounted) _say(context, 'Letra importada.');
  } catch (error) {
    if (context.mounted) _say(context, 'Ese archivo no tiene una letra que Kiji entienda.');
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.track, required this.request, required this.lyrics});

  final Track track;
  final LyricsRequest request;
  final Lyrics? lyrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          GlassIconButton(
            icon: Icons.keyboard_arrow_down_rounded,
            tooltip: 'Cerrar la letra',
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrackTitleText(track, maxLines: 1, overflow: TextOverflow.ellipsis, style: KijiText.title(size: 18)),
                TrackArtistText(track,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: KijiColors.muted)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Más opciones de la letra',
            onSelected: (action) {
              switch (action) {
                case 'search':
                  searchLyricsManually(context, ref, request);
                case 'import':
                  importLrc(context, ref, request);
                case 'offset':
                  ref.read(_adjustingOffsetProvider.notifier).state = true;
                case 'share':
                  ref.read(lyricsSelectionModeProvider.notifier).state = true;
                case 'translate':
                  final on = ref.read(lyricsTranslationOnProvider);
                  ref.read(lyricsTranslationOnProvider.notifier).state = !on;
              }
            },
            itemBuilder: (context) => [
              if (!(lyrics?.isEmpty ?? true))
                PopupMenuItem(
                  value: 'translate',
                  child: Text(ref.watch(lyricsTranslationOnProvider) ? 'Quitar la traducción' : 'Traducir la letra'),
                ),
              const PopupMenuItem(value: 'search', child: Text('Buscar a mano')),
              const PopupMenuItem(value: 'import', child: Text('Importar un .lrc')),
              if (lyrics?.isSynced ?? false) const PopupMenuItem(value: 'offset', child: Text('Ajustar el desfase')),
              if (!(lyrics?.isEmpty ?? true))
                const PopupMenuItem(value: 'share', child: Text('Elegir líneas para compartir')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Barra para ajustar el desfase de a ±0,5 s (se guarda por canción).
class _OffsetBar extends ConsumerWidget {
  const _OffsetBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(_adjustingOffsetProvider)) return const SizedBox.shrink();
    final track = ref.watch(playbackProvider.select((p) => p.track));
    if (track == null) return const SizedBox.shrink();
    final offset = ref.watch(lyricsOffsetProvider(track.id)).valueOrNull ?? Duration.zero;
    Future<void> move(int ms) async {
      await ref.read(lyricsRepositoryProvider).setOffset(track.id, offset + Duration(milliseconds: ms));
      ref.invalidate(lyricsOffsetProvider(track.id));
    }

    final seconds = offset.inMilliseconds / 1000;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Glass(
        blur: false,
        radius: KijiRadii.tile,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(onPressed: () => move(-500), icon: const Text('−0,5 s'), tooltip: 'La letra va después'),
              Expanded(
                child: Text(
                  offset == Duration.zero
                      ? 'Sin desfase'
                      : '${seconds > 0 ? '+' : ''}${seconds.toStringAsFixed(1).replaceAll('.', ',')} s',
                  textAlign: TextAlign.center,
                  style: KijiText.mono(size: 13, color: KijiColors.cyan),
                ),
              ),
              IconButton(onPressed: () => move(500), icon: const Text('+0,5 s'), tooltip: 'La letra va antes'),
              TextButton(
                onPressed: () => ref.read(_adjustingOffsetProvider.notifier).state = false,
                child: const Text('Listo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modo "elegir líneas para compartir".
final lyricsSelectionModeProvider = StateProvider.autoDispose<bool>((ref) => false);

/// Letra sincronizada: resalta la línea que suena, avanza sola y al tocar una
/// línea va a ese momento. Si el usuario se aleja por la letra, deja de
/// seguir y aparece "Volver a la canción" (Tarea Z4). Mantener apretada una
/// línea entra en el modo de elegir líneas para compartir.
class SyncedLyricsView extends ConsumerStatefulWidget {
  const SyncedLyricsView({
    super.key,
    required this.lines,
    this.track,
    this.trackId,
    this.translations,
  });

  final List<LyricLine> lines;
  final Track? track;
  final String? trackId;

  /// Traducción de cada línea (mismo orden), o null.
  final List<String?>? translations;

  @override
  ConsumerState<SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends ConsumerState<SyncedLyricsView> {
  /// Sin tocar nada este tiempo, vuelve a seguir la canción solo.
  static const _pauseFollowAfterScroll = Duration(seconds: 8);

  late List<GlobalKey> _keys = _makeKeys();
  int _shown = -2;
  bool _away = false;
  Timer? _backTimer;
  final Set<int> _selected = {};

  List<GlobalKey> _makeKeys() => List.generate(widget.lines.length, (_) => GlobalKey());

  @override
  void didUpdateWidget(SyncedLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lines != widget.lines) {
      _keys = _makeKeys();
      _shown = -2;
      _selected.clear();
    }
  }

  @override
  void dispose() {
    _backTimer?.cancel();
    super.dispose();
  }

  void _scrollTo(int index, bool reduceMotion) {
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _keys[index].currentContext;
      if (context == null || !mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.35,
        duration: reduceMotion ? Duration.zero : KijiMotion.normal,
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _follow(int index, bool reduceMotion) {
    if (index == _shown) return;
    _shown = index;
    if (_away) return;
    _scrollTo(index, reduceMotion);
  }

  void _backToSong(int current, bool reduceMotion) {
    _backTimer?.cancel();
    setState(() {
      _away = false;
    });
    _shown = current;
    _scrollTo(current, reduceMotion);
  }

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(playbackProvider.select((p) => p.position));
    final offset = widget.trackId == null
        ? Duration.zero
        : ref.watch(lyricsOffsetProvider(widget.trackId!)).valueOrNull ?? Duration.zero;
    final current = currentLineIndex(widget.lines, position + offset);
    final calm = reduceMotion(context, ref);
    final selecting = ref.watch(lyricsSelectionModeProvider);
    _follow(current, calm);

    return Stack(
      children: [
        NotificationListener<UserScrollNotification>(
          onNotification: (_) {
            if (!_away) setState(() => _away = true);
            _backTimer?.cancel();
            _backTimer = Timer(_pauseFollowAfterScroll, () {
              if (mounted) _backToSong(_shown, calm);
            });
            return false;
          },
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(24, 160, 24, selecting ? 220 : 160),
            itemCount: widget.lines.length,
            itemBuilder: (context, index) {
              final line = widget.lines[index];
              final isCurrent = index == current;
              final isPast = index < current;
              final translation = widget.translations != null && index < widget.translations!.length
                  ? widget.translations![index]
                  : null;
              final selected = _selected.contains(index);
              return InkWell(
                key: _keys[index],
                borderRadius: BorderRadius.circular(KijiRadii.tile),
                onTap: selecting
                    ? () => setState(() => selected ? _selected.remove(index) : _selected.add(index))
                    : () => ref.read(playbackProvider.notifier).seekTo(line.time - offset),
                onLongPress: line.text.isEmpty
                    ? null
                    : () {
                        ref.read(lyricsSelectionModeProvider.notifier).state = true;
                        setState(() => _selected.add(index));
                      },
                child: Container(
                  decoration: selected
                      ? BoxDecoration(
                          color: KijiColors.violet.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(KijiRadii.tile),
                        )
                      : null,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: calm ? Duration.zero : KijiMotion.fast,
                        style: KijiText.title(
                          size: isCurrent ? 26 : 22,
                          weight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                          color: isCurrent ? Colors.white : KijiColors.muted.withValues(alpha: isPast ? 0.45 : 0.75),
                        ),
                        child: Text(
                          line.text.isEmpty ? '♪' : line.text,
                          semanticsLabel: isCurrent ? 'Ahora: ${line.text}' : line.text,
                        ),
                      ),
                      if (translation != null && translation.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            translation,
                            style: TextStyle(
                              color: KijiColors.cyan.withValues(alpha: isCurrent ? 0.95 : 0.6),
                              fontSize: isCurrent ? 17 : 15,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_away && !selecting)
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Center(
              child: FilledButton.icon(
                key: const Key('back-to-song'),
                onPressed: () => _backToSong(current, calm),
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Volver a la canción'),
              ),
            ),
          ),
        if (selecting && widget.track != null)
          _SelectionBar(
            count: _selected.length,
            onCancel: () {
              setState(_selected.clear);
              ref.read(lyricsSelectionModeProvider.notifier).state = false;
            },
            lines: () => [for (final i in (_selected.toList()..sort())) widget.lines[i].text],
            track: widget.track!,
          ),
      ],
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.count, required this.onCancel, required this.lines, required this.track});

  final int count;
  final VoidCallback onCancel;
  final List<String> Function() lines;
  final Track track;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: Glass(
        radius: KijiRadii.card,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                count == 0 ? 'Tocá las líneas que querés compartir' : '$count ${count == 1 ? 'línea elegida' : 'líneas elegidas'}',
                style: const TextStyle(color: KijiColors.muted),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: count == 0 ? null : () => shareLyricsText(lines(), track),
                    icon: const Icon(Icons.text_snippet_outlined),
                    label: const Text('Como texto'),
                  ),
                  FilledButton.icon(
                    onPressed: count == 0 ? null : () => showLyricsCardDialog(context, lines(), track),
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Como imagen'),
                  ),
                  TextButton(onPressed: onCancel, child: const Text('Cancelar')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Letra sin tiempos. Mantener apretada una línea permite compartir.
class PlainLyricsView extends ConsumerStatefulWidget {
  const PlainLyricsView({super.key, required this.text, required this.track, this.translations});

  final String text;
  final Track track;

  /// Traducción de cada línea (mismo orden), o null.
  final List<String?>? translations;

  @override
  ConsumerState<PlainLyricsView> createState() => _PlainLyricsViewState();
}

class _PlainLyricsViewState extends ConsumerState<PlainLyricsView> {
  final Set<int> _selected = {};

  @override
  Widget build(BuildContext context) {
    final lines = widget.text.split('\n');
    final selecting = ref.watch(lyricsSelectionModeProvider);
    return Stack(
      children: [
        ListView.builder(
          padding: EdgeInsets.fromLTRB(24, 16, 24, selecting ? 220 : 40),
          itemCount: lines.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('LETRA SIN SINCRONIZAR', style: KijiText.mono(size: 10)),
              );
            }
            final i = index - 1;
            final selected = _selected.contains(i);
            return GestureDetector(
              onLongPress: lines[i].trim().isEmpty
                  ? null
                  : () {
                      ref.read(lyricsSelectionModeProvider.notifier).state = true;
                      setState(() => _selected.add(i));
                    },
              onTap: selecting && lines[i].trim().isNotEmpty
                  ? () => setState(() => selected ? _selected.remove(i) : _selected.add(i))
                  : null,
              child: Container(
                color: selected ? KijiColors.violet.withValues(alpha: 0.18) : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lines[i], style: KijiText.title(size: 20, weight: FontWeight.w500)),
                    if (widget.translations != null &&
                        i < widget.translations!.length &&
                        (widget.translations![i]?.isNotEmpty ?? false))
                      Text(widget.translations![i]!, style: const TextStyle(color: KijiColors.cyan, fontSize: 15)),
                  ],
                ),
              ),
            );
          },
        ),
        if (selecting)
          _SelectionBar(
            count: _selected.length,
            onCancel: () {
              setState(_selected.clear);
              ref.read(lyricsSelectionModeProvider.notifier).state = false;
            },
            lines: () => [for (final i in (_selected.toList()..sort())) lines[i]],
            track: widget.track,
          ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.actionLabel, this.onAction});

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: KijiColors.muted),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: KijiColors.muted)),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
