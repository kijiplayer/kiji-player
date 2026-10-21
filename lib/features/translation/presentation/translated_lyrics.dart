import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/kiji_tokens.dart';
import '../../../utils/byte_formatter.dart';
import '../../settings/data/settings_store.dart';
import '../data/translation_service.dart';
import '../domain/languages.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Si la letra se muestra traducida (se prende desde la pantalla de letras).
final lyricsTranslationOnProvider = StateProvider<bool>((ref) => false);

/// Traduce las líneas de una letra y se las pasa a [builder]. Original y
/// traducción se muestran línea por línea.
class TranslatedLyrics extends ConsumerStatefulWidget {
  const TranslatedLyrics({super.key, required this.trackId, required this.lines, required this.builder});

  final String trackId;
  final List<String> lines;
  final Widget Function(List<String?>? translations) builder;

  @override
  ConsumerState<TranslatedLyrics> createState() => _TranslatedLyricsState();
}

class _TranslatedLyricsState extends ConsumerState<TranslatedLyrics> {
  List<String?>? _translations;
  LocalPlan? _needsDownload;
  double? _progress;
  String? _message;
  bool _offerLocal = false;
  bool _busy = false;
  bool _forceLocal = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void didUpdateWidget(TranslatedLyrics old) {
    super.didUpdateWidget(old);
    if (old.trackId != widget.trackId || old.lines.length != widget.lines.length) {
      _translations = null;
      _needsDownload = null;
      _forceLocal = false;
      _run();
    }
  }

  Future<void> _run({bool download = false}) async {
    final settings = ref.read(settingsProvider);
    final service = ref.read(translationServiceProvider);
    final target = settings.translationTarget;
    setState(() {
      _busy = true;
      _message = null;
      _offerLocal = false;
    });
    try {
      List<String?> result;
      final useGemini = settings.geminiEnabled && settings.useGemini && settings.geminiModel != null && !_forceLocal;
      if (useGemini) {
        result = await service.translateGemini(widget.trackId, widget.lines, settings.geminiModel!, target);
      } else {
        final cached = await service.cached(widget.trackId, widget.lines, 'local', target);
        if (cached != null) {
          result = cached;
        } else {
          final plan = await service.planLocal(widget.lines, target);
          if (plan.missingBytes > 0 && !download) {
            if (mounted) setState(() => _needsDownload = plan);
            return;
          }
          if (plan.missingBytes > 0) {
            await service.models.install(
              plan.route,
              onProgress: (done, total) {
                if (mounted) setState(() => _progress = total == 0 ? null : done / total);
              },
            );
          }
          result = await service.translateLocal(widget.trackId, widget.lines, plan, target);
        }
      }
      if (mounted) {
        setState(() {
          _translations = result;
          _needsDownload = null;
        });
      }
    } on TranslationException catch (error) {
      if (mounted) {
        setState(() {
          _message = error.message;
          _offerLocal = error.suggestLocal;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _message = tx.noSePudoTraducir(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bar = _bar(context);
    return Column(
      children: [
        ?bar,
        Expanded(child: widget.builder(_translations)),
      ],
    );
  }

  Widget? _bar(BuildContext context) {
    Widget card(List<Widget> children) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        // Vidrio sobre el fondo de la letra (no una tarjeta de formulario).
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(KijiRadii.tile),
          border: Border.all(color: KijiColors.glassBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
    final plan = _needsDownload;
    if (plan != null) {
      return card([
        Text(
          tx.paraTraducirDelEnTuTelefono(languageName(plan.source).toLowerCase(), formatBytes(plan.missingBytes)),
          style: TextStyle(color: KijiPalette.nocturne.muted),
        ),
        if (_progress != null) ...[const SizedBox(height: 8), LinearProgressIndicator(value: _progress)],
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _busy ? null : () => ref.read(lyricsTranslationOnProvider.notifier).state = false,
              child: Text(tx.ahoraNo),
            ),
            FilledButton(
              onPressed: _busy ? null : () => _run(download: true),
              child: Text(tx.bajar(formatBytes(plan.missingBytes))),
            ),
          ],
        ),
      ]);
    }
    if (_message != null) {
      return card([
        Text(_message!, style: TextStyle(color: KijiPalette.nocturne.muted)),
        if (_offerLocal)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                _forceLocal = true;
                _run();
              },
              child: Text(tx.traducirEnElTelefono),
            ),
          ),
      ]);
    }
    if (_busy && _translations == null) {
      return const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator());
    }
    return null;
  }
}
