// Apagar la sincronización o cerrar sesión (0.9): si hay cambios sin subir a YouTube Music, se
// pregunta antes con «Sincronizar ahora», «Borrar igual» y «Cancelar». Datos inventados.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/account/data/yt_sync.dart';
import 'package:kiji_player/features/account/presentation/account_screens.dart';
import 'package:kiji_player/features/playlists/domain/playlist.dart';
import 'package:kiji_player/features/playlists/playlists_provider.dart';
import 'package:kiji_player/features/settings/data/settings_store.dart';
import 'package:kiji_player/models/track.dart';
import 'package:kiji_player/theme/app_theme.dart';

Future<Directory> _noDisk() async => throw const FileSystemException('sin disco en el test');

Track _t(String id) => Track(
  id: 'yt-$id',
  title: 'Canción $id',
  artist: 'Grupo Inventado',
  coverColor: const Color(0xFF7C5CFF),
  audioUrl: '',
  source: TrackSource.youtube,
);

class _Playlists extends PlaylistsNotifier {
  _Playlists(this.initial);
  final List<Playlist> initial;
  @override
  List<Playlist> build() => initial;
}

class _Sync extends YtSyncNotifier {
  int syncs = 0;
  @override
  YtSyncState build() => const YtSyncState();
  @override
  Future<bool> syncNow({bool push = true}) async {
    syncs++;
    return true;
  }
}

Playlist _linked({required bool pending}) => Playlist(
  id: 'y1',
  name: 'Lista Mía',
  tracks: [_t('aaaaaaaaaaa'), if (pending) _t('kkkkkkkkkkk')],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  yt: const YtLink(id: 'PLmia', base: ['aaaaaaaaaaa']),
);

void main() {
  late _Sync sync;
  late bool? result;

  Future<void> open(WidgetTester tester, List<Playlist> playlists) async {
    sync = _Sync();
    result = null;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        settingsProvider.overrideWith(() => SettingsNotifier(directory: _noDisk)),
        playlistsProvider.overrideWith(() => _Playlists(playlists)),
        ytSyncProvider.overrideWith(() => sync),
      ],
      child: MaterialApp(
        theme: AppTheme.darkWith(),
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await confirmDropYouTubeCopies(context, ref),
              child: const Text('apagar'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('apagar'));
    await tester.pumpAndSettle();
  }

  testWidgets('Sin cambios sin subir: sigue sin preguntar', (tester) async {
    await open(tester, [_linked(pending: false)]);
    expect(find.byType(AlertDialog), findsNothing);
    expect(result, isTrue);
  });

  testWidgets('Con cambios sin subir: «Cancelar» no sigue', (tester) async {
    await open(tester, [_linked(pending: true)]);
    expect(find.textContaining('Lista Mía'), findsOneWidget);
    await tester.tap(find.byKey(const Key('drop-yt-cancel')));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(sync.syncs, 0);
  });

  testWidgets('«Borrar igual» sigue sin mandar nada', (tester) async {
    await open(tester, [_linked(pending: true)]);
    await tester.tap(find.byKey(const Key('drop-yt-anyway')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(sync.syncs, 0);
  });

  testWidgets('«Sincronizar ahora» manda los cambios y sigue', (tester) async {
    await open(tester, [_linked(pending: true)]);
    await tester.tap(find.byKey(const Key('drop-yt-sync')));
    await tester.pumpAndSettle();
    expect(sync.syncs, 1);
    expect(result, isTrue);
  });
}
