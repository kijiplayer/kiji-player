// Sincronizar con YouTube Music de ida y vuelta (0.9), con respuestas simuladas: nada sale de la
// PC. Datos inventados.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/account/data/yt_sync.dart';
import 'package:kiji_player/features/account/domain/yt_playlist_merge.dart';
import 'package:kiji_player/features/account/domain/yt_session.dart';
import 'package:kiji_player/features/playlists/domain/playlist.dart';
import 'package:kiji_player/features/playlists/playlists_provider.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/features/yt_music/data/ytm_browse_parser.dart';
import 'package:kiji_player/models/track.dart';

Map<String, dynamic> _flex(String text) => {
  'musicResponsiveListItemFlexColumnRenderer': {
    'text': {
      'runs': [
        {'text': text},
      ],
    },
  },
};

Map<String, dynamic> _row(String id) => {
  'musicResponsiveListItemRenderer': {
    'playlistItemData': {'videoId': id, 'playlistSetVideoId': 'set-$id'},
    'flexColumns': [_flex('Canción $id'), _flex('Grupo Inventado')],
  },
};

Map<String, dynamic> _card(String browseId, String title) => {
  'musicTwoRowItemRenderer': {
    'title': {
      'runs': [
        {'text': title},
      ],
    },
    'navigationEndpoint': {
      'browseEndpoint': {'browseId': browseId},
    },
  },
};

/// La cuenta inventada: playlists y sus videos (ids de 11 letras).
class _Account implements YtAccountReader, YtAccountWriter {
  final playlists = <String, List<String>>{'PLmia': ['aaaaaaaaaaa', 'bbbbbbbbbbb']};
  final names = <String, String>{'PLmia': 'Lista Mía'};
  final notMine = <String>{};
  final sent = <(String, List<Map<String, dynamic>>)>[];
  bool failWrites = false;

  @override
  Future<Map<String, dynamic>?> browse(String browseId, YtSession session) async {
    if (browseId == 'FEmusic_liked_playlists') {
      return {
        'contents': [for (final id in playlists.keys) _card('VL$id', names[id]!)],
      };
    }
    if (browseId.startsWith('VL') && playlists.containsKey(browseId.substring(2))) {
      final id = browseId.substring(2);
      return {
        if (!notMine.contains(id)) 'header': {'musicEditablePlaylistDetailHeaderRenderer': {}},
        'contents': [for (final v in playlists[id]!) _row(v)],
      };
    }
    return {'contents': []};
  }

  @override
  Future<Map<String, dynamic>?> continuation(String token, YtSession session) async => null;

  @override
  Future<bool> editPlaylist(String playlistId, List<Map<String, dynamic>> actions, YtSession session) async {
    if (failWrites) throw DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError);
    sent.add((playlistId, actions));
    final list = playlists[playlistId]!;
    for (final a in actions) {
      if (a['action'] == 'ACTION_ADD_VIDEO') list.add(a['addedVideoId'] as String);
      if (a['action'] == 'ACTION_REMOVE_VIDEO') list.remove(a['removedVideoId'] as String);
    }
    return true;
  }
}

class _Settings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings(ytSync: true);
}

Track _t(String id) => Track(
  id: 'yt-$id',
  title: 'Canción $id',
  artist: 'Grupo Inventado',
  coverColor: const Color(0xFF7C5CFF),
  audioUrl: '',
  source: TrackSource.youtube,
);

void main() {
  group('Juntar Kiji y YouTube', () {
    test('Lo agregado en Kiji se manda; lo agregado en YouTube se trae', () {
      final m = mergeYtPlaylist(base: ['a', 'b'], local: ['a', 'b', 'k'], remote: ['a', 'b', 'y']);
      expect(m.toAdd, ['k']);
      expect(m.toRemove, isEmpty);
      expect(m.result, ['a', 'b', 'y', 'k']);
      expect(m.conflict, isTrue, reason: 'cambió en los dos lados: se avisa');
    });

    test('Lo quitado en Kiji se quita en YouTube; lo quitado en YouTube se va de Kiji', () {
      final m = mergeYtPlaylist(base: ['a', 'b', 'c'], local: ['a', 'c'], remote: ['a', 'b']);
      expect(m.toRemove, ['b']);
      expect(m.result, ['a']);
    });

    test('Sin cambios en Kiji no se manda nada', () {
      final m = mergeYtPlaylist(base: ['a'], local: ['a'], remote: ['a', 'y']);
      expect(m.needsPush, isFalse);
      expect(m.conflict, isFalse);
      expect(m.result, ['a', 'y']);
    });

    test('Una playlist de otra persona: no se le manda nada, lo de Kiji queda en Kiji', () {
      final m = mergeYtPlaylist(base: ['a'], local: ['a', 'k'], remote: ['a'], editable: false);
      expect(m.needsPush, isFalse);
      expect(m.result, ['a', 'k']);
    });
  });

  test('El lector encuentra el setVideoId y si la playlist es editable', () {
    final page = {
      'header': {'musicEditablePlaylistDetailHeaderRenderer': {}},
      'contents': [_row('aaaaaaaaaaa')],
    };
    expect(parsePlaylistSetVideoIds(page), {'aaaaaaaaaaa': 'set-aaaaaaaaaaa'});
    expect(isEditablePlaylist(page), isTrue);
    expect(isEditablePlaylist({'contents': []}), isFalse);
  });

  group('Sincronizar', () {
    late Directory dir;
    late _Account account;
    late ProviderContainer c;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('kiji_sync2_');
      account = _Account();
      YtSessionHolder.current = const YtSession(cookie: 'SAPISID=inventada');
      c = ProviderContainer(overrides: [
        ytAccountReaderProvider.overrideWithValue(account),
        ytAccountWriterProvider.overrideWithValue(account),
        settingsProvider.overrideWith(_Settings.new),
        ytSyncProvider.overrideWith(() => YtSyncNotifier(directory: () async => dir)),
        playlistsProvider.overrideWith(() => PlaylistsNotifier(directory: () async => dir)),
      ]);
    });
    tearDown(() async {
      // Que termine de guardar antes de borrar la carpeta.
      await c.read(playlistsProvider.notifier).flush();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      c.dispose();
      YtSessionHolder.current = null;
      dir.deleteSync(recursive: true);
    });

    Playlist linked() => c.read(playlistsProvider).singleWhere((pl) => pl.yt?.id == 'PLmia');
    List<String?> videos() => [for (final t in linked().tracks) t.youtubeVideoId];

    test('La primera vez la trae como playlist de Kiji, vinculada', () async {
      expect(await c.read(ytSyncProvider.notifier).syncNow(), isTrue);
      expect(linked().name, 'Lista Mía');
      expect(videos(), ['aaaaaaaaaaa', 'bbbbbbbbbbb']);
      expect(linked().yt!.editable, isTrue);
      expect(account.sent, isEmpty, reason: 'leer no escribe nada');
    });

    test('Lo que se agrega y quita en Kiji llega a YouTube al sincronizar (y no antes)', () async {
      await c.read(ytSyncProvider.notifier).syncNow();
      final store = c.read(playlistsProvider.notifier);
      store.addTracks(linked().id, [_t('kkkkkkkkkkk')]);
      store.removeTrackAt(linked().id, 0);
      expect(account.sent, isEmpty, reason: 'nada se manda hasta tocar «Sincronizar»');

      await c.read(ytSyncProvider.notifier).syncNow();
      expect(account.playlists['PLmia'], ['bbbbbbbbbbb', 'kkkkkkkkkkk']);
      final actions = account.sent.single.$2;
      expect(actions, contains(containsPair('addedVideoId', 'kkkkkkkkkkk')));
      expect(actions, contains(allOf(containsPair('removedVideoId', 'aaaaaaaaaaa'), containsPair('setVideoId', 'set-aaaaaaaaaaa'))));
      expect(c.read(ytSyncProvider).sent, 2);
      expect(videos(), ['bbbbbbbbbbb', 'kkkkkkkkkkk']);

      // Otra vez, sin cambios: no se manda nada más.
      await c.read(ytSyncProvider.notifier).syncNow();
      expect(account.sent, hasLength(1));
    });

    test('Si cambió en los dos lados se juntan los cambios y se avisa', () async {
      await c.read(ytSyncProvider.notifier).syncNow();
      c.read(playlistsProvider.notifier).addTracks(linked().id, [_t('kkkkkkkkkkk')]);
      account.playlists['PLmia']!.add('yyyyyyyyyyy');
      await c.read(ytSyncProvider.notifier).syncNow();
      expect(videos(), ['aaaaaaaaaaa', 'bbbbbbbbbbb', 'yyyyyyyyyyy', 'kkkkkkkkkkk']);
      expect(account.playlists['PLmia'], ['aaaaaaaaaaa', 'bbbbbbbbbbb', 'yyyyyyyyyyy', 'kkkkkkkkkkk']);
      expect(c.read(ytSyncProvider).merged, ['Lista Mía']);
    });

    test('Si YouTube no responde al mandar, lo de Kiji se guarda y se manda la próxima vez', () async {
      await c.read(ytSyncProvider.notifier).syncNow();
      c.read(playlistsProvider.notifier).addTracks(linked().id, [_t('kkkkkkkkkkk')]);
      account.failWrites = true;
      await c.read(ytSyncProvider.notifier).syncNow();
      expect(videos(), contains('kkkkkkkkkkk'), reason: 'no se pierde');
      expect(account.playlists['PLmia'], isNot(contains('kkkkkkkkkkk')));
      account.failWrites = false;
      await c.read(ytSyncProvider.notifier).syncNow();
      expect(account.playlists['PLmia'], contains('kkkkkkkkkkk'));
    });

    test('La lectura automática (al abrir Kiji) no manda nada: lo de Kiji queda para «Sincronizar»', () async {
      await c.read(ytSyncProvider.notifier).syncNow();
      c.read(playlistsProvider.notifier).addTracks(linked().id, [_t('kkkkkkkkkkk')]);
      await c.read(ytSyncProvider.notifier).syncNow(push: false);
      expect(account.sent, isEmpty);
      expect(videos(), contains('kkkkkkkkkkk'));
      await c.read(ytSyncProvider.notifier).syncNow();
      expect(account.playlists['PLmia'], contains('kkkkkkkkkkk'));
    });

    test('Una guardada de otra persona: no se le manda nada', () async {
      account.notMine.add('PLmia');
      await c.read(ytSyncProvider.notifier).syncNow();
      expect(linked().yt!.editable, isFalse);
      c.read(playlistsProvider.notifier).addTracks(linked().id, [_t('kkkkkkkkkkk')]);
      await c.read(ytSyncProvider.notifier).syncNow();
      expect(account.sent, isEmpty);
      expect(videos(), contains('kkkkkkkkkkk'), reason: 'queda en Kiji');
    });

    test('Si ya no está en la cuenta, queda en Kiji sin vínculo; al apagar, las vinculadas se van', () async {
      account.playlists['PLotra'] = ['ccccccccccc'];
      account.names['PLotra'] = 'Otra Lista';
      await c.read(ytSyncProvider.notifier).syncNow();
      expect(c.read(playlistsProvider).where((pl) => pl.yt != null), hasLength(2));
      account.playlists.remove('PLotra');
      await c.read(ytSyncProvider.notifier).syncNow();
      final otra = c.read(playlistsProvider).singleWhere((pl) => pl.name == 'Otra Lista');
      expect(otra.yt, isNull, reason: 'sigue en Kiji como una playlist más');

      await c.read(ytSyncProvider.notifier).forget();
      expect(c.read(playlistsProvider).where((pl) => pl.yt != null), isEmpty);
      expect(c.read(playlistsProvider).where((pl) => pl.name == 'Otra Lista'), hasLength(1));
    });

    test('El vínculo se guarda en el dispositivo y vuelve al abrir', () async {
      await c.read(ytSyncProvider.notifier).syncNow();
      await c.read(playlistsProvider.notifier).flush();
      final again = ProviderContainer(overrides: [
        playlistsProvider.overrideWith(() => PlaylistsNotifier(directory: () async => dir)),
      ]);
      addTearDown(again.dispose);
      again.read(playlistsProvider);
      await again.read(playlistsProvider.notifier).loaded;
      final pl = again.read(playlistsProvider).singleWhere((pl) => pl.yt != null);
      expect(pl.yt!.base, ['aaaaaaaaaaa', 'bbbbbbbbbbb']);
    });
  });
}
