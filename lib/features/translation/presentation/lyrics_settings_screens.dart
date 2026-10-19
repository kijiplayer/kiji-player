import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../theme/kiji_tokens.dart';
import '../../../utils/byte_formatter.dart';
import '../../../widgets/nocturne/glass.dart';
import '../../lyrics/domain/lyrics.dart';
import '../../settings/data/settings_store.dart';
import '../data/gemini_client.dart';
import '../data/translation_service.dart';
import '../domain/languages.dart';

/// Texto del apartado 1, tal como se definió.
const localTranslationNotice =
    'La letra se traduce dentro de tu teléfono. No se envía a nadie y no pierdes anonimato. Solo una vez '
    'por idioma se descarga el modelo de traducción (el servidor solo sabe que alguien bajó ese idioma, no '
    'qué canción). Es buena para entender la letra, aunque a veces suena literal.';

/// Configuración → Letras → Fuentes: una por una, se pueden apagar.
class LyricsSourcesScreen extends ConsumerWidget {
  const LyricsSourcesScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LyricsSourcesScreen()));

  static const _sends = {
    LyricsSource.lrclib: 'título, artista, álbum y duración',
    LyricsSource.youlyplus: 'título, artista, álbum, duración e id del video',
    LyricsSource.paxsenix: 'título y artista',
    LyricsSource.unison: 'id del video, o título, artista y duración',
    LyricsSource.betterlyrics: 'título, artista, álbum y duración',
    LyricsSource.kugou: 'título, artista y duración',
    LyricsSource.youtubeSubtitles: 'id del video (a YouTube)',
    LyricsSource.youtubeMusic: 'id del video (a YouTube Music)',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disabled = ref.watch(settingsProvider.select((s) => s.disabledLyricsSources));
    final order = ref.watch(settingsProvider.select((s) => s.lyricsSourceOrder));
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Fuentes de letras')),
      body: ReorderableListView(
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        header: const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Kiji busca la letra primero en el archivo (sin internet) y después en estas fuentes, en este '
            'orden, hasta que una la tenga. Arrastra para cambiar el orden. Solo se busca cuando abres la '
            'letra, y cada fuente recibe únicamente lo que dice abajo; nada tuyo.',
            style: TextStyle(color: KijiColors.muted),
          ),
        ),
        onReorderItem: (from, to) {
          final next = [...order];
          next.insert(to, next.removeAt(from));
          notifier.update((s) => s.copyWith(lyricsSourceOrder: next));
        },
        children: [
          for (final (index, source) in order.indexed)
            ListTile(
              key: ValueKey(source),
              contentPadding: const EdgeInsets.only(left: 4),
              leading: ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.drag_indicator_rounded, semanticLabel: 'Arrastrar para cambiar el orden'),
                ),
              ),
              title: Text('${index + 1}. ${source.label}'),
              subtitle: Text('Recibe: ${_sends[source] ?? '—'}'),
              trailing: Switch(
                value: !disabled.contains(source),
                onChanged: (on) => notifier.update((s) => s.copyWith(
                      disabledLyricsSources: on
                          ? ({...s.disabledLyricsSources}..remove(source))
                          : {...s.disabledLyricsSources, source},
                    )),
              ),
            ),
        ],
      ),
    );
  }
}

/// Configuración → Letras → Traducción: dos apartados claramente separados.
class TranslationSettingsScreen extends ConsumerStatefulWidget {
  const TranslationSettingsScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TranslationSettingsScreen()));

  @override
  ConsumerState<TranslationSettingsScreen> createState() => _TranslationSettingsScreenState();
}

class _TranslationSettingsScreenState extends ConsumerState<TranslationSettingsScreen> {
  Map<String, int>? _installed;
  bool _hasKey = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final service = ref.read(translationServiceProvider);
    final installed = await service.models.installed();
    final key = await service.secrets.read(geminiKeySecret);
    if (mounted) {
      setState(() {
        _installed = installed;
        _hasKey = key != null && key.isNotEmpty;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    Widget section(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Glass(
            blur: false,
            radius: KijiRadii.tile,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(title, style: KijiText.title(size: 17)), const SizedBox(height: 8), ...children],
              ),
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Traducción de letras')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          const Text(
            'Original y traducción se ven línea por línea (en la letra: ⋮ → Traducir la letra). Cada '
            'traducción se guarda para no repetirla.',
            style: TextStyle(color: KijiColors.muted),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: settings.translationTarget,
            decoration: const InputDecoration(labelText: 'Traducir al'),
            items: [
              for (final entry in translationLanguages.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) {
              if (value != null) notifier.update((s) => s.copyWith(translationTarget: value));
            },
          ),
          const SizedBox(height: 16),
          section('1 · En tu teléfono (anónimo)', [
            const Text(localTranslationNotice),
            const SizedBox(height: 8),
            const Text(
              'Motor y modelos de Firefox Translations (Mozilla, licencia MPL-2.0).',
              style: TextStyle(color: KijiColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text('IDIOMAS BAJADOS', style: KijiText.mono(size: 11)),
            if (_installed == null)
              const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator())
            else if (_installed!.isEmpty)
              const Text('Ninguno todavía: se bajan solos (avisando el tamaño) la primera vez que traduces.',
                  style: TextStyle(color: KijiColors.muted))
            else
              for (final entry in _installed!.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.key.split('-').map(languageName).join(' → ')),
                  subtitle: Text(formatBytes(entry.value)),
                  trailing: IconButton(
                    tooltip: 'Borrar',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () async {
                      await ref.read(translationServiceProvider).models.delete(entry.key);
                      await _refresh();
                    },
                  ),
                ),
          ]),
          section('2 · Con IA (Gemini)', [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Traducir con Gemini'),
              subtitle: Text(settings.geminiEnabled
                  ? 'Activado. Pierdes parte del anonimato al usarlo.'
                  : 'Apagado. Antes de activarlo vas a ver qué implica.'),
              value: settings.geminiEnabled,
              onChanged: (on) async {
                if (!on) {
                  await notifier.update((s) => s.copyWith(geminiEnabled: false, useGemini: false));
                  return;
                }
                final accepted = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const GeminiConsentScreen()),
                );
                if (accepted == true) await notifier.update((s) => s.copyWith(geminiEnabled: true));
              },
            ),
            if (settings.geminiEnabled) ...[
              const SizedBox(height: 4),
              _GeminiSetup(hasKey: _hasKey, onChanged: _refresh),
              if (_hasKey && settings.geminiModel != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Usar Gemini para traducir'),
                  subtitle: const Text('Si lo apagas, se traduce en el teléfono.'),
                  value: settings.useGemini,
                  onChanged: (on) => notifier.update((s) => s.copyWith(useGemini: on)),
                ),
            ],
          ]),
        ],
      ),
    );
  }
}

/// Pantalla de avisos antes de activar Gemini (en palabras simples).
class GeminiConsentScreen extends StatelessWidget {
  const GeminiConsentScreen({super.key});

  static const points = [
    'Pierdes parte del anonimato: las líneas de la letra se envían a Google, asociadas a tu cuenta de '
        'Google (por la clave).',
    'En el nivel gratuito, Google usa ese contenido para mejorar sus productos y personas de Google pueden '
        'leerlo (Google dice que lo separa de tu cuenta antes).',
    'Kiji NO envía tu nombre, tu historial ni tu biblioteca: solo las líneas de la letra y el idioma de '
        'destino.',
    'Requisitos de Google: tener 18 años o más. En Europa, Reino Unido y Suiza el nivel gratuito no está '
        'permitido para esto.',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Antes de usar Gemini')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          const Text('Qué cambia si activas la traducción con Gemini', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 16),
          for (final point in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2, right: 10),
                    child: Icon(Icons.info_outline_rounded, size: 20, color: KijiColors.cyan),
                  ),
                  Expanded(child: Text(point)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'Si no quieres nada de esto, la traducción en tu teléfono sigue disponible y es anónima.',
            style: TextStyle(color: KijiColors.muted),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Entiendo, activar')),
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Mejor no')),
        ],
      ),
    );
  }
}

/// Guía paso a paso, clave, probar y elegir modelo.
class _GeminiSetup extends ConsumerStatefulWidget {
  const _GeminiSetup({required this.hasKey, required this.onChanged});

  final bool hasKey;
  final Future<void> Function() onChanged;

  @override
  ConsumerState<_GeminiSetup> createState() => _GeminiSetupState();
}

class _GeminiSetupState extends ConsumerState<_GeminiSetup> {
  final _key = TextEditingController();
  List<GeminiModel>? _models;
  String? _status;
  bool _testing = false;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final service = ref.read(translationServiceProvider);
    final typed = _key.text.trim();
    final key = typed.isNotEmpty ? typed : await service.secrets.read(geminiKeySecret);
    if (key == null || key.isEmpty) {
      setState(() => _status = 'Pega la clave primero.');
      return;
    }
    setState(() {
      _testing = true;
      _status = null;
    });
    try {
      final models = await service.gemini.models(key);
      if (typed.isNotEmpty) {
        final saved = await service.secrets.write(geminiKeySecret, typed);
        if (!saved) throw const GeminiException('No se pudo guardar la clave cifrada en este dispositivo.');
        _key.clear();
      }
      final settings = ref.read(settingsProvider);
      if (settings.geminiModel == null && models.isNotEmpty) {
        await ref.read(settingsProvider.notifier).update((s) => s.copyWith(geminiModel: models.first.name));
      }
      setState(() {
        _models = models;
        _status = models.isEmpty ? 'La clave anda, pero no hay modelos de texto.' : 'La clave anda. Guardada cifrada.';
      });
      await widget.onChanged();
    } on GeminiException catch (error) {
      setState(() => _status = '${error.message} Mientras tanto puedes traducir en el teléfono.');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final models = _models;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CÓMO CONSEGUIR TU CLAVE', style: KijiText.mono(size: 11)),
        const SizedBox(height: 6),
        Row(
          children: [
            const Expanded(child: Text('1. Entra a aistudio.google.com con tu cuenta de Google.')),
            TextButton(
              onPressed: () => launchUrl(Uri.parse('https://aistudio.google.com/apikey'),
                  mode: LaunchMode.externalApplication),
              child: const Text('Abrir'),
            ),
          ],
        ),
        const Text('2. Toca "Get API key" → "Create API key" (no pide tarjeta).'),
        const Text('3. Copia la clave y pégala aquí abajo.'),
        const Text('4. Toca "Probar".'),
        const Text('5. Elige el modelo (Kiji recomienda el más liviano, Flash-Lite).'),
        const SizedBox(height: 10),
        TextField(
          controller: _key,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: widget.hasKey ? 'Clave guardada (pega otra para cambiarla)' : 'Clave de Gemini',
            suffixIcon: IconButton(
              tooltip: 'Pegar',
              icon: const Icon(Icons.content_paste_rounded),
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data?.text != null) _key.text = data!.text!.trim();
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton(
              onPressed: _testing ? null : _test,
              child: _testing
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Probar'),
            ),
            const SizedBox(width: 8),
            if (widget.hasKey)
              TextButton.icon(
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Borrar clave'),
                onPressed: () async {
                  await ref.read(translationServiceProvider).secrets.delete(geminiKeySecret);
                  await ref.read(settingsProvider.notifier).update((s) => s.copyWith(useGemini: false));
                  setState(() {
                    _models = null;
                    _status = 'Clave borrada de este dispositivo.';
                  });
                  await widget.onChanged();
                },
              ),
          ],
        ),
        if (_status != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_status!)),
        if (models != null && models.isNotEmpty) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: models.any((m) => m.name == settings.geminiModel) ? settings.geminiModel : models.first.name,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Modelo'),
            items: [
              for (final m in models)
                DropdownMenuItem(
                  value: m.name,
                  child: Text('${m.displayName}${identical(m, models.first) && m.isLite ? ' (recomendado)' : ''}',
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) {
              if (value != null) ref.read(settingsProvider.notifier).update((s) => s.copyWith(geminiModel: value));
            },
          ),
        ] else if (settings.geminiModel != null)
          Text('Modelo: ${settings.geminiModel!.replaceFirst('models/', '')}',
              style: const TextStyle(color: KijiColors.muted)),
      ],
    );
  }
}
