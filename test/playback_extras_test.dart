import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/equalizer/data/equalizer_engine.dart';
import 'package:kiji_player/features/equalizer/domain/equalizer_model.dart';
import 'package:kiji_player/features/playback_extras/data/playback_automation.dart';
import 'package:kiji_player/features/playback_extras/domain/playback_rules.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/features/yt_music/data/ytm_client.dart';
import 'package:kiji_player/models/track.dart';

Track _track(String id, {String artist = 'Soda Stereo'}) => Track(
      id: id,
      title: 'De música ligera',
      artist: artist,
      coverColor: Colors.black,
      audioUrl: '',
      source: id.startsWith('yt-') ? TrackSource.youtube : TrackSource.local,
    );

class _FakeControl implements PlaybackControl {
  @override
  bool isPlaying = false;
  @override
  bool hasTrack = true;
  final calls = <String>[];
  @override
  Future<void> play() async {
    calls.add('play');
    isPlaying = true;
  }

  final reasons = <String>[];
  Duration? keptAlive;
  @override
  Future<void> pause({required String reason, Duration? keepAliveFor}) async {
    calls.add('pause');
    reasons.add(reason);
    keptAlive = keepAliveFor;
    isPlaying = false;
  }
}

class _FakeVolume implements SystemVolumeMonitor {
  final controller = StreamController<double>.broadcast();
  @override
  Stream<double> get volume => controller.stream;
  Future<void> close() => controller.close();
}

class _FakeOutputs extends AudioOutputMonitor {
  final controller = StreamController<AudioOutputKind>.broadcast();
  Future<void> close() => controller.close();
  @override
  Future<AudioOutputKind> current() async => AudioOutputKind.bluetooth;
  @override
  Stream<AudioOutputKind> get changes => controller.stream;
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  group('transición suave', () {
    const minute = Duration(minutes: 3);
    double gain(int ms, {int seconds = 6, bool fadeIn = false, Duration duration = minute}) =>
        transitionGain(position: Duration(milliseconds: ms), duration: duration, seconds: seconds, fadeIn: fadeIn);

    test('apagada o en el medio de la canción no cambia el volumen', () {
      expect(gain(179000, seconds: 0), 1);
      expect(gain(60000), 1);
      expect(gain(0), 1, reason: 'sin fadeIn, el principio suena entero');
    });

    test('baja al final con curva de potencia constante', () {
      expect(gain(180000), 0);
      expect(gain(177000), closeTo(0.7071, 0.001)); // a mitad: sin(45°)
      expect(gain(174000), closeTo(1, 0.0001));
    });

    test('sube al empezar si la anterior terminó sola', () {
      expect(gain(0, fadeIn: true), 0);
      expect(gain(3000, fadeIn: true), closeTo(0.7071, 0.001));
      expect(gain(7000, fadeIn: true), 1);
    });

    test('en una canción corta dura como mucho un cuarto', () {
      const short = Duration(seconds: 8);
      expect(gain(7000, seconds: 12, duration: short), closeTo(0.7071, 0.001)); // 2 s de transición
      expect(gain(5000, seconds: 12, duration: short), 1);
    });
  });

  test('Pausar al silenciar: solo sigue si la pausa la causó el silencio', () {
    final rule = MuteRule();
    expect(rule.onVolume(0.5, isPlaying: true), MuteAction.none);
    expect(rule.onVolume(0, isPlaying: true), MuteAction.pause);
    expect(rule.onVolume(0.3, isPlaying: false), MuteAction.resume);
    // En pausa a mano, silenciar y volver no la arranca.
    expect(rule.onVolume(0, isPlaying: false), MuteAction.none);
    expect(rule.onVolume(0.3, isPlaying: false), MuteAction.none);
    // Si la persona toma el control mientras está en silencio, manda ella.
    expect(rule.onVolume(0, isPlaying: true), MuteAction.pause);
    rule.userTookControl();
    expect(rule.onVolume(0.4, isPlaying: false), MuteAction.none);
  });

  test('Retomar con el Bluetooth: siempre que haya una canción en pausa', () {
    final rule = BluetoothResumeRule();
    expect(rule.onConnected(isPlaying: false, hasTrack: true), isTrue);
    expect(rule.onConnected(isPlaying: true, hasTrack: true), isFalse, reason: 'ya suena');
    expect(rule.onConnected(isPlaying: false, hasTrack: false), isFalse, reason: 'no hay nada para seguir');
  });

  test('Mezcla real: se prepara antes, arranca a N s del final y solo con siguiente', () {
    CrossfadeStep at(int sec, {bool prepared = false, bool hasNext = true, bool started = false}) => crossfadeStep(
          position: Duration(seconds: sec),
          duration: const Duration(seconds: 200),
          seconds: 5,
          hasNext: hasNext,
          prepared: prepared,
          started: started,
        );
    expect(at(150), CrossfadeStep.none);
    expect(at(193), CrossfadeStep.prepare, reason: '3 s antes de la mezcla');
    expect(at(193, prepared: true), CrossfadeStep.none);
    expect(at(196, prepared: true), CrossfadeStep.start);
    expect(at(196), CrossfadeStep.none, reason: 'sin cola lista: queda el fundido simple');
    expect(at(196, prepared: true, hasNext: false), CrossfadeStep.none, reason: 'última canción');
    expect(at(196, prepared: true, started: true), CrossfadeStep.none, reason: 'una sola vez');
    expect(
      crossfadeStep(position: const Duration(seconds: 5), duration: const Duration(seconds: 8), seconds: 5,
          hasNext: true, prepared: true, started: false),
      CrossfadeStep.none,
      reason: 'canción más corta que el doble de la mezcla',
    );
  });

  test('La cola baja con potencia constante', () {
    expect(crossfadeOutGain(Duration.zero, 5), 1);
    expect(crossfadeOutGain(const Duration(milliseconds: 2500), 5), closeTo(0.7071, 0.001));
    expect(crossfadeOutGain(const Duration(seconds: 5), 5), closeTo(0, 1e-9));
  });

  test('compartir: enlace de song.link para YouTube, solo texto para archivos', () {
    expect(shareTextFor(_track('yt-abc123XYZ_-')),
        'De música ligera — Soda Stereo\nhttps://song.link/y/abc123XYZ_-');
    expect(shareTextFor(_track('local-42')), 'De música ligera — Soda Stereo');
    expect(shareTextFor(_track('local-42', artist: ' ')), 'De música ligera');
  });

  test('ahorro de datos: calidad baja solo sin WiFi y si está activo', () {
    expect(useLowQuality(dataSaver: false, connection: [ConnectivityResult.mobile]), isFalse);
    expect(useLowQuality(dataSaver: true, connection: [ConnectivityResult.mobile]), isTrue);
    expect(useLowQuality(dataSaver: true, connection: [ConnectivityResult.wifi]), isFalse);
    expect(useLowQuality(dataSaver: true, connection: [ConnectivityResult.mobile, ConnectivityResult.wifi]),
        isFalse);
    expect(useLowQuality(dataSaver: true, connection: [ConnectivityResult.ethernet]), isFalse);

    final formats = [
      {'mimeType': 'audio/webm', 'bitrate': 160000, 'itag': 251},
      {'mimeType': 'video/mp4', 'bitrate': 10, 'itag': 160},
      {'mimeType': 'audio/mp4', 'bitrate': 48000, 'itag': 139},
      {'mimeType': 'audio/mp4', 'bitrate': 130000, 'itag': 140},
    ];
    expect(YtMusicClient.sortAudioFormats(formats).map((f) => f['itag']), [251, 140, 139]);
    expect(YtMusicClient.sortAudioFormats(formats, lowQuality: true).map((f) => f['itag']), [139, 140, 251]);
  });

  test('los ajustes nuevos se guardan, vienen apagados y un valor raro vuelve al de fábrica', () {
    const d = AppSettings();
    // "Retomar con el Bluetooth" viene prendido de fábrica (decisión del proyecto).
    expect([d.pauseOnMute, d.resumeOnBluetooth, d.dataSaver, d.crossfadeSeconds], [false, true, false, 0]);
    final s = d.copyWith(pauseOnMute: true, resumeOnBluetooth: false, crossfadeSeconds: 5, dataSaver: true);
    final back = AppSettings.fromJson(s.toJson());
    expect([back.pauseOnMute, back.resumeOnBluetooth, back.dataSaver, back.crossfadeSeconds], [true, false, true, 5]);
    expect(AppSettings.fromJson({'crossfadeSeconds': 7}).crossfadeSeconds, 0);
  });

  group('PlaybackAutomation', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('kiji_auto_'));
    tearDown(() async {
      await _settle();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('no escucha nada si está apagada; con las opciones, pausa y sigue', () async {
      final control = _FakeControl()..isPlaying = true;
      final volume = _FakeVolume();
      final outputs = _FakeOutputs();
      // Las dos apagadas a mano ("Retomar con el Bluetooth" viene prendida de fábrica).
      File('${dir.path}/settings.json').writeAsStringSync('{"pauseOnMute": false, "resumeOnBluetooth": false}');
      final automationProvider = Provider((ref) => PlaybackAutomation(ref)..start());
      final c = ProviderContainer(overrides: [
        settingsProvider.overrideWith(() => SettingsNotifier(directory: () async => dir)),
        playbackControlProvider.overrideWithValue(control),
        systemVolumeMonitorProvider.overrideWithValue(volume),
        audioOutputMonitorProvider.overrideWithValue(outputs),
      ]);
      addTearDown(c.dispose);
      final automation = c.read(automationProvider);
      await _settle();

      // Apagadas: nadie escucha el volumen (la salida se sigue siempre, para el corte de 15 s).
      expect(volume.controller.hasListener, isFalse);

      await c.read(settingsProvider.notifier)
          .update((s) => s.copyWith(pauseOnMute: true, resumeOnBluetooth: true));
      await _settle();
      expect(volume.controller.hasListener, isTrue);

      volume.controller.add(0);
      await _settle();
      automation.onPlayingChanged(false);
      volume.controller.add(0.4);
      await _settle();
      automation.onPlayingChanged(true);
      expect(control.calls, ['pause', 'play']);

      // Se desconecta el Bluetooth mientras suena: pausa (nunca por el parlante), sigue
      // en primer plano y, al volver en menos de 15 s, sigue sola.
      outputs.controller.add(AudioOutputKind.speaker);
      await _settle();
      automation.onPlayingChanged(false);
      expect(control.keptAlive, const Duration(seconds: 15));
      outputs.controller.add(AudioOutputKind.bluetooth);
      await _settle();
      automation.onPlayingChanged(true);
      expect(control.calls, ['pause', 'play', 'pause', 'play']);

      // En pausa a mano y con "Retomar con el Bluetooth" prendido, también sigue al conectar.
      await control.pause(reason: 'botón de pausa');
      automation.onPlayingChanged(false);
      outputs.controller.add(AudioOutputKind.speaker);
      outputs.controller.add(AudioOutputKind.bluetooth);
      await _settle();
      expect(control.calls.last, 'play');
      automation.onPlayingChanged(true);

      // Al apagar las opciones deja de escuchar el volumen.
      await c.read(settingsProvider.notifier)
          .update((s) => s.copyWith(pauseOnMute: false, resumeOnBluetooth: false));
      await _settle();
      expect(volume.controller.hasListener, isFalse);

      // Sin "Retomar con el Bluetooth", el corte corto igual sigue solo; el largo no.
      control.calls.clear();
      automation.onBecomingNoisy();
      automation.onPlayingChanged(false);
      outputs.controller.add(AudioOutputKind.speaker);
      outputs.controller.add(AudioOutputKind.bluetooth);
      await _settle();
      expect(control.calls, ['pause', 'play'], reason: 'el aviso y el cambio al parlante pausan una sola vez');
      expect(control.reasons.last, contains('Bluetooth'));
      automation.onPlayingChanged(true);
    });

    test('interrupciones: pausa con motivo y sigue solo si la pausa fue de ellas', () async {
      final control = _FakeControl()..isPlaying = true;
      final outputs = _FakeOutputs();
      final automationProvider = Provider((ref) => PlaybackAutomation(ref)..start());
      final c = ProviderContainer(overrides: [
        settingsProvider.overrideWith(() => SettingsNotifier(directory: () async => dir)),
        playbackControlProvider.overrideWithValue(control),
        audioOutputMonitorProvider.overrideWithValue(outputs),
      ]);
      addTearDown(c.dispose);
      final automation = c.read(automationProvider);
      await _settle();

      automation.onInterruption(AudioInterruptionEvent(true, AudioInterruptionType.pause));
      automation.onPlayingChanged(false);
      automation.onInterruption(AudioInterruptionEvent(false, AudioInterruptionType.pause));
      automation.onPlayingChanged(true);
      expect(control.calls, ['pause', 'play']);
      expect(control.reasons.single, contains('otra app'));

      // Si la persona pausó durante la llamada, no la arranca al terminar.
      automation.onInterruption(AudioInterruptionEvent(true, AudioInterruptionType.pause));
      automation.onPlayingChanged(false);
      automation.onPlayingChanged(true); // play a mano
      await control.pause(reason: 'botón de pausa');
      automation.onPlayingChanged(false);
      automation.onInterruption(AudioInterruptionEvent(false, AudioInterruptionType.pause));
      expect(control.calls, ['pause', 'play', 'pause', 'pause']);
    });
  });

  test('corte de la salida: sigue solo si vuelve en 15 s', () {
    var now = DateTime(2026, 10, 27, 12);
    final rule = OutputLossRule(now: () => now);
    expect(rule.onLost(isPlaying: false), isFalse, reason: 'en pausa no hay nada que cuidar');
    expect(rule.onBack(), isFalse);
    expect(rule.onLost(isPlaying: true), isTrue);
    now = now.add(const Duration(seconds: 14));
    expect(rule.onBack(), isTrue);
    expect(rule.onBack(), isFalse, reason: 'una sola vez');
    rule.onLost(isPlaying: true);
    now = now.add(const Duration(seconds: 16));
    expect(rule.onBack(), isFalse);
    rule.onLost(isPlaying: true);
    rule.userTookControl();
    expect(rule.onBack(), isFalse);
  });
}
