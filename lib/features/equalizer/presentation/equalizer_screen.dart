// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivo de referencia: app/src/main/kotlin/.../ui/screens/equalizer/EqScreen.kt
// (pantalla del ecualizador con perfiles). Diseño y código propios de Kiji.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/kiji_tokens.dart';
import '../../../widgets/nocturne/glass.dart';
import '../data/equalizer_notifier.dart';
import '../domain/equalizer_model.dart';

/// Configuración → Reproductor → Ecualizador (Tarea J).
class EqualizerScreen extends ConsumerStatefulWidget {
  const EqualizerScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const EqualizerScreen()),
      );

  @override
  ConsumerState<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends ConsumerState<EqualizerScreen> {
  /// Qué perfil se está editando (con "un perfil por dispositivo"); de
  /// entrada, el de la salida que suena ahora.
  AudioOutputKind? _editing;

  /// Valor de la banda mientras se arrastra (se guarda al soltar).
  final Map<int, double> _dragging = {};

  @override
  Widget build(BuildContext context) {
    final eq = ref.watch(equalizerProvider);
    final notifier = ref.read(equalizerProvider.notifier);
    final settings = eq.settings;
    final editing = settings.perDevice ? (_editing ?? eq.output) : eq.output;
    final profile = settings.profileFor(editing);

    return Scaffold(
      appBar: AppBar(title: const Text('Ecualizador')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          if (!eq.supported)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'En la PC todavía no hay ecualizador: por ahora funciona solo en Android. '
                'Lo que elijas acá se guarda igual.',
                style: TextStyle(color: KijiColors.muted),
              ),
            ),
          Glass(
            blur: false,
            radius: KijiRadii.tile,
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Ecualizador'),
                    subtitle: Text(settings.enabled
                        ? 'Encendido: ${eq.activeProfile.label}'
                        : 'Apagado: el sonido no cambia.'),
                    value: settings.enabled,
                    onChanged: notifier.setEnabled,
                  ),
                  SwitchListTile(
                    title: const Text('Un perfil por dispositivo'),
                    subtitle: Text(
                      'El parlante, los auriculares con cable y el Bluetooth recuerdan cada uno su '
                      'perfil y cambia solo al conectarlos. Ahora suena: ${eq.output.label}.',
                    ),
                    value: settings.perDevice,
                    onChanged: notifier.setPerDevice,
                  ),
                ],
              ),
            ),
          ),
          if (settings.perDevice) ...[
            const SizedBox(height: 16),
            SegmentedButton<AudioOutputKind>(
              segments: [
                for (final kind in AudioOutputKind.values)
                  ButtonSegment(
                    value: kind,
                    label: Text(kind == AudioOutputKind.headphones ? 'Cable' : kind.label),
                    icon: Icon(_icon(kind)),
                  ),
              ],
              selected: {editing},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => setState(() {
                _editing = selection.first;
                _dragging.clear();
              }),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            settings.perDevice ? 'PERFIL: ${editing.label.toUpperCase()}' : 'PERFIL',
            style: KijiText.mono(size: 11),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in eqPresets)
                ChoiceChip(
                  label: Text(preset.label),
                  selected: profile.presetId == preset.id,
                  onSelected: (_) {
                    _dragging.clear();
                    notifier.selectPreset(editing, preset.id);
                  },
                ),
              if (profile.presetId == EqProfile.custom)
                const ChoiceChip(label: Text('Personalizado'), selected: true, onSelected: null),
            ],
          ),
          const SizedBox(height: 20),
          Text('BANDAS', style: KijiText.mono(size: 11)),
          const SizedBox(height: 8),
          _bands(eq, profile, editing),
        ],
      ),
    );
  }

  Widget _bands(EqualizerState eq, EqProfile profile, AudioOutputKind editing) {
    final bands = eq.bands;
    if (bands == null) {
      return Text(
        eq.supported
            ? 'Las bandas aparecen cuando empieza a sonar algo.'
            : 'En la PC no hay bandas para ajustar todavía.',
        style: const TextStyle(color: KijiColors.muted),
      );
    }
    final gains = profile.gainsFor(bands.centers, min: bands.minDb, max: bands.maxDb);
    return Glass(
      blur: false,
      radius: KijiRadii.tile,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            for (var i = 0; i < bands.centers.length; i++)
              Expanded(
                child: Column(
                  children: [
                    Text(_db(_dragging[i] ?? gains[i]), style: KijiText.mono(size: 11)),
                    SizedBox(
                      height: 200,
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Slider(
                          min: bands.minDb,
                          max: bands.maxDb,
                          value: (_dragging[i] ?? gains[i]).clamp(bands.minDb, bands.maxDb),
                          onChanged: (value) => setState(() => _dragging[i] = value),
                          onChangeEnd: (value) async {
                            final rounded = double.parse(value.toStringAsFixed(1));
                            await ref.read(equalizerProvider.notifier).setBand(editing, i, rounded);
                            if (mounted) setState(() => _dragging.remove(i));
                          },
                        ),
                      ),
                    ),
                    Text(_hz(bands.centers[i]), style: KijiText.mono(size: 11)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static IconData _icon(AudioOutputKind kind) => switch (kind) {
        AudioOutputKind.speaker => Icons.speaker_rounded,
        AudioOutputKind.headphones => Icons.headphones_rounded,
        AudioOutputKind.bluetooth => Icons.bluetooth_audio_rounded,
      };

  static String _db(double db) => '${db > 0 ? '+' : ''}${db.toStringAsFixed(1)}';

  static String _hz(double hz) =>
      hz >= 1000 ? '${(hz / 1000).toStringAsFixed(hz >= 10000 ? 0 : 1)}k' : '${hz.round()}';
}
