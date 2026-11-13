// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivo de referencia: app/src/main/kotlin/.../ui/screens/equalizer/EqScreen.kt
// (pantalla del ecualizador con perfiles). Diseño y código propios de Kiji.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/data/settings_store.dart';
import '../../../widgets/nocturne/kiji_sheet.dart';
import '../../../theme/kiji_tokens.dart';
import '../../../widgets/nocturne/glass.dart';
import '../../settings/domain/app_settings.dart';
import '../data/equalizer_notifier.dart';
import '../domain/equalizer_model.dart';

import 'package:kiji_player/l10n/l10n.dart';

/// "Sonido": ecualizador, presets, bajos, velocidad y tono, reverb y mezcla entre canciones, en
/// una sola pantalla. Se abre en un toque desde el reproductor y desde Configuración. Lo que el
/// dispositivo no tenga no se muestra.
class SoundScreen extends ConsumerStatefulWidget {
  const SoundScreen({super.key, this.perDeviceAvailable});

  /// Para pruebas: si se muestra "un perfil por dispositivo" (null: solo en Android, donde Kiji
  /// sabe si suenan los auriculares o el parlante).
  final bool? perDeviceAvailable;

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SoundScreen()));

  @override
  ConsumerState<SoundScreen> createState() => _SoundScreenState();
}

class _SoundScreenState extends ConsumerState<SoundScreen> {
  /// Qué perfil se está editando (con "un perfil por dispositivo"); de
  /// entrada, el de la salida que suena ahora.
  AudioOutputKind? _editing;

  /// Valores mientras se arrastra (suenan en vivo; se guardan al soltar).
  final Map<int, double> _dragging = {};
  double? _bassDrag, _speedDrag, _crossfadeDrag;

  EqualizerNotifier get _notifier => ref.read(equalizerProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final eq = ref.watch(equalizerProvider);
    final settings = eq.settings;
    final perDeviceAvailable = widget.perDeviceAvailable ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
    final perDevice = perDeviceAvailable && settings.perDevice;
    final editing = perDevice ? (_editing ?? eq.output) : eq.output;
    final profile = settings.profileFor(editing);

    return Scaffold(
      appBar: AppBar(title: Text(tx.sonido)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          _card(
            SwitchListTile(
              secondary: Icon(Icons.graphic_eq_rounded, color: settings.enabled ? KijiColors.cyan : KijiColors.muted),
              title: Text(tx.efectos),
              subtitle: Text(settings.enabled ? tx.efectosEncendidos(eq.activeProfile.label) : tx.efectosApagados),
              value: settings.enabled,
              onChanged: _notifier.setEnabled,
            ),
          ),
          if (eq.supported) ...[
            _title(eq.bands == null ? tx.ecualizador2 : tx.ecualizadorBandas(eq.bands!.centers.length)),
            if (perDeviceAvailable)
              _card(
                SwitchListTile(
                  title: Text(tx.unPerfilPorDispositivo),
                  subtitle: Text(tx.elParlanteLosAuricularesConCable(eq.output.label)),
                  value: settings.perDevice,
                  onChanged: _notifier.setPerDevice,
                ),
              ),
            if (perDevice) ...[
              const SizedBox(height: 12),
              SegmentedButton<AudioOutputKind>(
                segments: [
                  for (final kind in AudioOutputKind.values)
                    ButtonSegment(
                      value: kind,
                      label: Text(kind == AudioOutputKind.headphones ? tx.cable : kind.label),
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
            const SizedBox(height: 12),
            _presets(settings, profile, editing),
            const SizedBox(height: 12),
            _bands(eq, profile, editing),
          ],
          if (eq.capabilities.bass) ...[
            _title(tx.refuerzoDeBajos),
            _card(
              _sliderRow(
                value: _bassDrag ?? settings.bass,
                label: '${((_bassDrag ?? settings.bass) * 100).round()} %',
                divisions: 20,
                onChanged: (value) {
                  setState(() => _bassDrag = value);
                  _notifier.setBass(value, persist: false);
                },
                onChangeEnd: (value) async {
                  await _notifier.setBass(value);
                  if (mounted) setState(() => _bassDrag = null);
                },
              ),
            ),
          ],
          _title('${tx.velocidad} · ${tx.tono}'),
          _speedPitch(settings),
          if (eq.capabilities.reverb) ...[
            _title(tx.reverb),
            SegmentedButton<ReverbMode>(
              segments: [for (final mode in ReverbMode.values) ButtonSegment(value: mode, label: Text(mode.label))],
              selected: {settings.reverb},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => _notifier.setReverb(selection.first),
            ),
          ],
          _title(tx.mezclaEntreCanciones),
          _crossfade(),
        ],
      ),
    );
  }

  Widget _title(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(text.toUpperCase(), style: KijiText.mono(size: 11)),
  );

  Widget _card(Widget child) => Glass(
    blur: false,
    radius: KijiRadii.tile,
    child: Material(type: MaterialType.transparency, child: child),
  );

  Widget _sliderRow({
    required double value,
    required String label,
    double min = 0,
    double max = 1,
    int? divisions,
    required ValueChanged<double> onChanged,
    ValueChanged<double>? onChangeEnd,
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
    child: Row(
      children: [
        Expanded(
          child: Slider(
            min: min,
            max: max,
            divisions: divisions,
            value: value.clamp(min, max),
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
        SizedBox(
          width: 64,
          child: Text(label, textAlign: TextAlign.end, style: KijiText.mono(size: 13)),
        ),
      ],
    ),
  );

  Widget _presets(EqualizerSettings settings, EqProfile profile, AudioOutputKind editing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  _notifier.selectPreset(editing, preset.id);
                },
              ),
            for (final preset in settings.userPresets)
              GestureDetector(
                onLongPress: () => _presetMenu(preset),
                onSecondaryTap: () => _presetMenu(preset),
                child: ChoiceChip(
                  avatar: const Icon(Icons.person_outline_rounded, size: 16),
                  label: Text(preset.name),
                  selected: profile.presetId == preset.profileId,
                  onSelected: (_) {
                    _dragging.clear();
                    _notifier.selectPreset(editing, preset.profileId);
                  },
                ),
              ),
            if (profile.presetId == EqProfile.custom)
              ChoiceChip(label: Text(tx.personalizado), selected: true, onSelected: null),
            ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 18),
              label: Text(tx.guardarComoPreset),
              onPressed: () async {
                final name = await _askName(tx.guardarComoPreset, '');
                if (name != null) await _notifier.saveUserPreset(editing, name);
              },
            ),
          ],
        ),
        if (settings.userPresets.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(tx.presetsPropiosNota, style: TextStyle(color: KijiColors.muted, fontSize: 12)),
          ),
      ],
    );
  }

  Future<void> _presetMenu(EqUserPreset preset) async {
    final action = await showKijiSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(preset.name, style: KijiText.title(size: 16))),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(tx.renombrarPreset),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(tx.borrar),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'rename') {
      final name = await _askName(tx.renombrarPreset, preset.name);
      if (name != null) await _notifier.renameUserPreset(preset.id, name);
    } else if (action == 'delete') {
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tx.borrarPresetPregunta(preset.name)),
          content: Text(tx.borrarPresetNota),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tx.cancelar)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tx.borrar)),
          ],
        ),
      );
      if (sure == true) await _notifier.deleteUserPreset(preset.id);
    }
  }

  Future<String?> _askName(String title, String initial) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _NameDialog(title: title, initial: initial),
    );
    return name == null || name.trim().isEmpty ? null : name.trim();
  }

  Widget _bands(EqualizerState eq, EqProfile profile, AudioOutputKind editing) {
    final bands = eq.bands;
    if (bands == null) return Text(tx.lasBandasAparecenCuandoSuena, style: TextStyle(color: KijiColors.muted));
    final gains = profile.gainsFor(bands.centers, min: bands.minDb, max: bands.maxDb);
    final desktop = !kIsWeb && defaultTargetPlatform != TargetPlatform.android;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Glass(
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
                        FittedBox(child: Text(_db(_dragging[i] ?? gains[i]), style: KijiText.mono(size: 11))),
                        SizedBox(
                          height: 200,
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Slider(
                              min: bands.minDb,
                              max: bands.maxDb,
                              value: (_dragging[i] ?? gains[i]).clamp(bands.minDb, bands.maxDb),
                              onChanged: (value) {
                                setState(() => _dragging[i] = value);
                                _notifier.setBand(editing, i, double.parse(value.toStringAsFixed(1)), persist: false);
                              },
                              onChangeEnd: (value) async {
                                await _notifier.setBand(editing, i, double.parse(value.toStringAsFixed(1)));
                                if (mounted) setState(() => _dragging.remove(i));
                              },
                            ),
                          ),
                        ),
                        FittedBox(child: Text(_hz(bands.centers[i]), style: KijiText.mono(size: 11))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          desktop ? tx.enLaPcLasBandasSon : tx.elTelefonoTieneBandas(bands.centers.length),
          style: TextStyle(color: KijiColors.muted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _speedPitch(EqualizerSettings settings) {
    final speed = _speedDrag ?? settings.speed;
    return _card(
      Column(
        children: [
          ListTile(dense: true, title: Text(tx.velocidad)),
          _sliderRow(
            value: speed,
            min: minSpeed,
            max: maxSpeed,
            divisions: 30,
            label: '${speed.toStringAsFixed(2)}x',
            onChanged: (value) {
              setState(() => _speedDrag = value);
              _notifier.setSpeed(value, persist: false);
            },
            onChangeEnd: (value) async {
              await _notifier.setSpeed(value);
              if (mounted) setState(() => _speedDrag = null);
            },
          ),
          ListTile(dense: true, title: Text(tx.tono), subtitle: Text(tx.semitonos(settings.semitones))),
          _sliderRow(
            value: settings.semitones.toDouble(),
            min: -maxSemitones.toDouble(),
            max: maxSemitones.toDouble(),
            divisions: maxSemitones * 2,
            label: '${settings.semitones > 0 ? '+' : ''}${settings.semitones}',
            onChanged: (value) => _notifier.setSemitones(value.round()),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.restart_alt_rounded),
                label: Text(tx.volverALoNormal),
                onPressed: settings.speedPitchNormal ? null : _notifier.resetSpeedPitch,
              ),
            ),
          ),
          SwitchListTile(
            title: Text(tx.mantenerEntreCanciones),
            subtitle: Text(tx.mantenerEntreCancionesNota),
            value: settings.keepSpeedPitch,
            onChanged: _notifier.setKeepSpeedPitch,
          ),
        ],
      ),
    );
  }

  Widget _crossfade() {
    final saved = ref.watch(settingsProvider.select((s) => s.crossfadeSeconds));
    final seconds = (_crossfadeDrag ?? saved.toDouble()).round();
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              seconds == 0 ? tx.apagada : tx.sElFinalDeUnaCancion(seconds),
              style: TextStyle(color: KijiColors.muted, fontSize: 13),
            ),
          ),
          _sliderRow(
            value: seconds.toDouble(),
            max: AppSettings.maxCrossfadeSeconds.toDouble(),
            divisions: AppSettings.maxCrossfadeSeconds,
            label: seconds == 0 ? tx.no : '$seconds s',
            onChanged: (value) => setState(() => _crossfadeDrag = value),
            onChangeEnd: (value) async {
              await ref.read(settingsProvider.notifier).update((s) => s.copyWith(crossfadeSeconds: value.round()));
              if (mounted) setState(() => _crossfadeDrag = null);
            },
          ),
        ],
      ),
    );
  }

  static IconData _icon(AudioOutputKind kind) => switch (kind) {
    AudioOutputKind.speaker => Icons.speaker_rounded,
    AudioOutputKind.headphones => Icons.headphones_rounded,
    AudioOutputKind.bluetooth => Icons.bluetooth_audio_rounded,
  };

  static String _db(double db) => '${db > 0 ? '+' : ''}${db.toStringAsFixed(1)}';

  static String _hz(double hz) => hz >= 1000 ? '${(hz / 1000).toStringAsFixed(hz >= 10000 ? 0 : 1)}k' : '${hz.round()}';
}

/// Pide el nombre de un preset propio. El campo es suyo: se suelta cuando el diálogo termina de
/// cerrarse (soltarlo antes rompía la animación de salida).
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 30,
      decoration: InputDecoration(labelText: tx.nombreDelPreset),
      onSubmitted: (value) => Navigator.pop(context, value),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text(tx.cancelar)),
      FilledButton(onPressed: () => Navigator.pop(context, _controller.text), child: Text(tx.guardar)),
    ],
  );
}
