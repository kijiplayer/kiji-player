import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/downloads/data/download_service.dart';
import 'package:kiji_player/features/downloads/data/downloads_repository.dart';
import 'package:kiji_player/features/downloads/data/playlist_download.dart';
import 'package:kiji_player/features/downloads/domain/download_failure.dart';
import 'package:kiji_player/features/downloads/presentation/download_status.dart';
import 'package:kiji_player/features/extractor/data/engines.dart';
import 'package:kiji_player/features/extractor/data/extractor_trace.dart';
import 'package:kiji_player/features/extractor/data/path_health.dart';
import 'package:kiji_player/features/extractor/data/stream_resolver.dart';
import 'package:kiji_player/features/extractor/domain/extraction_failure.dart';
import 'package:kiji_player/features/extractor/domain/resolved_stream.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/providers/downloads_provider.dart';

class _FakeEngine extends ExtractionEngine {
  _FakeEngine(this.answer);
  @override
  EngineId get id => EngineId.b;
  final EngineResult Function(Set<String> skip) answer;

  @override
  bool get isSupported => true;

  @override
  Future<EngineResult> resolve(String videoId, {bool lowQuality = false, Set<String> skip = const {}, List<String>? order}) async =>
      answer(skip);
}

Track _yt(String id) => Track(
      id: 'yt-$id',
      title: 'Tema $id',
      artist: 'Artista inventado',
      coverColor: const Color(0xFF7C5CFF),
      audioUrl: '',
      source: TrackSource.youtube,
      durationMs: 200000,
    );

/// Descargas falsas: [failing] no se pueden bajar (con su motivo); el resto empieza.
class _FakeDownloads extends DownloadsNotifier {
  final failing = <String, DownloadFailure>{};
  final retried = <String>[];

  @override
  DownloadsState build() => const DownloadsState(loaded: true);

  @override
  Future<DownloadCheck> check(Track track) async {
    final failure = failing[track.youtubeVideoId];
    if (failure != null) return DownloadCheck(blockedReason: failure.message, failure: failure);
    return const DownloadCheck(estimate: DownloadEstimate(url: 'x', extension: 'm4a', sizeBytes: 100));
  }

  @override
  void start(Track track, DownloadEstimate estimate) {
    state = state.copyWith(active: {
      ...state.active,
      track.youtubeVideoId!: ActiveDownload(track: track, status: ActiveDownloadStatus.downloading, total: 100),
    });
  }

  @override
  int retryAll([Iterable<String>? videoIds]) {
    retried.addAll(videoIds ?? const []);
    return retried.length;
  }
}

void main() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('kiji_t4');
    ExtractorTrace.instance.clear();
  });
  tearDown(() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      try {
        dir.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        continue;
      }
    }
  });

  DownloadService service(EngineResult Function(Set<String> skip) answer) => DownloadService(
        DownloadsRepository(baseDirectory: () async => dir),
        resolver: StreamResolver(engines: [_FakeEngine(answer)], health: PathHealth(directory: () async => dir.path)),
      );

  group('Descargas con los motores de Z8 (T4)', () {
    test('Una lista HLS no se puede bajar por pedazos: se saltea y se usa la forma siguiente', () async {
      final seen = <Set<String>>[];
      final s = service((skip) {
        seen.add(skip);
        if (!skip.contains('VISIONOS_HLS')) {
          return const EngineResult.ok(ResolvedStream(
              videoId: 'v', url: 'https://g/hls', engine: EngineId.b, form: 'VISIONOS_HLS', isHls: true));
        }
        return const EngineResult.ok(ResolvedStream(
          videoId: 'v',
          url: 'https://g/a?mime=audio%2Fwebm',
          engine: EngineId.b,
          form: 'WEB_REMIX',
          headers: {'User-Agent': 'prueba'},
          contentLength: 1234,
          chunkSize: 512 * 1024,
        ));
      });
      final out = await s.estimate('v');
      expect(out.estimate?.path, 'B/WEB_REMIX');
      expect(out.estimate?.extension, 'webm');
      expect(out.estimate?.sizeBytes, 1234);
      expect(out.estimate?.headers['User-Agent'], 'prueba', reason: 'los encabezados de la forma viajan con la descarga');
      expect(out.estimate?.chunkBytes, 512 * 1024);
      expect(seen.last, contains('VISIONOS_HLS'));
    });

    test('Restricción de edad: el motivo en palabras simples y se puede buscar otra versión', () async {
      final s = service((_) => EngineResult.failed([('WEB_REMIX', classifyFailure('Sign in to confirm your age'))]));
      final out = await s.estimate('v');
      expect(out.estimate, isNull);
      expect(out.failure!.kind, DownloadFailureKind.content);
      expect(out.failure!.message, contains('restricción de edad'));
      expect(out.failure!.canSearchAlternative, isTrue);
    });

    test('Todas las formas fallan (con internet): se dice que suele arreglarse solo', () async {
      final s = service((_) => EngineResult.failed([('WEB_REMIX', classifyFailure('HTTP 403'))]));
      final out = await s.estimate('v');
      expect(out.failure!.kind, DownloadFailureKind.allForms);
      expect(out.failure!.message, contains('Suele arreglarse solo'));
    });
  });

  test('Buscar otra versión sin éxito: se conserva el motivo y no se vuelve a ofrecer', () {
    final age = DownloadFailure.fromOutcome(const ResolveOutcome.content(ContentProblem.ageRestricted, []));
    final after = age.withoutAlternative();
    expect(after.message, contains('restricción de edad'));
    expect(after.message, contains('no hay'));
    expect(after.message, isNot(contains('Puedes buscar otra versión')));
    expect(after.canSearchAlternative, isFalse);
    expect(DownloadFailure.fromJson(after.toJson()).canSearchAlternative, isFalse);
  });

  test('Errores comunes en palabras simples', () {
    expect(DownloadFailure.fromError(const SocketException('x')).kind, DownloadFailureKind.network);
    expect(
      DownloadFailure.fromError(const FileSystemException('x', 'p', OSError('No space left on device', 28))).kind,
      DownloadFailureKind.noSpace,
    );
    expect(DownloadFailure.fromError(StateError('x')).kind, DownloadFailureKind.unknown);
  });

  test('Las fallidas se guardan y vuelven al abrir Kiji, con su motivo', () async {
    final repository = DownloadsRepository(baseDirectory: () async => dir);
    final failed = ActiveDownload(
      track: _yt('abc'),
      status: ActiveDownloadStatus.failed,
      failure: const DownloadFailure(DownloadFailureKind.content, 'Tiene restricción de edad',
          problem: ContentProblem.ageRestricted),
      sourceId: 'otra',
    );
    await repository.saveFailed({'abc': failed.toFailedJson()});
    final back = ActiveDownload.fromFailedJson((await DownloadsRepository(baseDirectory: () async => dir).failed())['abc']!);
    expect(back.status, ActiveDownloadStatus.failed);
    expect(back.track.title, 'Tema abc');
    expect(back.failure?.problem, ContentProblem.ageRestricted);
    expect(back.errorMessage, 'Tiene restricción de edad');
    expect(back.sourceId, 'otra');
  });

  test('Estado para las listas: ✓, %, espera y error', () {
    final state = DownloadsState(active: {
      'a': ActiveDownload(track: _yt('a'), status: ActiveDownloadStatus.downloading, received: 25, total: 100),
      'b': ActiveDownload(track: _yt('b'), status: ActiveDownloadStatus.queued),
      'c': ActiveDownload(track: _yt('c'), status: ActiveDownloadStatus.failed),
    });
    expect(downloadMarkOf(state, 'a'), (DownloadMark.downloading, 25));
    expect(downloadMarkOf(state, 'b').$1, DownloadMark.queued);
    expect(downloadMarkOf(state, 'c').$1, DownloadMark.failed);
    expect(downloadMarkOf(state, 'z').$1, DownloadMark.none);
  });

  group('Playlist entera (T4)', () {
    test('Las que YouTube no da quedan en la lista con su motivo, "Ver cuáles" y "Reintentar las fallidas"', () async {
      final container = ProviderContainer(overrides: [downloadsProvider.overrideWith(_FakeDownloads.new)]);
      addTearDown(container.dispose);
      container.listen(playlistDownloadsProvider, (_, _) {});
      final downloads = container.read(downloadsProvider.notifier) as _FakeDownloads;
      downloads.failing['b'] = DownloadFailure.fromOutcome(const ResolveOutcome.content(ContentProblem.ageRestricted, []));
      final batch = container.read(playlistDownloadsProvider.notifier);

      batch.start('p', planPlaylistDownload([_yt('a'), _yt('b')], {}));
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      final failed = container.read(downloadsProvider).active['b'];
      expect(failed?.status, ActiveDownloadStatus.failed, reason: 'antes solo se sumaba al contador');
      expect(failed?.errorMessage, contains('restricción de edad'));
      expect(container.read(playlistDownloadsProvider)['p']!.failedIds, ['b']);

      batch.retryFailed('p');
      expect(downloads.retried, ['b']);
      expect(container.read(playlistDownloadsProvider)['p']!.total, 1);
    });
  });
}
