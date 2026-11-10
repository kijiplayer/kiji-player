import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:kiji_player/features/account/data/yt_sync.dart';
import 'package:kiji_player/features/account/domain/yt_session.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';

// Páginas inventadas con la forma de YouTube Music (datos inventados).
Map<String, dynamic> _flex(String text) => {
  'musicResponsiveListItemFlexColumnRenderer': {
    'text': {
      'runs': [
        {'text': text},
      ],
    },
  },
};

Map<String, dynamic> _song(String id, String title, String artist) => {
  'musicResponsiveListItemRenderer': {
    'playlistItemData': {'videoId': id},
    'flexColumns': [_flex(title), _flex(artist)],
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

class _Reader implements YtAccountReader {
  final asked = <String>[];
  bool refuse = false;

  @override
  Future<Map<String, dynamic>?> browse(String browseId, YtSession session) async {
    asked.add(browseId);
    if (refuse) {
      throw DioException(
        requestOptions: RequestOptions(),
        response: Response(requestOptions: RequestOptions(), statusCode: 401),
      );
    }
    return switch (browseId) {
      'FEmusic_liked_videos' => {
        'contents': [_song('aaaaaaaaaaa', 'Glass Harbor', 'The Velvet Tides')],
      },
      'FEmusic_liked_playlists' => {
        'contents': [_card('VLLM', 'Me gusta'), _card('VLPLinventada', 'Lista Inventada')],
      },
      'VLPLinventada' => {
        'contents': [_song('bbbbbbbbbbb', 'Slow Comet', 'Aurelio Fen')],
      },
      _ => null,
    };
  }
}

class _Settings extends SettingsNotifier {
  _Settings(this.initial);
  final AppSettings initial;
  @override
  AppSettings build() => initial;
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('kiji_sync_'));
  tearDown(() {
    YtSessionHolder.current = null;
    YtSessionHolder.rejected = false;
    dir.deleteSync(recursive: true);
  });

  ProviderContainer make(_Reader reader, {bool on = true}) {
    final c = ProviderContainer(overrides: [
      ytAccountReaderProvider.overrideWithValue(reader),
      settingsProvider.overrideWith(() => _Settings(AppSettings(ytSync: on))),
      ytSyncProvider.overrideWith(() => YtSyncNotifier(directory: () async => dir)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('Apagado de fábrica, y sin sesión no lee nada', () async {
    expect(const AppSettings().ytSync, isFalse);
    final reader = _Reader();
    YtSessionHolder.current = const YtSession(cookie: 'SAPISID=inventada');
    expect(await make(reader, on: false).read(ytSyncProvider.notifier).syncNow(), isFalse);
    YtSessionHolder.current = null;
    expect(await make(reader).read(ytSyncProvider.notifier).syncNow(), isFalse);
    expect(reader.asked, isEmpty);
  });

  test('Con sesión y prendido: lee "Me gusta" y las playlists (solo lectura) y lo guarda en el dispositivo', () async {
    YtSessionHolder.current = const YtSession(cookie: 'SAPISID=inventada');
    final reader = _Reader();
    final c = make(reader);
    expect(await c.read(ytSyncProvider.notifier).syncNow(), isTrue);
    final state = c.read(ytSyncProvider);
    expect(state.liked.single.title, 'Glass Harbor');
    expect(state.playlists.single.name, 'Lista Inventada');
    expect(state.playlists.single.tracks.single.title, 'Slow Comet');
    expect(reader.asked, isNot(contains('VLLM')), reason: '"Me gusta" va aparte');
    expect(File(p.join(dir.path, 'yt_sync.json')).existsSync(), isTrue);
    // Apagarlo borra lo leído.
    await c.read(ytSyncProvider.notifier).forget();
    expect(c.read(ytSyncProvider).isEmpty, isTrue);
    expect(File(p.join(dir.path, 'yt_sync.json')).existsSync(), isFalse);
  });

  test('Si la sesión vence (401), sigue como invitado sin romper nada', () async {
    YtSessionHolder.current = const YtSession(cookie: 'SAPISID=inventada');
    final reader = _Reader()..refuse = true;
    final c = make(reader);
    expect(await c.read(ytSyncProvider.notifier).syncNow(), isFalse);
    expect(YtSessionHolder.rejected, isTrue);
    expect(YtSessionHolder.usable, isNull, reason: 'los pedidos siguen sin la cuenta');
    expect(c.read(ytSyncProvider).syncing, isFalse);
  });
}
