// Que nada se pierda al actualizar (0.9): datos con la forma de la 0.8.6 y de la 0.9 inicial, la
// versión nueva encima, y la copia de seguridad completa. Datos inventados.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/account/data/yt_sync.dart';
import 'package:kiji_player/features/account/domain/yt_session.dart';
import 'package:kiji_player/features/backup/data/backup_service.dart';
import 'package:kiji_player/features/playlists/playlists_provider.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';
import 'package:kiji_player/features/streaks/streaks.dart';
import 'package:kiji_player/models/track.dart';
import 'package:path/path.dart' as p;

Map<String, dynamic> _track(String id, String title) => const Track(
  id: 'x',
  title: '',
  artist: 'Grupo Inventado',
  coverColor: Color(0xFF7C5CFF),
  audioUrl: '',
  source: TrackSource.youtube,
).toJson()..addAll({'id': 'yt-$id', 'title': title});

class _Settings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings(ytSync: true);
  @override
  Future<AppSettings> get loaded async => state;
}

class _NoReader implements YtAccountReader {
  @override
  Future<Map<String, dynamic>?> browse(String browseId, YtSession session) async => null;
  @override
  Future<Map<String, dynamic>?> continuation(String token, YtSession session) async => null;
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('kiji_migra_'));
  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows a veces tarda en soltar un archivo: la carpeta temporal se borra sola después.
    }
  });

  void write(String name, Object json) => File(p.join(dir.path, name)).writeAsStringSync(jsonEncode(json));

  ProviderContainer open() {
    final c = ProviderContainer(overrides: [
      settingsProvider.overrideWith(_Settings.new),
      ytAccountReaderProvider.overrideWithValue(_NoReader()),
      ytSyncProvider.overrideWith(() => YtSyncNotifier(directory: () async => dir)),
      playlistsProvider.overrideWith(() => PlaylistsNotifier(directory: () async => dir)),
      streaksProvider.overrideWith(() => StreaksNotifier(directory: () async => dir.path)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('Datos de la 0.8.6 → 0.9: las playlists leídas de YouTube quedan vinculadas y las de Kiji, igual', () async {
    // 0.8.6: las playlists de Kiji sin vínculo y lo leído de la cuenta (solo lectura).
    write('playlists.json', {
      'playlists': [
        {'id': 'k1', 'name': 'Mía', 'tracks': [_track('aaaaaaaaaaa', 'Glass Harbor')], 'createdAt': 1, 'updatedAt': 1},
      ],
    });
    write('yt_sync.json', {
      'syncedAt': '2026-11-20T10:00:00.000',
      'playlists': [
        {'id': 'PLvieja', 'name': 'De la Cuenta', 'tracks': [_track('bbbbbbbbbbb', 'Slow Comet')]},
      ],
    });
    final c = open();
    c.read(ytSyncProvider);
    await c.read(playlistsProvider.notifier).loaded;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final all = c.read(playlistsProvider);
    expect(all.singleWhere((pl) => pl.id == 'k1').yt, isNull, reason: 'la de Kiji sigue siendo de Kiji');
    final linked = all.singleWhere((pl) => pl.yt?.id == 'PLvieja');
    expect(linked.name, 'De la Cuenta');
    expect(linked.yt!.base, ['bbbbbbbbbbb']);
    await c.read(playlistsProvider.notifier).flush();
  });

  test('0.9 → 0.9 actualizada: la racha (formato viejo) y los vínculos con cambios sin subir siguen', () async {
    final days = [for (var i = 0; i < 8; i++) dayKey(DateTime(2026, 11, 20 + i))];
    write('streaks.json', days); // la 0.9 inicial guardaba solo la lista
    write('playlists.json', {
      'playlists': [
        {
          'id': 'y1',
          'name': 'De la Cuenta',
          // Una canción agregada en Kiji y todavía no mandada a YouTube.
          'tracks': [_track('bbbbbbbbbbb', 'Slow Comet'), _track('kkkkkkkkkkk', 'Paper Lanterns')],
          'createdAt': 1,
          'updatedAt': 2,
          'yt': {'id': 'PLcuenta', 'base': ['bbbbbbbbbbb']},
        },
      ],
    });
    final c = open();
    final streaks = c.read(streaksProvider.notifier);
    await streaks.loaded;
    expect(c.read(streaksProvider).days, days.toSet());
    expect(c.read(streaksProvider).best, 8);
    expect(c.read(streaksProvider).achievements.keys, containsAll([3, 7]));
    await c.read(playlistsProvider.notifier).loaded;
    final pl = c.read(playlistsProvider).single;
    expect(pl.yt!.id, 'PLcuenta');
    expect(pl.yt!.base, ['bbbbbbbbbbb']);
    expect(pl.tracks.map((t) => t.youtubeVideoId), ['bbbbbbbbbbb', 'kkkkkkkkkkk'], reason: 'el cambio sin subir sigue ahí');
    expect(pl.yt!.base, isNot(contains('kkkkkkkkkkk')), reason: 'se sabe que falta mandarla');
  });

  test('La copia de seguridad completa lleva la racha y la sincronización, y al restaurar vuelven', () async {
    write('streaks.json', {'version': 2, 'days': ['2026-11-26'], 'best': 30, 'achievements': {'30': '2026-10-01'}});
    write('yt_sync.json', {'syncedAt': '2026-11-27T10:00:00.000', 'playlists': []});
    write('playlists.json', {
      'playlists': [
        {'id': 'y1', 'name': 'De la Cuenta', 'tracks': [], 'createdAt': 1, 'updatedAt': 1, 'yt': {'id': 'PLc', 'base': []}},
      ],
    });
    final folder = Directory(p.join(dir.path, 'copias'))..createSync();
    final copy = await BackupService(dataDirectory: () async => dir, platform: 'android').create(folder);
    final other = Directory(p.join(dir.path, 'otro'))..createSync();
    await BackupService(dataDirectory: () async => other, platform: 'android').restore(copy, safetyFolder: folder);
    final streaks = StreakData.fromJson(jsonDecode(File(p.join(other.path, 'streaks.json')).readAsStringSync()));
    expect(streaks.best, 30);
    expect(streaks.achievements[30], '2026-10-01');
    expect(File(p.join(other.path, 'yt_sync.json')).existsSync(), isTrue);
    expect(File(p.join(other.path, 'playlists.json')).readAsStringSync(), contains('"PLc"'));
  });
}
