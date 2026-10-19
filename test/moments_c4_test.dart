import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/moments/domain/moment.dart';
import 'package:kiji_player/features/moments/presentation/moment_marks.dart';
import 'package:kiji_player/models/track.dart';

const _track = Track(
  id: 'yt-abcdefghijk',
  title: 'Tema inventado',
  artist: 'Artista inventado',
  coverColor: Color(0xFF7C5CFF),
  audioUrl: '',
  source: TrackSource.youtube,
);

Moment _tramo() => Moment(
      id: '1',
      track: _track,
      position: const Duration(seconds: 72),
      end: const Duration(seconds: 100),
      createdAt: DateTime(2026),
    );

void main() {
  test('Un tramo se guarda con su final y se comparte como "de 1:12 a 1:40"', () {
    final back = Moment.fromJson(_tramo().toJson())!;
    expect(back.isInterval, isTrue);
    expect(back.end, const Duration(seconds: 100));
    expect(momentShareText(back), contains('de 1:12 a 1:40'));
    expect(momentShareText(back), contains('t=72'));
  });

  test('Un punto sigue siendo un punto (y los guardados antes siguen funcionando)', () {
    final point = Moment.fromJson({
      'id': '2',
      'track': _track.toJson(),
      'positionMs': 30000,
      'createdAt': '2026-10-19T00:00:00',
    })!;
    expect(point.isInterval, isFalse);
    expect(momentShareText(point), contains('desde el 0:30'));
  });

  test('Repetir un tramo: al llegar al final vuelve al principio; si cambia la canción, deja de repetir', () {
    final loop = _tramo();
    expect(loopActionFor(loop, _track.id, const Duration(seconds: 80)), LoopAction.none);
    expect(loopActionFor(loop, _track.id, const Duration(seconds: 100)), LoopAction.seekToStart);
    expect(loopActionFor(loop, 'yt-otra', const Duration(seconds: 5)), LoopAction.stop);
    expect(loopActionFor(null, _track.id, const Duration(seconds: 100)), LoopAction.none);
  });
}
