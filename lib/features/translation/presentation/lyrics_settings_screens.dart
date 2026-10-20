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
import 'translate_sheet.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Texto del apartado 1, tal como se definió.
String get localTranslationNotice => tx.laLetraSeTraduceDentroDe;

/// Configuración → Letras → Fuentes: una por una, se pueden apagar.
class LyricsSourcesScreen extends ConsumerWidget {
  const LyricsSourcesScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LyricsSourcesScreen()));

  static Map<LyricsSource, String> get _sends => {
    LyricsSource.lrclib: tx.tituloArtistaAlbumYDuracion,
    LyricsSource.youlyplus: tx.tituloArtistaAlbumDuracionEId,
    LyricsSource.paxsenix: tx.tituloYArtista,
    LyricsSource.unison: tx.idDelVideoOTituloArtista,
    LyricsSource.betterlyrics: tx.tituloArtistaAlbumYDuracion,
    LyricsSource.kugou: tx.tituloArtistaYDuracion,
    LyricsSource.youtubeSubtitles: tx.idDelVideoAYoutube,
    LyricsSource.youtubeMusic: tx.idDelVideoAYoutubeMusic,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disabled = ref.watch(settingsProvider.select((s) => s.disabledLyricsSources));
    final order = ref.watch(settingsProvider.select((s) => s.lyricsSourceOrder));
    final notifier = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(tx.fuentesDeLetras)),
      body: ReorderableListView(
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        header: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(tx.kijiBuscaLaLetraPrimeroEn, style: const TextStyle(color: KijiColors.muted)),
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
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.drag_indicator_rounded, semanticLabel: tx.arrastrarParaCambiarElOrden),
                ),
              ),
              title: Text('${index + 1}. ${source.label}'),
              subtitle: Text(tx.recibe(_sends[source] ?? '—')),
              trailing: Switch(
                value: !disabled.contains(source),
                onChanged: (on) => notifier.update(
                  (s) => s.copyWith(
                    disabledLyricsSources: on
                        ? ({...s.disabledLyricsSources}..remove(source))
                        : {...s.disabledLyricsSources, source},
                  ),
                ),
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
    Widget section(String title, List<Widget> children, {Widget? badge}) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Glass(
        blur: false,
        radius: KijiRadii.tile,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [Text(title, style: KijiText.title(size: 17)), ?badge],
              ),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(tx.traduccionDeLetras)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Text(tx.originalYTraduccionSeVenLinea, style: const TextStyle(color: KijiColors.muted)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: settings.translationTarget,
            decoration: InputDecoration(labelText: tx.traducirAl),
            items: [
              for (final entry in translationLanguages.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) {
              if (value != null) notifier.update((s) => s.copyWith(translationTarget: value));
            },
          ),
          const SizedBox(height: 16),
          section(tx.n1EnTuTelefonoAnonimo, [
            Text(localTranslationNotice),
            const SizedBox(height: 8),
            Text(
              tx.motorYModelosDeFirefox,
              style: TextStyle(color: KijiColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(tx.idiomasBajados, style: KijiText.mono(size: 11)),
            if (_installed == null)
              const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator())
            else if (_installed!.isEmpty)
              Text(tx.ningunoTodaviaSeBajanSolosAvisando, style: const TextStyle(color: KijiColors.muted))
            else
              for (final entry in _installed!.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.key.split('-').map(languageName).join(' → ')),
                  subtitle: Text(formatBytes(entry.value)),
                  trailing: IconButton(
                    tooltip: tx.borrar,
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () async {
                      await ref.read(translationServiceProvider).models.delete(entry.key);
                      await _refresh();
                    },
                  ),
                ),
          ]),
          section(tx.n2ConIaGemini, [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tx.traducirConGemini),
              subtitle: Text(
                settings.geminiEnabled
                    ? tx.activadoPierdesAnonimato
                    : tx.apagadoAntesDeActivarloVasA,
              ),
              value: settings.geminiEnabled,
              onChanged: (on) async {
                if (!on) {
                  await notifier.update((s) => s.copyWith(geminiEnabled: false, useGemini: false));
                  return;
                }
                final accepted = await Navigator.of(context)
                    .push<bool>(MaterialPageRoute(builder: (_) => const GeminiConsentScreen()));
                if (accepted == true) await notifier.update((s) => s.copyWith(geminiEnabled: true));
              },
            ),
            if (settings.geminiEnabled) ...[
              const SizedBox(height: 4),
              _GeminiSetup(hasKey: _hasKey, onChanged: _refresh),
              if (_hasKey && settings.geminiModel != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tx.usarGeminiParaTraducir),
                  subtitle: Text(tx.siLoApagasSeTraduceEn),
                  value: settings.useGemini,
                  onChanged: (on) => notifier.update((s) => s.copyWith(useGemini: on)),
                ),
            ],
          ], badge: const BetaBadge()),
        ],
      ),
    );
  }
}

/// Pantalla de avisos antes de activar Gemini (en palabras simples).
class GeminiConsentScreen extends StatelessWidget {
  const GeminiConsentScreen({super.key});

  static List<String> get points => [
    tx.pierdesParteDelAnonimatoLasLineas,
    tx.enElNivelGratuitoGoogleUsa,
    tx.kijiNoEnviaTuNombreTu,
    tx.requisitosDeGoogleTener18Anos,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tx.antesDeUsarGemini)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(tx.queCambiaSiActivasLaTraduccion, style: const TextStyle(fontSize: 18)),
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
          Text(tx.siNoQuieresNadaDeEsto, style: const TextStyle(color: KijiColors.muted)),
          const SizedBox(height: 24),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tx.entiendoActivar)),
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tx.mejorNo)),
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
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final typed = _key.text.trim();
    final key = typed.isNotEmpty ? typed : await service.secrets.read(geminiKeySecret);
    if (!mounted) return;
    if (key == null || key.isEmpty) {
      setState(() => _status = tx.pegaLaClavePrimero);
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
        if (!saved) throw GeminiException(tx.noSePudoGuardarLaClave);
        _key.clear();
      }
      if (models.isNotEmpty) {
        await settingsNotifier.update((s) => s.geminiModel == null ? s.copyWith(geminiModel: models.first.name) : s);
      }
      if (!mounted) return;
      setState(() {
        _models = models;
        _status = models.isEmpty ? tx.laClaveAndaSinModelos : tx.laClaveAndaGuardadaCifrada;
      });
      await widget.onChanged();
    } on GeminiException catch (error) {
      if (mounted) setState(() => _status = tx.mientrasTantoPuedesTraducirEnEl(error.message));
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
        Text(tx.comoConseguirTuClave, style: KijiText.mono(size: 11)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: Text(tx.n1EntraAAistudioGoogleCom)),
            TextButton(
              onPressed: () =>
                  launchUrl(Uri.parse('https://aistudio.google.com/apikey'), mode: LaunchMode.externalApplication),
              child: Text(tx.abrir),
            ),
          ],
        ),
        Text(tx.n2TocaGetApiKeyCreate),
        Text(tx.n3CopiaLaClaveYPegala),
        Text(tx.n4TocaProbar),
        Text(tx.n5EligeElModeloKijiRecomienda),
        const SizedBox(height: 10),
        TextField(
          controller: _key,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: widget.hasKey ? tx.claveGuardadaPegaOtra : tx.claveDeGemini,
            suffixIcon: IconButton(
              tooltip: tx.pegar,
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
                  : Text(tx.probar),
            ),
            const SizedBox(width: 8),
            if (widget.hasKey)
              TextButton.icon(
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(tx.borrarClave),
                onPressed: () async {
                  final settingsNotifier = ref.read(settingsProvider.notifier);
                  await ref.read(translationServiceProvider).secrets.delete(geminiKeySecret);
                  await settingsNotifier.update((s) => s.copyWith(useGemini: false));
                  if (!mounted) return;
                  setState(() {
                    _models = null;
                    _status = tx.claveBorradaDeEsteDispositivo;
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
            decoration: InputDecoration(labelText: tx.modelo),
            items: [
              for (final m in models)
                DropdownMenuItem(
                  value: m.name,
                  child: Text(
                    '${m.displayName}${identical(m, models.first) && m.isLite ? tx.recomendadoSufijo : ''}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) ref.read(settingsProvider.notifier).update((s) => s.copyWith(geminiModel: value));
            },
          ),
        ] else if (settings.geminiModel != null)
          Text(
            tx.modelo2(settings.geminiModel!.replaceFirst('models/', '')),
            style: const TextStyle(color: KijiColors.muted),
          ),
      ],
    );
  }
}
