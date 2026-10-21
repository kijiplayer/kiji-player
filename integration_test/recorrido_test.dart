// Recorrido de toda la app en la PC, SOLO EN PC:
//   flutter test integration_test/recorrido_test.dart -d windows
// Usa una carpeta de datos temporal (nunca la de Kiji de la PC) con canciones, artistas,
// portadas y letra inventadas. Pasa por cada pantalla en ventana chica y grande, con y sin
// internet, y falla si aparece algún error de Flutter, un error no capturado o una línea de
// error nueva en kiji.log. Deja capturas en <temp>/kiji_recorrido/capturas para revisarlas.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:kiji_player/app.dart';
import 'package:kiji_player/features/account/presentation/account_screens.dart';
import 'package:kiji_player/features/backup/presentation/backup_screen.dart';
import 'package:kiji_player/features/customize/data/track_overrides.dart';
import 'package:kiji_player/features/downloads/presentation/downloads_screen.dart';
import 'package:kiji_player/features/equalizer/presentation/equalizer_screen.dart';
import 'package:kiji_player/features/history/listening_history.dart';
import 'package:kiji_player/features/import/presentation/import_screen.dart';
import 'package:kiji_player/features/lyrics/domain/lyrics.dart';
import 'package:kiji_player/features/lyrics/presentation/lyrics_screen.dart';
import 'package:kiji_player/features/moments/presentation/moments_screen.dart';
import 'package:kiji_player/features/playback_memory/domain/playback_snapshot.dart';
import 'package:kiji_player/features/playlists/domain/playlist.dart';
import 'package:kiji_player/features/playlists/presentation/playlist_screens.dart';
import 'package:kiji_player/features/queue/presentation/queue_screen.dart';
import 'package:kiji_player/features/reports/data/error_reporter.dart';
import 'package:kiji_player/features/reports/presentation/reports_screen.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/features/settings/presentation/credits_screen.dart';
import 'package:kiji_player/features/settings/presentation/settings_screen.dart';
import 'package:kiji_player/features/sleep_timer/presentation/sleep_timer_sheet.dart';
import 'package:kiji_player/features/translation/presentation/lyrics_settings_screens.dart';
import 'package:kiji_player/features/updates/whats_new.dart';
import 'package:kiji_player/l10n/l10n.dart';
import 'package:kiji_player/features/welcome/presentation/welcome_screen.dart';
import 'package:kiji_player/features/yt_music/presentation/extractor_health_screen.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/version.dart';
import 'package:kiji_player/providers/playback_provider.dart';
import 'package:kiji_player/screens/player/player_screen.dart';
import 'package:kiji_player/widgets/global_mini_player.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

final _root = Directory('${Directory.systemTemp.path}/kiji_recorrido');
final _shots = Directory('${_root.path}/capturas');

/// Todas las carpetas de path_provider apuntan a [dir].
class _TempPaths extends PathProviderPlatform {
  _TempPaths(this.dir);
  final Directory dir;
  String _sub(String name) => (Directory('${dir.path}/$name')..createSync(recursive: true)).path;
  @override
  Future<String?> getApplicationSupportPath() async => _sub('support');
  @override
  Future<String?> getApplicationDocumentsPath() async => _sub('documents');
  @override
  Future<String?> getApplicationCachePath() async => _sub('cache');
  @override
  Future<String?> getTemporaryPath() async => _sub('tmp');
  @override
  Future<String?> getDownloadsPath() async => _sub('downloads');
}

/// Sin internet: toda conexión de dart:io falla como cuando no hay red.
class _Offline extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => super.createHttpClient(context)
    ..connectionFactory = (uri, proxyHost, proxyPort) =>
        Future.error(const SocketException('Sin conexión (recorrido)', osError: OSError('offline', 10051)));
}

// --- Datos inventados -------------------------------------------------------------------------

const _songs = [
  ('Paper Lanterns', 'Mira Solenne', 'Night Orchard', 0xFF7C5CFF, 0xFF3DF5FF),
  ('Glass Harbor', 'The Velvet Tides', 'Low Tide Hymns', 0xFFFF6B9A, 0xFFFFC46B),
  ('Slow Comet', 'Aurelio Fen', 'Slow Comet', 0xFF2E86FF, 0xFF7CFFB2),
  ('Neon Rainfall', 'Kaiyo & the Lanterns', 'Wet Asphalt', 0xFFB15CFF, 0xFFFF5C8A),
  ('Lemon Static', 'June Arbor', 'Lemon Static', 0xFFFFD25C, 0xFFFF7A3D),
  ('Orbit of You', 'Lumen Drive', 'Satellites', 0xFF3DF5FF, 0xFF2E5CFF),
];

const _lyricLines = [
  'The sun is warm today',
  'We walk along the river',
  'Paper lanterns in the trees',
  'Counting stars we cannot see',
  'Hold the light a little longer',
  'Every street becomes a song',
];

Uint8List _tone(int seconds, double hz) {
  const rate = 8000;
  final samples = rate * seconds;
  final data = ByteData(44 + samples * 2);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + samples * 2, Endian.little);
  ascii(8, 'WAVEfmt ');
  data
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, rate, Endian.little)
    ..setUint32(28, rate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, samples * 2, Endian.little);
  for (var n = 0; n < samples; n++) {
    data.setInt16(44 + n * 2, (sin(2 * pi * hz * n / rate) * 3000).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

Future<Uint8List> _cover(int seed, Color a, Color b) async {
  const size = 400.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(
      const Rect.fromLTWH(0, 0, size, size),
      Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(size, size), [a, b]),
    );
  final rnd = Random(seed);
  for (var k = 1; k <= 6; k++) {
    canvas.drawCircle(
      Offset(size * (0.3 + rnd.nextDouble() * 0.4), size * (0.3 + rnd.nextDouble() * 0.4)),
      k * 26.0,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.25),
    );
  }
  final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

/// Escribe en [support] la biblioteca inventada y devuelve sus canciones.
Future<List<Track>> _seed(
  Directory support, {
  required String language,
  String theme = 'dark',
  String accent = 'nocturne',
}) async {
  void write(String name, Object json) {
    final f = File('${support.path}/$name')..parent.createSync(recursive: true);
    f.writeAsStringSync(jsonEncode(json));
  }

  final tones = Directory('${_root.path}/tonos')..createSync(recursive: true);
  final tracks = <Track>[];
  final overrides = <String, dynamic>{};
  for (var i = 0; i < _songs.length; i++) {
    final s = _songs[i];
    final file = File('${tones.path}/tono_$i.wav');
    if (!file.existsSync()) file.writeAsBytesSync(_tone(24, 220.0 + i * 55));
    final track = Track(
      id: 'local-${9001 + i}',
      title: s.$1,
      artist: s.$2,
      album: s.$3,
      coverColor: Color(s.$4),
      audioUrl: file.path,
      source: TrackSource.local,
      durationMs: 24000,
      sizeBytes: file.lengthSync(),
    );
    tracks.add(track);
    final cover = 'demo-${9001 + i}.png';
    File('${support.path}/covers/$cover')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(await _cover(i, Color(s.$4), Color(s.$5)));
    overrides[track.id] = TrackOverride(coverFile: cover).toJson();
  }
  final now = DateTime.now();
  write('track_overrides.json', overrides);
  write('playlists.json', {
    'version': 1,
    'playlists': [
      Playlist(
        id: 'pl-demo0',
        name: 'Late Night Drive',
        tracks: [tracks[0], tracks[3], tracks[5], tracks[1]],
        createdAt: now,
        updatedAt: now,
        colorValue: 0xFF7C5CFF,
        pinned: true,
      ).toJson(),
      Playlist(id: 'pl-demo1', name: 'Sunday Morning', tracks: [tracks[4], tracks[2]], createdAt: now, updatedAt: now)
          .toJson(),
    ],
  });
  write('history.json', [
    for (var i = 0; i < tracks.length; i++)
      HistoryEntry(track: tracks[i], lastPlayed: now.subtract(Duration(hours: i)), playCount: 6 - i).toJson(),
  ]);
  write('favorites.json', [tracks[0].toJson(), tracks[2].toJson()]);
  write('playback_state.json', PlaybackSnapshot(
    queue: tracks,
    currentIndex: 0,
    positionMs: 4000,
    repeatMode: 'all',
    shuffleEnabled: false,
  ).toJson());
  write('lyrics/${tracks[0].id}.json', {
    'savedAt': now.millisecondsSinceEpoch,
    'lyrics': Lyrics(synced: [
      for (var i = 0; i < _lyricLines.length; i++) LyricLine(Duration(seconds: 1 + i * 3), _lyricLines[i]),
    ]).toJson(),
  });
  write('moments.json', []);
  write(
    'settings.json',
    const AppSettings(checkUpdates: false, autoExtractorTests: false)
        .copyWith(language: language, theme: theme, accent: accent, lastSeenVersion: kijiVersion)
        .toJson(),
  );
  write('welcome.json', {'seen': true, 'at': now.toIso8601String()});
  return tracks;
}

// --- Recorrido --------------------------------------------------------------------------------

final _problems = <String>[];
final _visited = <String>[];

/// La pantalla en la que está el recorrido (para saber dónde saltó un error).
var _where = 'inicio';

Future<void> _settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  final view = tester.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  final image = await layer.toImage(Offset.zero & view.size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  _shots.createSync(recursive: true);
  File('${_shots.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

BuildContext get _ctx => kijiNavigatorKey.currentContext!;

/// Abre una pantalla, espera, toma la captura y vuelve. Un fallo se anota y el recorrido sigue.
Future<void> _visit(WidgetTester tester, String name, FutureOr<void> Function() open, {bool scroll = false}) async {
  _where = name;
  try {
    unawaited(Future.sync(open));
    await _settle(tester);
    if (scroll) {
      final scrollables = find.byType(Scrollable);
      if (scrollables.evaluate().isNotEmpty) {
        for (var i = 0; i < 25; i++) {
          await tester.drag(scrollables.first, const Offset(0, -400), warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 60));
        }
      }
    }
    await _shot(tester, name);
    _visited.add(name);
  } catch (error, stack) {
    _problems.add('$name: $error\n$stack');
  }
  await kijiNavigatorKey.currentState?.maybePop();
  await _settle(tester, 6);
}

Future<void> _tab(WidgetTester tester, IconData icon, String name) async {
  _where = name;
  final finder = find.byIcon(icon);
  if (finder.evaluate().isEmpty) {
    _problems.add('$name: no se encontró la pestaña');
    return;
  }
  await tester.tap(finder.last, warnIfMissed: false);
  await _settle(tester);
  await _shot(tester, name);
  _visited.add(name);
}

/// Un paso con varias acciones (tocar, mantener presionado…): un fallo se anota y el recorrido
/// sigue. Al final vuelve atrás hasta la pantalla principal.
Future<void> _step(WidgetTester tester, String name, Future<void> Function() body, {int pops = 1}) async {
  _where = name;
  try {
    await body();
    _visited.add(name);
  } catch (error, stack) {
    _problems.add('$name: $error\n$stack');
  }
  for (var i = 0; i < pops; i++) {
    await kijiNavigatorKey.currentState?.maybePop();
    await _settle(tester, 6);
  }
}

/// Selección múltiple: mantener presionada la primera fila, captura, "todas", captura y cerrar.
Future<void> _selection(WidgetTester tester, String name) async {
  final rows = find.byType(ListTile);
  if (rows.evaluate().isEmpty) throw StateError('no hay filas para elegir');
  await tester.longPress(rows.first, warnIfMissed: false);
  await _settle(tester, 6);
  await _shot(tester, name);
  final all = find.byTooltip(tx.seleccionarTodas);
  if (all.evaluate().isEmpty) throw StateError('no apareció la barra de selección');
  await tester.tap(all.first);
  await _settle(tester, 6);
  await _shot(tester, '$name-todas');
  await tester.tap(find.byTooltip(tx.quitarSeleccion).first);
  await _settle(tester, 6);
  if (find.byTooltip(tx.quitarSeleccion).evaluate().isNotEmpty) throw StateError('la selección no se cerró');
}

Future<void> _walk(WidgetTester tester, String tag, ProviderContainer container, List<Track> tracks,
    {required bool online}) async {
  await _tab(tester, Icons.home_rounded, '$tag-inicio');
  final scroll = find.byType(Scrollable);
  if (scroll.evaluate().isNotEmpty) {
    await tester.drag(scroll.first, const Offset(0, -900), warnIfMissed: false);
    await _settle(tester, 6);
    await _shot(tester, '$tag-inicio-abajo');
  }

  // Buscar: con internet una búsqueda real; sin internet tiene que avisar sin romper.
  await _tab(tester, Icons.search_rounded, '$tag-buscar');
  final field = find.byType(TextField);
  if (field.evaluate().isNotEmpty) {
    await tester.enterText(field.first, online ? 'lofi piano' : 'paper');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await _shot(tester, '$tag-buscar-resultados');
  }

  await _tab(tester, Icons.library_music_rounded, '$tag-biblioteca');

  // Reproducir dos canciones inventadas (locales) y pasar por el reproductor.
  final player = container.read(playbackProvider.notifier);
  await tester.runAsync(() => player.playQueue(tracks, startIndex: 0));
  await _settle(tester, 20);
  await _visit(tester, '$tag-reproductor', () => PlayerScreen.open(_ctx));
  await _visit(tester, '$tag-cola', () => QueueScreen.open(_ctx));
  await _visit(tester, '$tag-letra', () => LyricsScreen.open(_ctx));
  await _step(tester, '$tag-letra-menu', () async {
    unawaited(LyricsScreen.open(_ctx));
    await _settle(tester);
    await tester.tap(find.byTooltip(tx.opcionesDeLaLetra).first);
    await _settle(tester);
    await _shot(tester, '$tag-letra-menu');
    // Se cierra deslizando hacia abajo desde la mitad de la hoja.
    await tester.timedDrag(find.text(tx.tamanoDeLasLetras.toUpperCase()), const Offset(0, 260),
        const Duration(milliseconds: 500));
    await _settle(tester);
    if (find.text(tx.tamanoDeLasLetras.toUpperCase()).evaluate().isNotEmpty) {
      throw StateError('la hoja no se cerró deslizando desde la mitad');
    }
  });
  await _visit(tester, '$tag-momentos', () => MomentsScreen.open(_ctx));
  await _visit(tester, '$tag-temporizador', () => showSleepTimerSheet(_ctx));
  await tester.runAsync(player.nextTrack);
  await _settle(tester, 10);
  await tester.runAsync(player.pause);

  await _visit(tester, '$tag-playlist', () => PlaylistScreen.open(_ctx, 'pl-demo0'));
  await _step(tester, '$tag-playlist-seleccion', () async {
    unawaited(PlaylistScreen.open(_ctx, 'pl-demo0'));
    await _settle(tester);
    await _selection(tester, '$tag-playlist-seleccion');
  });
  await _visit(tester, '$tag-novedades', () async {
    final notes = await tester.runAsync(() => loadBundledWhatsNew(kijiLanguage));
    await showWhatsNewSheet(_ctx, notes ?? '');
  });
  await _step(tester, '$tag-apariencia', () async {
    unawaited(SettingsScreen.open(_ctx));
    await _settle(tester);
    await tester.enterText(find.byType(TextField).first, tx.apariencia);
    await _settle(tester, 6);
    await _shot(tester, '$tag-apariencia');
  });
  await _visit(tester, '$tag-descargas', () => DownloadsScreen.open(_ctx));
  await _visit(tester, '$tag-ecualizador', () => EqualizerScreen.open(_ctx));
  await _visit(tester, '$tag-copias', () => BackupScreen.open(_ctx), scroll: true);
  await _visit(tester, '$tag-importar', () => ImportScreen.open(_ctx));
  await _visit(tester, '$tag-cuenta', () => AccountScreen.open(_ctx));
  await _visit(tester, '$tag-fuentes-letras', () => LyricsSourcesScreen.open(_ctx));
  await _visit(tester, '$tag-traduccion', () => TranslationSettingsScreen.open(_ctx));
  await _visit(tester, '$tag-salud', () => ExtractorHealthScreen.open(_ctx), scroll: true);
  await _visit(tester, '$tag-registros', () => ReportsScreen.open(_ctx));
  await _visit(tester, '$tag-creditos', () => CreditsScreen.open(_ctx), scroll: true);
  await _visit(tester, '$tag-configuracion', () => SettingsScreen.open(_ctx), scroll: true);
  await _visit(tester, '$tag-bienvenida', () => WelcomeScreen.open(_ctx, instant: true));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  JustAudioMediaKit.ensureInitialized(windows: true, linux: true);

  setUpAll(() {
    if (_root.existsSync()) _root.deleteSync(recursive: true);
    _root.createSync(recursive: true);
  });

  Future<void> run(WidgetTester tester, String tag,
      {required Size window, required bool online, required bool fresh, String language = 'es',
      String theme = 'dark', String accent = 'nocturne'}) async {
    final data = Directory('${_root.path}/$tag')..createSync(recursive: true);
    PathProviderPlatform.instance = _TempPaths(data);
    final support = Directory('${data.path}/support')..createSync(recursive: true);
    final tracks = fresh ? <Track>[] : await tester.runAsync(() => _seed(support, language: language, theme: theme, accent: accent)) ?? [];
    HttpOverrides.global = online ? null : _Offline();
    addTearDown(() => HttpOverrides.global = null);

    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final flutterErrors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final frame = details.stack.toString().split('\n').where((l) => l.contains('package:kiji_player/')).firstOrNull;
      flutterErrors.add('[$_where] ${details.exceptionAsString().split('\n').first} · ${frame?.trim() ?? 'sin pila de Kiji'}');
    };
    ErrorReporter.instance.reset();

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const KijiApp()));
    await _settle(tester, 30);

    if (fresh) {
      // Usuario nuevo: la bienvenida aparece sola; se recorre entera y se empieza.
      await _shot(tester, '$tag-bienvenida-1');
      for (var page = 2; page <= 5; page++) {
        final next = find.textContaining(RegExp(r'^(Siguiente|Next)$'));
        if (next.evaluate().isEmpty) {
          _problems.add('$tag: la bienvenida no apareció sola o le falta "Siguiente" (página $page)');
          break;
        }
        await tester.tap(next.last);
        await _settle(tester);
        await _shot(tester, '$tag-bienvenida-$page');
      }
      final start = find.textContaining(RegExp(r'^(Empezar|Start)$'));
      if (start.evaluate().isNotEmpty) {
        await tester.tap(start.last);
        await _settle(tester);
      }
      // Usuario nuevo sin nada: Inicio, Buscar y Biblioteca vacíos.
      await _tab(tester, Icons.home_rounded, '$tag-inicio-vacio');
      await _tab(tester, Icons.library_music_rounded, '$tag-biblioteca-vacia');
      await _visit(tester, '$tag-configuracion', () => SettingsScreen.open(_ctx), scroll: true);
    } else {
      await _walk(tester, tag, container, tracks, online: online);
    }

    // Que todo lo pendiente termine antes de mirar el registro.
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await _settle(tester, 10);

    final log = File('${support.path}/logs/kiji.log');
    final logText = log.existsSync() ? log.readAsStringSync() : '';
    final logErrors = [
      for (final line in const LineSplitter().convert(logText))
        if (RegExp(r'ERROR|Exception|excepción|no capturado', caseSensitive: false).hasMatch(line)) line,
    ];
    File('${_root.path}/$tag-kiji.log').writeAsStringSync(logText);
    File('${_root.path}/$tag-resumen.txt').writeAsStringSync([
      'Pantallas: ${_visited.where((v) => v.startsWith('$tag-')).join(', ')}',
      'Errores de Flutter: ${flutterErrors.length}',
      ...flutterErrors,
      'Errores capturados: ${ErrorReporter.instance.recent.length}',
      for (final r in ErrorReporter.instance.recent) '${r.summary}: ${r.detail}',
      'Líneas de error en kiji.log: ${logErrors.length}',
      ...logErrors,
      'Problemas del recorrido: ${_problems.length}',
      ..._problems,
    ].join('\n'));

    await tester.pumpWidget(const SizedBox());
    await _settle(tester, 4);
    FlutterError.onError = previous;
    expect(flutterErrors, isEmpty, reason: 'errores de Flutter en $tag');
    expect(_problems, isEmpty, reason: 'pasos del recorrido que fallaron en $tag');
    expect(logErrors, isEmpty, reason: 'líneas de error en kiji.log ($tag)');
    expect(ErrorReporter.instance.recent, isEmpty, reason: 'errores capturados en $tag');
  }

  testWidgets('Usuario nuevo, ventana chica: bienvenida y pantallas vacías', (tester) async {
    await run(tester, 'nuevo-chica', window: const Size(420, 860), online: true, fresh: true);
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('Con datos, ventana chica, con internet', (tester) async {
    await run(tester, 'datos-chica', window: const Size(420, 860), online: true, fresh: false);
  }, timeout: const Timeout(Duration(minutes: 10)));

  testWidgets('Con datos, ventana grande, en inglés', (tester) async {
    await run(tester, 'datos-grande-en', window: const Size(1440, 900), online: true, fresh: false, language: 'en');
  }, timeout: const Timeout(Duration(minutes: 10)));

  testWidgets('Tema claro con acento Brasa, ventana chica', (tester) async {
    await run(tester, 'claro-chica', window: const Size(420, 860), online: true, fresh: false, theme: 'light',
        accent: 'ember');
  }, timeout: const Timeout(Duration(minutes: 10)));

  testWidgets('Tema más oscuro con acento Aurora, ventana grande', (tester) async {
    await run(tester, 'oscuro-grande', window: const Size(1440, 900), online: true, fresh: false, theme: 'darker',
        accent: 'aurora');
  }, timeout: const Timeout(Duration(minutes: 10)));

  testWidgets('Con datos, sin internet', (tester) async {
    await run(tester, 'sin-internet', window: const Size(1100, 800), online: false, fresh: false);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
