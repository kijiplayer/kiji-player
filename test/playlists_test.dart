import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/history/listening_history.dart';
import 'package:kiji_player/features/playlists/domain/playlist.dart';
import 'package:kiji_player/features/playlists/domain/smart_lists.dart';
import 'package:kiji_player/features/playlists/playlists_provider.dart';
import 'package:kiji_player/models/track.dart';

Track _t(String id, {TrackSource source = TrackSource.youtube}) => Track(
      id: source == TrackSource.youtube ? 'yt-$id' : 'local-$id',
      title: id,
      artist: 'Artista',
      coverColor: const Color(0xFF7C5CFF),
      audioUrl: source == TrackSource.local ? '/m/$id.mp3' : '',
      source: source,
    );

Playlist _pl(List<Track> tracks) {
  final t = DateTime(2026, 10, 16);
  return Playlist(id: 'pl', name: 'Mía', tracks: tracks, createdAt: t, updatedAt: t);
}

List<String> _ids(Playlist pl) => [for (final t in pl.tracks) t.title];

void main() {
  final now = DateTime(2026, 10, 16, 3);

  group('Operaciones de playlist', () {
    test('Nunca se pisa un nombre (sin importar mayúsculas)', () {
      expect(PlaylistOps.uniqueName('Rock', ['Pop']), 'Rock');
      expect(PlaylistOps.uniqueName('rock', ['Rock']), 'rock 2');
      expect(PlaylistOps.uniqueName('Rock', ['Rock'], suffix: '(importada)'), 'Rock (importada)');
      expect(
        PlaylistOps.uniqueName('Rock', ['Rock', 'Rock (importada)'], suffix: '(importada)'),
        'Rock (importada) 2',
      );
      expect(PlaylistOps.uniqueName('   ', []), 'Playlist sin nombre');
    });

    test('Agregar no duplica y cuenta las agregadas', () {
      final (pl, added) = PlaylistOps.addTracks(_pl([_t('a')]), [_t('a'), _t('b'), _t('b')], now);
      expect(_ids(pl), ['a', 'b']);
      expect(added, 1);
    });

    test('Quitar y deshacer deja todo igual; mover reordena', () {
      final pl = _pl([_t('a'), _t('b'), _t('c')]);
      final removed = PlaylistOps.removeAt(pl, 1, now);
      expect(_ids(removed), ['a', 'c']);
      expect(_ids(PlaylistOps.insertAt(removed, 1, _t('b'), now)), ['a', 'b', 'c']);
      expect(_ids(PlaylistOps.move(pl, 2, 0, now)), ['c', 'a', 'b']);
      expect(identical(PlaylistOps.move(pl, 0, 9, now), pl), isTrue);
    });

    test('Una playlist se guarda y se lee igual', () {
      final restored = Playlist.fromJson(_pl([_t('a'), _t('x', source: TrackSource.local)]).toJson());
      expect(_ids(restored), ['a', 'x']);
      expect(restored.tracks.last.audioUrl, '/m/x.mp3');
    });
  });

  test('Las playlists se guardan, se renombran y se recuperan al reabrir', () async {
    final dir = await Directory.systemTemp.createTemp('kiji_playlists_');
    addTearDown(() => dir.delete(recursive: true));

    final first = ProviderContainer(overrides: [
      playlistsProvider.overrideWith(() => PlaylistsNotifier(directory: () async => dir)),
    ]);
    first.read(playlistsProvider);
    await first.read(playlistsProvider.notifier).loaded;
    final notifier = first.read(playlistsProvider.notifier);
    final rock = notifier.create('Rock', tracks: [_t('a')]);
    notifier.create('Rock'); // mismo nombre: no pisa
    notifier.rename(rock.id, 'Rock clásico');
    notifier.addTracks(rock.id, [_t('b')]);
    await notifier.flush();
    first.dispose();

    final second = ProviderContainer(overrides: [
      playlistsProvider.overrideWith(() => PlaylistsNotifier(directory: () async => dir)),
    ]);
    addTearDown(second.dispose);
    second.read(playlistsProvider);
    await second.read(playlistsProvider.notifier).loaded;
    final lists = second.read(playlistsProvider);
    expect(lists.map((pl) => pl.name), ['Rock clásico', 'Rock 2']);
    expect(_ids(lists.first), ['a', 'b']);

    // Borrar y deshacer.
    final removed = second.read(playlistsProvider.notifier).delete(lists.first.id)!;
    expect(second.read(playlistsProvider), hasLength(1));
    second.read(playlistsProvider.notifier).restore(removed.$1, removed.$2);
    expect(second.read(playlistsProvider).first.name, 'Rock clásico');
  });

  group('Listas inteligentes', () {
    HistoryEntry played(Track t, {required int count, required Duration ago}) =>
        HistoryEntry(track: t, lastPlayed: now.subtract(ago), playCount: count);

    final inputs = SmartListInputs(
      now: now,
      liked: [_t('fav-reciente'), _t('fav-vieja'), _t('fav-nunca')],
      history: [
        played(_t('fav-reciente'), count: 2, ago: const Duration(days: 2)),
        played(_t('fav-vieja'), count: 9, ago: const Duration(days: 40)),
        played(_t('x', source: TrackSource.local), count: 1, ago: const Duration(hours: 1)),
      ],
      local: [_t('x', source: TrackSource.local), _t('y', source: TrackSource.local)],
      downloaded: [_t('d')],
    );

    test('Favoritas olvidadas: con ♥ y sin escuchar hace más de un mes (o nunca)', () {
      expect(SmartList.forgottenFavorites.compute(inputs).map((t) => t.title), ['fav-vieja', 'fav-nunca']);
    });

    test('Más escuchadas, recientes, nunca escuchadas y descargadas', () {
      expect(SmartList.mostPlayed.compute(inputs).first.title, 'fav-vieja');
      expect(SmartList.recent.compute(inputs).first.title, 'x');
      expect(SmartList.neverPlayed.compute(inputs).map((t) => t.title), ['y']);
      expect(SmartList.downloaded.compute(inputs).map((t) => t.title), ['d']);
      expect(SmartList.liked.compute(inputs), hasLength(3));
    });

    test('Cada regla se puede leer', () {
      for (final list in SmartList.values) {
        expect(list.rule, isNotEmpty);
        expect(list.rule.endsWith('.'), isTrue);
      }
    });
  });
}
