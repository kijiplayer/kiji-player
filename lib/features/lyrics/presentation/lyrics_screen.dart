// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivo de referencia: ui/component/LyricsV2.kt (línea actual resaltada, avance solo, tocar
// una línea para ir a ese momento) y ui/menu/LyricsMenu.kt (buscar a mano, desfase).

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/track.dart';
import '../../../providers/appearance_provider.dart';
import '../../../providers/playback_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/kiji_tokens.dart';
import '../../../screens/player/player_motion.dart';
import '../../../widgets/album_cover.dart';
import '../../../widgets/global_mini_player.dart';
import '../../../widgets/nocturne/glass.dart';
import '../../customize/presentation/track_text.dart';
import '../../settings/data/settings_store.dart';
import '../../settings/domain/app_settings.dart';
import '../data/lrclib_client.dart';
import '../data/lyrics_repository.dart';
import '../domain/lyrics.dart';
import '../lyrics_provider.dart';
import '../../translation/presentation/translate_sheet.dart';
import '../../translation/presentation/translated_lyrics.dart';
import 'lyrics_menu_sheet.dart';
import 'lyrics_side_panel.dart';
import 'lyrics_views.dart';
import 'lyrics_share.dart';
import 'lyrics_sources_sheet.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Desfase que se está ajustando ahora (null = no se está ajustando).
final _adjustingOffsetProvider = StateProvider.autoDispose<bool>((ref) => false);

/// Letra de la canción que suena.
/// La pantalla de la letra es siempre oscura (se lee sobre la carátula difuminada), aunque el
/// resto de Kiji use el tema claro.
const _dark = KijiPalette.nocturne;

class LyricsScreen extends ConsumerWidget {
  const LyricsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    PageRouteBuilder<void>(
      settings: const RouteSettings(name: KijiRoutes.lyrics),
      transitionDuration: KijiMotion.emphasized,
      reverseTransitionDuration: KijiMotion.normal,
      pageBuilder: (_, _, _) => const LyricsScreen(),
      // Sube desde abajo, como si la letra estuviera debajo del reproductor.
      transitionsBuilder: (context, animation, _, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero)
            .chain(CurveTween(curve: KijiLook.museum ? KijiMotion.softSpring : KijiMotion.emphasizedCurve))
            .animate(animation),
        child: child,
      ),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(playbackProvider.select((p) => p.track));
    if (track == null) {
      return Scaffold(body: Center(child: Text(tx.eligeUnaCancion)));
    }
    final request = _requestFor(ref, track);
    final lyrics = ref.watch(lyricsProvider(request));
    final panel = ref.watch(settingsProvider.select((s) => s.lyricsPanel));

    return AlwaysDark(
      child: Scaffold(
        backgroundColor: _dark.background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(child: LyricsBackdrop(track: track)),
            SafeArea(
              // Escaparate: la barra de arriba y los botones se esconden solos.
              child: ChromeAutoHide(
                enabled: panel == 'showcase',
                child: LayoutBuilder(
                  builder: (context, box) {
                    // Dos columnas (la letra a la izquierda y, a la derecha, la canción, los controles
                    // y los ajustes): en la PC y con el teléfono en horizontal, o siempre/nunca según
                    // "Diseño".
                    final wide = lyricsTwoColumns(
                      ref.watch(settingsProvider.select((s) => s.lyricsLayout)),
                      box.biggest,
                    );
                    final header = HideWhenIdle(
                      child: _Header(
                        track: track,
                        request: request,
                        lyrics: lyrics.valueOrNull,
                        panel: panel,
                        showTitle: !wide && panel != 'showcase',
                      ),
                    );
                    // Una columna, Escaparate: la portada y la línea que suena ocupan la pantalla.
                    if (!wide && panel == 'showcase') {
                      return Column(
                        children: [
                          header,
                          Expanded(
                            child: _ShowcaseWithLine(track: track, lyrics: lyrics.valueOrNull),
                          ),
                        ],
                      );
                    }
                    final column = Column(
                      children: [
                        header,
                        Expanded(
                          child: lyrics.when(
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (error, _) => _Message(
                              icon: Icons.cloud_off_rounded,
                              text: error is LyricsUnavailableException
                                  ? tx.noSePudoBuscarLaLetraPorque(error.reason)
                                  : tx.noSePudoBuscarLaLetra,
                              actionLabel: tx.reintentar,
                              onAction: () => ref.invalidate(lyricsProvider(request)),
                            ),
                            data: (value) {
                              if (value.instrumental) {
                                return _Message(icon: Icons.piano_rounded, text: tx.instrumental);
                              }
                              if (value.isEmpty) {
                                return _Message(
                                  icon: Icons.lyrics_outlined,
                                  text: tx.noEncontramosLaLetraDeEsta,
                                  actionLabel: tx.buscarAMano,
                                  onAction: () => searchLyricsManually(context, ref, request),
                                );
                              }
                              Widget body(List<String?>? translations) => value.isSynced
                                  ? SyncedLyricsView(
                                      lines: value.synced,
                                      track: track,
                                      trackId: request.id,
                                      translations: translations,
                                      depth: wide,
                                    )
                                  : PlainLyricsView(text: value.plain!, track: track, translations: translations);
                              final translating = ref.watch(lyricsTranslationOnProvider);
                              return Column(
                                children: [
                                  if (!wide) const _OffsetBar(),
                                  Expanded(
                                    child: translating
                                        ? TranslatedLyrics(
                                            // Otro motor (teléfono o IA): se vuelve a traducir.
                                            key: ValueKey(ref.watch(settingsProvider.select((s) => s.useGemini))),
                                            trackId: request.id,
                                            lines: value.isSynced
                                                ? [for (final l in value.synced) l.text]
                                                : value.plain!.split('\n'),
                                            builder: body,
                                          )
                                        : body(null),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    );
                    if (!wide) {
                      // Una columna, Simple: el reproductor limpio debajo de la letra.
                      if (panel != 'simple') return column;
                      return Column(
                        children: [
                          Expanded(child: column),
                          LyricsSimplePanel(track: track, compact: true),
                        ],
                      );
                    }
                    final synced = lyrics.valueOrNull?.isSynced ?? false;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: column),
                        SizedBox(
                          width: min(440, box.maxWidth * 0.36),
                          child: switch (panel) {
                            'simple' => LyricsSimplePanel(track: track),
                            'showcase' => LyricsShowcase(track: track),
                            _ => LyricsSidePanel(track: track, synced: synced),
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Escaparate en una columna: la portada y, debajo, la línea de la letra que suena.
class _ShowcaseWithLine extends ConsumerWidget {
  const _ShowcaseWithLine({required this.track, required this.lyrics});

  final Track track;
  final Lyrics? lyrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = lyrics?.isSynced ?? false ? lyrics!.synced : const <LyricLine>[];
    final offset = ref.watch(lyricsOffsetProvider(track.id)).valueOrNull ?? Duration.zero;
    // Solo cambia cuando cambia la línea (no en cada avance de la posición).
    final index = ref.watch(playbackProvider.select((p) => currentLineIndex(lines, p.position + offset)));
    return LyricsShowcase(track: track, line: index >= 0 && index < lines.length ? lines[index].text : null);
  }
}

/// ¿La letra va a dos columnas? "Automático": en ventanas anchas (PC) y en horizontal. "Dos
/// columnas": siempre que entren (al menos 560 de ancho; si no, la letra no se podría leer).
bool lyricsTwoColumns(String layout, Size size) {
  if (layout == 'single' || size.width < 560) return false;
  if (layout == 'double') return true;
  return size.width >= KijiSizes.desktopBreakpoint || size.width > size.height;
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
      title: Text(tx.buscarLaLetraAMano),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: title,
            decoration: InputDecoration(labelText: tx.titulo),
          ),
          TextField(
            controller: artist,
            decoration: InputDecoration(labelText: tx.artista),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tx.cancelar)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tx.navSearch)),
      ],
    ),
  );
  if (go != true || !context.mounted) return;
  _say(context, tx.buscandoEnTodasLasFuentes);
  try {
    final found = await ref.read(lyricsRepositoryProvider).search((
      id: request.id,
      title: title.text.trim(),
      artist: artist.text.trim(),
      album: null,
      durationMs: request.durationMs,
      localPath: null,
    ), disabled: ref.read(settingsProvider).disabledLyricsSources);
    if (!context.mounted) return;
    if (found.isEmpty) {
      _say(context, tx.tampocoSeEncontroConEsosDatos);
    } else {
      ref.invalidate(lyricsProvider(request));
      ref.invalidate(lyricsOffsetProvider(request.id));
      _say(context, tx.encontradaEn(found.source?.label ?? tx.unaFuente));
    }
  } on LyricsUnavailableException catch (error) {
    if (context.mounted) _say(context, tx.noSePudoBuscar(error.reason));
  }
}

/// "Importar un .lrc" para la canción que suena.
Future<void> importLrc(BuildContext context, WidgetRef ref, LyricsRequest request) async {
  final picked = await FilePicker.pickFiles(dialogTitle: tx.eligeUnArchivoLrc, type: FileType.any);
  if (picked.isEmpty || !context.mounted) return;
  try {
    final text = utf8.decode(await picked.first.readAsBytes(), allowMalformed: true);
    await ref.read(lyricsRepositoryProvider).importText(request.id, text);
    ref.invalidate(lyricsProvider(request));
    ref.invalidate(lyricsOffsetProvider(request.id));
    if (context.mounted) _say(context, tx.letraImportada);
  } catch (error) {
    if (context.mounted) _say(context, tx.eseArchivoNoTieneUnaLetra);
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.track,
    required this.request,
    required this.lyrics,
    required this.panel,
    this.showTitle = true,
  });

  final Track track;
  final LyricsRequest request;
  final Lyrics? lyrics;

  /// Vista del panel (Completo, Simple o Escaparate): el botón de arriba la cambia.
  final String panel;

  /// En la PC el título va en el panel de la derecha.
  final bool showTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          GlassIconButton(
            foreground: Colors.white,
            icon: Icons.keyboard_arrow_down_rounded,
            tooltip: tx.cerrarLaLetra,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: !showTitle
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TrackTitleText(
                        track,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KijiText.title(size: 18, color: Colors.white),
                      ),
                      TrackArtistText(
                        track,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
          ),
          GlassIconButton(
            foreground: Colors.white,
            icon: lyricsPanelIcon(panel),
            tooltip: tx.cambiarVistaDeLaLetra(lyricsPanelLabel(nextLyricsPanel(panel))),
            onPressed: () =>
                ref.read(settingsProvider.notifier).update((s) => s.copyWith(lyricsPanel: nextLyricsPanel(panel))),
          ),
          const SizedBox(width: 8),
          GlassIconButton(
            foreground: Colors.white,
            icon: Icons.more_horiz_rounded,
            tooltip: tx.opcionesDeLaLetra,
            onPressed: () {
              final hasLyrics = !(lyrics?.isEmpty ?? true);
              final translating = ref.read(lyricsTranslationOnProvider);
              showLyricsMenuSheet(
                context,
                groups: [
                  LyricsMenuGroup(tx.menuLetraLeer, [
                    if (hasLyrics)
                      LyricsMenuAction(
                        icon: Icons.translate_rounded,
                        label: translating ? tx.quitarLaTraduccion : tx.traducir,
                        active: translating,
                        // Prendida: se quita. Apagada: se elige cómo traducir (teléfono o IA).
                        onTap: () => translating
                            ? ref.read(lyricsTranslationOnProvider.notifier).state = false
                            : showTranslateSheet(context, ref),
                      ),
                  ]),
                  LyricsMenuGroup(tx.menuLetraAjustar, [
                    if (lyrics?.isSynced ?? false)
                      LyricsMenuAction(
                        icon: Icons.sync_rounded,
                        label: tx.menuLetraSincronizar,
                        onTap: () => ref.read(_adjustingOffsetProvider.notifier).state = true,
                      ),
                    if (hasLyrics)
                      LyricsMenuAction(
                        icon: Icons.ios_share_rounded,
                        label: tx.compartirLineas,
                        onTap: () => ref.read(lyricsSelectionModeProvider.notifier).state = true,
                      ),
                  ]),
                  LyricsMenuGroup(lyrics?.source == null ? tx.fuenteDeLaLetra : tx.fuente(lyrics!.source!.label), [
                    LyricsMenuAction(
                      icon: Icons.library_books_outlined,
                      label: tx.menuLetraElegirFuente,
                      onTap: () => showLyricsSourcesSheet(
                        context,
                        request,
                        current: lyrics?.source,
                        onSearchByHand: () => searchLyricsManually(context, ref, request),
                        onImport: () => importLrc(context, ref, request),
                      ),
                    ),
                    LyricsMenuAction(
                      icon: Icons.manage_search_rounded,
                      label: tx.menuLetraBuscarOtra,
                      onTap: () => searchLyricsManually(context, ref, request),
                    ),
                    LyricsMenuAction(
                      icon: Icons.file_open_outlined,
                      label: tx.menuLetraImportar,
                      onTap: () => importLrc(context, ref, request),
                    ),
                  ]),
                ],
              );
            },
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
        onDark: true,
        radius: KijiRadii.tile,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(onPressed: () => move(-500), icon: const Text('−0,5 s'), tooltip: tx.laLetraVaDespues),
              Expanded(
                child: Text(
                  offset == Duration.zero
                      ? tx.sinDesfase
                      : '${seconds > 0 ? '+' : ''}${seconds.toStringAsFixed(1).replaceAll('.', kijiLanguage == 'es' ? ',' : '.')} s',
                  textAlign: TextAlign.center,
                  // La letra es siempre oscura: con un estilo claro, el acento (tinta) no se vería.
                  style: KijiText.mono(size: 13, color: KijiColors.palette.isLight ? Colors.white : KijiColors.cyan),
                ),
              ),
              IconButton(onPressed: () => move(500), icon: const Text('+0,5 s'), tooltip: tx.laLetraVaAntes),
              TextButton(
                onPressed: () => ref.read(_adjustingOffsetProvider.notifier).state = false,
                child: Text(tx.listo),
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
/// seguir y aparece "Volver a la canción". Mantener presionada una
/// línea entra en el modo de elegir líneas para compartir.
class SyncedLyricsView extends ConsumerStatefulWidget {
  const SyncedLyricsView({
    super.key,
    required this.lines,
    this.track,
    this.trackId,
    this.translations,
    this.depth = false,
  });

  final List<LyricLine> lines;
  final Track? track;
  final String? trackId;

  /// Traducción de cada línea (mismo orden), o null.
  final List<String?>? translations;

  /// PC: la línea actual nítida y las demás con un leve desenfoque y más transparentes cuanto más
  /// lejos están; el desplazamiento es más largo y suave.
  final bool depth;

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

  final _controller = ScrollController();

  /// Relleno arriba y abajo de la lista (para que la línea actual quede al 40 % de la altura).
  static const _top = 220.0;
  double get _bottom => ref.read(lyricsSelectionModeProvider) ? 260 : 320;

  @override
  void dispose() {
    _backTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Lleva la línea [index] al 40 % de la pantalla, con desplazamiento suave. Si está lejos, la
  /// lista todavía no la construyó (no tiene posición): primero va a una posición estimada con la
  /// altura promedio de las líneas y después la ajusta exacta.
  void _scrollTo(int index, bool reduceMotion) {
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (var attempt = 0; attempt < 3 && mounted; attempt++) {
        final line = _keys[index].currentContext;
        if (line != null && line.mounted) {
          await Scrollable.ensureVisible(
            line,
            alignment: 0.4,
            duration: reduceMotion
                ? Duration.zero
                : (widget.depth ? const Duration(milliseconds: 700) : KijiMotion.normal),
            curve: Curves.easeOutCubic,
          );
          return;
        }
        if (!_controller.hasClients) return;
        final pos = _controller.position;
        final average = (pos.maxScrollExtent + pos.viewportDimension - _top - _bottom) / widget.lines.length;
        final target = (_top + index * average - pos.viewportDimension * 0.4).clamp(0.0, pos.maxScrollExtent);
        if (reduceMotion) {
          _controller.jumpTo(target);
        } else {
          await _controller.animateTo(target, duration: KijiMotion.emphasized, curve: Curves.easeInOutCubic);
        }
        await WidgetsBinding.instance.endOfFrame;
      }
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
    final scale = lyricsScaleFor(ref.watch(settingsProvider.select((s) => s.lyricsSize)));
    final offset = widget.trackId == null
        ? Duration.zero
        : ref.watch(lyricsOffsetProvider(widget.trackId!)).valueOrNull ?? Duration.zero;
    // Solo la línea que suena (no la posición): la lista se vuelve a armar cuando cambia de línea,
    // no en cada cuadro (antes costaba ~30 ms por cuadro con la letra abierta).
    final current = ref.watch(playbackProvider.select((p) => currentLineIndex(widget.lines, p.position + offset)));
    final calm = reduceMotion(context, ref);
    final selecting = ref.watch(lyricsSelectionModeProvider);
    final centered = ref.watch(settingsProvider.select((s) => s.lyricsAlign)) == 'center';
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
            controller: _controller,
            padding: EdgeInsets.fromLTRB(28, _top, 28, selecting ? 260 : 320),
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
                  child: _Depth(
                    enabled: widget.depth && !selecting,
                    distance: (index - current).abs(),
                    calm: calm,
                    child: Column(
                      crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                      children: [
                        // La línea activa crece con un fundido.
                        AnimatedDefaultTextStyle(
                          duration: calm ? Duration.zero : KijiMotion.normal,
                          curve: Curves.easeOutCubic,
                          style: KijiText.title(
                            size: (isCurrent ? 30 : 24) * scale,
                            weight: isCurrent ? FontWeight.w800 : FontWeight.w700,
                            color: Colors.white.withValues(alpha: isCurrent ? 1 : (isPast ? 0.3 : 0.48)),
                          ).copyWith(height: 1.2),
                          child: Text(
                            line.text.isEmpty ? '♪' : line.text,
                            textAlign: centered ? TextAlign.center : TextAlign.start,
                            semanticsLabel: isCurrent ? tx.ahoraLinea(line.text) : line.text,
                          ),
                        ),
                        if (translation != null && translation.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              translation,
                              textAlign: centered ? TextAlign.center : TextAlign.start,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: isCurrent ? 0.8 : 0.3),
                                fontSize: (isCurrent ? 18 : 16) * scale,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
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
                label: Text(tx.volverALaCancion),
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
            translations: widget.translations == null
                ? null
                : () => [
                    for (final i in (_selected.toList()..sort()))
                      i < widget.translations!.length ? widget.translations![i] : null,
                  ],
            track: widget.track!,
          ),
      ],
    );
  }
}

/// Profundidad de una línea en la PC: cuanto más lejos de la que suena ([distance] líneas), más
/// transparente y un poco más desenfocada. La que suena queda nítida. Con "Reducir animaciones",
/// solo la transparencia (sin desenfoque ni transición).
class _Depth extends StatelessWidget {
  const _Depth({required this.enabled, required this.distance, required this.calm, required this.child});

  /// Solo en la PC (en el teléfono la letra queda como estaba).
  final bool enabled;
  final int distance;
  final bool calm;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final d = min(distance, 5);
    final faded = AnimatedOpacity(
      opacity: max(0.35, 1 - 0.13 * d),
      duration: calm ? Duration.zero : KijiMotion.emphasized,
      child: child,
    );
    if (calm) return faded;
    // Siempre el mismo árbol (también con 0): así la línea pasa de borrosa a nítida sin saltos.
    final sigma = 0.6 * d;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: faded,
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.onCancel,
    required this.lines,
    required this.track,
    this.translations,
  });

  final int count;
  final VoidCallback onCancel;
  final List<String> Function() lines;
  final Track track;

  /// La traducción de las líneas elegidas (mismo orden), si se está traduciendo.
  final List<String?>? Function()? translations;

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
                count == 0 ? tx.tocaLasLineasQueQuieresCompartir : tx.nLineasElegidas(count),
                style: TextStyle(color: _dark.muted),
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
                    label: Text(tx.comoTexto),
                  ),
                  FilledButton.icon(
                    onPressed: count == 0
                        ? null
                        : () => showLyricsCardDialog(context, lines(), track, translations: translations?.call()),
                    icon: const Icon(Icons.image_outlined),
                    label: Text(tx.comoImagen),
                  ),
                  TextButton(onPressed: onCancel, child: Text(tx.cancelar)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Letra sin tiempos. Mantener presionada una línea permite compartir.
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
    final scale = lyricsScaleFor(ref.watch(settingsProvider.select((s) => s.lyricsSize)));
    final lines = widget.text.split('\n');
    final selecting = ref.watch(lyricsSelectionModeProvider);
    final centered = ref.watch(settingsProvider.select((s) => s.lyricsAlign)) == 'center';
    return Stack(
      children: [
        ListView.builder(
          padding: EdgeInsets.fromLTRB(24, 16, 24, selecting ? 220 : 40),
          itemCount: lines.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(tx.letraSinSincronizar, style: KijiText.mono(size: 10, color: _dark.muted)),
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
                  crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                  children: [
                    Text(
                      lines[i],
                      textAlign: centered ? TextAlign.center : TextAlign.start,
                      style: KijiText.title(
                        size: 22 * scale,
                        weight: FontWeight.w600,
                        color: Colors.white,
                      ).copyWith(height: 1.3),
                    ),
                    if (widget.translations != null &&
                        i < widget.translations!.length &&
                        (widget.translations![i]?.isNotEmpty ?? false))
                      Text(
                        widget.translations![i]!,
                        textAlign: centered ? TextAlign.center : TextAlign.start,
                        style: TextStyle(color: Colors.white60, fontSize: 16 * scale, fontStyle: FontStyle.italic),
                      ),
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
            translations: widget.translations == null
                ? null
                : () => [
                    for (final i in (_selected.toList()..sort()))
                      i < widget.translations!.length ? widget.translations![i] : null,
                  ],
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
            Icon(icon, size: 44, color: _dark.muted),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: _dark.muted),
            ),
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

/// Fondo de la letra: la portada difuminada con el color real de la canción. El difuminado sale de
/// decodificar la portada en 24 px y estirarla (barato: no usa filtros de desenfoque, que en el
/// teléfono costaban ~10 ms por cuadro).
class LyricsBackdrop extends ConsumerStatefulWidget {
  const LyricsBackdrop({super.key, required this.track});

  final Track track;

  @override
  ConsumerState<LyricsBackdrop> createState() => _LyricsBackdropState();
}

class _LyricsBackdropState extends ConsumerState<LyricsBackdrop> {
  String? _askedFor;

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final image = trackImageProvider(ref, track);
    final accent = knownCoverAccent(track.id) ?? track.coverColor;
    if (_askedFor != track.id && knownCoverAccent(track.id) == null) {
      _askedFor = track.id;
      coverAccentFor(track, image).then((_) {
        if (mounted) setState(() {});
      }, onError: (Object error) => debugPrint('=== LETRAS: sin color de la carátula (${error.runtimeType}) ==='));
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        if (image != null)
          Opacity(
            opacity: 0.6,
            child: Image(
              image: ResizeImage(image, width: 24, height: 24),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        // Capa oscura fija: la letra se lee igual con portadas claras.
        const ColoredBox(color: Color(0x80000000)),
        AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                accent.withValues(alpha: 0.4),
                Color.lerp(accent, _dark.background, 0.75)!.withValues(alpha: 0.7),
                _dark.background.withValues(alpha: 0.95),
              ],
              stops: const [0, 0.45, 1],
            ),
          ),
        ),
      ],
    );
  }
}
