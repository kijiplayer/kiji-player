import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:kiji_player/features/downloads/data/auto_downloads.dart';
import 'package:kiji_player/features/downloads/data/download_service.dart';
import 'package:kiji_player/features/downloads/domain/download_failure.dart';
import 'package:kiji_player/features/downloads/domain/downloaded_track.dart';
import 'package:kiji_player/features/favorites/favorites.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/downloads_provider.dart';
import 'package:kiji_player/utils/json_file.dart';

Track _t(String id, {TrackSource source = TrackSource.youtube}) => Track(
  id: source == TrackSource.youtube ? 'yt-$id' : 'local-$id',
  title: id,
  artist: 'Artista',
  coverColor: const Color(0xFF7C5CFF),
  audioUrl: source == TrackSource.local ? '/m/$id.mp3' : '',
  source: source,
);

/// Descargas simuladas: sin red, "WiFi" a elección y videos que YouTube "no da".
class _FakeDownloads extends DownloadsNotifier {
  bool wifi = true;
  final broken = <String>{};
  final started = <String>[];
  final failed = <String>[];

  /// Conectado por WiFi (para el ahorro de datos); [wifi] es "solo con WiFi" cumplido o no.
  bool onWifi = true;

  @override
  DownloadsState build() => const DownloadsState(loaded: true);

  @override
  Future<bool> onWifiOrEthernet() async => onWifi;

  @override
  Future<DownloadCheck> check(Track track) async {
    if (!wifi) return const DownloadCheck(blockedReason: 'sin WiFi', waitingForWifi: true);
    if (broken.contains(track.youtubeVideoId)) {
      return DownloadCheck(blockedReason: 'no', failure: DownloadFailure.unknown);
    }
    return const DownloadCheck(
      estimate: DownloadEstimate(url: 'https://x', extension: 'm4a', sizeBytes: 10),
    );
  }

  @override
  void start(Track track, DownloadEstimate estimate) => started.add(track.youtubeVideoId!);

  @override
  void recordFailure(Track track, DownloadFailure failure) => failed.add(track.youtubeVideoId!);
}

class _FakeSettings extends SettingsNotifier {
  _FakeSettings(this.initial);
  final AppSettings initial;
  @override
  AppSettings build() => initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late _FakeDownloads downloads;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('kiji_auto_');
    downloads = _FakeDownloads();
  });
  tearDown(() async {
    // Puede quedar un guardado en camino: se reintenta un momento (Windows bloquea el archivo).
    for (var i = 0; i < 20; i++) {
      try {
        dir.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });

  ProviderContainer container({bool downloadLiked = false, bool dataSaver = false}) {
    final c = ProviderContainer(
      overrides: [
        downloadsProvider.overrideWith(() => downloads),
        connectivityChangesProvider.overrideWithValue(const Stream.empty()),
        autoDownloadsFileProvider.overrideWithValue(
          Future.value(JsonFile(p.join(dir.path, 'auto.json'), logTag: 'PRUEBA')),
        ),
        settingsProvider.overrideWith(() => _FakeSettings(AppSettings(downloadLiked: downloadLiked, dataSaver: dataSaver))),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

  /// Espera (hasta 3 s) a que se cumpla [condition]: con la PC cargada, guardar tarda más.
  Future<void> eventually(bool Function() condition) async {
    for (var i = 0; i < 60 && !condition(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  test('Baja las de YouTube, saltea las locales y las repetidas', () async {
    final c = container();
    c.read(autoDownloadsProvider);
    await settle();
    final added = c.read(autoDownloadsProvider.notifier).enqueue([
      _t('a'),
      _t('b'),
      _t('a'),
      _t('x', source: TrackSource.local),
    ]);
    expect(added, 2);
    await settle();
    expect(downloads.started, ['a', 'b']);
    expect(c.read(autoDownloadsProvider).pending, isEmpty);
  });

  test('Sin WiFi esperan (y se guardan); con WiFi siguen', () async {
    downloads.wifi = false;
    final c = container();
    c.read(autoDownloadsProvider);
    await settle();
    c.read(autoDownloadsProvider.notifier).enqueue([_t('a'), _t('b')]);
    await settle();
    expect(downloads.started, isEmpty);
    expect(c.read(autoDownloadsProvider).pending.length, 2);
    expect(c.read(autoDownloadsProvider).waitingReason, 'sin WiFi');
    await eventually(() => File(p.join(dir.path, 'auto.json')).existsSync());
    expect(File(p.join(dir.path, 'auto.json')).existsSync(), isTrue);

    downloads.wifi = true;
    await c.read(autoDownloadsProvider.notifier).process();
    expect(downloads.started, ['a', 'b']);
    expect(c.read(autoDownloadsProvider).waitingReason, isNull);
  });

  test('Al reabrir Kiji, la lista de espera sigue', () async {
    downloads.wifi = false;
    final c1 = container();
    c1.read(autoDownloadsProvider);
    await settle();
    c1.read(autoDownloadsProvider.notifier).enqueue([_t('a')]);
    await eventually(() => File(p.join(dir.path, 'auto.json')).existsSync());
    await settle();
    c1.dispose();

    downloads = _FakeDownloads();
    final c2 = container();
    c2.read(autoDownloadsProvider);
    await eventually(() => downloads.started.isNotEmpty);
    expect(downloads.started, ['a']);
  });

  test('Si YouTube no da el audio, queda como fallida y la cola sigue', () async {
    downloads.broken.add('a');
    final c = container();
    c.read(autoDownloadsProvider);
    await settle();
    c.read(autoDownloadsProvider.notifier).enqueue([_t('a'), _t('b')]);
    await settle();
    expect(downloads.failed, ['a']);
    expect(downloads.started, ['b']);
  });

  group('Me gusta → descargar', () {
    test('Apagado de fábrica: dar me gusta no baja nada', () async {
      final c = container();
      c.read(favoritesProvider.notifier).toggle(_t('a'));
      await settle();
      expect(downloads.started, isEmpty);
    });

    test('Prendido: dar me gusta la baja; quitarlo antes la saca de la espera', () async {
      final c = container(downloadLiked: true);
      c.read(autoDownloadsProvider);
      await settle();
      c.read(favoritesProvider.notifier).toggle(_t('a'));
      await settle();
      expect(downloads.started, ['a']);

      downloads.wifi = false;
      c.read(favoritesProvider.notifier).toggle(_t('b'));
      await settle();
      expect(c.read(autoDownloadsProvider).pending.map((t) => t.id), ['yt-b']);
      c.read(favoritesProvider.notifier).toggle(_t('b')); // quita el me gusta
      expect(c.read(autoDownloadsProvider).pending, isEmpty);
    });
  });

  test('Ahorro de datos: con datos móviles esperan al WiFi; con WiFi siguen', () async {
    downloads.onWifi = false;
    final c = container(dataSaver: true);
    c.read(autoDownloadsProvider);
    await settle();
    c.read(autoDownloadsProvider.notifier).enqueue([_t('a'), _t('b')]);
    await settle();
    expect(downloads.started, isEmpty);
    expect(c.read(autoDownloadsProvider).waitingReason, 'Con el ahorro de datos, esperan al WiFi.');
    downloads.onWifi = true;
    await c.read(autoDownloadsProvider.notifier).process();
    expect(downloads.started, ['a', 'b']);
  });

  test('Tanda: el avance de todas juntas, que sigue sumando y termina', () async {
    downloads.wifi = false; // que esperen, para ver la tanda
    final c = container();
    c.read(autoDownloadsProvider);
    await settle();
    c.read(autoDownloadsProvider.notifier).enqueue([_t('a'), _t('b')]);
    c.read(autoDownloadsProvider.notifier).enqueue([_t('c')]); // se suma a la que va
    await settle();
    final auto = c.read(autoDownloadsProvider);
    expect(auto.batch, ['a', 'b', 'c']);
    final waiting = c.read(batchProgressProvider)!;
    expect((waiting.done, waiting.total, waiting.fraction, waiting.waitingReason), (0, 3, 0.0, 'sin WiFi'));

    // Una bajada, una a la mitad, una que falló.
    DownloadedTrack done(String id) => DownloadedTrack(
      videoId: id,
      title: id,
      artist: 'Artista',
      coverColor: const Color(0xFF7C5CFF),
      fileName: '$id.m4a',
      sizeBytes: 10,
      downloadedAt: DateTime(2026),
      durationMs: 1000,
    );
    final state = DownloadsState(
      completed: {'a': done('a')},
      active: {
        'b': ActiveDownload(track: _t('b'), status: ActiveDownloadStatus.downloading, received: 5, total: 10),
        'c': ActiveDownload(track: _t('c'), status: ActiveDownloadStatus.failed),
      },
    );
    final mid = BatchProgress.of(auto.copyWith(pending: const []), state)!;
    expect((mid.done, mid.failed, mid.total), (1, 1, 3));
    expect(mid.fraction, closeTo(2.5 / 3, 0.001));
    // Terminada (o de una sola): no se muestra.
    final finished = DownloadsState(completed: {'a': done('a'), 'b': done('b')}, active: state.active);
    expect(BatchProgress.of(auto.copyWith(pending: const []), finished), isNull);
    expect(BatchProgress.of(const AutoDownloadsState(batch: ['a']), state), isNull);
  });

  test('Cancelar la tanda: las que esperan salen de la lista', () async {
    downloads.wifi = false;
    final c = container();
    c.read(autoDownloadsProvider);
    await settle();
    c.read(autoDownloadsProvider.notifier).enqueue([_t('a'), _t('b')]);
    await settle();
    await c.read(autoDownloadsProvider.notifier).cancelBatch();
    expect(c.read(autoDownloadsProvider).pending, isEmpty);
    expect(c.read(batchProgressProvider), isNull);
  });
}
