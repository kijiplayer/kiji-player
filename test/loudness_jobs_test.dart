import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/loudness/data/loudness_analyzer.dart';

/// Un análisis que termina cuando la prueba quiere, y que se corta con [cancel].
class _SlowAnalyzer implements LoudnessAnalyzer {
  final started = <String>[];
  var running = 0;
  var maxRunning = 0;
  var cancels = 0;
  Completer<Uint8List?>? _now;

  @override
  Future<Uint8List?> analyze(String path) {
    started.add(path);
    running++;
    if (running > maxRunning) maxRunning = running;
    final c = _now = Completer<Uint8List?>();
    return c.future.whenComplete(() => running--);
  }

  void finish() => _now?.complete(Uint8List.fromList([1, 2, 3]));

  @override
  Future<void> cancel() async {
    cancels++;
    final c = _now;
    if (c != null && !c.isCompleted) c.complete(null);
  }
}

void main() {
  test('Onda: una canción a la vez; pasar de canción corta la anterior y las que esperaban no se analizan', () async {
    final analyzer = _SlowAnalyzer();
    final jobs = LoudnessJobs(analyzer);

    final a = jobs.analyze('yt-a', '/a.m4a');
    await Future<void>.delayed(Duration.zero);
    expect(analyzer.started, ['/a.m4a']);

    // Se pasa rápido por b y c: a se corta, b nunca empieza, c es la que queda.
    final b = jobs.analyze('yt-b', '/b.m4a');
    final c = jobs.analyze('yt-c', '/c.m4a');
    expect(await a, isNull, reason: 'cortada');
    expect(await b, isNull, reason: 'ya no hacía falta');
    await Future<void>.delayed(Duration.zero);
    expect(analyzer.started, ['/a.m4a', '/c.m4a']);
    analyzer.finish();
    expect(await c, [1, 2, 3]);
    expect(analyzer.maxRunning, 1, reason: 'nunca dos a la vez');
  });

  test('Onda: al dejar de verse la canción (cambió), se corta su análisis', () async {
    final analyzer = _SlowAnalyzer();
    final jobs = LoudnessJobs(analyzer);
    final a = jobs.analyze('yt-a', '/a.m4a');
    await Future<void>.delayed(Duration.zero);
    jobs.cancel('yt-b');
    expect(analyzer.cancels, 0, reason: 'otra canción: no toca la que suena');
    jobs.cancel('yt-a');
    expect(await a, isNull);
    expect(analyzer.cancels, 1);
    expect(jobs.current, isNull);
  });
}
