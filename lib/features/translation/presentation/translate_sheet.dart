import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/kiji_tokens.dart';
import '../../settings/data/settings_store.dart';
import '../../settings/domain/app_settings.dart';
import 'lyrics_settings_screens.dart';
import 'translated_lyrics.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// Etiqueta "Beta" (traducción con IA).
class BetaBadge extends StatelessWidget {
  const BetaBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      border: Border.all(color: KijiColors.cyan.withValues(alpha: 0.7)),
      borderRadius: BorderRadius.circular(KijiRadii.pill),
    ),
    child: Text(tx.beta.toUpperCase(), style: KijiText.mono(size: 10, color: KijiColors.cyan)),
  );
}

/// La traducción con IA está lista para usarse: activada y con un modelo elegido (eso solo pasa
/// después de probar la clave).
bool geminiReady(AppSettings settings) => settings.geminiEnabled && settings.geminiModel != null;

/// Letras → ⋯ → Traducir: dos opciones claras. Un toque elige y traduce; lo demás está en los
/// ajustes.
Future<void> showTranslateSheet(BuildContext context, WidgetRef ref) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  // Con letra grande o pantallas bajas, la hoja crece y se desplaza en vez de cortarse.
  isScrollControlled: true,
  builder: (sheetContext) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tx.traducirLaLetra, style: KijiText.title(size: 20)),
            const SizedBox(height: 12),
            _Option(
              icon: Icons.phone_android_rounded,
              title: tx.traduccionEnElTelefono,
              text: tx.traduccionEnElTelefonoTexto,
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await _translateWith(ref, gemini: false);
              },
            ),
            const SizedBox(height: 10),
            _Option(
              icon: Icons.auto_awesome_rounded,
              title: tx.traduccionConIa,
              badge: const BetaBadge(),
              text: geminiReady(ref.read(settingsProvider))
                  ? tx.traduccionConIaTexto
                  : '${tx.traduccionConIaTexto} ${tx.traduccionConIaPreparar}',
              onTap: () async {
                final navigator = Navigator.of(sheetContext);
                navigator.pop();
                if (!geminiReady(ref.read(settingsProvider))) {
                  // Primero se configura (activar y poner la clave); al volver, si quedó lista, traduce.
                  await TranslationSettingsScreen.open(navigator.context);
                  if (!geminiReady(ref.read(settingsProvider))) return;
                }
                await _translateWith(ref, gemini: true);
              },
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.tune_rounded),
                label: Text(tx.ajustesDeTraduccion),
                onPressed: () {
                  final navigator = Navigator.of(sheetContext);
                  navigator.pop();
                  TranslationSettingsScreen.open(navigator.context);
                },
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

Future<void> _translateWith(WidgetRef ref, {required bool gemini}) async {
  // El ajuste cambia al instante; guardarlo en disco no hace esperar a la traducción.
  unawaited(ref.read(settingsProvider.notifier).update((s) => s.copyWith(useGemini: gemini)));
  ref.read(lyricsTranslationOnProvider.notifier).state = true;
}

class _Option extends StatelessWidget {
  const _Option({required this.icon, required this.title, required this.text, required this.onTap, this.badge});

  final IconData icon;
  final String title;
  final String text;
  final Widget? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: KijiColors.glassFill,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(KijiRadii.tile),
      side: const BorderSide(color: KijiColors.glassBorder),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: KijiColors.cyan),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ?badge,
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(text, style: const TextStyle(color: KijiColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
