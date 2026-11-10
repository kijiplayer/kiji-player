import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../models/track.dart';
import '../../../utils/json_file.dart';
import '../../favorites/favorites.dart';

/// Las reacciones de una canción: tomates (abucheos) y rosas (aplausos).
@immutable
class TheaterEntry {
  const TheaterEntry({required this.id, required this.title, required this.artist, this.tomatoes = 0, this.roses = 0});

  final String id;
  final String title;
  final String artist;
  final int tomatoes;
  final int roses;

  TheaterEntry copyWith({int? tomatoes, int? roses}) =>
      TheaterEntry(id: id, title: title, artist: artist, tomatoes: tomatoes ?? this.tomatoes, roses: roses ?? this.roses);

  Map<String, dynamic> toJson() => {'title': title, 'artist': artist, 'tomatoes': tomatoes, 'roses': roses};

  static TheaterEntry? fromJson(String id, Object? json) {
    if (json is! Map || json['title'] is! String) return null;
    int count(Object? v) => v is int && v > 0 ? v : 0;
    return TheaterEntry(
      id: id,
      title: json['title'] as String,
      artist: json['artist'] is String ? json['artist'] as String : '',
      tomatoes: count(json['tomatoes']),
      roses: count(json['roses']),
    );
  }
}

/// Todo el teatro: las canciones y cuántos tomates cayeron cada día ("aaaa-mm-dd").
@immutable
class TheaterState {
  const TheaterState({this.songs = const {}, this.tomatoDays = const {}});

  final Map<String, TheaterEntry> songs;
  final Map<String, int> tomatoDays;

  /// Con estos tomates una canción se saltea y deja de recomendarse.
  static const tomatoLimit = 3;

  /// Canciones que ya no se recomiendan (3 tomates o más).
  Set<String> get booedOff => {
    for (final e in songs.values)
      if (e.tomatoes >= tomatoLimit) e.id,
  };

  int get totalTomatoes => songs.values.fold(0, (sum, e) => sum + e.tomatoes);
  int get totalRoses => songs.values.fold(0, (sum, e) => sum + e.roses);
  bool get isEmpty => totalTomatoes == 0 && totalRoses == 0;

  List<TheaterEntry> topTomatoes([int count = 5]) =>
      (songs.values.where((e) => e.tomatoes > 0).toList()..sort((a, b) => b.tomatoes.compareTo(a.tomatoes))).take(count).toList();

  List<TheaterEntry> topRoses([int count = 5]) =>
      (songs.values.where((e) => e.roses > 0).toList()..sort((a, b) => b.roses.compareTo(a.roses))).take(count).toList();

  /// El artista con más tomates (y cuántos), o null.
  (String, int)? get mostBooedArtist {
    final byArtist = <String, int>{};
    for (final e in songs.values) {
      if (e.tomatoes > 0 && e.artist.isNotEmpty) byArtist[e.artist] = (byArtist[e.artist] ?? 0) + e.tomatoes;
    }
    if (byArtist.isEmpty) return null;
    final top = byArtist.entries.reduce((a, b) => b.value > a.value ? b : a);
    return (top.key, top.value);
  }

  /// El día con más tomates (y cuántos), o null.
  (DateTime, int)? get worstDay {
    if (tomatoDays.isEmpty) return null;
    final top = tomatoDays.entries.reduce((a, b) => b.value > a.value ? b : a);
    final day = DateTime.tryParse(top.key);
    return day == null ? null : (day, top.value);
  }
}

/// Qué pasó con un tomate: si ya van [TheaterState.tomatoLimit], la canción se saltea.
enum TomatoResult { counted, booedOff }

String _day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// "Reacciones de teatro": tomates y rosas por canción. Todo queda solo en el dispositivo
/// (`theater.json`, que entra en la copia de seguridad).
class TheaterNotifier extends Notifier<TheaterState> {
  TheaterNotifier({Future<Directory> Function()? directory, DateTime Function()? clock})
    : _directory = directory ?? getApplicationSupportDirectory,
      _clock = clock ?? DateTime.now;

  final Future<Directory> Function() _directory;
  final DateTime Function() _clock;
  JsonFile? _file;

  Future<JsonFile> _json() async => _file ??= JsonFile(p.join((await _directory()).path, 'theater.json'), logTag: 'TEATRO');

  /// Se completa cuando se leyó lo guardado.
  final _loaded = Completer<void>();
  Future<void> get loaded => _loaded.future;

  @override
  TheaterState build() {
    unawaited(_load());
    return const TheaterState();
  }

  Future<void> _load() async {
    try {
      final json = await (await _json()).read();
      if (json is Map) {
        final songs = <String, TheaterEntry>{};
        final rawSongs = json['songs'];
        if (rawSongs is Map) {
          for (final e in rawSongs.entries) {
            if (e.key is String) {
              final entry = TheaterEntry.fromJson(e.key as String, e.value);
              if (entry != null) songs[entry.id] = entry;
            }
          }
        }
        final days = <String, int>{
          if (json['tomatoDays'] case final Map raw)
            for (final e in raw.entries)
              if (e.key is String && e.value is int) e.key as String: e.value as int,
        };
        // Lo que se haya sumado mientras se leía, encima.
        state = TheaterState(songs: {...songs, ...state.songs}, tomatoDays: {...days, ...state.tomatoDays});
      }
    } catch (error) {
      debugPrint('=== TEATRO: no se pudo leer: ${error.runtimeType} ===');
    } finally {
      if (!_loaded.isCompleted) _loaded.complete();
    }
  }

  Future<void> _save() async {
    try {
      await (await _json()).write({
        'version': 1,
        'songs': {for (final e in state.songs.values) e.id: e.toJson()},
        'tomatoDays': state.tomatoDays,
      });
    } catch (error) {
      debugPrint('=== TEATRO: no se pudo guardar: ${error.runtimeType} ===');
    }
  }

  TheaterEntry _entry(Track track) =>
      state.songs[track.id] ?? TheaterEntry(id: track.id, title: track.title, artist: track.artist);

  /// 🍅 a [track]. Con el tercero, la canción se saltea y deja de recomendarse.
  TomatoResult tomato(Track track) {
    final entry = _entry(track).copyWith(tomatoes: _entry(track).tomatoes + 1);
    final day = _day(_clock());
    state = TheaterState(
      songs: {...state.songs, track.id: entry},
      tomatoDays: {...state.tomatoDays, day: (state.tomatoDays[day] ?? 0) + 1},
    );
    unawaited(_save());
    debugPrint('=== TEATRO: tomate (${entry.tomatoes}) ===');
    return entry.tomatoes >= TheaterState.tomatoLimit ? TomatoResult.booedOff : TomatoResult.counted;
  }

  /// 🌹 a [track]: aplausos, y cuenta como "me gusta".
  void rose(Track track) {
    final entry = _entry(track).copyWith(roses: _entry(track).roses + 1);
    state = TheaterState(songs: {...state.songs, track.id: entry}, tomatoDays: state.tomatoDays);
    unawaited(_save());
    if (!ref.read(favoritesProvider).containsKey(track.id)) ref.read(favoritesProvider.notifier).toggle(track);
    debugPrint('=== TEATRO: rosa (${entry.roses}) ===');
  }

  /// "Perdonar" una canción: vuelve a 0 tomates (se puede recomendar otra vez).
  void forgive(String id) {
    final entry = state.songs[id];
    if (entry == null) return;
    state = TheaterState(songs: {...state.songs, id: entry.copyWith(tomatoes: 0)}, tomatoDays: state.tomatoDays);
    unawaited(_save());
  }
}

final theaterProvider = NotifierProvider<TheaterNotifier, TheaterState>(TheaterNotifier.new);
