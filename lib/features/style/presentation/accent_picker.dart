import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/kiji_tokens.dart';
import '../../../widgets/nocturne/kiji_sheet.dart';
import '../../settings/data/settings_store.dart';
import '../../settings/domain/app_settings.dart';

/// Nombre de un acento de Nocturne.
String accentName(String accent) => switch (accent) {
  'aurora' => tx.acentoAurora,
  'ember' => tx.acentoEmber,
  'mint' => tx.acentoMint,
  'ocean' => tx.acentoOcean,
  AppSettings.customAccentName => tx.acentoPropio,
  _ => tx.acentoNocturne,
};

/// Muestras para elegir rápido (después se ajustan para que se lean en cada estilo).
const accentSwatches = <Color>[
  Color(0xFF7C5CFF), Color(0xFF3D7BFF), Color(0xFF3DF5FF), Color(0xFF2EE6A6),
  Color(0xFF8BC34A), Color(0xFFFFD54F), Color(0xFFFF9800), Color(0xFFFF7A45),
  Color(0xFFE53935), Color(0xFFFF3D8B), Color(0xFFB388FF), Color(0xFF9E9E9E),
];

/// "#RRGGBB" de [color].
String colorHex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Lee "#RRGGBB" o "RRGGBB" (también "#RGB"); null si no es un color.
Color? parseHex(String text) {
  var t = text.trim().replaceFirst('#', '');
  if (t.length == 3) t = t.split('').map((c) => '$c$c').join();
  if (t.length != 6) return null;
  final value = int.tryParse(t, radix: 16);
  return value == null ? null : Color(0xFF000000 | value);
}

/// Elige el color de acento (en los tres estilos): el del estilo, los de Kiji (en Nocturne), una
/// muestra, tono y luz, o un código. Lo elegido se aplica en vivo y se ve ya ajustado para que se lea.
Future<void> showAccentPicker(BuildContext context, WidgetRef ref) => showKijiSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const AccentPicker(),
);

class AccentPicker extends ConsumerStatefulWidget {
  const AccentPicker({super.key, this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 24), this.showTitle = true});

  final EdgeInsets padding;

  /// En el asistente el título ya está arriba.
  final bool showTitle;

  @override
  ConsumerState<AccentPicker> createState() => _AccentPickerState();
}

class _AccentPickerState extends ConsumerState<AccentPicker> {
  late final _hex = TextEditingController(text: _current == null ? '' : colorHex(_current!));

  Color? get _current => ref.read(settingsProvider).customAccentColor;

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  Future<void> _setPreset(String accent) =>
      ref.read(settingsProvider.notifier).update((s) => s.copyWith(accent: accent));

  Future<void> _setCustom(Color color, {bool updateField = true}) async {
    if (updateField) _hex.text = colorHex(color);
    await ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(accent: AppSettings.customAccentName, customAccent: color.toARGB32()));
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final custom = settings.customAccentColor;
    final nocturne = KijiLook.nocturne;
    final base = custom ?? KijiColors.violet;
    final hsl = HSLColor.fromColor(base);

    Widget dot({required Widget child, required bool selected, required VoidCallback onTap, String? label}) => Tooltip(
      message: label ?? '',
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: selected ? KijiColors.text : Colors.transparent, width: 2),
          ),
          child: ClipOval(child: child),
        ),
      ),
    );

    return SingleChildScrollView(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showTitle) ...[
            Text(tx.colorDeAcento, style: KijiText.title(size: 20)),
            const SizedBox(height: 14),
          ],
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (nocturne)
                for (final a in AppSettings.accents)
                  dot(
                    label: accentName(a),
                    selected: settings.accent == a,
                    onTap: () => _setPreset(a),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [KijiPalette.accents[a]!.$1, KijiPalette.accents[a]!.$2]),
                      ),
                    ),
                  )
              else
                dot(
                  label: tx.acentoDelEstilo,
                  selected: custom == null,
                  onTap: () => _setPreset('nocturne'),
                  child: ColoredBox(color: KijiPalette.forStyle(KijiLook.style).violet),
                ),
              for (final color in accentSwatches)
                dot(
                  label: colorHex(color),
                  selected: custom == color,
                  onTap: () => _setCustom(color),
                  child: ColoredBox(color: color),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(tx.colorMatiz, style: KijiText.mono(size: 11)),
          _HueSlider(
            hue: hsl.hue,
            onChanged: (hue) => _setCustom(hsl.withHue(hue).withSaturation(hsl.saturation.clamp(0.55, 1)).toColor()),
          ),
          Text(tx.colorLuz, style: KijiText.mono(size: 11)),
          Slider(
            value: hsl.lightness.clamp(0.15, 0.85),
            min: 0.15,
            max: 0.85,
            onChanged: (l) => _setCustom(hsl.withLightness(l).toColor()),
          ),
          TextField(
            controller: _hex,
            decoration: InputDecoration(labelText: tx.colorHex, hintText: '#7C5CFF'), // l10n-ignore
            onSubmitted: (text) {
              final color = parseHex(text);
              if (color != null) _setCustom(color, updateField: false);
            },
            onChanged: (text) {
              final color = parseHex(text);
              if (color != null) _setCustom(color, updateField: false);
            },
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 120,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: KijiColors.accentGradient,
                  borderRadius: BorderRadius.circular(KijiRadii.pill),
                ),
                child: Text(tx.asiSeVera, style: TextStyle(color: KijiColors.onAccent, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(tx.acentoAjustadoNota, style: TextStyle(color: KijiColors.muted, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Deslizador de tono: la rueda de colores estirada en una barra.
class _HueSlider extends StatelessWidget {
  const _HueSlider({required this.hue, required this.onChanged});

  final double hue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KijiRadii.pill),
            gradient: LinearGradient(
              colors: [for (var h = 0; h <= 360; h += 60) HSLColor.fromAHSL(1, h % 360, 0.85, 0.55).toColor()],
            ),
          ),
        ),
      ),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: Colors.transparent,
          inactiveTrackColor: Colors.transparent,
        ),
        child: Slider(value: hue.clamp(0, 359.9), max: 359.9, onChanged: onChanged),
      ),
    ],
  );
}
