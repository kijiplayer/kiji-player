import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/queue/domain/queue_operations.dart';
import 'package:kiji_player/models/track.dart';

Track _t(String id) => Track(
      id: 'yt-$id',
      title: id,
      artist: 'Artista',
      coverColor: const Color(0xFF7C5CFF),
      audioUrl: '',
      source: TrackSource.youtube,
    );

List<String> _ids(QueueSnapshot q) => [for (final t in q.tracks) t.title];

void main() {
  // Cola a b c d e, sonando "c" (índice 2).
  final queue = QueueSnapshot([_t('a'), _t('b'), _t('c'), _t('d'), _t('e')], 2);

  group('Mover', () {
    test('Mover la que suena la sigue', () {
      final q = queue.move(2, 4);
      expect(_ids(q), ['a', 'b', 'd', 'e', 'c']);
      expect(q.current!.title, 'c');
    });

    test('Mover una de antes hacia después de la que suena', () {
      final q = queue.move(0, 3);
      expect(_ids(q), ['b', 'c', 'd', 'a', 'e']);
      expect(q.current!.title, 'c');
    });

    test('Mover una de después hacia antes de la que suena', () {
      final q = queue.move(4, 0);
      expect(_ids(q), ['e', 'a', 'b', 'c', 'd']);
      expect(q.current!.title, 'c');
    });

    test('Índices inválidos no cambian nada', () {
      expect(identical(queue.move(1, 9), queue), isTrue);
    });
  });

  group('Quitar y deshacer', () {
    test('Quitar una de antes mantiene la que suena', () {
      final q = queue.remove(0);
      expect(_ids(q), ['b', 'c', 'd', 'e']);
      expect(q.current!.title, 'c');
    });

    test('Quitar la que suena pasa a la siguiente', () {
      final q = queue.remove(2);
      expect(q.current!.title, 'd');
    });

    test('Quitar la última cuando suena la última pasa a la anterior', () {
      final q = QueueSnapshot([_t('a'), _t('b')], 1).remove(1);
      expect(q.current!.title, 'a');
    });

    test('Quitar la única deja la cola vacía', () {
      final q = QueueSnapshot([_t('a')], 0).remove(0);
      expect(q.tracks, isEmpty);
      expect(q.current, isNull);
    });

    test('Deshacer devuelve todo exactamente como estaba', () {
      for (var index = 0; index < queue.tracks.length; index++) {
        final removed = queue.tracks[index];
        final undone = queue
            .remove(index)
            .insert(index, removed, wasCurrent: index == queue.currentIndex);
        expect(_ids(undone), _ids(queue), reason: 'quitando el índice $index');
        expect(undone.currentIndex, queue.currentIndex, reason: 'quitando el índice $index');
      }
    });
  });

  group('Reproducir a continuación y agregar', () {
    test('Una nueva queda justo después de la que suena', () {
      final q = queue.playNext(_t('x'));
      expect(_ids(q), ['a', 'b', 'c', 'x', 'd', 'e']);
      expect(q.current!.title, 'c');
    });

    test('Si ya estaba en la cola se mueve, no se duplica', () {
      final antes = queue.playNext(_t('a'));
      expect(_ids(antes), ['b', 'c', 'a', 'd', 'e']);
      expect(antes.current!.title, 'c');

      final despues = queue.playNext(_t('e'));
      expect(_ids(despues), ['a', 'b', 'c', 'e', 'd']);
    });

    test('La que suena no se mueve', () {
      expect(identical(queue.playNext(_t('c')), queue), isTrue);
    });

    test('Con la cola vacía, la canción pasa a ser la cola', () {
      final q = const QueueSnapshot([], 0).playNext(_t('x'));
      expect(_ids(q), ['x']);
      expect(q.currentIndex, 0);
    });

    test('Agregar al final no duplica', () {
      expect(_ids(queue.addToEnd(_t('x'))), ['a', 'b', 'c', 'd', 'e', 'x']);
      expect(identical(queue.addToEnd(_t('b')), queue), isTrue);
    });
  });

  group('"A continuación" gana sobre el aleatorio', () {
    test('Sin pedidos no hay preferencia', () {
      expect(queue.nextRequestedIndex({}), isNull);
    });

    test('Elige la pedida más cercana después de la que suena', () {
      final q = queue.playNext(_t('x')).playNext(_t('y'));
      // a b c y x d e — sonando c
      expect(_ids(q), ['a', 'b', 'c', 'y', 'x', 'd', 'e']);
      expect(q.tracks[q.nextRequestedIndex({'yt-x', 'yt-y'})!].title, 'y');
      expect(q.tracks[q.nextRequestedIndex({'yt-x'})!].title, 'x');
    });

    test('Si se reordenó y quedó antes de la que suena, igual se elige', () {
      expect(queue.tracks[queue.nextRequestedIndex({'yt-a'})!].title, 'a');
    });

    test('Una pedida que ya no está en la cola se ignora', () {
      expect(queue.nextRequestedIndex({'yt-zzz'}), isNull);
    });

    test('La que suena no cuenta como pedida', () {
      expect(queue.nextRequestedIndex({'yt-c'}), isNull);
    });
  });
}
