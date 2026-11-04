import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiji_player/features/downloads/data/downloads_repository.dart';
import 'package:kiji_player/features/downloads/domain/downloaded_track.dart';
import 'package:kiji_player/features/lyrics/data/lyrics_repository.dart';
import 'package:kiji_player/features/lyrics/data/lyrics_sources.dart';
import 'package:kiji_player/features/lyrics/domain/lyrics.dart';

// Letras inventadas (nunca letras reales).

class _Fake implements LyricsFetcher {
  _Fake(this.source, this.lyrics);
  @override
  final LyricsSource source;
  final Lyrics? lyrics;
  int calls = 0;
  @override
  Future<Lyrics?> fetch(LyricsRequest request) async {
    calls++;
    return lyrics;
  }
}

const LyricsRequest _request = (
  id: 'yt-inventado',
  title: 'Canción inventada',
  artist: 'Grupo Inventado',
  album: null,
  durationMs: 180000,
  localPath: null,
);

void main() {
  test('La letra como .lrc va y vuelve igual: fuente, líneas, palabras, texto simple e instrumental', () {
    final synced = Lyrics(
      synced: parseLrc('[00:01.00]<00:01.00>Uno <00:01.50>dos<00:02.00>\n[00:03.20]Tres sin palabras'),
      source: LyricsSource.betterlyrics,
    );
    final back = lyricsFromLrcFile(lyricsToLrc(synced))!;
    expect(back.source, LyricsSource.betterlyrics);
    expect(back.synced.map((l) => (l.time, l.text)), synced.synced.map((l) => (l.time, l.text)));
    expect(back.synced.first.words.map((w) => (w.start, w.text, w.end)),
        synced.synced.first.words.map((w) => (w.start, w.text, w.end)));

    final plain = lyricsFromLrcFile(lyricsToLrc(const Lyrics(plain: 'Texto simple\ninventado', source: LyricsSource.youtubeMusic)))!;
    expect(plain.plain, 'Texto simple\ninventado');
    expect(plain.source, LyricsSource.youtubeMusic);

    expect(lyricsFromLrcFile(lyricsToLrc(const Lyrics(instrumental: true)))!.instrumental, isTrue);
    // Un .lrc de otro lado (sin la etiqueta de Kiji) también se lee.
    expect(lyricsFromLrcFile('[00:05.00]Línea suelta')!.synced.single.text, 'Línea suelta');
  });

  test('La letra se guarda junto a la descarga y se borra con ella', () async {
    final dir = Directory.systemTemp.createTempSync('kiji_letra_descarga_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final repository = DownloadsRepository(baseDirectory: () async => dir);
    await repository.add(DownloadedTrack(
      videoId: 'inventado',
      title: 'Canción inventada',
      artist: 'Grupo Inventado',
      coverColor: Colors.teal,
      fileName: 'inventado.m4a',
      sizeBytes: 10,
      downloadedAt: DateTime(2026, 11, 1),
    ));
    File(await repository.pathFor('inventado.m4a')).writeAsBytesSync([1]);

    final updated = await repository.saveLyrics('inventado', '[00:01.00]Hola inventada');
    expect(updated?.lyricsFileName, 'inventado.lrc');
    expect(await repository.lyricsFor('inventado'), '[00:01.00]Hola inventada');
    // Queda en el índice.
    expect((await DownloadsRepository(baseDirectory: () async => dir).all())['inventado']?.lyricsFileName,
        'inventado.lrc');

    await repository.remove('inventado');
    expect(File(await repository.pathFor('inventado.lrc')).existsSync(), isFalse);
  });

  test('Sin internet, la letra guardada con la descarga se usa antes que las fuentes', () async {
    final dir = Directory.systemTemp.createTempSync('kiji_letra_offline_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final online = _Fake(LyricsSource.lrclib, const Lyrics(plain: 'De internet', source: LyricsSource.lrclib));
    final repository = LyricsRepository(
      fetchers: [online],
      baseDirectory: () async => dir,
      offline: (request) async => request.id == _request.id
          ? lyricsFromLrcFile('[kiji-source:lrclib]\n[00:02.00]Guardada con la descarga')
          : null,
    );
    final lyrics = await repository.get(_request);
    expect(lyrics.synced.single.text, 'Guardada con la descarga');
    expect(online.calls, 0, reason: 'no hizo falta preguntar a ninguna fuente');
  });
}
