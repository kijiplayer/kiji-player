// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivos de referencia: app/src/main/kotlin/.../ui/screens/settings/ (secciones) y
// SearchableSettings.kt (buscador de opciones).

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/history/listening_history.dart';
import '../../../providers/downloads_provider.dart';
import '../../../providers/playback_provider.dart';
import '../../../theme/kiji_tokens.dart';
import '../../../utils/byte_formatter.dart';
import '../../../utils/clock_format.dart';
import '../../../widgets/kiji_logo.dart';
import '../../../widgets/nocturne/glass.dart';
import '../../backup/data/backup_notifier.dart';
import '../../desktop/desktop_hotkeys.dart';
import '../../desktop/desktop_settings.dart';
import '../../desktop/desktop_window.dart';
import '../../dev_tools/dev_build.dart';
import '../../performance/high_performance_tile.dart';
import '../../dev_tools/dev_tools_screen.dart';
import '../../backup/presentation/backup_screen.dart';
import '../../downloads/data/auto_downloads.dart';
import '../../downloads/domain/download_settings.dart';
import '../../favorites/favorites.dart';
import '../../downloads/presentation/downloads_screen.dart';
import '../../equalizer/data/equalizer_notifier.dart';
import '../../equalizer/presentation/equalizer_screen.dart';
import '../../import/presentation/import_screen.dart';
import '../../lyrics/presentation/lyrics_menu_sheet.dart';
import '../../lyrics/presentation/lyrics_views.dart' show lyricsPanelLabel;
import '../../reports/presentation/reports_screen.dart';
import '../../recommendations/data/search_history.dart';
import '../../updates/updates_screen.dart';
import '../../updates/whats_new.dart';
import '../../translation/domain/languages.dart';
import '../../translation/presentation/lyrics_settings_screens.dart';
import '../../yt_music/presentation/extractor_health_screen.dart';
import '../data/settings_store.dart';
import '../domain/app_settings.dart';
import '../domain/setting_search.dart';
import 'credits_screen.dart';
import '../../../l10n/l10n.dart';
import '../../account/data/account_store.dart';
import '../../account/presentation/account_screens.dart';
import '../../../version_label.dart';
import '../../welcome/presentation/welcome_screen.dart';
import '../../playback_extras/data/battery_optimization.dart';
import '../../style/presentation/style_chooser_screen.dart';

/// Secciones de Configuración, en el orden en que se muestran, cada una con su ícono y una
/// descripción corta.
enum SettingsSection {
  appearance(Icons.palette_outlined),
  player(Icons.play_circle_outline_rounded),
  lyrics(Icons.lyrics_outlined),
  storage(Icons.sd_storage_outlined),
  desktop(Icons.desktop_windows_outlined),
  privacy(Icons.shield_outlined),
  about(Icons.info_outline_rounded),
  developer(Icons.developer_mode_rounded);

  const SettingsSection(this.icon);
  String get label => switch (this) {
    SettingsSection.appearance => tx.apariencia,
    SettingsSection.player => tx.reproductorYAudio,
    SettingsSection.lyrics => tx.letras2,
    SettingsSection.storage => tx.descargasYAlmacenamiento,
    SettingsSection.desktop => tx.seccionPc,
    SettingsSection.privacy => tx.privacidadYDatos,
    SettingsSection.about => tx.acercaDe,
    SettingsSection.developer => tx.kijiDev,
  };

  String get description => switch (this) {
    SettingsSection.appearance => tx.seccionAparienciaDescripcion,
    SettingsSection.player => tx.seccionReproductorDescripcion,
    SettingsSection.lyrics => tx.seccionLetrasDescripcion,
    SettingsSection.storage => tx.seccionDescargasDescripcion,
    SettingsSection.desktop => tx.seccionPcDescripcion,
    SettingsSection.privacy => tx.seccionPrivacidadDescripcion,
    SettingsSection.about => tx.seccionAcercaDescripcion,
    SettingsSection.developer => tx.seccionDevDescripcion,
  };

  final IconData icon;
}

/// Una opción de Configuración: lo que se busca y cómo se dibuja.
class SettingOption {
  const SettingOption({
    required this.section,
    required this.title,
    this.subtitle = '',
    this.keywords = const [],
    required this.builder,
  });

  final SettingsSection section;
  final String title;
  final String subtitle;
  final List<String> keywords;
  final Widget Function(BuildContext context, WidgetRef ref) builder;

  bool matches(String query) =>
      settingMatches(query, title: title, subtitle: subtitle, section: section.label, keywords: keywords);
}

/// Pantalla de Configuración: el buscador arriba y las secciones en tarjetas. Buscar muestra los
/// ajustes que coinciden (por nombre, descripción o palabras relacionadas, en los dos idiomas);
/// tocar uno abre su sección y lo resalta un momento. En la PC (ventana ancha), las secciones a la
/// izquierda y la elegida a la derecha.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _query = TextEditingController();

  /// Sección abierta en el panel derecho (PC) y el ajuste a resaltar.
  SettingsSection _selected = SettingsSection.appearance;
  String? _highlight;
  int _highlightRun = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool _wide(BuildContext context) => MediaQuery.sizeOf(context).width >= KijiSizes.desktopBreakpoint;

  void _open(BuildContext context, SettingsSection section, {String? highlight}) {
    if (_wide(context)) {
      setState(() {
        _selected = section;
        _highlight = highlight;
        _highlightRun++;
      });
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsSectionScreen(section: section, options: _options, highlight: highlight),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = _options();
    final query = _query.text.trim();
    final results = query.isEmpty ? const <SettingOption>[] : options.where((o) => o.matches(query)).toList();
    final sections = [
      for (final section in SettingsSection.values)
        if (options.any((o) => o.section == section)) section,
    ];
    final wide = _wide(context);

    final search = GradientBorder(
      radius: KijiRadii.pill,
      fill: KijiColors.surface,
      child: TextField(
        controller: _query,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: tr(context).settingsSearchHint,
          prefixIcon: Icon(Icons.search_rounded, color: KijiColors.muted),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  tooltip: tx.borrarLaBusqueda,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(_query.clear),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
    );

    final list = ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        search,
        const SizedBox(height: 14),
        if (query.isEmpty)
          for (final section in sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SectionCard(
                section: section,
                selected: wide && section == _selected,
                onTap: () => _open(context, section),
              ),
            )
        else if (results.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              tx.noHayNingunaOpcionConEse,
              textAlign: TextAlign.center,
              style: TextStyle(color: KijiColors.muted),
            ),
          )
        else
          Glass(
            blur: false,
            radius: KijiRadii.tile,
            child: Column(
              children: [
                for (final option in results)
                  ListTile(
                    key: ValueKey('resultado-${option.title}'),
                    leading: Icon(option.section.icon, color: KijiColors.cyan),
                    title: Text(option.title),
                    subtitle: Text(
                      option.subtitle.isEmpty ? option.section.label : '${option.section.label} · ${option.subtitle}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _open(context, option.section, highlight: option.title),
                  ),
              ],
            ),
          ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(tr(context).settingsTitle)),
      body: !wide
          ? list
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 380, child: list),
                VerticalDivider(width: 1, color: KijiColors.glassBorder),
                Expanded(
                  child: SettingsSectionView(
                    key: ValueKey('$_selected-$_highlightRun'),
                    section: _selected,
                    options: _options,
                    highlight: _highlight,
                    showTitle: true,
                  ),
                ),
              ],
            ),
    );
  }

  List<SettingOption> _options() {
    return [
      // Reproductor y audio
      SettingOption(
        section: SettingsSection.player,
        title: tx.recordarLaColaAlCerrar,
        subtitle: tx.alAbrirKijiVolverALa,
        keywords: ['memoria', 'reanudar', 'continuar', tx.guardarCola],
        builder: (context, ref) => SwitchListTile(
          title: Text(tx.recordarLaColaAlCerrar),
          subtitle: Text(tx.alAbrirKijiVuelveALa),
          value: ref.watch(settingsProvider).rememberQueue,
          onChanged: (value) async {
            await ref.read(settingsProvider.notifier).update((s) => s.copyWith(rememberQueue: value));
            // Apagarlo borra la cola guardada: no queda nada a escondidas.
            if (!value) await ref.read(playbackProvider.notifier).forgetSavedQueue();
          },
        ),
      ),
      SettingOption(
        section: SettingsSection.player,
        title: tx.ecualizador2,
        subtitle: tx.presetsBandasAManoYUn,
        keywords: const ['eq', 'graves', 'agudos', 'bajos', 'sonido', 'auriculares', 'bluetooth'],
        builder: (context, ref) => ListTile(
          leading: const Icon(Icons.equalizer_rounded),
          title: Text(tx.ecualizador2),
          subtitle: Text(
            ref.watch(equalizerProvider.select((e) => e.settings.enabled))
                ? tx.encendidoPerfil(ref.watch(equalizerProvider.select((e) => e.activeProfile.label)))
                : tx.apagado,
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => EqualizerScreen.open(context),
        ),
      ),
      SettingOption(
        section: SettingsSection.player,
        title: tx.transicionSuaveEntreCanciones,
        subtitle: tx.elFinalDeUnaCancionY,
        keywords: const ['crossfade', 'fundido', 'mezcla', 'fade', 'transicion'],
        builder: (context, ref) {
          final seconds = ref.watch(settingsProvider.select((s) => s.crossfadeSeconds));
          return ListTile(
            leading: const Icon(Icons.swap_horiz_rounded),
            title: Text(tx.transicionSuaveEntreCanciones),
            subtitle: Text(seconds == 0 ? tx.apagada : tx.sElFinalDeUnaCancion(seconds)),
            trailing: Text(seconds == 0 ? tx.no : '$seconds s', style: KijiText.mono(size: 13)),
            // Toda la fila abre la lista (antes solo respondía el texto chico de la derecha).
            onTap: () async {
              final value = await showDialog<int>(
                context: context,
                builder: (context) => SimpleDialog(
                  title: Text(tx.transicionSuave),
                  children: [
                    RadioGroup<int>(
                      groupValue: seconds,
                      onChanged: (value) => Navigator.pop(context, value),
                      child: Column(
                        children: [
                          for (final option in AppSettings.crossfadeOptions)
                            RadioListTile<int>(
                              value: option,
                              title: Text(option == 0 ? tx.apagada : tx.nSegundos(option)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
              if (value != null) {
                await ref.read(settingsProvider.notifier).update((s) => s.copyWith(crossfadeSeconds: value));
              }
            },
          );
        },
      ),
      SettingOption(
        section: SettingsSection.player,
        title: tx.pausarAlSilenciar,
        subtitle: tx.siBajasElVolumenACero,
        keywords: ['mute', 'silencio', tx.volumenCero, 'pausa'],
        builder: (context, ref) => SwitchListTile(
          title: Text(tx.pausarAlSilenciar),
          subtitle: Text(tx.siBajasElVolumenDelTelefono),
          value: ref.watch(settingsProvider).pauseOnMute,
          onChanged: (value) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(pauseOnMute: value)),
        ),
      ),
      SettingOption(
        section: SettingsSection.player,
        title: tx.retomarAlConectarElBluetooth,
        subtitle: tx.alConectarAuricularesOUnParlante,
        keywords: const ['auriculares', 'bluetooth', 'reanudar', 'auto', 'coche'],
        builder: (context, ref) => SwitchListTile(
          title: Text(tx.retomarAlConectarElBluetooth),
          subtitle: Text(tx.alConectarAuricularesOUnParlante2),
          value: ref.watch(settingsProvider).resumeOnBluetooth,
          onChanged: (value) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(resumeOnBluetooth: value)),
        ),
      ),
      if (BatteryOptimization.applies)
        SettingOption(
          section: SettingsSection.player,
          title: tx.bateriaTitulo,
          subtitle: tx.bateriaPendiente,
          keywords: const ['batería', 'battery', 'segundo plano', 'background', 'optimización', 'se corta', 'motorola'], // l10n-ignore
          builder: (context, ref) => const BatteryOptimizationTile(),
        ),
      // En la PC (bandeja, atajos globales, controles de Windows)
      if (DesktopWindow.isDesktop) ...[
        SettingOption(
          section: SettingsSection.desktop,
          title: tx.alCerrarLaVentana,
          subtitle: tx.alCerrarDescripcion,
          keywords: const ['bandeja', 'tray', 'minimizar', 'cerrar', 'fondo', 'background', 'salir', 'quit'],
          builder: (context, ref) => const CloseActionTile(),
        ),
        SettingOption(
          section: SettingsSection.desktop,
          title: tx.atajosGlobales,
          subtitle: tx.atajosGlobalesDescripcion,
          keywords: const ['teclado', 'keyboard', 'hotkey', 'shortcut', 'atajo', 'tecla', 'global'],
          builder: (context, ref) => Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.keyboard_rounded),
                title: Text(tx.atajosGlobales),
                subtitle: Text(tx.atajosGlobalesDescripcion),
                value: ref.watch(settingsProvider.select((s) => s.globalHotkeys)),
                onChanged: (value) =>
                    ref.read(settingsProvider.notifier).update((s) => s.copyWith(globalHotkeys: value)),
              ),
              for (final action in HotkeyAction.values) HotkeyTile(action: action),
              if (ref.watch(settingsProvider.select((s) => s.hotkeys.isNotEmpty)))
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => ref.read(settingsProvider.notifier).update((s) => s.copyWith(hotkeys: const {})),
                    child: Text(tx.atajosDeFabrica),
                  ),
                ),
            ],
          ),
        ),
        if (Platform.isWindows)
          SettingOption(
            section: SettingsSection.desktop,
            title: tx.controlesDeWindows,
            subtitle: tx.controlesDeWindowsDescripcion,
            keywords: const ['smtc', 'multimedia', 'media', 'teclas', 'keys', 'bloqueo', 'lock', 'volumen'],
            builder: (context, ref) => ListTile(
              leading: const Icon(Icons.music_video_outlined),
              title: Text(tx.controlesDeWindows),
              subtitle: Text(tx.controlesDeWindowsDescripcion),
            ),
          ),
      ],
      // Contenido
      SettingOption(
        section: SettingsSection.storage,
        title: tx.ocultarAudiosCortos,
        subtitle: tx.noMostrarEnLaBibliotecaLos,
        keywords: const ['sonidos', 'notificaciones', 'juegos', 'tonos', 'filtrar'],
        builder: (context, ref) => SwitchListTile(
          title: Text(tx.ocultarAudiosCortos),
          subtitle: Text(tx.noMuestraEnLaBibliotecaLos),
          value: ref.watch(settingsProvider).hideShortAudios,
          onChanged: (value) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(hideShortAudios: value)),
        ),
      ),
      // Letras
      SettingOption(
        section: SettingsSection.lyrics,
        title: tx.tamanoDeLasLetras,
        subtitle: tx.tamanoDeLasLetrasDescripcion,
        keywords: const ['grande', 'chica', 'leer', 'accesibilidad'],
        builder: (context, ref) => choiceTile<String>(
          context,
          icon: Icons.format_size_rounded,
          title: tx.tamanoDeLasLetras,
          value: ref.watch(settingsProvider.select((s) => s.lyricsSize)),
          options: AppSettings.lyricsSizes,
          label: lyricsSizeLabel,
          onChanged: (value) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(lyricsSize: value)),
        ),
      ),
      SettingOption(
        section: SettingsSection.lyrics,
        title: tx.disenoDeLaLetra,
        subtitle: tx.disenoDeLaLetraDescripcion,
        keywords: const ['columnas', 'horizontal', 'panel', 'pc'],
        builder: (context, ref) => choiceTile<String>(
          context,
          icon: Icons.vertical_split_outlined,
          title: tx.disenoDeLaLetra,
          value: ref.watch(settingsProvider.select((s) => s.lyricsLayout)),
          options: AppSettings.lyricsLayouts,
          label: lyricsLayoutLabel,
          onChanged: (value) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(lyricsLayout: value)),
        ),
      ),
      SettingOption(
        section: SettingsSection.lyrics,
        title: tx.modoDelPanel,
        subtitle: tx.modoDelPanelDescripcion,
        keywords: const ['completo', 'simple', 'escaparate', 'showcase', 'grabar', 'compartir'],
        builder: (context, ref) => choiceTile<String>(
          context,
          icon: Icons.auto_awesome_rounded,
          title: tx.modoDelPanel,
          value: ref.watch(settingsProvider.select((s) => s.lyricsPanel)),
          options: AppSettings.lyricsPanels,
          label: lyricsPanelLabel,
          onChanged: (value) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(lyricsPanel: value)),
        ),
      ),
      SettingOption(
        section: SettingsSection.lyrics,
        title: tx.mostrarMarcaKiji,
        subtitle: tx.mostrarMarcaKijiDescripcion,
        keywords: const ['logo', 'escaparate', 'marca'],
        builder: (context, ref) => SwitchListTile(
          secondary: const Icon(Icons.branding_watermark_outlined),
          title: Text(tx.mostrarMarcaKiji),
          subtitle: Text(tx.mostrarMarcaKijiDescripcion),
          value: ref.watch(settingsProvider.select((s) => s.showcaseMark)),
          onChanged: (on) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(showcaseMark: on)),
        ),
      ),
      SettingOption(
        section: SettingsSection.lyrics,
        title: tx.fuentesDeLetras,
        subtitle: tx.dondeBuscaKijiLasLetrasCada,
        keywords: const ['letra', 'lrclib', 'kugou', 'karaoke', 'sincronizada'],
        builder: (context, ref) => ListTile(
          leading: const Icon(Icons.travel_explore_rounded),
          title: Text(tx.fuentesDeLetras),
          subtitle: Text(
            ref.watch(settingsProvider).disabledLyricsSources.isEmpty
                ? tx.todasPrendidas
                : tx.nApagadas(ref.watch(settingsProvider).disabledLyricsSources.length),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => LyricsSourcesScreen.open(context),
        ),
      ),
      SettingOption(
        section: SettingsSection.lyrics,
        title: tx.traduccionDeLetras,
        subtitle: tx.enTuTelefonoAnonimaOCon,
        keywords: const ['traducir', 'idioma', 'gemini', 'ia', 'ingles'],
        builder: (context, ref) => ListTile(
          leading: const Icon(Icons.translate_rounded),
          title: Text(tx.traduccionDeLetras),
          subtitle: Text(
            tx.al(
              kijiLanguage == 'es'
                  ? languageName(ref.watch(settingsProvider).translationTarget).toLowerCase()
                  : languageName(ref.watch(settingsProvider).translationTarget),
              ref.watch(settingsProvider).useGemini && ref.watch(settingsProvider).geminiEnabled
                  ? tx.conGemini
                  : tx.enTuTelefono,
            ),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => TranslationSettingsScreen.open(context),
        ),
      ),
      // Apariencia
      SettingOption(
        section: SettingsSection.appearance,
        title: tx.idioma,
        subtitle: tx.idiomaDescripcion,
        keywords: const ['idioma', 'language', 'english', 'español', 'ingles', 'espanol'], // l10n-ignore
        builder: (context, ref) {
          final language = ref.watch(settingsProvider.select((s) => s.language));
          String name(String option) => switch (option) {
            'es' => 'Español', // l10n-ignore
            'en' => 'English', // l10n-ignore
            _ => tx.idiomaDelSistema,
          };
          return ListTile(
            leading: const Icon(Icons.language_rounded),
            title: Text(tx.idioma),
            subtitle: Text(name(language)),
            onTap: () async {
              final value = await showDialog<String>(
                context: context,
                builder: (context) => SimpleDialog(
                  title: Text(tx.idioma),
                  children: [
                    RadioGroup<String>(
                      groupValue: language,
                      onChanged: (value) => Navigator.pop(context, value),
                      child: Column(
                        children: [
                          for (final option in AppSettings.languages)
                            RadioListTile<String>(value: option, title: Text(name(option))),
                        ],
                      ),
                    ),
                  ],
                ),
              );
              if (value != null) {
                await ref.read(settingsProvider.notifier).update((s) => s.copyWith(language: value));
              }
            },
          );
        },
      ),
      SettingOption(
        section: SettingsSection.appearance,
        title: tx.estilo,
        subtitle: tx.estiloDescripcion,
        keywords: const ['nocturne', 'grafito', 'graphite', 'papel', 'paper', 'look', 'aspecto', 'diseño'], // l10n-ignore
        builder: (context, ref) {
          final style = KijiStyle.parse(ref.watch(settingsProvider.select((s) => s.style)));
          return ListTile(
            leading: const Icon(Icons.style_outlined),
            title: Text(tx.estilo),
            subtitle: Text(styleName(style)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => StyleChooserScreen.open(context, ref),
          );
        },
      ),
      SettingOption(
        section: SettingsSection.appearance,
        title: tx.tema,
        subtitle: tx.temaDescripcion,
        keywords: const ['modo', 'fondo', 'oled', 'negro', 'blanco'],
        builder: (context, ref) =>
            _onlyInNocturne(ref, Icons.contrast_rounded, tx.tema) ??
            choiceTile<String>(
              context,
              icon: Icons.contrast_rounded,
              title: tx.tema,
              value: ref.watch(settingsProvider.select((s) => s.theme)),
              options: AppSettings.themes,
              label: (t) => switch (t) {
                'darker' => tx.temaMasOscuro,
                'light' => tx.temaClaro,
                _ => tx.temaOscuro,
              },
              onChanged: (value) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(theme: value)),
            ),
      ),
      SettingOption(
        section: SettingsSection.appearance,
        title: tx.colorDeAcento,
        subtitle: tx.colorDeAcentoDescripcion,
        keywords: const ['degradado', 'violeta', 'naranja', 'verde', 'azul'],
        builder: (context, ref) {
          final disabled = _onlyInNocturne(ref, Icons.palette_outlined, tx.colorDeAcento);
          if (disabled != null) return disabled;
          final accent = ref.watch(settingsProvider.select((s) => s.accent));
          String name(String a) => switch (a) {
            'aurora' => tx.acentoAurora,
            'ember' => tx.acentoEmber,
            'mint' => tx.acentoMint,
            'ocean' => tx.acentoOcean,
            _ => tx.acentoNocturne,
          };
          return ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(tx.colorDeAcento),
            subtitle: Text(name(accent)),
            // Una muestra de cada acento: un toque y se aplica.
            trailing: Wrap(
              spacing: 6,
              children: [
                for (final a in AppSettings.accents)
                  Tooltip(
                    message: name(a),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => ref.read(settingsProvider.notifier).update((s) => s.copyWith(accent: a)),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [KijiPalette.accents[a]!.$1, KijiPalette.accents[a]!.$2]),
                          border: Border.all(color: a == accent ? KijiColors.text : Colors.transparent, width: 2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onTap: () async {
              final picked = await showDialog<String>(
                context: context,
                builder: (dialog) => SimpleDialog(
                  title: Text(tx.colorDeAcento),
                  children: [
                    RadioGroup<String>(
                      groupValue: accent,
                      onChanged: (value) => Navigator.pop(dialog, value),
                      child: Column(
                        children: [
                          for (final a in AppSettings.accents) RadioListTile<String>(value: a, title: Text(name(a))),
                        ],
                      ),
                    ),
                  ],
                ),
              );
              if (picked != null) {
                await ref.read(settingsProvider.notifier).update((s) => s.copyWith(accent: picked));
              }
            },
          );
        },
      ),
      SettingOption(
        section: SettingsSection.appearance,
        title: tx.tipografia,
        subtitle: tx.tipografiaDescripcion,
        keywords: const ['letra', 'fuente', 'space grotesk', 'jetbrains'], // l10n-ignore
        builder: (context, ref) => choiceTile<String>(
          context,
          icon: Icons.font_download_outlined,
          title: tx.tipografia,
          value: ref.watch(settingsProvider.select((s) => s.font)),
          options: AppSettings.fonts,
          label: (f) => f == 'system' ? tx.tipografiaSistema : tx.tipografiaKiji,
          onChanged: (value) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(font: value)),
        ),
      ),
      SettingOption(
        section: SettingsSection.appearance,
        title: tx.formatoDeHora,
        subtitle: tx.formatoDeHoraDescripcion,
        keywords: const ['reloj', 'am', 'pm', '12', '24', 'horas'], // l10n-ignore
        builder: (context, ref) {
          final example = DateTime(2026, 1, 1, 21, 10);
          // La del sistema sale del teléfono o la PC, no de la app (que ya aplica el ajuste).
          final system = View.of(context).platformDispatcher.alwaysUse24HourFormat;
          String name(String option) => switch (option) {
            '12' => tx.hora12(formatClock(example, use24Hour: false)),
            '24' => tx.hora24(formatClock(example, use24Hour: true)),
            _ => tx.horaDelSistema(formatClock(example, use24Hour: system)),
          };
          return choiceTile<String>(
            context,
            icon: Icons.schedule_rounded,
            title: tx.formatoDeHora,
            value: ref.watch(settingsProvider.select((s) => s.timeFormat)),
            options: AppSettings.timeFormats,
            label: name,
            onChanged: (value) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(timeFormat: value)),
          );
        },
      ),
      SettingOption(
        section: SettingsSection.appearance,
        title: tx.reducirAnimaciones,
        subtitle: tx.sinAnimacionesDecorativasComoElAnillo,
        keywords: const ['movimiento', 'accesibilidad', 'mareo', 'animacion'],
        builder: (context, ref) => SwitchListTile(
          title: Text(tx.reducirAnimaciones),
          subtitle: Text(tx.sinAnimacionesDecorativasPorEjemploEl),
          value: ref.watch(settingsProvider).reduceMotion,
          onChanged: (value) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(reduceMotion: value)),
        ),
      ),
      SettingOption(
        section: SettingsSection.appearance,
        title: tx.modoAltoRendimiento,
        subtitle: tx.modoAltoRendimientoDescripcion,
        keywords: const [
          'rendimiento',
          'performance',
          'fps',
          'hz',
          '120',
          'fluido',
          'smooth',
          'blur',
          'efectos',
          'aurora',
        ],
        builder: (context, ref) => const HighPerformanceTile(),
      ),
      // Almacenamiento
      SettingOption(
        section: SettingsSection.storage,
        title: tx.descargarSoloConWifi,
        subtitle: tx.noUsaLosDatosMovilesPara,
        keywords: const ['datos', 'movil', 'descargas'],
        builder: (context, ref) => SwitchListTile(
          title: Text(tx.descargarSoloConWifi),
          subtitle: Text(tx.noUsaLosDatosMovilesPara),
          value: ref.watch(downloadsProvider).settings.wifiOnly,
          onChanged: ref.read(downloadsProvider.notifier).setWifiOnly,
        ),
      ),
      SettingOption(
        section: SettingsSection.storage,
        title: tx.descargarLoQueMeGusta,
        subtitle: tx.descargarLoQueMeGustaDescripcion,
        keywords: const ['me gusta', 'favoritas', 'automatico', 'sin conexion', 'like', 'offline'], // l10n-ignore
        builder: (context, ref) {
          final auto = ref.watch(autoDownloadsProvider);
          final waiting = auto.pending.length;
          return SwitchListTile(
            secondary: const Icon(Icons.favorite_border_rounded),
            title: Text(tx.descargarLoQueMeGusta),
            subtitle: Text(switch (auto.waitingReason) {
              final reason? when waiting > 0 => tx.nEsperandoParaBajarse(waiting, reason),
              _ when waiting > 0 => tx.nBajandoseSolas(waiting),
              _ => tx.descargarLoQueMeGustaDescripcion,
            }),
            value: ref.watch(settingsProvider.select((s) => s.downloadLiked)),
            onChanged: (value) => _setDownloadLiked(context, ref, value),
          );
        },
      ),
      SettingOption(
        section: SettingsSection.storage,
        title: tx.limiteDeEspacioParaDescargas,
        keywords: const ['descargas', 'espacio', 'gb'],
        builder: (context, ref) {
          final downloads = ref.watch(downloadsProvider);
          return ListTile(
            title: Text(tx.limiteDeEspacioParaDescargas),
            subtitle: Text(tx.usado(formatBytes(downloads.usedBytes))),
            trailing: DropdownButton<int?>(
              value: downloads.settings.limitBytes,
              underline: const SizedBox.shrink(),
              items: [
                for (final option in DownloadSettings.limitOptions)
                  DropdownMenuItem(value: option, child: Text(option == null ? tx.sinLimite : formatBytes(option))),
              ],
              onChanged: ref.read(downloadsProvider.notifier).setLimit,
            ),
          );
        },
      ),
      SettingOption(
        section: SettingsSection.storage,
        title: tx.limiteDeLaCache,
        subtitle: tx.loQueYaEscuchasteSeGuarda,
        keywords: const ['cache', 'espacio', 'escuchado', 'streaming'],
        builder: (context, ref) => ListTile(
          title: Text(tx.limiteDeLaCache),
          subtitle: Text(tx.loYaEscuchadoSeGuardaPara),
          trailing: DropdownButton<int>(
            value: ref.watch(settingsProvider).streamCacheLimitBytes,
            underline: const SizedBox.shrink(),
            items: [
              for (final option in AppSettings.cacheLimitOptions)
                DropdownMenuItem(value: option, child: Text(formatBytes(option))),
            ],
            onChanged: (value) {
              if (value == null) return;
              ref.read(settingsProvider.notifier).update((s) => s.copyWith(streamCacheLimitBytes: value));
            },
          ),
        ),
      ),
      SettingOption(
        section: SettingsSection.storage,
        title: tx.vaciarLaCache,
        subtitle: tx.liberaEspacioLasDescargasNoSe,
        keywords: const ['cache', 'borrar', 'liberar', 'espacio'],
        builder: (context, ref) => ListTile(
          leading: const Icon(Icons.cleaning_services_outlined),
          title: Text(tx.vaciarLaCache),
          subtitle: Text(tx.liberaEspacioLasDescargasNoSe),
          onTap: () => _confirm(
            context,
            title: tx.vaciarLaCache2,
            message: tx.lasCancionesQueYaEscuchasteSe,
            action: tx.vaciar,
            onConfirm: () async {
              await ref.read(playbackProvider.notifier).clearStreamCache();
              if (context.mounted) _done(context, tx.cacheVaciada);
            },
          ),
        ),
      ),
      SettingOption(
        section: SettingsSection.storage,
        title: tx.ahorroDeDatos,
        subtitle: tx.conDatosMovilesYoutubeSuenaEn,
        keywords: const ['datos', 'movil', 'calidad', 'consumo', 'megas'],
        builder: (context, ref) => SwitchListTile(
          title: Text(tx.ahorroDeDatos),
          subtitle: Text(tx.conDatosMovilesYoutubeSuenaEn2),
          value: ref.watch(settingsProvider).dataSaver,
          onChanged: (value) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(dataSaver: value)),
        ),
      ),
      SettingOption(
        section: SettingsSection.storage,
        title: tx.verYBorrarDescargas,
        keywords: ['descargadas', 'borrar', tx.sinConexion3],
        builder: (context, ref) => ListTile(
          leading: const Icon(Icons.download_for_offline_outlined),
          title: Text(tx.verYBorrarDescargas),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => DownloadsScreen.open(context),
        ),
      ),
      // Privacidad
      SettingOption(
        section: SettingsSection.privacy,
        title: tx.queGuardaKiji,
        subtitle: tx.sinCuentasSinAnunciosYSin,
        keywords: const ['datos', 'telemetria', 'cuenta', 'transparencia'],
        builder: (context, ref) => ListTile(
          leading: Icon(Icons.verified_user_outlined, color: KijiColors.cyan),
          title: Text(tx.queGuardaKiji),
          subtitle: Text(tx.sinCuentasSinAnunciosYSin2),
        ),
      ),
      SettingOption(
        section: SettingsSection.privacy,
        title: tx.letrasYTraduccion,
        subtitle: tx.queSeEnviaAlBuscarO,
        keywords: const ['letras', 'traduccion', 'gemini', 'clave'],
        builder: (context, ref) => ListTile(
          leading: const Icon(Icons.lyrics_outlined),
          title: Text(tx.letrasYTraduccion),
          subtitle: Text(tx.alAbrirUnaLetraCadaFuente),
        ),
      ),
      SettingOption(
        section: SettingsSection.privacy,
        title: tx.actualizacionesYGithub,
        subtitle: tx.queVeGithubCuandoKijiBusca,
        keywords: const ['github', 'actualizaciones', 'version'],
        builder: (context, ref) => ListTile(
          leading: const Icon(Icons.system_update_alt_rounded),
          title: Text(tx.actualizacionesYGithub),
          subtitle: Text(tx.privacidadActualizaciones),
        ),
      ),
      SettingOption(
        section: SettingsSection.privacy,
        title: tx.recomendacionesDeInicio,
        subtitle: tx.queSeLePideAYoutube,
        keywords: const ['recomendaciones', 'descubri', 'mezcla', 'relacionadas', 'youtube'],
        builder: (context, ref) => ListTile(
          leading: const Icon(Icons.auto_awesome_outlined),
          title: Text(tx.recomendacionesDeInicio),
          subtitle: Text(tx.tuGustoSeCalculaEnEste),
        ),
      ),
      SettingOption(
        section: SettingsSection.privacy,
        title: tx.borrarLasBusquedasRecientes,
        subtitle: tx.lasQueAparecenEnBuscarAntes,
        keywords: const ['busquedas', 'recientes', 'borrar', 'buscar'],
        builder: (context, ref) => ListTile(
          leading: const Icon(Icons.manage_search_rounded),
          title: Text(tx.borrarLasBusquedasRecientes),
          subtitle: Text(tx.guardadasEnEsteDispositivo(ref.watch(searchHistoryProvider).length)),
          onTap: () {
            ref.read(searchHistoryProvider.notifier).clear();
            _done(context, tx.busquedasBorradas);
          },
        ),
      ),
      SettingOption(
        section: SettingsSection.privacy,
        title: tx.borrarElHistorialDeEscucha,
        subtitle: tx.vaciaEscuchadoRecientementeYParaTi,
        keywords: const ['historial', 'recientes', 'borrar'],
        builder: (context, ref) => ListTile(
          leading: const Icon(Icons.history_toggle_off_rounded),
          title: Text(tx.borrarElHistorialDeEscucha),
          subtitle: Text(tx.cancionesRecordadas(ref.watch(listeningHistoryProvider).length)),
          onTap: () => _confirm(
            context,
            title: tx.borrarElHistorial,
            message: tx.inicioDejaDeMostrarEscuchadoRecientement,
            action: tx.borrar,
            onConfirm: () async {
              await ref.read(listeningHistoryProvider.notifier).clear();
              if (context.mounted) _done(context, tx.historialBorrado);
            },
          ),
        ),
      ),
      SettingOption(
        section: SettingsSection.privacy,
        title: tx.datosDelReproductorDeYoutubeGithub,
        subtitle: tx.queSeConsultaParaPoderDescifrar,
        keywords: const ['github', 'zemer', 'cipher', 'reproductor', 'extractor'],
        builder: (context, ref) => ListTile(
          leading: const Icon(Icons.memory_rounded),
          title: Text(tx.datosDelReproductorDeYoutubeGithub),
          subtitle: Text(tx.youtubeCambiaSuReproductorCadaPocos),
        ),
      ),
      SettingOption(
        section: SettingsSection.privacy,
        title: tx.pruebasAutomaticasDelExtractor,
        subtitle: tx.cada12HPruebaLasFormas,
        keywords: const ['extractor', 'salud', 'pruebas', 'youtube', 'automatico'],
        builder: (context, ref) => SwitchListTile(
          title: Text(tx.pruebasAutomaticasDelExtractor),
          subtitle: Text(tx.alAbrirKijiSiPasaron12),
          value: ref.watch(settingsProvider).autoExtractorTests,
          onChanged: (value) =>
              ref.read(settingsProvider.notifier).update((s) => s.copyWith(autoExtractorTests: value)),
        ),
      ),
      SettingOption(
        section: SettingsSection.privacy,
        title: tx.saludDelExtractor,
        subtitle: tx.comoEstaFuncionandoYoutubeHoy,
        keywords: const ['youtube', 'extractor', 'diagnostico'],
        builder: (context, ref) => ListTile(
          leading: const Icon(Icons.health_and_safety_outlined),
          title: Text(tx.saludDelExtractor),
          subtitle: Text(tx.comoEstaFuncionandoYoutubeHoy),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => ExtractorHealthScreen.open(context),
        ),
      ),
      // Cuenta de Google opcional.
      SettingOption(
        section: SettingsSection.privacy,
        title: tx.cuentaDeGoogleOpcional,
        subtitle: tx.soloParaCancionesQueYoutubeEntrega,
        keywords: ['cuenta', 'google', tx.iniciarSesion2, 'login', 'edad', tx.cerrarSesion],
        builder: (context, ref) {
          final session = ref.watch(accountProvider);
          return ListTile(
            leading: Icon(session == null ? Icons.person_outline_rounded : Icons.verified_user_rounded),
            title: Text(session == null ? tx.cuentaDeGoogleOpcional : tx.sesionIniciada2),
            subtitle: Text(session == null ? tx.soloParaCancionesConCuenta : tx.tocaParaVerOCerrarLa),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => AccountScreen.open(context),
          );
        },
      ),
      // Registros e informes.
      SettingOption(
        section: SettingsSection.privacy,
        title: tx.guardarUnRegistroEnEsteDispositivo,
        subtitle: tx.ayudaAEntenderUnaFallaSin,
        keywords: const ['registro', 'log', 'errores', 'fallas', 'informe'],
        builder: (context, ref) => SwitchListTile(
          title: Text(tx.guardarUnRegistroEnEsteDispositivo),
          subtitle: Text(tx.ayudaAEntenderUnaFallaSin),
          value: ref.watch(settingsProvider.select((s) => s.saveLogs)),
          onChanged: (v) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(saveLogs: v)),
        ),
      ),
      SettingOption(
        section: SettingsSection.privacy,
        title: tx.ofrecerUnInformeCuandoAlgoFalla,
        subtitle: tx.kijiPreguntaSiQuieresAvisarAl,
        keywords: const ['error', 'informe', 'github', 'reportar', 'fallas'],
        builder: (context, ref) => SwitchListTile(
          title: Text(tx.ofrecerUnInformeCuandoAlgoFalla),
          subtitle: Text(tx.kijiPreguntaSiQuieresAvisarAl),
          value: ref.watch(settingsProvider.select((s) => s.offerErrorReports)),
          onChanged: (v) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(offerErrorReports: v)),
        ),
      ),
      SettingOption(
        section: SettingsSection.privacy,
        title: tx.verElRegistroYLosInformes,
        subtitle: tx.leerElRegistroDescargarUnInforme,
        keywords: const ['registro', 'log', 'informe', 'txt', 'github', 'issue'],
        builder: (context, ref) => ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(tx.verElRegistroYLosInformes),
          subtitle: Text(tx.leerElRegistroDescargarUnInforme),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => ReportsScreen.open(context),
        ),
      ),
      // Herramientas de desarrollo: solo en Kiji Dev.
      if (isDevBuild)
        SettingOption(
          section: SettingsSection.developer,
          title: tx.herramientasDeDesarrollo,
          subtitle: tx.registroEnVivoExtractorCacheY,
          keywords: const ['dev', 'registro', 'log', 'diagnostico', 'cache'],
          builder: (context, ref) => ListTile(
            leading: const Icon(Icons.terminal_rounded),
            title: Text(tx.herramientasDeDesarrollo),
            subtitle: Text(tx.registroEnVivoExtractorCacheY),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => DevToolsScreen.open(context),
          ),
        ),
      // Actualizaciones
      SettingOption(
        section: SettingsSection.about,
        title: tx.buscarActualizaciones,
        subtitle: tx.unaVezPorDiaPreguntaA,
        keywords: const ['version', 'nueva', 'github', 'novedades', 'actualizar'],
        builder: (context, ref) => SwitchListTile(
          title: Text(tx.buscarActualizaciones),
          subtitle: Text(tx.unaVezPorDiaPreguntaA2),
          value: ref.watch(settingsProvider).checkUpdates,
          onChanged: (value) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(checkUpdates: value)),
        ),
      ),
      SettingOption(
        section: SettingsSection.about,
        title: tx.versionDeKiji,
        subtitle: tx.buscarAhoraYVerLasNovedades,
        keywords: ['version', tx.buscarAhora, 'novedades'],
        builder: (context, ref) => const UpdateStatusTile(),
      ),
      // Copia de seguridad
      SettingOption(
        section: SettingsSection.privacy,
        title: tx.importarDesdeOtraApp,
        subtitle: tx.echoMetrolistInnertuneOutertuneM3uExport,
        keywords: const ['backup', 'respaldo', 'importar', 'exportar', 'spotify', 'csv', 'm3u', 'metrolist', 'echo'],
        builder: (context, ref) => ListTile(
          leading: const Icon(Icons.download_rounded),
          title: Text(tx.importarDesdeOtraApp),
          subtitle: Text(tx.playlistsMeGustaEHistorialDe),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => ImportScreen.open(context),
        ),
      ),
      SettingOption(
        section: SettingsSection.privacy,
        title: tx.copiaDeSeguridadDeKiji,
        subtitle: tx.copiaDiariaAutomaticaEnDocumentosKiji,
        keywords: const ['backup', 'respaldo', 'copia', 'restaurar', 'recuperar'],
        builder: (context, ref) {
          final last = ref.watch(backupProvider.select((b) => b.lastBackup));
          final auto = ref.watch(settingsProvider.select((s) => s.autoBackup));
          return ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: Text(tx.copiaDeSeguridadDeKiji),
            subtitle: Text(
              [
                auto ? tx.copiaAutomaticaDiaria : tx.copiaAutomaticaApagada,
                last == null ? tx.todaviaSinCopias : tx.ultima(describeDate(last, DateTime.now())),
              ].join(' · '),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => BackupScreen.open(context),
          );
        },
      ),
      // Acerca de
      SettingOption(
        section: SettingsSection.about,
        title: 'Kiji Player', // l10n-ignore
        subtitle: tx.softwareLibreGpl30,
        keywords: const ['version', 'licencia', 'gpl'],
        builder: (context, ref) => ListTile(
          leading: const KijiLogo(size: 40),
          title: Text('${isDevBuild ? 'Kiji Dev' : 'Kiji Player'} $kijiVersionLabel'), // l10n-ignore
          subtitle: Text(tx.canalCompiladaElSoftwareLibreGpl(kijiChannel, kijiBuildDateLabel)),
          isThreeLine: true,
        ),
      ),
      SettingOption(
        section: SettingsSection.about,
        title: tx.novedadesDeEstaVersion,
        subtitle: tx.novedadesDeEstaVersionDescripcion(kijiVersion),
        keywords: const ['changelog', 'novedades', 'cambios', 'version', 'whats new'], // l10n-ignore
        builder: (context, ref) => ListTile(
          leading: const Icon(Icons.auto_awesome_outlined),
          title: Text(tx.novedadesDeEstaVersion),
          subtitle: Text(tx.novedadesDeEstaVersionDescripcion(kijiVersion)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () async {
            final notes = await loadBundledWhatsNew(kijiLanguage);
            if (context.mounted) await showWhatsNewSheet(context, notes ?? tx.estaVersionNoTraeNovedades);
          },
        ),
      ),
      SettingOption(
        section: SettingsSection.about,
        title: tx.verBienvenidaOtraVez,
        subtitle: tx.verBienvenidaOtraVezTexto,
        keywords: const ['bienvenida', 'welcome', 'inicio', 'tutorial'],
        builder: (context, ref) => ListTile(
          leading: const Icon(Icons.waving_hand_outlined),
          title: Text(tx.verBienvenidaOtraVez),
          subtitle: Text(tx.verBienvenidaOtraVezTexto),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => WelcomeScreen.open(context),
        ),
      ),
      SettingOption(
        section: SettingsSection.about,
        title: tx.creditos,
        subtitle: tx.losProyectosLibresEnLosQue,
        keywords: const ['echo', 'metrolist', 'licencias', 'agradecimientos'],
        builder: (context, ref) => ListTile(
          leading: const Icon(Icons.favorite_outline_rounded),
          title: Text(tx.creditos),
          subtitle: Text(tx.losProyectosLibresEnLosQue),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => CreditsScreen.open(context),
        ),
      ),
    ];
  }

  Future<void> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
    required Future<void> Function() onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tx.cancelar)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
        ],
      ),
    );
    if (confirmed == true) await onConfirm();
  }

  /// Al prender "Descargar lo que me gusta" se pregunta por las que ya tenían me gusta: de
  /// fábrica solo se bajan las nuevas (nada de cientos de descargas de golpe sin avisar).
  Future<void> _setDownloadLiked(BuildContext context, WidgetRef ref, bool value) async {
    await ref.read(settingsProvider.notifier).update((s) => s.copyWith(downloadLiked: value));
    if (!value) return;
    final downloads = ref.read(downloadsProvider);
    final missing = [
      for (final track in ref.read(favoritesProvider).values)
        if (track.youtubeVideoId case final id?)
          if (!downloads.completed.containsKey(id) && !downloads.active.containsKey(id)) track,
    ];
    if (missing.isEmpty || !context.mounted) return;
    final all = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(tx.tambienLasQueYaTeGustan),
        content: Text(tx.tambienLasQueYaTeGustanTexto(missing.length)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(tx.soloLasNuevas)),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(tx.tambienEsasN(missing.length))),
        ],
      ),
    );
    if (all == true) ref.read(autoDownloadsProvider.notifier).enqueue(missing);
  }

  void _done(BuildContext context, String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Tema y acento solo cambian Nocturne: en Grafito y Papel la opción se ve apagada y dice por qué.
/// null en Nocturne.
Widget? _onlyInNocturne(WidgetRef ref, IconData icon, String title) {
  if (ref.watch(settingsProvider.select((s) => s.style)) == KijiStyle.nocturne.name) return null;
  return ListTile(enabled: false, leading: Icon(icon), title: Text(title), subtitle: Text(tx.soloEnNocturne));
}

/// Una opción con varias alternativas (formato de hora, tema, acento…): muestra la elegida y,
/// al tocarla, una lista para cambiarla.
Widget choiceTile<T>(
  BuildContext context, {
  required IconData icon,
  required String title,
  required T value,
  required List<T> options,
  required String Function(T option) label,
  required void Function(T value) onChanged,
}) {
  return ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(label(value)),
    onTap: () async {
      final picked = await showDialog<T>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(title),
          children: [
            RadioGroup<T>(
              groupValue: value,
              onChanged: (value) => Navigator.pop(context, value),
              child: Column(
                children: [for (final option in options) RadioListTile<T>(value: option, title: Text(label(option)))],
              ),
            ),
          ],
        ),
      );
      if (picked != null && picked != value) onChanged(picked);
    },
  );
}

/// Tarjeta de una sección: ícono, nombre y descripción corta.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section, required this.onTap, this.selected = false});

  final SettingsSection section;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Glass(
      blur: false,
      radius: KijiRadii.tile,
      child: ListTile(
        key: ValueKey('seccion-${section.name}'),
        selected: selected,
        selectedTileColor: KijiColors.violet.withValues(alpha: 0.14),
        selectedColor: KijiColors.text,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Icon(section.icon, color: KijiColors.cyan),
        title: Text(section.label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(section.description, style: TextStyle(color: KijiColors.muted)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

/// Una sección de Configuración en su propia pantalla (teléfono).
class SettingsSectionScreen extends StatelessWidget {
  const SettingsSectionScreen({super.key, required this.section, required this.options, this.highlight});

  final SettingsSection section;
  final List<SettingOption> Function() options;
  final String? highlight;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(section.label)),
    body: SettingsSectionView(section: section, options: options, highlight: highlight),
  );
}

/// Los ajustes de una sección. Si viene de una búsqueda, va hasta [highlight] y lo resalta un
/// momento.
class SettingsSectionView extends ConsumerStatefulWidget {
  const SettingsSectionView({
    super.key,
    required this.section,
    required this.options,
    this.highlight,
    this.showTitle = false,
  });

  final SettingsSection section;
  final List<SettingOption> Function() options;
  final String? highlight;

  /// En la PC, el nombre y la descripción de la sección arriba (en el teléfono van en la barra).
  final bool showTitle;

  @override
  ConsumerState<SettingsSectionView> createState() => _SettingsSectionViewState();
}

class _SettingsSectionViewState extends ConsumerState<SettingsSectionView> {
  final _target = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.highlight == null) return;
    // Espera a que la pantalla termine de entrar y lleva el ajuste a la vista.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final target = _target.currentContext;
      if (target == null || !target.mounted) return;
      await Scrollable.ensureVisible(
        target,
        alignment: 0.3,
        duration: KijiEffects.still(target) ? Duration.zero : KijiMotion.emphasized,
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.options().where((o) => o.section == widget.section).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        if (widget.showTitle) ...[
          Row(
            children: [
              Icon(widget.section.icon, color: KijiColors.cyan),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.section.label, style: KijiText.title(size: 22))),
            ],
          ),
          const SizedBox(height: 4),
          Text(widget.section.description, style: TextStyle(color: KijiColors.muted)),
          const SizedBox(height: 14),
        ],
        Glass(
          blur: false,
          radius: KijiRadii.tile,
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                for (final option in options)
                  option.title == widget.highlight
                      ? SettingHighlight(key: _target, child: option.builder(context, ref))
                      : option.builder(context, ref),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Resalta un ajuste un momento (el que se tocó en la búsqueda): un fondo del acento que se
/// desvanece. Con "Reducir animaciones", se ve fijo un instante y se va sin fundido.
class SettingHighlight extends StatefulWidget {
  const SettingHighlight({super.key, required this.child});

  static const duration = Duration(milliseconds: 2200);

  final Widget child;

  @override
  State<SettingHighlight> createState() => _SettingHighlightState();
}

class _SettingHighlightState extends State<SettingHighlight> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: SettingHighlight.duration)..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = KijiEffects.still(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        // Fijo los primeros 2/3 y después se desvanece (o se corta, sin animaciones).
        final t = _c.value;
        final strength = t < 0.66 ? 1.0 : (still ? 0.0 : 1 - (t - 0.66) / 0.34);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: KijiColors.violet.withValues(alpha: 0.16 * strength),
            border: Border(
              left: BorderSide(color: KijiColors.violet.withValues(alpha: strength), width: 3),
            ),
          ),
          child: child,
        );
      },
      // Material propio: el efecto al tocar y los interruptores se pintan encima del resaltado.
      child: Material(type: MaterialType.transparency, child: widget.child),
    );
  }
}
