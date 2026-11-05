import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/kiji_tokens.dart';
import '../../../widgets/global_mini_player.dart';
import '../../settings/data/settings_store.dart';
import '../../settings/domain/app_settings.dart';
import 'accent_picker.dart';
import 'custom_background.dart';
import 'style_parts.dart';

/// Los pasos de "Personaliza Kiji".
enum PersonalizeStep { style, color, font, background }

/// "Personaliza Kiji desde cero": un asistente corto (estilo, color, fuente y fondo) con la vista
/// previa en vivo (cada elección se aplica en el momento) y "Saltar". Aparece al instalar y una vez
/// al actualizar a la 0.8.0; después, desde Configuración → Apariencia.
class PersonalizeScreen extends ConsumerStatefulWidget {
  const PersonalizeScreen({super.key, this.start = PersonalizeStep.style});

  final PersonalizeStep start;

  /// Abre el asistente. Al cerrarlo (terminando, con "Saltar" o hacia atrás) queda anotado.
  static Future<void> open(BuildContext context, WidgetRef ref, {PersonalizeStep start = PersonalizeStep.style}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: KijiRoutes.style),
        builder: (_) => PersonalizeScreen(start: start),
      ),
    );
    final s = ref.read(settingsProvider);
    if (!s.personalized || !s.styleChosen) {
      await ref.read(settingsProvider.notifier).update((s) => s.copyWith(personalized: true, styleChosen: true));
    }
  }

  @override
  ConsumerState<PersonalizeScreen> createState() => _PersonalizeScreenState();
}

class _PersonalizeScreenState extends ConsumerState<PersonalizeScreen> {
  late var _step = widget.start;

  void _next() {
    if (_step == PersonalizeStep.values.last) {
      Navigator.of(context).pop();
    } else {
      setState(() => _step = PersonalizeStep.values[_step.index + 1]);
    }
  }

  (String, String) get _texts => switch (_step) {
    PersonalizeStep.style => (tx.estiloPregunta, tx.estiloPreguntaTexto),
    PersonalizeStep.color => (tx.colorDeAcento, tx.colorDeAcentoDescripcion),
    PersonalizeStep.font => (tx.tipografia, tx.tipografiaDescripcion),
    PersonalizeStep.background => (
      tx.fondo,
      MediaQuery.sizeOf(context).width >= KijiSizes.desktopBreakpoint ? tx.fondoDescripcionPc : tx.fondoDescripcion,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = _texts;
    final last = _step == PersonalizeStep.values.last;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth >= 760;
            final preview = SizedBox(
              width: wide ? 240 : 132,
              child: StylePreview(
                style: KijiLook.style,
                palette: KijiColors.palette,
                titleFont: KijiText.titleFamily,
              ),
            );
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: KijiText.title(size: 26)),
                const SizedBox(height: 6),
                Text(subtitle, style: TextStyle(color: KijiColors.muted)),
                const SizedBox(height: 18),
                switch (_step) {
                  PersonalizeStep.style => const _StyleStep(),
                  PersonalizeStep.color => const AccentPicker(padding: EdgeInsets.zero, showTitle: false),
                  PersonalizeStep.font => const _FontStep(),
                  PersonalizeStep.background => const BackgroundOptions(),
                },
              ],
            );
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tx.pasoDe(_step.index + 1, PersonalizeStep.values.length),
                          style: KijiText.mono(size: 12),
                        ),
                      ),
                      TextButton(
                        key: const Key('personalize-skip'),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(tx.saltar),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [Expanded(child: content), const SizedBox(width: 32), preview],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [Center(child: preview), const SizedBox(height: 18), content],
                              ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Row(
                      children: [
                        if (_step != PersonalizeStep.style)
                          TextButton(
                            onPressed: () => setState(() => _step = PersonalizeStep.values[_step.index - 1]),
                            child: Text(tx.atras),
                          ),
                        const Spacer(),
                        FilledButton(
                          key: const Key('personalize-next'),
                          style: FilledButton.styleFrom(
                            backgroundColor: KijiColors.violet,
                            foregroundColor: KijiColors.onAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          ),
                          onPressed: _next,
                          child: Text(last ? tx.listo : tx.siguiente),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Paso 1: los tres estilos, cada uno con su miniatura.
class _StyleStep extends ConsumerWidget {
  const _StyleStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = KijiStyle.parse(ref.watch(settingsProvider.select((s) => s.style)));
    return Column(
      children: [
        for (final style in KijiStyle.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: StyleCard(
              style: style,
              selected: style == current,
              wide: false,
              onTap: () => ref.read(settingsProvider.notifier).update((s) => s.copyWith(style: style.name)),
            ),
          ),
      ],
    );
  }
}

/// Paso 3: las fuentes, cada una escrita con su propia letra.
class _FontStep extends ConsumerWidget {
  const _FontStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(settingsProvider.select((s) => s.font));
    return RadioGroup<String>(
      groupValue: current,
      onChanged: (font) {
        if (font != null) ref.read(settingsProvider.notifier).update((s) => s.copyWith(font: font));
      },
      child: Column(
        children: [
          for (final font in AppSettings.fonts)
            RadioListTile<String>(
              value: font,
              contentPadding: EdgeInsets.zero,
              title: Text(
                fontLabel(font),
                style: TextStyle(
                  fontFamily: font == 'kiji' ? KijiText.titleFamilyOf(KijiLook.style) : KijiText.familyFor(font),
                  fontSize: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
