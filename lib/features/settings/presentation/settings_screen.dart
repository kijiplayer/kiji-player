// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivos de referencia: app/src/main/kotlin/.../ui/screens/settings/ (secciones) y
// SearchableSettings.kt (buscador de opciones).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/history/listening_history.dart';
import '../../../providers/downloads_provider.dart';
import '../../../providers/playback_provider.dart';
import '../../../theme/kiji_tokens.dart';
import '../../../utils/byte_formatter.dart';
import '../../../widgets/kiji_logo.dart';
import '../../../widgets/nocturne/glass.dart';
import '../../backup/data/backup_notifier.dart';
import '../../backup/presentation/backup_screen.dart';
import '../../downloads/domain/download_settings.dart';
import '../../downloads/presentation/downloads_screen.dart';
import '../../equalizer/data/equalizer_notifier.dart';
import '../../equalizer/presentation/equalizer_screen.dart';
import '../../import/presentation/import_screen.dart';
import '../../recommendations/data/search_history.dart';
import '../../translation/domain/languages.dart';
import '../../translation/presentation/lyrics_settings_screens.dart';
import '../../yt_music/presentation/extractor_health_screen.dart';
import '../data/settings_store.dart';
import '../domain/app_settings.dart';
import '../domain/setting_search.dart';
import 'credits_screen.dart';

/// Secciones de Configuración, en el orden del plan (Tarea G).
enum SettingsSection {
  player('Reproductor y audio', Icons.play_circle_outline_rounded),
  content('Contenido', Icons.library_music_outlined),
  lyrics('Letras', Icons.lyrics_outlined),
  appearance('Apariencia', Icons.palette_outlined),
  storage('Almacenamiento', Icons.sd_storage_outlined),
  privacy('Privacidad', Icons.shield_outlined),
  backup('Copia de seguridad', Icons.backup_outlined),
  about('Acerca de', Icons.info_outline_rounded);

  const SettingsSection(this.label, this.icon);
  final String label;
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

  bool matches(String query) => settingMatches(
        query,
        title: title,
        subtitle: subtitle,
        section: section.label,
        keywords: keywords,
      );
}

/// Pantalla de Configuración con buscador de opciones desde el primer día.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
      );

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = _options();
    final query = _query.text.trim();
    final visible = query.isEmpty ? options : options.where((o) => o.matches(query)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          GradientBorder(
            radius: KijiRadii.pill,
            fill: KijiColors.surface,
            child: TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar una opción…',
                prefixIcon: const Icon(Icons.search_rounded, color: KijiColors.muted),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Borrar la búsqueda',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(_query.clear),
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No hay ninguna opción con ese nombre.',
                textAlign: TextAlign.center,
                style: TextStyle(color: KijiColors.muted),
              ),
            ),
          for (final section in SettingsSection.values)
            if (visible.any((o) => o.section == section)) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                child: Row(
                  children: [
                    Icon(section.icon, size: 18, color: KijiColors.cyan),
                    const SizedBox(width: 8),
                    Text(section.label.toUpperCase(), style: KijiText.mono(size: 11)),
                  ],
                ),
              ),
              Glass(
                blur: false,
                radius: KijiRadii.tile,
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    children: [
                      for (final option in visible.where((o) => o.section == section))
                        option.builder(context, ref),
                    ],
                  ),
                ),
              ),
            ],
        ],
      ),
    );
  }

  List<SettingOption> _options() {
    return [
      // Reproductor y audio
      SettingOption(
        section: SettingsSection.player,
        title: 'Recordar la cola al cerrar',
        subtitle: 'Al abrir Kiji, volver a la canción y al segundo donde quedó (en pausa).',
        keywords: const ['memoria', 'reanudar', 'continuar', 'guardar cola'],
        builder: (context, ref) => SwitchListTile(
          title: const Text('Recordar la cola al cerrar'),
          subtitle: const Text('Al abrir Kiji, vuelve a la canción y al segundo donde quedó, en pausa.'),
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
        title: 'Ecualizador',
        subtitle: 'Presets, bandas a mano y un perfil por dispositivo (parlante, auriculares, Bluetooth).',
        keywords: const ['eq', 'graves', 'agudos', 'bajos', 'sonido', 'auriculares', 'bluetooth'],
        builder: (context, ref) => ListTile(
          leading: const Icon(Icons.equalizer_rounded),
          title: const Text('Ecualizador'),
          subtitle: Text(ref.watch(equalizerProvider.select((e) => e.settings.enabled))
              ? 'Encendido: ${ref.watch(equalizerProvider.select((e) => e.activeProfile.label))}'
              : 'Apagado'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => EqualizerScreen.open(context),
        ),
      ),
      SettingOption(
        section: SettingsSection.player,
        title: 'Transición suave entre canciones',
        subtitle: 'La canción baja al final y la siguiente sube al empezar.',
        keywords: const ['crossfade', 'fundido', 'mezcla', 'fade', 'transicion'],
        builder: (context, ref) {
          final seconds = ref.watch(settingsProvider.select((s) => s.crossfadeSeconds));
          return ListTile(
            leading: const Icon(Icons.swap_horiz_rounded),
            title: const Text('Transición suave entre canciones'),
            subtitle: Text(seconds == 0
                ? 'Apagada'
                : '$seconds s: la canción baja al final y la siguiente sube al empezar.'),
            trailing: Text(seconds == 0 ? 'No' : '$seconds s', style: KijiText.mono(size: 13)),
            // Toda la fila abre la lista (antes solo respondía el texto chico de la derecha).
            onTap: () async {
              final value = await showDialog<int>(
                context: context,
                builder: (context) => SimpleDialog(
                  title: const Text('Transición suave'),
                  children: [
                    RadioGroup<int>(
                      groupValue: seconds,
                      onChanged: (value) => Navigator.pop(context, value),
                      child: Column(
                        children: [
                          for (final option in AppSettings.crossfadeOptions)
                            RadioListTile<int>(
                              value: option,
                              title: Text(option == 0 ? 'Apagada' : '$option segundos'),
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
        title: 'Pausar al silenciar',
        subtitle: 'Si bajás el volumen a cero, la música se pausa; al subirlo, sigue.',
        keywords: const ['mute', 'silencio', 'volumen cero', 'pausa'],
        builder: (context, ref) => SwitchListTile(
          title: const Text('Pausar al silenciar'),
          subtitle: const Text(
            'Si bajás el volumen del teléfono a cero, la música se pausa; al subirlo, sigue. Solo en Android.',
          ),
          value: ref.watch(settingsProvider).pauseOnMute,
          onChanged: (value) =>
              ref.read(settingsProvider.notifier).update((s) => s.copyWith(pauseOnMute: value)),
        ),
      ),
      SettingOption(
        section: SettingsSection.player,
        title: 'Retomar al reconectar el Bluetooth',
        subtitle: 'Si la música se cortó al desconectarse los auriculares, sigue al volver.',
        keywords: const ['auriculares', 'bluetooth', 'reanudar', 'auto', 'coche'],
        builder: (context, ref) => SwitchListTile(
          title: const Text('Retomar al reconectar el Bluetooth'),
          subtitle: const Text(
            'Si la música sonaba cuando se desconectaron los auriculares y vuelven en menos de 10 minutos, '
            'sigue sola.',
          ),
          value: ref.watch(settingsProvider).resumeOnBluetooth,
          onChanged: (value) =>
              ref.read(settingsProvider.notifier).update((s) => s.copyWith(resumeOnBluetooth: value)),
        ),
      ),
      // Contenido
      SettingOption(
        section: SettingsSection.content,
        title: 'Ocultar audios cortos',
        subtitle: 'No mostrar en la Biblioteca los audios de menos de 30 segundos.',
        keywords: const ['sonidos', 'notificaciones', 'juegos', 'tonos', 'filtrar'],
        builder: (context, ref) => SwitchListTile(
          title: const Text('Ocultar audios cortos'),
          subtitle: const Text(
            'No muestra en la Biblioteca los audios de menos de 30 segundos (avisos, sonidos de juegos). '
            'No borra nada.',
          ),
          value: ref.watch(settingsProvider).hideShortAudios,
          onChanged: (value) =>
              ref.read(settingsProvider.notifier).update((s) => s.copyWith(hideShortAudios: value)),
        ),
      ),
      // Letras
      SettingOption(
        section: SettingsSection.lyrics,
        title: 'Fuentes de letras',
        subtitle: 'Dónde busca Kiji las letras; cada fuente se puede apagar.',
        keywords: const ['letra', 'lrclib', 'kugou', 'karaoke', 'sincronizada'],
        builder: (context, ref) => ListTile(
          leading: const Icon(Icons.travel_explore_rounded),
          title: const Text('Fuentes de letras'),
          subtitle: Text(ref.watch(settingsProvider).disabledLyricsSources.isEmpty
              ? 'Todas prendidas.'
              : '${ref.watch(settingsProvider).disabledLyricsSources.length} apagadas.'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => LyricsSourcesScreen.open(context),
        ),
      ),
      SettingOption(
        section: SettingsSection.lyrics,
        title: 'Traducción de letras',
        subtitle: 'En tu teléfono (anónima) o con Gemini (opcional).',
        keywords: const ['traducir', 'idioma', 'gemini', 'ia', 'ingles'],
        builder: (context, ref) => ListTile(
          leading: const Icon(Icons.translate_rounded),
          title: const Text('Traducción de letras'),
          subtitle: Text('Al ${languageName(ref.watch(settingsProvider).translationTarget).toLowerCase()} · '
              '${ref.watch(settingsProvider).useGemini && ref.watch(settingsProvider).geminiEnabled ? 'con Gemini' : 'en tu teléfono'}'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => TranslationSettingsScreen.open(context),
        ),
      ),
      // Apariencia
      SettingOption(
        section: SettingsSection.appearance,
        title: 'Reducir animaciones',
        subtitle: 'Sin animaciones decorativas, como el anillo que respira del botón play.',
        keywords: const ['movimiento', 'accesibilidad', 'mareo', 'animacion'],
        builder: (context, ref) => SwitchListTile(
          title: const Text('Reducir animaciones'),
          subtitle: const Text('Sin animaciones decorativas (por ejemplo, el anillo que respira del botón play).'),
          value: ref.watch(settingsProvider).reduceMotion,
          onChanged: (value) =>
              ref.read(settingsProvider.notifier).update((s) => s.copyWith(reduceMotion: value)),
        ),
      ),
      // Almacenamiento
      SettingOption(
        section: SettingsSection.storage,
        title: 'Descargar solo con WiFi',
        subtitle: 'No usa los datos móviles para descargar.',
        keywords: const ['datos', 'movil', 'descargas'],
        builder: (context, ref) => SwitchListTile(
          title: const Text('Descargar solo con WiFi'),
          subtitle: const Text('No usa los datos móviles para descargar.'),
          value: ref.watch(downloadsProvider).settings.wifiOnly,
          onChanged: ref.read(downloadsProvider.notifier).setWifiOnly,
        ),
      ),
      SettingOption(
        section: SettingsSection.storage,
        title: 'Límite de espacio para descargas',
        keywords: const ['descargas', 'espacio', 'gb'],
        builder: (context, ref) {
          final downloads = ref.watch(downloadsProvider);
          return ListTile(
            title: const Text('Límite de espacio para descargas'),
            subtitle: Text('Usado: ${formatBytes(downloads.usedBytes)}'),
            trailing: DropdownButton<int?>(
              value: downloads.settings.limitBytes,
              underline: const SizedBox.shrink(),
              items: [
                for (final option in DownloadSettings.limitOptions)
                  DropdownMenuItem(
                    value: option,
                    child: Text(option == null ? 'Sin límite' : formatBytes(option)),
                  ),
              ],
              onChanged: ref.read(downloadsProvider.notifier).setLimit,
            ),
          );
        },
      ),
      SettingOption(
        section: SettingsSection.storage,
        title: 'Límite de la caché',
        subtitle: 'Lo que ya escuchaste se guarda para no bajarlo otra vez.',
        keywords: const ['cache', 'espacio', 'escuchado', 'streaming'],
        builder: (context, ref) => ListTile(
          title: const Text('Límite de la caché'),
          subtitle: const Text('Lo ya escuchado se guarda para no bajarlo otra vez. Lo más viejo se borra solo.'),
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
        title: 'Vaciar la caché',
        subtitle: 'Libera espacio. Las descargas no se tocan.',
        keywords: const ['cache', 'borrar', 'liberar', 'espacio'],
        builder: (context, ref) => ListTile(
          leading: const Icon(Icons.cleaning_services_outlined),
          title: const Text('Vaciar la caché'),
          subtitle: const Text('Libera espacio. Las descargas no se tocan.'),
          onTap: () => _confirm(
            context,
            title: '¿Vaciar la caché?',
            message: 'Las canciones que ya escuchaste se van a volver a bajar la próxima vez. '
                'Las descargas no se tocan.',
            action: 'Vaciar',
            onConfirm: () async {
              await ref.read(playbackProvider.notifier).clearStreamCache();
              if (context.mounted) _done(context, 'Caché vaciada');
            },
          ),
        ),
      ),
      SettingOption(
        section: SettingsSection.storage,
        title: 'Ahorro de datos',
        subtitle: 'Con datos móviles, YouTube suena en calidad baja. Con WiFi, en la mejor.',
        keywords: const ['datos', 'movil', 'calidad', 'consumo', 'megas'],
        builder: (context, ref) => SwitchListTile(
          title: const Text('Ahorro de datos'),
          subtitle: const Text(
            'Con datos móviles, YouTube suena en la calidad más baja (gasta unas 4 veces menos). '
            'Con WiFi, siempre en la mejor.',
          ),
          value: ref.watch(settingsProvider).dataSaver,
          onChanged: (value) =>
              ref.read(settingsProvider.notifier).update((s) => s.copyWith(dataSaver: value)),
        ),
      ),
      SettingOption(
        section: SettingsSection.storage,
        title: 'Ver y borrar descargas',
        keywords: const ['descargadas', 'borrar', 'sin conexion'],
        builder: (context, ref) => ListTile(
          leading: const Icon(Icons.download_for_offline_outlined),
          title: const Text('Ver y borrar descargas'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => DownloadsScreen.open(context),
        ),
      ),
      // Privacidad
      SettingOption(
        section: SettingsSection.privacy,
        title: 'Qué guarda Kiji',
        subtitle: 'Sin cuentas, sin anuncios y sin telemetría.',
        keywords: const ['datos', 'telemetria', 'cuenta', 'transparencia'],
        builder: (context, ref) => const ListTile(
          leading: Icon(Icons.verified_user_outlined, color: KijiColors.cyan),
          title: Text('Qué guarda Kiji'),
          subtitle: Text(
            'Sin cuentas, sin anuncios y sin telemetría. Tu cola, tus descargas, tu historial y tus '
            'me gusta se guardan solo en este dispositivo.',
          ),
        ),
      ),
      SettingOption(
        section: SettingsSection.privacy,
        title: 'Letras y traducción',
        subtitle: 'Qué se envía al buscar o traducir una letra.',
        keywords: const ['letras', 'traduccion', 'gemini', 'clave'],
        builder: (context, ref) => const ListTile(
          leading: Icon(Icons.lyrics_outlined),
          title: Text('Letras y traducción'),
          subtitle: Text(
            'Al abrir una letra, cada fuente recibe solo título, artista, álbum, duración o el id del video. '
            'La traducción en el teléfono no envía nada (solo se baja el modelo del idioma, una vez). '
            'Gemini es opcional y está apagado: si lo activás, las líneas de la letra van a Google con tu '
            'clave, que queda cifrada solo en este dispositivo.',
          ),
        ),
      ),
      SettingOption(
        section: SettingsSection.privacy,
        title: 'Recomendaciones de Inicio',
        subtitle: 'Qué se le pide a YouTube Music para "Porque escuchaste", "Mezcla" y "Descubrí".',
        keywords: const ['recomendaciones', 'descubri', 'mezcla', 'relacionadas', 'youtube'],
        builder: (context, ref) => const ListTile(
          leading: Icon(Icons.auto_awesome_outlined),
          title: Text('Recomendaciones de Inicio'),
          subtitle: Text(
            'Tu gusto se calcula en este teléfono. A YouTube Music solo se le piden, sin cuenta, las '
            'canciones relacionadas con hasta 5 que escuchaste (solo su id). Tu historial no sale de acá.',
          ),
        ),
      ),
      SettingOption(
        section: SettingsSection.privacy,
        title: 'Borrar las búsquedas recientes',
        subtitle: 'Las que aparecen en Buscar antes de escribir.',
        keywords: const ['busquedas', 'recientes', 'borrar', 'buscar'],
        builder: (context, ref) => ListTile(
          leading: const Icon(Icons.manage_search_rounded),
          title: const Text('Borrar las búsquedas recientes'),
          subtitle: Text('${ref.watch(searchHistoryProvider).length} guardadas en este dispositivo'),
          onTap: () {
            ref.read(searchHistoryProvider.notifier).clear();
            _done(context, 'Búsquedas borradas');
          },
        ),
      ),
      SettingOption(
        section: SettingsSection.privacy,
        title: 'Borrar el historial de escucha',
        subtitle: 'Vacía "Escuchado recientemente" y "Para vos".',
        keywords: const ['historial', 'recientes', 'borrar'],
        builder: (context, ref) => ListTile(
          leading: const Icon(Icons.history_toggle_off_rounded),
          title: const Text('Borrar el historial de escucha'),
          subtitle: Text('${ref.watch(listeningHistoryProvider).length} canciones recordadas'),
          onTap: () => _confirm(
            context,
            title: '¿Borrar el historial?',
            message: 'Inicio deja de mostrar "Escuchado recientemente" y "Para vos" hasta que vuelvas '
                'a escuchar música. No borra canciones ni descargas.',
            action: 'Borrar',
            onConfirm: () async {
              await ref.read(listeningHistoryProvider.notifier).clear();
              if (context.mounted) _done(context, 'Historial borrado');
            },
          ),
        ),
      ),
      SettingOption(
        section: SettingsSection.privacy,
        title: 'Salud del Extractor',
        subtitle: 'Cómo está funcionando YouTube hoy.',
        keywords: const ['youtube', 'extractor', 'diagnostico'],
        builder: (context, ref) => ListTile(
          leading: const Icon(Icons.health_and_safety_outlined),
          title: const Text('Salud del Extractor'),
          subtitle: const Text('Cómo está funcionando YouTube hoy.'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => ExtractorHealthScreen.open(context),
        ),
      ),
      // Copia de seguridad
      SettingOption(
        section: SettingsSection.backup,
        title: 'Importar desde otra app',
        subtitle: 'Echo, Metrolist, InnerTune, OuterTune, .m3u, Exportify y Google Takeout.',
        keywords: const ['backup', 'respaldo', 'importar', 'exportar', 'spotify', 'csv', 'm3u', 'metrolist', 'echo'],
        builder: (context, ref) => ListTile(
          leading: const Icon(Icons.download_rounded),
          title: const Text('Importar desde otra app'),
          subtitle: const Text(
            'Playlists, me gusta e historial de Echo, Metrolist, InnerTune u OuterTune (.backup), '
            '.m3u, y CSV de Exportify o Google Takeout. También exportar tus playlists.',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => ImportScreen.open(context),
        ),
      ),
      SettingOption(
        section: SettingsSection.backup,
        title: 'Copia de seguridad de Kiji',
        subtitle: 'Copia diaria automática en Documentos/Kiji; restaurar con vista previa.',
        keywords: const ['backup', 'respaldo', 'copia', 'restaurar', 'recuperar'],
        builder: (context, ref) {
          final last = ref.watch(backupProvider.select((b) => b.lastBackup));
          final auto = ref.watch(settingsProvider.select((s) => s.autoBackup));
          return ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Copia de seguridad de Kiji'),
            subtitle: Text([
              auto ? 'Copia automática diaria' : 'Copia automática apagada',
              last == null ? 'todavía sin copias' : 'última: ${describeDate(last, DateTime.now())}',
            ].join(' · ')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => BackupScreen.open(context),
          );
        },
      ),
      // Acerca de
      SettingOption(
        section: SettingsSection.about,
        title: 'Kiji Player',
        subtitle: 'Software libre (GPL-3.0).',
        keywords: const ['version', 'licencia', 'gpl'],
        builder: (context, ref) => const ListTile(
          leading: KijiLogo(size: 40),
          title: Text('Kiji Player 1.0.0'),
          subtitle: Text('Software libre (GPL-3.0). Sin pagos, sin anuncios y sin telemetría.'),
        ),
      ),
      SettingOption(
        section: SettingsSection.about,
        title: 'Créditos',
        subtitle: 'Los proyectos libres en los que se basa Kiji.',
        keywords: const ['echo', 'metrolist', 'licencias', 'agradecimientos'],
        builder: (context, ref) => ListTile(
          leading: const Icon(Icons.favorite_outline_rounded),
          title: const Text('Créditos'),
          subtitle: const Text('Los proyectos libres en los que se basa Kiji.'),
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
        ],
      ),
    );
    if (confirmed == true) await onConfirm();
  }

  void _done(BuildContext context, String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
