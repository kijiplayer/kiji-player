// Qué audios del teléfono son música (Biblioteca). Datos inventados.
import 'package:flutter_test/flutter_test.dart';
import 'package:kiji_player/features/local_library/domain/local_exclusions.dart';
import 'package:kiji_player/features/local_library/domain/music_filter.dart';
import 'package:kiji_player/features/settings/domain/app_settings.dart';

const _root = '/storage/emulated/0';

AudioCandidate _a(String path, {String? artist = 'Grupo Inventado', bool? music = true, bool? rec, int ms = 200000}) =>
    AudioCandidate(path: '$_root/$path', artist: artist, isMusic: music, isRecording: rec, durationMs: ms);

List<String> _keptPaths(List<AudioCandidate> all, MusicFilterResult r) =>
    [for (final i in r.kept) all[i].path.substring(_root.length + 1)];

void main() {
  test('1. Base: solo lo que Android marca como música y dura 30 s o más', () {
    final all = [
      _a('Music/cancion.mp3'),
      _a('Music/no-musica.mp3', music: false),
      _a('Music/tono-corto.mp3', ms: 12000),
      _a('Music/sin-duracion.mp3', ms: 0), // no se sabe: se deja
    ];
    final r = filterMusic(all);
    expect(_keptPaths(all, r), ['Music/cancion.mp3', 'Music/sin-duracion.mp3']);
    expect(r.skipped[MusicSkip.system], 2);
  });

  test('2. Carpetas que nunca son música, fuera por defecto', () {
    final all = [
      _a('Recordings/grabacion.m4a'),
      _a('Voice Recorder/nota.m4a'),
      _a('Call/llamada.m4a'),
      _a('Ringtones/tono.mp3'),
      _a('Notifications/aviso.ogg'),
      _a('Alarms/alarma.mp3'),
      _a('Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Audio/audio.opus'),
      _a('Telegram/Telegram Audio/audio.ogg'),
      _a('Music/Album/cancion.mp3'),
    ];
    final r = filterMusic(all);
    expect(_keptPaths(all, r), ['Music/Album/cancion.mp3']);
    expect(r.skipped[MusicSkip.system], 3, reason: 'tonos, avisos y alarmas');
    expect(r.skipped[MusicSkip.voice], 5, reason: 'grabaciones, llamadas y mensajería');
  });

  test('3. Interruptor por carpeta: ocultar no borra, y se puede volver a mostrar', () {
    final all = [_a('Music/A/uno.mp3'), _a('Music/A/dos.mp3'), _a('Music/B/tres.mp3')];
    final hidden = filterMusic(all, choices: {'$_root/Music/A': false});
    expect(_keptPaths(all, hidden), ['Music/B/tres.mp3']);
    expect(hidden.skipped[MusicSkip.hiddenFolder], 2);
    final a = hidden.folders.firstWhere((f) => f.name == 'A');
    expect((a.total, a.shown), (2, false), reason: 'sigue en la lista para volver a prenderla');
    final shownAgain = filterMusic(all, choices: {'$_root/Music/A': true});
    expect(_keptPaths(all, shownAgain), hasLength(3));
  });

  test('4. Valor inicial: se muestra si la mayoría tiene artista (Download con grabaciones, oculta)', () {
    final all = [
      // Como en el teléfono de David: Download con audios sin etiquetas.
      for (var i = 0; i < 5; i++) _a('Download/audio$i.mp3', artist: '<unknown>'),
      _a('Download/cancion-con-datos.mp3'),
      // Música de verdad.
      for (var i = 0; i < 3; i++) _a('Music/Album/c$i.mp3'),
    ];
    final r = filterMusic(all);
    final download = r.folders.firstWhere((f) => f.name == 'Download');
    expect((download.total, download.withArtist, download.shown), (6, 1, false));
    expect(r.folders.firstWhere((f) => f.name == 'Album').shown, isTrue);
    expect(_keptPaths(all, r), hasLength(3), reason: 'ninguna canción de Música desaparece');
    // Un toque la prende (y la canción bien etiquetada vuelve con todo lo de la carpeta).
    final on = filterMusic(all, choices: {'$_root/Download': true});
    expect(_keptPaths(all, on), hasLength(9));
  });

  test('La elección se guarda en los ajustes y cambia la clave (la Biblioteca se vuelve a leer)', () {
    const before = AppSettings();
    final after = before.copyWith(musicFolderChoices: {'$_root/Download': true});
    expect(AppSettings.fromJson(after.toJson()).musicFolderChoices, {'$_root/Download': true});
    expect(after.localExclusions.key, isNot(before.localExclusions.key));
    expect(LocalExclusions.defaultFolders, containsAll(['Recordings', 'Voice Recorder', 'Call', 'WhatsApp', 'Telegram']));
  });
}
