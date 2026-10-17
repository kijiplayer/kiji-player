// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivo de referencia: ui/component/LyricsV2.kt (línea actual resaltada, avance solo, tocar
// una línea para ir a ese momento).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/track.dart';
import '../../../providers/appearance_provider.dart';
import '../../../providers/playback_provider.dart';
import '../../../theme/kiji_tokens.dart';
import '../../../widgets/nocturne/glass.dart';
import '../data/lrclib_client.dart';
import '../domain/lyrics.dart';
import '../lyrics_provider.dart';
import '../../customize/presentation/track_text.dart';

/// Letra de la canción que suena (Tarea I).
class LyricsScreen extends ConsumerWidget {
  const LyricsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const LyricsScreen()),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(playbackProvider.select((p) => p.track));
    if (track == null) {
      return const Scaffold(body: Center(child: Text('Elige una canción')));
    }
    // La duración real (si ya se sabe) ayuda a LRCLIB a elegir la versión correcta.
    final knownDuration = ref.read(playbackProvider).duration.inMilliseconds;
    final request = lyricsRequestFor(
      knownDuration > 0 && track.durationMs == 0 ? track.copyWith(durationMs: knownDuration) : track,
    );
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
                _Header(track: track),
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
                        return const _Message(
                          icon: Icons.lyrics_outlined,
                          text: 'No encontramos la letra de esta canción.',
                        );
                      }
                      return Column(
                        children: [
                          Expanded(
                            child: value.isSynced
                                ? SyncedLyricsView(lines: value.synced)
                                : _PlainLyrics(text: value.plain!),
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

class _Header extends StatelessWidget {
  const _Header({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                TrackTitleText(track, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: KijiText.title(size: 18)),
                TrackArtistText(track, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: KijiColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Letra sincronizada: resalta la línea que suena, avanza sola y al tocar una
/// línea va a ese momento. Si el usuario mueve la lista, deja de seguir unos
/// segundos para no pelear con su dedo.
class SyncedLyricsView extends ConsumerStatefulWidget {
  const SyncedLyricsView({super.key, required this.lines});

  final List<LyricLine> lines;

  @override
  ConsumerState<SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends ConsumerState<SyncedLyricsView> {
  static const _pauseFollowAfterScroll = Duration(seconds: 4);

  late List<GlobalKey> _keys = _makeKeys();
  int _shown = -2;
  DateTime? _userScrolledAt;

  List<GlobalKey> _makeKeys() => List.generate(widget.lines.length, (_) => GlobalKey());

  @override
  void didUpdateWidget(SyncedLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lines != widget.lines) {
      _keys = _makeKeys();
      _shown = -2;
    }
  }

  void _follow(int index, bool reduceMotion) {
    if (index == _shown) return;
    _shown = index;
    final scrolled = _userScrolledAt;
    if (scrolled != null && DateTime.now().difference(scrolled) < _pauseFollowAfterScroll) return;
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

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(playbackProvider.select((p) => p.position));
    final current = currentLineIndex(widget.lines, position);
    final calm = reduceMotion(context, ref);
    _follow(current, calm);

    return NotificationListener<UserScrollNotification>(
      onNotification: (_) {
        _userScrolledAt = DateTime.now();
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 160),
        itemCount: widget.lines.length,
        itemBuilder: (context, index) {
          final line = widget.lines[index];
          final isCurrent = index == current;
          final isPast = index < current;
          return InkWell(
            key: _keys[index],
            borderRadius: BorderRadius.circular(KijiRadii.tile),
            onTap: () => ref.read(playbackProvider.notifier).seekTo(line.time),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: AnimatedDefaultTextStyle(
                duration: calm ? Duration.zero : KijiMotion.fast,
                style: KijiText.title(
                  size: isCurrent ? 26 : 22,
                  weight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                  color: isCurrent
                      ? Colors.white
                      : KijiColors.muted.withValues(alpha: isPast ? 0.45 : 0.75),
                ),
                child: Text(
                  line.text.isEmpty ? '♪' : line.text,
                  semanticsLabel: isCurrent ? 'Ahora: ${line.text}' : line.text,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PlainLyrics extends StatelessWidget {
  const _PlainLyrics({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LETRA SIN SINCRONIZAR', style: KijiText.mono(size: 10)),
          const SizedBox(height: 12),
          Text(text, style: KijiText.title(size: 20, weight: FontWeight.w500)),
        ],
      ),
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
