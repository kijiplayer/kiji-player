// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navSearch => 'Search';

  @override
  String get navLibrary => 'Library';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSearchHint => 'Search a setting…';

  @override
  String get errorReportTitle => 'Something went wrong in Kiji';

  @override
  String errorReportBody(String summary) {
    return '$summary.\n\nWould you like to let the developer know? GitHub opens with a report already written, without your name, your files or your accounts. You can read it before sending it.';
  }

  @override
  String get errorReportSend => 'Send to the developer';

  @override
  String get errorReportDownload => 'Download report (.txt)';

  @override
  String get errorReportNoThanks => 'No, thanks';

  @override
  String get estable => 'Stable';

  @override
  String get youtubePuedeLimitarOSuspenderCuentas =>
      'YouTube may limit or suspend accounts used in unofficial apps. We recommend using a secondary account, not your main one.';

  @override
  String get tuSesionSeGuardaCifradaSolo =>
      'Your session is stored encrypted on this device only and is sent only to YouTube. It is never written to Kiji\'s log. Signing out deletes everything. Kiji doesn\'t collect any of your data, signed in or not.';

  @override
  String get cuenta => 'Account';

  @override
  String sesionIniciada(Object? p0) {
    return 'Signed in$p0';
  }

  @override
  String get lasCancionesConRestriccionDeEdad =>
      'Age-restricted songs are requested with your account.';

  @override
  String get iniciarSesionConGoogle => 'Sign in with Google';

  @override
  String get cerrarSesionYBorrarla => 'Sign out and delete session';

  @override
  String get sesionCerradaYBorrada => 'Signed out and session deleted.';

  @override
  String get ofrecerIniciarSesionCuandoUnaCancion =>
      'Offer to sign in when a song needs it';

  @override
  String get comoMuchoUnaVezPorCancion => 'At most once per song.';

  @override
  String get noSePudoCompletarElInicio =>
      'Couldn\'t finish signing in. Please try again.';

  @override
  String get estaCancionNecesitaUnaCuenta => 'This song needs an account';

  @override
  String youtubeMarcoConRestriccionDeEdad(Object? p0, Object? p1) {
    return 'YouTube marked “$p0” as age-restricted and only plays it for signed-in accounts. If you want, you can sign in with Google to play it. It\'s optional.\n\n$p1';
  }

  @override
  String get noVolverAPreguntar => 'Don\'t ask again';

  @override
  String get iniciarSesion => 'Sign in';

  @override
  String get esaEsLaCarpetaDeKiji =>
      'That\'s Kiji\'s folder. Kiji Dev keeps its backups separately: choose another one.';

  @override
  String get kijiNoPuedeGuardarEnEsa =>
      'Kiji can\'t save to that folder. Choose another one.';

  @override
  String noSePudoHacerLaCopia(Object? p0) {
    return 'Couldn\'t create the backup in $p0.';
  }

  @override
  String get elArchivoNoEsUnaCopia =>
      'This file isn\'t a Kiji backup (or it\'s from a newer version).';

  @override
  String get elArchivoEstaDanadoONo =>
      'The file is damaged or isn\'t a Kiji backup.';

  @override
  String get copiaDeSeguridad => 'Backup';

  @override
  String get unaCopiaDeTusPlaylistsMe =>
      'A copy of your playlists, likes, history, settings, custom covers and your download list (without the audio). It\'s your own file, on your device: it never goes to a server. The last 7 are kept.';

  @override
  String get copiaAutomaticaDiaria => 'Daily automatic backup';

  @override
  String ultimaCopia(Object? p0) {
    return 'Last backup: $p0';
  }

  @override
  String get carpeta => 'Folder';

  @override
  String get buscando => 'Searching…';

  @override
  String get cambiar => 'Change';

  @override
  String get volverALaCarpetaDeFabrica => 'Back to the default folder';

  @override
  String get noSePudoHacerLaCopia2 => 'Couldn\'t create the backup';

  @override
  String get hacerUnaCopiaAhora => 'Back up now';

  @override
  String get copias => 'BACKUPS';

  @override
  String get noHayCopiasEnEstaCarpeta => 'There are no backups in this folder.';

  @override
  String get restaurar => 'Restore…';

  @override
  String get restaurarDesdeUnArchivo => 'Restore from a file…';

  @override
  String get porEjemploUnaCopiaDeOtro =>
      'For example, a backup from another phone or from your PC.';

  @override
  String get carpetaParaLasCopiasDeKiji => 'Folder for Kiji backups';

  @override
  String lasCopiasSeVanAGuardar(Object? p0) {
    return 'Backups will be saved in $p0';
  }

  @override
  String get eligeUnaCopiaDeKiji => 'Choose a Kiji backup';

  @override
  String get restaurarEstaCopia => 'Restore this backup?';

  @override
  String get cancelar => 'Cancel';

  @override
  String get restaurar2 => 'Restore';

  @override
  String noSePudoRestaurar(Object? p0) {
    return 'Couldn\'t restore: $p0';
  }

  @override
  String get listoLoQueTeniasAntesQuedo =>
      'Done. What you had before was saved in a “before restoring” backup.';

  @override
  String get volverABajarTusDescargas => 'Download your songs again?';

  @override
  String get cancionesDescargadas => 'downloaded songs';

  @override
  String laCopiaTieneElAudioNo(Object? p0) {
    return 'The backup has $p0. Audio isn\'t included in backups: it can be downloaded again from YouTube (respecting “Wi-Fi only”).';
  }

  @override
  String get ahoraNo => 'Not now';

  @override
  String get volverABajar => 'Download again';

  @override
  String bajandoLasDemasNo(Object? p0, Object? p1) {
    return 'Downloading $p0. Not the rest: $p1';
  }

  @override
  String get deUnCelularAndroid => ' (from an Android phone)';

  @override
  String get deUnaPcConWindows => ' (from a Windows PC)';

  @override
  String get meGusta => 'likes';

  @override
  String get cancion => 'song';

  @override
  String get cancionDescargada => 'downloaded song';

  @override
  String get caratulaPersonalizada => 'custom cover';

  @override
  String get caratulasPersonalizadas => 'custom covers';

  @override
  String copiaEnElHistorialElAudio(
    Object? p0,
    Object? p1,
    Object? p2,
    Object? p3,
    Object? p4,
    Object? p5,
    Object? p6,
    Object? p7,
  ) {
    return 'Backup from $p0 $p1$p2:\n• $p3\n• $p4\n• $p5 in your history\n• $p6 (audio is downloaded again)\n$p7\nIt replaces your current playlists, likes, history and settings. First, Kiji saves a backup of what you have now, so you can go back.';
  }

  @override
  String get noSePudoUsarEsaImagen => 'Couldn\'t use that image.';

  @override
  String get personalizarCancion => 'Customize song';

  @override
  String get soloCambiaComoSeVeEn =>
      'This only changes how it looks in Kiji. The music file isn\'t touched.';

  @override
  String get cambiarFoto => 'Change photo';

  @override
  String get titulo => 'Title';

  @override
  String original(Object? p0) {
    return 'Original: $p0';
  }

  @override
  String get artista => 'Artist';

  @override
  String get listo => 'Done';

  @override
  String get guardar => 'Save';

  @override
  String get volvioAComoEra => 'Back to how it was';

  @override
  String get restaurarOriginal => 'Restore original';

  @override
  String get personalizarPlaylist => 'Customize playlist';

  @override
  String get nombre => 'Name';

  @override
  String get descripcionOpcional => 'Description (optional)';

  @override
  String get color => 'COLOR';

  @override
  String restaurarOriginalSinFotoNiColor(Object? p0) {
    return 'Restore original (“$p0”, no photo or color)';
  }

  @override
  String get eligeUnaFoto => 'Choose a photo';

  @override
  String get noSePudoAbrirEsaImagen => 'Couldn\'t open that image.';

  @override
  String get recortar => 'Crop';

  @override
  String get noSePudoRecortarEsaImagen => 'Couldn\'t crop that image.';

  @override
  String kijiBuscoOtraVersionEnYoutube(Object? p0) {
    return '$p0 Kiji looked for another version on YouTube Music and there isn\'t one.';
  }

  @override
  String get seCortoLaConexionAlReintentar =>
      'The connection dropped. Retrying picks up where it left off.';

  @override
  String get youtubeNoEntregoElAudioCon =>
      'YouTube didn\'t deliver the audio with any of the methods Kiji tried. This usually fixes itself: try again in a while or look for another version.';

  @override
  String get youtubeCortoLaDescargaAMitad =>
      'YouTube cut the download halfway. Retrying will try another method.';

  @override
  String get noQuedaEspacioEnElDispositivo =>
      'There\'s no space left on the device.';

  @override
  String get noSePudoDescargarReintentaEn =>
      'Couldn\'t download. Try again in a while.';

  @override
  String get tieneRestriccionDeEdadYoutubeNo =>
      'It\'s age-restricted: YouTube won\'t allow downloading it without signing in. You can look for another version.';

  @override
  String get youtubeMusicYaNoLaOfrece =>
      'YouTube Music no longer offers it (it was removed or isn\'t available in your country).';

  @override
  String get elVideoEsPrivado => 'The video is private.';

  @override
  String get elVideoFueBorradoDeYoutube =>
      'The video was deleted from YouTube.';

  @override
  String get noEstaDisponibleEnTuPais => 'It isn\'t available in your country.';

  @override
  String get descargadas => 'Downloaded';

  @override
  String get borrarTodas => 'Delete all';

  @override
  String conErrorVerCuales(Object? p0) {
    return '$p0 failed: see which';
  }

  @override
  String get descargando => 'Downloading';

  @override
  String get buscaUnaCancionYTocaEl =>
      'Search for a song and tap the download icon to listen offline.';

  @override
  String get borrarDescarga => 'Delete download';

  @override
  String get borrarTodasLasDescargas => 'Delete all downloads';

  @override
  String get borrarTodasLasDescargas2 => 'Delete all downloads?';

  @override
  String get descargarSoloConWifi => 'Download on Wi-Fi only';

  @override
  String get noUsaTusDatosMoviles => 'Doesn\'t use your mobile data';

  @override
  String get limiteDeEspacio => 'Storage limit';

  @override
  String usadoDe(Object? p0, Object? p1) {
    return 'Used $p0 of $p1';
  }

  @override
  String get descargada => 'Downloaded';

  @override
  String get descargar => 'Download';

  @override
  String get noSePudoDescargarVerPor => 'Couldn\'t download: see why';

  @override
  String get cancelarDescarga => 'Cancel download';

  @override
  String get noSePudoDescargar => 'Couldn\'t download.';

  @override
  String get descargarCancion => 'Download song';

  @override
  String teQuedanLibres(Object? p0) {
    return 'You have $p0 free.';
  }

  @override
  String vaAOcuparSeGuardaDentro(Object? p0, Object? p1, Object? p2) {
    return '“$p0”\n\nIt will take up $p1.\n$p2\n\nIt\'s saved inside Kiji, not in your music folder.';
  }

  @override
  String get cancelarLaDescarga => 'Cancel the download?';

  @override
  String get seBorraLoQueSeHabia =>
      'What was already downloaded for this song will be deleted.';

  @override
  String get seguir => 'Continue';

  @override
  String get borrarLaDescarga => 'Delete the download?';

  @override
  String dejaDeOcuparEspacioSiEsta(Object? p0) {
    return '“$p0” will stop taking up space. If it\'s in your queue, it stays: it will play from the internet again.';
  }

  @override
  String get borrar => 'Delete';

  @override
  String get enEsperaParaDescargar => 'Waiting to download';

  @override
  String get laDescargaFallo => 'The download failed';

  @override
  String porCiento(Object? p0) {
    return ' $p0 percent';
  }

  @override
  String descargando2(Object? p0) {
    return 'Downloading$p0';
  }

  @override
  String get descargandoOtraVez => 'Downloading again…';

  @override
  String get buscarOtraVersion => 'Look for another version';

  @override
  String get noHayOtraVersionDeEsta =>
      'There\'s no other version of this song on YouTube Music.';

  @override
  String get iniciarSesionParaBajarla => 'Sign in to download it';

  @override
  String get reintentarPruebaOtrasFormas => 'Retry (tries other methods)';

  @override
  String get quitarDeLaLista => 'Remove from the list';

  @override
  String noSePudieronDescargar(Object? p0) {
    return '$p0 couldn\'t be downloaded';
  }

  @override
  String get reintentarTodas => 'Retry all';

  @override
  String reintentando(Object? p0) {
    return 'Retrying $p0';
  }

  @override
  String get parlante => 'Speaker';

  @override
  String get auricularesConCable => 'Wired headphones';

  @override
  String get plano => 'Flat';

  @override
  String get masGraves => 'More bass';

  @override
  String get masAgudos => 'More treble';

  @override
  String get voces => 'Vocals';

  @override
  String get electronica => 'Electronic';

  @override
  String get acustica => 'Acoustic';

  @override
  String get clasica => 'Classical';

  @override
  String get nocheSuave => 'Night (soft)';

  @override
  String get ecualizador2 => 'Equalizer';

  @override
  String get enLaPcTodaviaNoHay =>
      'There\'s no equalizer on PC yet: for now it only works on Android. What you choose here is still saved.';

  @override
  String get apagadoElSonidoNoCambia => 'Off: the sound doesn\'t change.';

  @override
  String get unPerfilPorDispositivo => 'One profile per device';

  @override
  String elParlanteLosAuricularesConCable(Object? p0) {
    return 'The speaker, wired headphones and Bluetooth each remember their own profile, and it switches automatically when you connect them. Now playing on: $p0.';
  }

  @override
  String get perfil => 'PROFILE';

  @override
  String get personalizado => 'Custom';

  @override
  String get bandas => 'BANDS';

  @override
  String get enLaPcNoHayBandas => 'There are no bands to adjust on PC yet.';

  @override
  String get sinAlternativa => 'no alternative';

  @override
  String get sinConexion => 'No connection';

  @override
  String get ningunaFormaEstaPudiendoBajarCanciones =>
      'No method can download songs from YouTube right now. Check the Extractor Health.';

  @override
  String get falloLaPruebaDiaria => 'The daily test failed';

  @override
  String elMotorAFallo(Object? p0) {
    return 'Engine A failed ($p0)';
  }

  @override
  String get elMotorANoRespondio => 'Engine A didn\'t respond';

  @override
  String get tieneRestriccionDeEdad => 'It\'s age-restricted';

  @override
  String get youtubeDiceQueNoEstaDisponible =>
      'YouTube says it isn\'t available';

  @override
  String innertubexNoLaReproduce(Object? p0) {
    return 'InnerTubeX can\'t play it ($p0)';
  }

  @override
  String motorA(Object? p0) {
    return 'Engine A: $p0';
  }

  @override
  String get elMotorANoDioUrl => 'Engine A didn\'t return a URL';

  @override
  String laListaHlsNoRespondeHttp(Object? p0) {
    return 'The HLS playlist isn\'t responding (HTTP $p0)';
  }

  @override
  String youtubeNoDijoElTamanoDel(Object? p0) {
    return 'YouTube didn\'t report the audio size (HTTP $p0)';
  }

  @override
  String elUltimoByteNoLlegoHttp(Object? p0) {
    return 'The last byte didn\'t arrive (HTTP $p0)';
  }

  @override
  String noSePudoPedirElUltimo(Object? p0) {
    return 'Couldn\'t request the last byte ($p0)';
  }

  @override
  String get falloLaPrueba => 'The test failed';

  @override
  String get sinAudio => 'No audio';

  @override
  String get todaviaNoSeProbo => 'Not tested yet.';

  @override
  String get cancionesNormalesNingunaFormaFuncionaAho =>
      'Regular songs: ✗ no method works right now';

  @override
  String get conRestriccionDeEdadNecesitanCuenta =>
      'Age-restricted: they need an account (not counted as failures)';

  @override
  String get fallo => 'failed';

  @override
  String get youtubeCortoElAudioAMitad =>
      'YouTube cut the audio halfway through the song';

  @override
  String get youtubePidioConfirmarQueNoEs =>
      'YouTube asked to confirm it\'s not a bot';

  @override
  String get elVideoEsPrivado2 => 'The video is private';

  @override
  String get elVideoFueBorrado => 'The video was deleted';

  @override
  String get estaBloqueadoEnTuPais => 'It\'s blocked in your country';

  @override
  String get sinConexion2 => 'no connection';

  @override
  String get requiereCuentaRestriccionDeEdad =>
      '🔞 Needs an account (age-restricted)';

  @override
  String get noEstaDisponibleEnYoutube => 'Not available on YouTube';

  @override
  String get bloqueadaEnTuPais => 'Blocked in your country';

  @override
  String get motorAInnertubex => 'Engine A · InnerTubeX';

  @override
  String get motorBKiji => 'Engine B · Kiji';

  @override
  String get motorCYtDlp => 'Engine C · yt-dlp';

  @override
  String resolvedstreamKbps(Object? p0, Object? p1, Object? p2) {
    return 'ResolvedStream($p0, $p1 kbps$p2)';
  }

  @override
  String noReconozcoElFormatoDeKiji(Object? p0) {
    return 'I don\'t recognize the format of “$p0”. Kiji reads .backup, .m3u, .m3u8 and .csv.';
  }

  @override
  String get elArchivoDeCopiaDeSeguridad => 'The backup file is damaged.';

  @override
  String get estaCopiaDeSeguridadNoTiene =>
      'This backup doesn\'t have the song database (song.db).';

  @override
  String get noSePudoLeerLaBase =>
      'Couldn\'t read the song database in the backup.';

  @override
  String get laBaseNoTieneElFormato =>
      'The database isn\'t in Echo / Metrolist format.';

  @override
  String laListaNoTieneCanciones(Object? p0) {
    return 'The playlist “$p0” has no songs.';
  }

  @override
  String noTieneCanciones(Object? p0) {
    return '“$p0” has no songs.';
  }

  @override
  String noEncontreColumnasDeCancionesEn(Object? p0) {
    return 'I couldn\'t find song columns in “$p0” (I looked for \"Track Name\", \"Title\" or \"Video ID\").';
  }

  @override
  String seVanACrear(Object? p0) {
    return '$p0 will be created';
  }

  @override
  String sinEncontrar(Object? p0) {
    return '$p0 not found';
  }

  @override
  String enElHistorial(Object? p0) {
    return '$p0 in history';
  }

  @override
  String tambien(Object? p0) {
    return '. Also: $p0';
  }

  @override
  String get artistaDesconocido => 'Unknown artist';

  @override
  String cancionDeYoutube(Object? p0) {
    return 'YouTube song ($p0)';
  }

  @override
  String get eligeElArchivoDeLaOtra => 'Choose the file from the other app';

  @override
  String get elArchivoNoTieneCancionesPara =>
      'The file has no songs to import.';

  @override
  String get noSePudoLeerElArchivo => 'Couldn\'t read the file.';

  @override
  String get importacionDeshechaSeQuitoTodoLo =>
      'Import undone: everything it added was removed.';

  @override
  String get importarYExportar => 'Import and export';

  @override
  String get traeTusPlaylistsMeGustaE =>
      'Bring your playlists, likes and history from Echo Music, Metrolist, InnerTune or OuterTune (.backup), .m3u/.m3u8 playlists, or CSV files from Exportify (Spotify) and Google Takeout (YouTube Music). Before importing you\'ll see what gets added; nothing you already have is deleted or changed.';

  @override
  String get importacionesAnteriores => 'PREVIOUS IMPORTS';

  @override
  String playlistsSinEncontrar(Object? p0, Object? p1, Object? p2) {
    return '$p0 · $p1 playlists · $p2 not found';
  }

  @override
  String get deshacer => 'Undo';

  @override
  String get elegirArchivo => 'Choose file';

  @override
  String leyendo(Object? p0) {
    return 'Reading “$p0”…';
  }

  @override
  String buscandoLasCancionesEnKijiDe(Object? p0, Object? p1) {
    return 'Looking for the songs in Kiji: $p0 of $p1';
  }

  @override
  String vistaPrevia(Object? p0) {
    return 'PREVIEW · $p0';
  }

  @override
  String yMas(Object? p0) {
    return '• and $p0 more';
  }

  @override
  String get siYaTienesUnaPlaylistCon =>
      'If you already have a playlist with the same name, the new one is called \"(imported)\".';

  @override
  String get importar2 => 'Import';

  @override
  String playlistsCreadasMeGustaYCanciones(Object? p0, Object? p1, Object? p2) {
    return '$p0 playlists created, $p1 likes and $p2 new songs in your history.';
  }

  @override
  String get deshacerLaImportacion => 'Undo the import';

  @override
  String get deshacerLaImportacion2 => 'Undo the import?';

  @override
  String get seQuitanLasPlaylistsMeGusta =>
      'The playlists, likes and history added by that import will be removed. What you already had isn\'t touched.';

  @override
  String get exportarTusPlaylists => 'EXPORT YOUR PLAYLISTS';

  @override
  String get todaviaNoTienesPlaylists => 'You don\'t have any playlists yet.';

  @override
  String get eligeUnaCarpetaConMusica => 'Choose a folder with music';

  @override
  String get canciones => 'Songs';

  @override
  String get playlists => 'Playlists';

  @override
  String get carpetas => 'Folders';

  @override
  String get eligeLaCarpetaDondeGuardasTu =>
      'Choose the folder where you keep your music. Kiji only reads the folders you choose.';

  @override
  String get elegirCarpeta => 'Choose folder';

  @override
  String get kijiNecesitaPermisoParaLeerTu =>
      'Kiji needs permission to read your local music.';

  @override
  String get concederPermiso => 'Grant permission';

  @override
  String get noSePudoLeerLaBiblioteca => 'Couldn\'t read the local library.';

  @override
  String get reintentar => 'Retry';

  @override
  String get noSeEncontroMusicaEnEste => 'No music was found on this device.';

  @override
  String get carpetasQueLeeKiji => 'Folders Kiji reads';

  @override
  String get quitarUnaCarpetaNoBorraNingun =>
      'Removing a folder doesn\'t delete any files.';

  @override
  String get dejarDeLeerEstaCarpeta => 'Stop reading this folder';

  @override
  String get agregarCarpeta => 'Add folder';

  @override
  String get espacio => 'STORAGE';

  @override
  String usadosPorKiji(Object? p0) {
    return '$p0 used by Kiji';
  }

  @override
  String libresCanciones(Object? p0, Object? p1) {
    return '$p0 free · $p1 songs';
  }

  @override
  String get todo => 'All';

  @override
  String get local => 'LOCAL';

  @override
  String get elServicioDeLetrasNoRespondio =>
      'the lyrics service didn\'t respond';

  @override
  String noRespondio(Object? p0) {
    return '$p0 didn\'t respond';
  }

  @override
  String get youlyplusNoRespondio => 'YouLyPlus didn\'t respond';

  @override
  String get youtubeNoRespondio => 'YouTube didn\'t respond';

  @override
  String get incluidaEnElArchivo => 'Embedded in the file';

  @override
  String get importadaPorTi => 'Imported by you';

  @override
  String get subtitulosDeYoutube => 'YouTube subtitles';

  @override
  String get eligeUnaCancion => 'Choose a song';

  @override
  String get noSePudoBuscarLaLetra => 'Couldn\'t search for the lyrics.';

  @override
  String get instrumental => 'Instrumental ♪';

  @override
  String get noEncontramosLaLetraDeEsta =>
      'We couldn\'t find the lyrics for this song in any source.';

  @override
  String get buscarAMano => 'Search manually';

  @override
  String get buscarLaLetraAMano => 'Search for the lyrics manually';

  @override
  String get buscandoEnTodasLasFuentes => 'Searching all sources…';

  @override
  String get tampocoSeEncontroConEsosDatos =>
      'Nothing found with those details either.';

  @override
  String get unaFuente => 'a source';

  @override
  String encontradaEn(Object? p0) {
    return 'Found on $p0.';
  }

  @override
  String noSePudoBuscar(Object? p0) {
    return 'Couldn\'t search ($p0).';
  }

  @override
  String get eligeUnArchivoLrc => 'Choose a .lrc file';

  @override
  String get letraImportada => 'Lyrics imported.';

  @override
  String get eseArchivoNoTieneUnaLetra =>
      'That file doesn\'t contain lyrics Kiji can understand.';

  @override
  String get cerrarLaLetra => 'Close lyrics';

  @override
  String get opcionesDeLaLetra => 'Lyrics options';

  @override
  String get traducir => 'Translate';

  @override
  String get sincronizarAdelantarOAtrasar => 'Sync (earlier or later)';

  @override
  String get compartirLineas => 'Share lines';

  @override
  String fuente(Object? p0) {
    return 'Source: $p0';
  }

  @override
  String get laLetraVaDespues => 'Lyrics are late';

  @override
  String get laLetraVaAntes => 'Lyrics are early';

  @override
  String get volverALaCancion => 'Back to the song';

  @override
  String get comoTexto => 'As text';

  @override
  String get comoImagen => 'As image';

  @override
  String get letraSinSincronizar => 'UNSYNCED LYRICS';

  @override
  String get historia916 => 'Story 9:16';

  @override
  String get cuadrado11 => 'Square 1:1';

  @override
  String get vertical45 => 'Portrait 4:5';

  @override
  String get horizontal169 => 'Landscape 16:9';

  @override
  String get soloTexto => 'Text only';

  @override
  String get portadaDifuminada => 'Blurred cover';

  @override
  String get colorDeLaCancion => 'Song color';

  @override
  String get oscuro => 'Dark';

  @override
  String get traduccion => 'Translation';

  @override
  String get ambas => 'Both';

  @override
  String get compartirComoImagen => 'Share as image';

  @override
  String get formato => 'Format';

  @override
  String get fondo => 'Background';

  @override
  String get texto => 'Text';

  @override
  String get logoDeKiji => 'Kiji logo';

  @override
  String get compartirImagen => 'Share image';

  @override
  String get fuenteDeLaLetra => 'Lyrics source';

  @override
  String get tocaUnaFuenteQueTengaLa =>
      'Tap a source that has the lyrics to use it for this song.';

  @override
  String get buscarConOtroTituloOArtista =>
      'Search with another title or artist';

  @override
  String get importarUnArchivoLrc => 'Import a .lrc file';

  @override
  String get cambiarElOrdenDeLasFuentes => 'Change the order of sources';

  @override
  String get sincronizada => 'Synced';

  @override
  String get sinSincronizar => 'Not synced';

  @override
  String get noLaTiene => 'Doesn\'t have it';

  @override
  String get noRespondio2 => 'Didn\'t respond';

  @override
  String get apagada => 'Off';

  @override
  String get esLaQueVesAhora => 'It\'s the one you see now';

  @override
  String deDeA(Object? p0, Object? p1, Object? p2, Object? p3) {
    return '“$p0” by $p1, from $p2 to $p3';
  }

  @override
  String momentoGuardadoEn(Object? p0) {
    return 'Moment saved at $p0';
  }

  @override
  String get ver => 'View';

  @override
  String get momentos2 => 'Moments';

  @override
  String get guardaElSegundoExactoDeUna =>
      'Save the exact second of a song (the solo, the chorus) with the player\'s \"Moment\" button. They show up here so you can go back to them with one tap.';

  @override
  String get repetirEsteTramo => 'Repeat this section';

  @override
  String get compartir => 'Share';

  @override
  String get seBorroElMomento => 'Moment deleted';

  @override
  String tramoDeA(Object? p0, Object? p1) {
    return 'Section from $p0 to $p1';
  }

  @override
  String momentoEn(Object? p0) {
    return 'Moment at $p0';
  }

  @override
  String repitiendo(Object? p0, Object? p1) {
    return 'Repeating $p0–$p1';
  }

  @override
  String get dejarDeRepetir => 'Stop repeating';

  @override
  String repitiendoDeA(Object? p0, Object? p1) {
    return 'Repeating from $p0 to $p1';
  }

  @override
  String get guardarUnMomento => 'Save a moment';

  @override
  String esteSegundo(Object? p0) {
    return 'This second ($p0)';
  }

  @override
  String get unTramo => 'A section';

  @override
  String deA(Object? p0, Object? p1) {
    return 'From $p0 to $p1';
  }

  @override
  String get vuelveAlPrincipioDelTramoAl =>
      'Goes back to the start of the section when it reaches the end.';

  @override
  String get meGusta2 => 'Liked';

  @override
  String get lasCancionesQueMarcasteCon => 'The songs you marked with ♥.';

  @override
  String get masEscuchadas => 'Most played';

  @override
  String get las25QueMasVecesEscuchaste =>
      'The 25 you\'ve played the most in Kiji.';

  @override
  String get escuchadasHacePoco => 'Recently played';

  @override
  String get lasUltimas25QueEscuchaste => 'The last 25 you played.';

  @override
  String get favoritasOlvidadas => 'Forgotten favorites';

  @override
  String get conQueNoEscuchasHaceMas =>
      'With ♥, but you haven\'t played them in over a month.';

  @override
  String get todoLoQueGuardasteParaEscuchar =>
      'Everything you saved to listen offline.';

  @override
  String get nuncaEscuchadas => 'Never played';

  @override
  String get deTuMusicaDelDispositivoLas =>
      'From the music on your device, the ones you haven\'t played in Kiji yet.';

  @override
  String canciones2(Object? p0, Object? p1) {
    return '“$p0” ($p1 songs)\n';
  }

  @override
  String get reproducir => 'Play';

  @override
  String get aleatorio => 'Shuffle';

  @override
  String get editar => 'Edit';

  @override
  String get nombreDescripcionYColor => 'Name, description and color';

  @override
  String get fijarArriba => 'Pin to top';

  @override
  String get descargarTodaLaPlaylist => 'Download the whole playlist';

  @override
  String get laListaDeCancionesComoTexto => 'The song list as text';

  @override
  String get exportar => 'Export';

  @override
  String get m3u8OtrasAppsOCsvPlanillas =>
      '.m3u8 (other apps) or .csv (spreadsheets)';

  @override
  String get borrarLaPlaylist => 'Delete the playlist';

  @override
  String get sePuedeDeshacer => 'Can be undone';

  @override
  String get exportarComo => 'Export as';

  @override
  String get m3u8ParaOtrasAppsDeMusica => '.m3u8 — for other music apps';

  @override
  String get csvParaPlanillas => '.csv — for spreadsheets';

  @override
  String get estaPlaylistNoTieneCancionesDe =>
      'This playlist has no YouTube songs to download.';

  @override
  String cancionesParaBajar(Object? p0) {
    return '$p0 songs to download.';
  }

  @override
  String yaEstabanDescargadasSeSaltean(Object? p0) {
    return '$p0 were already downloaded: they\'re skipped.';
  }

  @override
  String sonArchivosTuyosNoHaceFalta(Object? p0) {
    return '$p0 are your own files: no need to download them.';
  }

  @override
  String ocupanUnosEstimadoPorLaDuracion(Object? p0) {
    return 'They take up about $p0 (estimated from the duration).';
  }

  @override
  String espacioLibre(Object? p0) {
    return 'Free space: $p0.';
  }

  @override
  String get tienesSoloConWifiSiNo =>
      'You have \"Wi-Fi only\" on: without Wi-Fi, the download waits paused.';

  @override
  String get noEntraEnElEspacioLibre =>
      'It doesn\'t fit in the device\'s free space.';

  @override
  String de(Object? p0, Object? p1, Object? p2, Object? p3) {
    return '$p0: $p1 of $p2$p3';
  }

  @override
  String get cerrar => 'Close';

  @override
  String get pausar => 'Pause';

  @override
  String get verCuales => 'See which';

  @override
  String get reintentarLasFallidas => 'Retry the failed ones';

  @override
  String get nuevaPlaylist => 'New playlist';

  @override
  String get nombreDeLaPlaylist => 'Playlist name';

  @override
  String get agregarAPlaylist => 'Add to playlist';

  @override
  String seCreo(Object? p0) {
    return 'Created “$p0”';
  }

  @override
  String seAgregoA(Object? p0) {
    return 'Added to “$p0”';
  }

  @override
  String get tusPlaylists => 'YOUR PLAYLISTS';

  @override
  String get nueva => 'New';

  @override
  String get todaviaNoCreasteNingunaMantenPresionada =>
      'You haven\'t created any yet. Long-press a song → \"Add to playlist\".';

  @override
  String get fijada => 'Pinned';

  @override
  String segundosGuardadosDeTusCanciones(Object? p0) {
    return '$p0 saved seconds from your songs';
  }

  @override
  String get listasInteligentesCalculadasEnTuTelefono =>
      'SMART LISTS · CALCULATED ON YOUR PHONE';

  @override
  String get masOpciones => 'More options';

  @override
  String get estaPlaylistYaNoExiste => 'This playlist no longer exists.';

  @override
  String seBorro(Object? p0) {
    return 'Deleted “$p0”';
  }

  @override
  String get noSePudoDescargar2 => 'Couldn\'t download';

  @override
  String get porQueNoSeDescargo => 'Why it wasn\'t downloaded';

  @override
  String get quitarDeLaPlaylist => 'Remove from playlist';

  @override
  String seQuito(Object? p0) {
    return 'Removed “$p0”';
  }

  @override
  String get arrastrarParaMover => 'Drag to move';

  @override
  String importadaDe(Object? p0, Object? p1) {
    return '$p0 · imported from $p1';
  }

  @override
  String get ningunaCancionConEsteFiltro => 'No songs match this filter.';

  @override
  String deDescargadas(Object? p0, Object? p1) {
    return '$p0 of $p1 downloaded';
  }

  @override
  String conError(Object? p0) {
    return '· $p0 failed';
  }

  @override
  String get todas => 'All';

  @override
  String get sinDescargar => 'Not downloaded';

  @override
  String get conError2 => 'Failed';

  @override
  String regla(Object? p0) {
    return 'Rule: $p0';
  }

  @override
  String get porAhoraNoHayCancionesQue =>
      'For now there are no songs that match the rule.';

  @override
  String get cola => 'Queue';

  @override
  String get eligeUnaCancionParaEmpezar => 'Choose a song to start.';

  @override
  String seQuitoDeLaCola(Object? p0) {
    return 'Removed “$p0” from the queue';
  }

  @override
  String get pausarAlTerminarEsta => 'Pause after this one';

  @override
  String get quitarDeLaCola => 'Remove from queue';

  @override
  String get reproducirAContinuacion => 'Play next';

  @override
  String suenaDespuesDeEsta(Object? p0) {
    return '“$p0” plays after this one';
  }

  @override
  String get agregarALaCola => 'Add to queue';

  @override
  String seAgregoAlFinalDeLa(Object? p0) {
    return '“$p0” was added to the end of the queue';
  }

  @override
  String get personalizar2 => 'Customize';

  @override
  String get fotoTituloYArtistaSoloEn =>
      'Photo, title and artist (only in Kiji)';

  @override
  String get elTituloYElArtistaEs =>
      'The title and artist (it\'s a file on this device)';

  @override
  String get elTemporizadorParaCuandoTermineEsta =>
      'The timer stops when this song ends';

  @override
  String laMusicaSeVaAPausar(Object? p0) {
    return 'The music will pause when “$p0” ends';
  }

  @override
  String get reproducirTodo => 'Play all';

  @override
  String get buscandoMusicaParaTi => 'Finding music for you…';

  @override
  String porqueEscuchaste(Object? p0) {
    return 'Because you listened to $p0';
  }

  @override
  String get mezclaParaTi => 'Mix for you';

  @override
  String get tusFavoritasNuevas => 'your favorites + new ones';

  @override
  String get descubre => 'Discover';

  @override
  String get relacionadasDeYoutubeMusic => 'related from YouTube Music';

  @override
  String get paraEmpezar => 'To get started';

  @override
  String get eligeUnEstilo => 'pick a style';

  @override
  String get sinConexionLosGenerosAparecenCuando =>
      'No connection: genres will appear when the internet is back.';

  @override
  String get estadosDeAnimo => 'MOODS';

  @override
  String get generos => 'GENRES';

  @override
  String get noSePudoCargarRevisaTu => 'Couldn\'t load. Check your connection.';

  @override
  String seGuardoEnTusPlaylists(Object? p0) {
    return 'Saved “$p0” to your playlists';
  }

  @override
  String get guardarEnKiji => 'Save to Kiji';

  @override
  String algoFalloEn(Object? p0) {
    return 'Something went wrong in $p0';
  }

  @override
  String get unaCancionNoSePudoReproducir =>
      'A song couldn\'t be played with any method';

  @override
  String get reproduccion => 'playback';

  @override
  String videoCaminosAgotados(Object? p0) {
    return 'video $p0: all paths exhausted';
  }

  @override
  String get noSePudoAbrirElNavegador => 'Couldn\'t open the browser.';

  @override
  String get guardarInforme => 'Save report';

  @override
  String get borrarElRegistro => 'Delete the log?';

  @override
  String get seBorraTodoLoGuardadoSi =>
      'Everything saved will be deleted. If the log is on, it keeps recording from now on.';

  @override
  String get registrosEInformes => 'Logs and reports';

  @override
  String get elRegistroGuardadoEstaApagadoSolo =>
      'The saved log is off: only this session\'s log is used, and it\'s deleted when you close Kiji.';

  @override
  String get borrarElRegistro2 => 'Delete the log';

  @override
  String get erroresDeEstaSesion => 'ERRORS IN THIS SESSION';

  @override
  String get ninguno => 'None. 🎉';

  @override
  String get elRegistroLoUltimoTalComo =>
      'THE LOG (LATEST, EXACTLY AS IT\'S SENT)';

  @override
  String get creditos => 'Credits';

  @override
  String get noSePudieronLeerLosCreditos => 'Couldn\'t read the credits.';

  @override
  String get reproductorYAudio => 'Player and audio';

  @override
  String get contenido => 'Content';

  @override
  String get letras2 => 'Lyrics';

  @override
  String get apariencia => 'Appearance';

  @override
  String get almacenamiento => 'Storage';

  @override
  String get privacidad => 'Privacy';

  @override
  String get actualizaciones => 'Updates';

  @override
  String get acercaDe => 'About';

  @override
  String get kijiDev => 'Kiji Dev';

  @override
  String get borrarLaBusqueda => 'Clear search';

  @override
  String get noHayNingunaOpcionConEse => 'There\'s no setting with that name.';

  @override
  String get recordarLaColaAlCerrar => 'Remember the queue on close';

  @override
  String get alAbrirKijiVolverALa =>
      'When opening Kiji, go back to the song and the second where you left off (paused).';

  @override
  String get guardarCola => 'save queue';

  @override
  String get alAbrirKijiVuelveALa =>
      'When you open Kiji, it goes back to the song and the second where you left off, paused.';

  @override
  String get presetsBandasAManoYUn =>
      'Presets, manual bands and one profile per device (speaker, headphones, Bluetooth).';

  @override
  String get apagado => 'Off';

  @override
  String get transicionSuaveEntreCanciones => 'Smooth transition between songs';

  @override
  String get elFinalDeUnaCancionY =>
      'The end of one song and the start of the next play at the same time.';

  @override
  String sElFinalDeUnaCancion(Object? p0) {
    return '$p0 s: the end of one song and the start of the next play at the same time.';
  }

  @override
  String get transicionSuave => 'Crossfade';

  @override
  String get pausarAlSilenciar => 'Pause when muted';

  @override
  String get siBajasElVolumenACero =>
      'If you turn the volume down to zero, the music pauses; turn it up and it continues.';

  @override
  String get volumenCero => 'zero volume';

  @override
  String get siBajasElVolumenDelTelefono =>
      'If you turn the phone\'s volume down to zero, the music pauses; turn it up and it continues. Android only.';

  @override
  String get retomarAlConectarElBluetooth => 'Resume when Bluetooth connects';

  @override
  String get alConectarAuricularesOUnParlante =>
      'When you connect Bluetooth headphones or a speaker, the paused song continues on its own.';

  @override
  String get alConectarAuricularesOUnParlante2 =>
      'When you connect Bluetooth headphones or a speaker, the song that was paused continues on its own (like in Echo).';

  @override
  String get ocultarAudiosCortos => 'Hide short audio files';

  @override
  String get noMostrarEnLaBibliotecaLos =>
      'Don\'t show audio files shorter than 30 seconds in the Library.';

  @override
  String get noMuestraEnLaBibliotecaLos =>
      'Doesn\'t show audio files shorter than 30 seconds in the Library (notifications, game sounds). Nothing is deleted.';

  @override
  String get fuentesDeLetras => 'Lyrics sources';

  @override
  String get dondeBuscaKijiLasLetrasCada =>
      'Where Kiji looks for lyrics; each source can be turned off.';

  @override
  String get traduccionDeLetras => 'Lyrics translation';

  @override
  String get enTuTelefonoAnonimaOCon =>
      'On your phone (anonymous) or with Gemini (optional).';

  @override
  String get enTuTelefono => 'on your phone';

  @override
  String al(Object? p0, Object? p1) {
    return 'To $p0 · $p1';
  }

  @override
  String get reducirAnimaciones => 'Reduce animations';

  @override
  String get sinAnimacionesDecorativasComoElAnillo =>
      'No decorative animations, like the breathing ring on the play button.';

  @override
  String get sinAnimacionesDecorativasPorEjemploEl =>
      'No decorative animations (for example, the breathing ring on the play button).';

  @override
  String get noUsaLosDatosMovilesPara =>
      'Doesn\'t use mobile data for downloads.';

  @override
  String get limiteDeEspacioParaDescargas => 'Storage limit for downloads';

  @override
  String usado(Object? p0) {
    return 'Used: $p0';
  }

  @override
  String get limiteDeLaCache => 'Cache limit';

  @override
  String get loQueYaEscuchasteSeGuarda =>
      'What you\'ve already listened to is kept so it isn\'t downloaded again.';

  @override
  String get loYaEscuchadoSeGuardaPara =>
      'What you\'ve already listened to is kept so it isn\'t downloaded again. The oldest is deleted automatically.';

  @override
  String get vaciarLaCache => 'Clear the cache';

  @override
  String get liberaEspacioLasDescargasNoSe =>
      'Frees up space. Downloads aren\'t touched.';

  @override
  String get vaciarLaCache2 => 'Clear the cache?';

  @override
  String get lasCancionesQueYaEscuchasteSe =>
      'Songs you\'ve already listened to will be downloaded again next time. Downloads aren\'t touched.';

  @override
  String get vaciar => 'Clear';

  @override
  String get cacheVaciada => 'Cache cleared';

  @override
  String get ahorroDeDatos => 'Data saver';

  @override
  String get conDatosMovilesYoutubeSuenaEn =>
      'On mobile data, YouTube plays in low quality. On Wi-Fi, in the best.';

  @override
  String get conDatosMovilesYoutubeSuenaEn2 =>
      'On mobile data, YouTube plays in the lowest quality (about 4 times less data). On Wi-Fi, always in the best.';

  @override
  String get verYBorrarDescargas => 'View and delete downloads';

  @override
  String get sinConexion3 => 'offline';

  @override
  String get queGuardaKiji => 'What Kiji stores';

  @override
  String get sinCuentasSinAnunciosYSin =>
      'No accounts, no ads and no telemetry.';

  @override
  String get sinCuentasSinAnunciosYSin2 =>
      'No accounts, no ads and no telemetry. Your queue, downloads, history and likes are stored only on this device.';

  @override
  String get letrasYTraduccion => 'Lyrics and translation';

  @override
  String get queSeEnviaAlBuscarO =>
      'What\'s sent when searching for or translating lyrics.';

  @override
  String get alAbrirUnaLetraCadaFuente =>
      'When you open lyrics, each source receives only the title, artist, album, duration or video id. Translation on your phone sends nothing (only the language model is downloaded, once). Gemini is optional and off: if you turn it on, the lyric lines go to Google with your key, which is stored encrypted on this device only.';

  @override
  String get actualizacionesYGithub => 'Updates and GitHub';

  @override
  String get queVeGithubCuandoKijiBusca =>
      'What GitHub sees when Kiji checks for a new version.';

  @override
  String get recomendacionesDeInicio => 'Home recommendations';

  @override
  String get queSeLePideAYoutube =>
      'What\'s requested from YouTube Music for \"Because you listened to\", \"Mix\" and \"Discover\".';

  @override
  String get tuGustoSeCalculaEnEste =>
      'Your taste is calculated on this phone. YouTube Music is only asked, without an account, for songs related to up to 5 you\'ve listened to (just their id). Your history never leaves here.';

  @override
  String get borrarLasBusquedasRecientes => 'Clear recent searches';

  @override
  String get lasQueAparecenEnBuscarAntes =>
      'The ones shown in Search before you type.';

  @override
  String guardadasEnEsteDispositivo(Object? p0) {
    return '$p0 saved on this device';
  }

  @override
  String get busquedasBorradas => 'Searches cleared';

  @override
  String get borrarElHistorialDeEscucha => 'Clear listening history';

  @override
  String get vaciaEscuchadoRecientementeYParaTi =>
      'Empties \"Recently played\" and \"For you\".';

  @override
  String cancionesRecordadas(Object? p0) {
    return '$p0 songs remembered';
  }

  @override
  String get borrarElHistorial => 'Clear the history?';

  @override
  String get inicioDejaDeMostrarEscuchadoRecientement =>
      'Home stops showing \"Recently played\" and \"For you\" until you listen to music again. No songs or downloads are deleted.';

  @override
  String get historialBorrado => 'History cleared';

  @override
  String get datosDelReproductorDeYoutubeGithub =>
      'YouTube player data (GitHub)';

  @override
  String get queSeConsultaParaPoderDescifrar =>
      'What\'s checked to be able to decipher the audio.';

  @override
  String get youtubeCambiaSuReproductorCadaPocos =>
      'YouTube changes its player every few days. To keep deciphering the audio, Kiji downloads a public table at most every 6 hours (player_configs.json from the free zemer-cipher project, on GitHub), just like Echo and Metrolist. GitHub sees that request as a page visit; nothing of yours is sent.';

  @override
  String get pruebasAutomaticasDelExtractor => 'Automatic extractor tests';

  @override
  String get cada12HPruebaLasFormas =>
      'Every 12 h it tests the methods with control songs; it only warns you if they all fail.';

  @override
  String get alAbrirKijiSiPasaron12 =>
      'When you open Kiji (if 12 h have passed), every 12 h on PC and once a day on Android (only on Wi-Fi and when the battery isn\'t low). It uses 3 control songs, never your data. It only warns you if no method works.';

  @override
  String get saludDelExtractor => 'Extractor Health';

  @override
  String get comoEstaFuncionandoYoutubeHoy => 'How YouTube is working today.';

  @override
  String get cuentaDeGoogleOpcional => 'Google account (optional)';

  @override
  String get soloParaCancionesQueYoutubeEntrega =>
      'Only for songs that YouTube plays only for accounts.';

  @override
  String get iniciarSesion2 => 'sign in';

  @override
  String get cerrarSesion => 'sign out';

  @override
  String get sesionIniciada2 => 'Signed in';

  @override
  String get tocaParaVerOCerrarLa => 'Tap to view or end the session.';

  @override
  String get guardarUnRegistroEnEsteDispositivo => 'Keep a log on this device';

  @override
  String get ayudaAEntenderUnaFallaSin =>
      'Helps understand a problem. No personal data, takes at most 1 MB and never leaves the device unless you send it.';

  @override
  String get ofrecerUnInformeCuandoAlgoFalla =>
      'Offer a report when something fails';

  @override
  String get kijiPreguntaSiQuieresAvisarAl =>
      'Kiji asks if you want to let the developer know. It never sends anything on its own.';

  @override
  String get verElRegistroYLosInformes => 'View the log and reports';

  @override
  String get leerElRegistroDescargarUnInforme =>
      'Read the log, download a report (.txt) or send it to the developer.';

  @override
  String get herramientasDeDesarrollo => 'Developer tools';

  @override
  String get registroEnVivoExtractorCacheY =>
      'Live log, extractor, cache and downloads.';

  @override
  String get buscarActualizaciones => 'Check for updates';

  @override
  String get unaVezPorDiaPreguntaA =>
      'Once a day it asks GitHub if there\'s a new version. It never downloads or installs anything.';

  @override
  String get unaVezPorDiaPreguntaA2 =>
      'Once a day it asks GitHub if there\'s a new version and shows you what\'s new. It never downloads or installs anything on its own.';

  @override
  String get versionDeKiji => 'Kiji version';

  @override
  String get buscarAhoraYVerLasNovedades => 'Check now and see what\'s new.';

  @override
  String get buscarAhora => 'check now';

  @override
  String get importarDesdeOtraApp => 'Import from another app';

  @override
  String get echoMetrolistInnertuneOutertuneM3uExport =>
      'Echo, Metrolist, InnerTune, OuterTune, .m3u, Exportify and Google Takeout.';

  @override
  String get playlistsMeGustaEHistorialDe =>
      'Playlists, likes and history from Echo, Metrolist, InnerTune or OuterTune (.backup), .m3u, and CSV from Exportify or Google Takeout. You can also export your playlists.';

  @override
  String get copiaDeSeguridadDeKiji => 'Kiji backup';

  @override
  String get copiaDiariaAutomaticaEnDocumentosKiji =>
      'Daily automatic backup in Documents/Kiji; restore with a preview.';

  @override
  String get copiaAutomaticaApagada => 'Automatic backup off';

  @override
  String ultima(Object? p0) {
    return 'last: $p0';
  }

  @override
  String get softwareLibreGpl30 => 'Free software (GPL-3.0).';

  @override
  String canalCompiladaElSoftwareLibreGpl(Object? p0, Object? p1) {
    return '$p0 channel · built on $p1\nFree software (GPL-3.0). No payments, no ads and no telemetry.';
  }

  @override
  String get losProyectosLibresEnLosQue =>
      'The free projects Kiji is based on.';

  @override
  String get temporizadorLaMusicaQuedoEnPausa =>
      'Timer: the music is paused. Sleep well.';

  @override
  String get enUnosMinutos => 'In a few minutes';

  @override
  String get minutos => 'Minutes';

  @override
  String get alTerminarEstaCancion => 'When this song ends';

  @override
  String get estaCancion => 'This song';

  @override
  String get alTerminarLaCola => 'When the queue ends';

  @override
  String get finDeLaCola => 'End of queue';

  @override
  String get hastaUnaCancionDeLaCola => 'Until a song in the queue';

  @override
  String get hastaCancion => 'Until song';

  @override
  String get enUnMomentoExacto => 'At an exact moment';

  @override
  String get momentoExacto => 'Exact moment';

  @override
  String get laCancion => 'the song';

  @override
  String seQuitoDeLaColaEl(Object? p0) {
    return 'Removed “$p0” from the queue: the timer was turned off.';
  }

  @override
  String get cambioLaCancionElTemporizadorDe =>
      'The song changed: the exact-moment timer was turned off.';

  @override
  String get temporizador => 'Sleep timer';

  @override
  String get laMusicaBajaDeAPoco =>
      'The music fades out during the last 30 seconds (or less, if there\'s not much left) and stays paused.';

  @override
  String alTerminar(Object? p0) {
    return 'When “$p0” ends';
  }

  @override
  String enElDe(Object? p0, Object? p1) {
    return 'At $p0 of “$p1”';
  }

  @override
  String get activo => 'ACTIVE';

  @override
  String faltan(Object? p0) {
    return '$p0 left';
  }

  @override
  String get apagarElTemporizador => 'Turn off the timer';

  @override
  String get enUnosMinutos2 => 'IN A FEW MINUTES';

  @override
  String get otroNumeroDeMinutos => 'Another number of minutes';

  @override
  String get de1A600 => 'From 1 to 600';

  @override
  String get iniciar => 'Start';

  @override
  String get paraHastaUnaCancionEligelaEn =>
      'For \"until a song\", pick it in the Queue (⋮ menu → moon).';

  @override
  String get eligeElSegundoDeLaCancion =>
      'Choose the second of the song that\'s playing';

  @override
  String get marcarEnLaOnda => 'Mark on the waveform';

  @override
  String get tocaLaOndaDelReproductorDonde =>
      'Tap the player\'s waveform where you want it to pause';

  @override
  String get pausarEnEsteMomento => 'Pause at this moment';

  @override
  String get eseMomentoYaPasoLaMusica =>
      'That moment already passed: the music will pause when it gets back there (if you go back or the song repeats).';

  @override
  String laMusicaSeVaAPausar2(Object? p0, Object? p1) {
    return 'The music will pause at $p0$p1.';
  }

  @override
  String get tocaLaOndaDondeQuieresQue =>
      'Tap the waveform where you want it to pause';

  @override
  String get youtubeNoDijoElTamanoDel2 =>
      'YouTube didn\'t report the audio size';

  @override
  String youtubeRechazoElAudioHttpY(Object? p0) {
    return 'YouTube rejected the audio (HTTP $p0) and there was no other URL';
  }

  @override
  String youtubeRechazoElAudioHttp(Object? p0) {
    return 'YouTube rejected the audio (HTTP $p0)';
  }

  @override
  String get reproduccion2 => 'Playback';

  @override
  String get controlesDeLaMusicaQueEsta =>
      'Controls for the music that\'s playing';

  @override
  String get sinConexionAInternet => 'No internet connection.';

  @override
  String get llegasteAlLimiteGratuitoDeGemini =>
      'You\'ve reached Gemini\'s free limit for today. Try again tomorrow.';

  @override
  String get laClaveNoEsValidaRevisala =>
      'The key isn\'t valid. Please check it.';

  @override
  String get googleRechazoLaClaveOEl =>
      'Google rejected the key (or the free tier isn\'t available in your country).';

  @override
  String geminiNoRespondioHttp(Object? p0) {
    return 'Gemini didn\'t respond (HTTP $p0).';
  }

  @override
  String get geminiRespondioAlgoQueKijiNo =>
      'Gemini replied with something Kiji doesn\'t understand.';

  @override
  String get geminiDevolvioOtraCantidadDeLineas =>
      'Gemini returned a different number of lines. Please try again.';

  @override
  String get noSePudoSaberEnQue =>
      'Couldn\'t tell what language the lyrics are in.';

  @override
  String laLetraYaEstaEn(Object? p0) {
    return 'The lyrics are already in $p0.';
  }

  @override
  String get noSePudoConsultarLaLista =>
      'Couldn\'t get the list of languages (offline?).';

  @override
  String todaviaNoHayTraduccionDeA(Object? p0, Object? p1) {
    return 'There\'s no translation from $p0 to $p1 yet.';
  }

  @override
  String get faltaLaClaveDeGeminiConfiguracion =>
      'The Gemini key is missing (Settings → Lyrics → Translation).';

  @override
  String get espanol => 'Spanish';

  @override
  String get ingles => 'English';

  @override
  String get portugues => 'Portuguese';

  @override
  String get frances => 'French';

  @override
  String get italiano => 'Italian';

  @override
  String get aleman => 'German';

  @override
  String get neerlandes => 'Dutch';

  @override
  String get catalan => 'Catalan';

  @override
  String get polaco => 'Polish';

  @override
  String get ruso => 'Russian';

  @override
  String get ucraniano => 'Ukrainian';

  @override
  String get turco => 'Turkish';

  @override
  String get arabe => 'Arabic';

  @override
  String get hebreo => 'Hebrew';

  @override
  String get hindi => 'Hindi';

  @override
  String get japones => 'Japanese';

  @override
  String get coreano => 'Korean';

  @override
  String get chinoSimplificado => 'Chinese (Simplified)';

  @override
  String get chinoTradicional => 'Chinese (Traditional)';

  @override
  String get indonesio => 'Indonesian';

  @override
  String get vietnamita => 'Vietnamese';

  @override
  String get tailandes => 'Thai';

  @override
  String get sueco => 'Swedish';

  @override
  String get danes => 'Danish';

  @override
  String get noruego => 'Norwegian';

  @override
  String get fines => 'Finnish';

  @override
  String get griego => 'Greek';

  @override
  String get checo => 'Czech';

  @override
  String get rumano => 'Romanian';

  @override
  String get hungaro => 'Hungarian';

  @override
  String get laLetraSeTraduceDentroDe =>
      'The lyrics are translated inside your phone. Nothing is sent to anyone and you stay anonymous. The translation model is downloaded only once per language (the server only knows someone downloaded that language, not which song). It\'s good for understanding the lyrics, although it sometimes sounds literal.';

  @override
  String get tituloArtistaAlbumYDuracion => 'title, artist, album and duration';

  @override
  String get tituloArtistaAlbumDuracionEId =>
      'title, artist, album, duration and video id';

  @override
  String get tituloYArtista => 'title and artist';

  @override
  String get idDelVideoOTituloArtista =>
      'video id, or title, artist and duration';

  @override
  String get tituloArtistaYDuracion => 'title, artist and duration';

  @override
  String get idDelVideoAYoutube => 'video id (to YouTube)';

  @override
  String get idDelVideoAYoutubeMusic => 'video id (to YouTube Music)';

  @override
  String get kijiBuscaLaLetraPrimeroEn =>
      'Kiji looks for lyrics first in the file (no internet) and then in these sources, in this order, until one has them. Drag to change the order. It only searches when you open the lyrics, and each source receives only what\'s listed below; nothing of yours.';

  @override
  String get arrastrarParaCambiarElOrden => 'Drag to change the order';

  @override
  String recibe(Object? p0) {
    return 'Receives: $p0';
  }

  @override
  String get originalYTraduccionSeVenLinea =>
      'Original and translation are shown line by line (in the lyrics: ⋮ → Translate lyrics). Each translation is saved so it isn\'t repeated.';

  @override
  String get traducirAl => 'Translate to';

  @override
  String get n1EnTuTelefonoAnonimo => '1 · On your phone (anonymous)';

  @override
  String get idiomasBajados => 'DOWNLOADED LANGUAGES';

  @override
  String get ningunoTodaviaSeBajanSolosAvisando =>
      'None yet: they download automatically (telling you the size) the first time you translate.';

  @override
  String get n2ConIaGemini => '2 · With AI (Gemini)';

  @override
  String get traducirConGemini => 'Translate with Gemini';

  @override
  String get apagadoAntesDeActivarloVasA =>
      'Off. Before turning it on you\'ll see what it involves.';

  @override
  String get usarGeminiParaTraducir => 'Use Gemini to translate';

  @override
  String get siLoApagasSeTraduceEn =>
      'If you turn it off, translation happens on your phone.';

  @override
  String get pierdesParteDelAnonimatoLasLineas =>
      'You lose some anonymity: the lyric lines are sent to Google, linked to your Google account (through the key).';

  @override
  String get enElNivelGratuitoGoogleUsa =>
      'On the free tier, Google uses that content to improve its products and people at Google may read it (Google says it separates it from your account first).';

  @override
  String get kijiNoEnviaTuNombreTu =>
      'Kiji does NOT send your name, your history or your library: only the lyric lines and the target language.';

  @override
  String get requisitosDeGoogleTener18Anos =>
      'Google\'s requirements: you must be 18 or older. In Europe, the UK and Switzerland the free tier isn\'t allowed for this.';

  @override
  String get antesDeUsarGemini => 'Before using Gemini';

  @override
  String get queCambiaSiActivasLaTraduccion =>
      'What changes if you turn on translation with Gemini';

  @override
  String get siNoQuieresNadaDeEsto =>
      'If you don\'t want any of this, translation on your phone is still available and anonymous.';

  @override
  String get entiendoActivar => 'I understand, turn on';

  @override
  String get mejorNo => 'No, thanks';

  @override
  String get pegaLaClavePrimero => 'Paste the key first.';

  @override
  String get noSePudoGuardarLaClave =>
      'Couldn\'t save the encrypted key on this device.';

  @override
  String get laClaveAndaGuardadaCifrada => 'The key works. Saved encrypted.';

  @override
  String mientrasTantoPuedesTraducirEnEl(Object? p0) {
    return '$p0 Meanwhile you can translate on your phone.';
  }

  @override
  String get comoConseguirTuClave => 'HOW TO GET YOUR KEY';

  @override
  String get n1EntraAAistudioGoogleCom =>
      '1. Go to aistudio.google.com with your Google account.';

  @override
  String get abrir => 'Open';

  @override
  String get n2TocaGetApiKeyCreate =>
      '2. Tap \"Get API key\" → \"Create API key\" (no card needed).';

  @override
  String get n3CopiaLaClaveYPegala => '3. Copy the key and paste it below.';

  @override
  String get n4TocaProbar => '4. Tap \"Test\".';

  @override
  String get n5EligeElModeloKijiRecomienda =>
      '5. Choose the model (Kiji recommends the lightest one, Flash-Lite).';

  @override
  String get claveDeGemini => 'Gemini key';

  @override
  String get pegar => 'Paste';

  @override
  String get probar => 'Test';

  @override
  String get borrarClave => 'Delete key';

  @override
  String get claveBorradaDeEsteDispositivo => 'Key deleted from this device.';

  @override
  String get modelo => 'Model';

  @override
  String modelo2(Object? p0) {
    return 'Model: $p0';
  }

  @override
  String noSePudoTraducir(Object? p0) {
    return 'Couldn\'t translate: $p0';
  }

  @override
  String paraTraducirDelEnTuTelefono(Object? p0, Object? p1) {
    return 'To translate from $p0 on your phone, $p1 needs to be downloaded (only once). The server only knows someone downloaded that language, not which song.';
  }

  @override
  String bajar(Object? p0) {
    return 'Download $p0';
  }

  @override
  String get traducirEnElTelefono => 'Translate on the phone';

  @override
  String get recien => 'just now';

  @override
  String haceMin(Object? p0) {
    return '$p0 min ago';
  }

  @override
  String kiji(Object? p0) {
    return 'Kiji $p0';
  }

  @override
  String get kijiNuncaSeActualizaSoloNi =>
      'Kiji never updates itself or downloads anything: you download it yourself from the official page, if you want.';

  @override
  String get abrirLaPaginaOficial => 'Open the official page';

  @override
  String hayUnaVersionNueva(Object? p0) {
    return 'There\'s a new version: $p0';
  }

  @override
  String ultimaConsulta(Object? p0) {
    return 'Last checked: $p0.';
  }

  @override
  String get buscarAhora2 => 'Check now';

  @override
  String get todaviaNoHayVersionesPublicadas =>
      'No versions have been published yet.';

  @override
  String tienesLaUltimaVersion(Object? p0) {
    return 'You have the latest version ($p0).';
  }

  @override
  String get noSePudoConsultarRevisaTu =>
      'Couldn\'t check. Check your connection.';

  @override
  String get sinTitulo => 'Untitled';

  @override
  String get obtenidoOk => 'obtained OK';

  @override
  String get enLaPcTodaviaNoSe => 'HLS playlists can\'t be played on PC yet';

  @override
  String get noSePudoLeerLaPagina => 'Couldn\'t read the embedded player page';

  @override
  String get enEsteDispositivoNoSePuede =>
      'This device can\'t decipher (no WebView)';

  @override
  String get noSePudoUbicarElReproductor =>
      'Couldn\'t locate the YouTube player';

  @override
  String youtubeRechazoElPedido(Object? p0) {
    return 'YouTube rejected the request ($p0)';
  }

  @override
  String get youtubeRespondioVacio => 'YouTube returned an empty response';

  @override
  String get sinEstado => 'No status';

  @override
  String get sinFormatosDeAudio => 'no audio formats';

  @override
  String get elFormatoNoTraeUrlNi => 'The format has no URL or signature';

  @override
  String get laFirmaCifradaVinoIncompleta =>
      'The encrypted signature was incomplete';

  @override
  String get formatoCifradoEnUnaFormaQue =>
      'Encrypted format in a method that doesn\'t decipher';

  @override
  String get sinRespuesta => 'no response';

  @override
  String noSePudoDescifrarLaFirma(Object? p0) {
    return 'Couldn\'t decipher the signature: $p0';
  }

  @override
  String noSePudoTransformarElParametro(Object? p0) {
    return 'Couldn\'t transform the \"n\" parameter: $p0';
  }

  @override
  String get youtubeNoEntregoLaListaHls =>
      'YouTube didn\'t deliver the HLS playlist';

  @override
  String get laListaHlsNoTraeAudio =>
      'The HLS playlist has no audio-only stream';

  @override
  String get laListaDeAudioHlsVino => 'The HLS audio playlist was empty';

  @override
  String unSegmentoHlsNoBajaHttp(Object? p0) {
    return 'An HLS segment won\'t download (HTTP $p0)';
  }

  @override
  String laListaHlsFallo(Object? p0) {
    return 'The HLS playlist failed: $p0';
  }

  @override
  String get youtubeSoloDejaBajarElPrimer =>
      'YouTube only allows downloading the first minute (HTTP 403 at the end of the file)';

  @override
  String elAudioNoRespondeHttp(Object? p0) {
    return 'The audio isn\'t responding (HTTP $p0)';
  }

  @override
  String elAudioNoResponde(Object? p0) {
    return 'The audio isn\'t responding ($p0)';
  }

  @override
  String get audioDirectoSinDescifrar => 'Direct audio, no deciphering.';

  @override
  String get listaHlsDeSegmentosChicosOtro =>
      'HLS playlist of small segments (a different server than direct VISIONOS). Not stored in the cache.';

  @override
  String get televisorSimpleDescifraConElSolver =>
      'Simple TV; deciphers with the solver and sends a PO token.';

  @override
  String get comoTvhtml5SimplyPeroPidiendoA =>
      'Like TVHTML5_SIMPLY, but requesting from music.youtube.com.';

  @override
  String get entregaSoloElPrimerMibMedido =>
      'Only delivers the first MiB (measured with InnerTubeX, 10/18/2026).';

  @override
  String get youtubeRespondeVolverACargarLa =>
      'YouTube replies \"reload the page\" (InnerTubeX: test only).';

  @override
  String get televisorDescifraConElSolver => 'TV; deciphers with the solver.';

  @override
  String get youtubeYaNoLeDaFormatos =>
      'YouTube no longer gives it audio formats (InnerTubeX: NO_PLAYABLE_STREAM).';

  @override
  String get versionViejaDeAndroidVrDe =>
      'Old version of ANDROID_VR, as a control.';

  @override
  String get youtubeYaNoLeDaFormatos2 =>
      'YouTube no longer gives it audio formats (InnerTubeX: broken).';

  @override
  String get sueleDarSoloElPrimerMinuto =>
      'It usually gives only the first minute.';

  @override
  String get laWebDeYoutubeMusicDescifra =>
      'The YouTube Music website; deciphers with the solver and sends a PO token.';

  @override
  String get elReproductorIncrustadoUsaElVisitor =>
      'The embedded player; uses the visitor from the embed page (Task Z8, like InnerTubeX 0.8.4).';

  @override
  String get necesitaUnPoTokenLigadoA =>
      'Needs a PO token tied to the page, which Kiji doesn\'t generate (measured on 10/18/2026).';

  @override
  String get laWebParaCelularesDescifraCon =>
      'The mobile website; deciphers with the solver and sends a PO token.';

  @override
  String get enEsteDispositivoNoHayWebview =>
      'This device has no WebView to decipher';

  @override
  String get aPlaylist => 'A playlist';

  @override
  String get noSePudoAbrirRevisaTu => 'Couldn\'t open. Check your connection.';

  @override
  String get canciones3 => 'SONGS';

  @override
  String get albumesYSingles => 'ALBUMS AND SINGLES';

  @override
  String haceH(Object? p0) {
    return '$p0 h ago';
  }

  @override
  String ultimaPruebaAutomaticaSePruebaCon(Object? p0, Object? p1) {
    return 'Last automatic test: $p0. It tests with $p1 control songs, never with your history; the test requests the last byte of the audio to find the methods that cut off after a minute.';
  }

  @override
  String get probarTodasLasFormasAhora => 'Test all methods now';

  @override
  String formasRetiradasYoutubeYaNoLas(Object? p0) {
    return 'Retired methods (YouTube no longer allows them) · $p0';
  }

  @override
  String falloCon(Object? p0, Object? p1) {
    return 'Failed with $p0: $p1';
  }

  @override
  String get sinProbarTodavia => 'Not tested yet';

  @override
  String ultimaVezQueAnduvo(Object? p0) {
    return 'Last time it worked: $p0';
  }

  @override
  String ultimoProblema(Object? p0) {
    return 'Last problem: $p0';
  }

  @override
  String noSePudoInstalar(Object? p0) {
    return 'Couldn\'t install: $p0';
  }

  @override
  String get opcionalYSoloEnLaPc =>
      'Optional and PC only. If engines A and B can\'t handle a song, Kiji can use yt-dlp, a well-known free program. It\'s downloaded from its official GitHub page (about 18 MB), its fingerprint is verified, and it updates only once a week. Nothing is downloaded unless you ask.';

  @override
  String get instalado => 'Installed';

  @override
  String get quitarYtDlp => 'Remove yt-dlp';

  @override
  String get bajarYUsarYtDlp18 => 'Download and use yt-dlp (≈18 MB)';

  @override
  String get artistas => 'Artists';

  @override
  String get albumes => 'Albums';

  @override
  String get misArchivos => 'My files';

  @override
  String get noSePudoBuscarRevisaTu =>
      'Couldn\'t search. Check your internet connection.';

  @override
  String get recientes => 'RECENT';

  @override
  String get quitar => 'Remove';

  @override
  String get tePuedeGustar => 'You might like';

  @override
  String get segunLoQueEscuchas => 'based on what you listen to';

  @override
  String get exploraPorEstilo => 'Explore by style';

  @override
  String get generosYAnimosDeYoutubeMusic =>
      'genres and moods from YouTube Music';

  @override
  String get noSePudoReproducirEstaCancion => 'Couldn\'t play this song.';

  @override
  String get buscarCancionesArtistas => 'Search songs, artists...';

  @override
  String get sinResultados => 'No results';

  @override
  String get buscaEntreTuMusicaGuardadaY =>
      'Search your saved music and downloads';

  @override
  String get noHayCoincidenciasEnTusArchivos => 'No matches in your files';

  @override
  String get soloSePuedenDescargarCancionesDe =>
      'Only YouTube songs can be downloaded.';

  @override
  String get estasSinWifiYElegisteDescargar =>
      'You\'re not on Wi-Fi and you chose to download on Wi-Fi only. You can change this in Library → Downloaded.';

  @override
  String get noHayEspacioSuficienteEnEl =>
      'There isn\'t enough space on the device.';

  @override
  String get superariaElLimiteDeEspacioPara =>
      'It would exceed the storage limit for downloads you chose. You can change it or delete downloads in Library → Downloaded.';

  @override
  String get enPausa => 'Paused';

  @override
  String terminoAntesDeTiempoEnS(Object? p0, Object? p1) {
    return 'ended early at $p0 s of $p1 s';
  }

  @override
  String get caminosAgotados => 'all paths exhausted';

  @override
  String elVideoTieneRestriccionOEsta(Object? p0) {
    return '“$p0”: the video is restricted or blocked; playing its “Song” version.';
  }

  @override
  String get elAudioNoSePudoAbrir => 'The audio couldn\'t be opened';

  @override
  String sinConexionSeguimosConQueEsta(Object? p0) {
    return 'No connection. Continuing with “$p0”, which is saved on your phone.';
  }

  @override
  String get sinConexionLaMusicaQuedoEn =>
      'No connection: the music is paused. When the internet is back, tap play.';

  @override
  String get pasamosALaSiguiente => 'Moving on to the next one.';

  @override
  String get youtubeNoEstaDejandoReproducirAhora =>
      'YouTube isn\'t allowing playback right now. Try again in a while or listen to your saved music.';

  @override
  String noSePudoReproducirPasamosA(Object? p0) {
    return 'Couldn\'t play “$p0”. Moving on to the next one.';
  }

  @override
  String get seCortoDuranteLaReproduccion => 'It cut off during playback';

  @override
  String get lasCancionesDeEstaColaYa =>
      'The songs in this queue are no longer on the device.';

  @override
  String yaNoEstaEnElDispositivo(Object? p0) {
    return '“$p0” is no longer on the device. Moving on to the next one.';
  }

  @override
  String get lasCancionesDeTuUltimaCola =>
      'The songs in your last queue are no longer on the device.';

  @override
  String get verDescargadas => 'View downloads';

  @override
  String hayUnaVersionNuevaDeKiji(Object? p0) {
    return 'There\'s a new version of Kiji ($p0).';
  }

  @override
  String get buenosDias => 'Good morning';

  @override
  String get buenasTardes => 'Good afternoon';

  @override
  String get buenasNoches => 'Good evening';

  @override
  String get escuchadoRecientemente => 'Recently played';

  @override
  String get tusMasEscuchadas => 'Your most played';

  @override
  String get calculadoEnTuTelefono => 'calculated on your phone';

  @override
  String get sinInternet => 'offline';

  @override
  String get sigueDondeQuedaste => 'PICK UP WHERE YOU LEFT OFF';

  @override
  String get loQueEscuchesApareceAquiTodo =>
      'What you listen to shows up here. Everything is calculated on your phone; nothing leaves it.';

  @override
  String get buscarMusica => 'Search music';

  @override
  String get tusPlaylists2 => 'Your playlists';

  @override
  String get nueva2 => '+ New';

  @override
  String get tuBiblioteca => 'YOUR LIBRARY';

  @override
  String get descargadas2 => 'DOWNLOADED';

  @override
  String get minimizar => 'Minimize';

  @override
  String get reproduciendoDesde => 'PLAYING FROM';

  @override
  String get escucharSinConexion => 'Listen offline';

  @override
  String get descargarDentroDeKiji => 'Download inside Kiji';

  @override
  String get cancionGuardadaEnElDispositivo => 'Song saved on the device';

  @override
  String get yaSuenaSinConexion => 'Already plays offline';

  @override
  String get comoEstaFuncionandoYoutubeHoy2 => 'How YouTube is working today';

  @override
  String get descargadaSuenaSinConexion => 'Downloaded: plays offline';

  @override
  String get repetirApagado => 'Repeat: off';

  @override
  String get repetirTodaLaCola => 'Repeat: whole queue';

  @override
  String get repetirEstaCancion => 'Repeat: this song';

  @override
  String get aleatorioApagado => 'Shuffle: off';

  @override
  String get anterior => 'Previous';

  @override
  String get siguiente => 'Next';

  @override
  String get letra => 'Lyrics';

  @override
  String temporizadorActivo(Object? p0) {
    return 'Sleep timer on: $p0';
  }

  @override
  String get momento => 'Moment';

  @override
  String get guardarEsteMomento => 'Save this moment';

  @override
  String get tusListas => 'YOUR LISTS';

  @override
  String get tusPlaylistsVanAAparecerAqui =>
      'Your playlists will show up here.';

  @override
  String get sinUsarTodavia => 'Not used yet';

  @override
  String get saludDelExtractor2 => 'EXTRACTOR HEALTH';

  @override
  String get buscarCancionesArtistas2 => 'Search songs, artists…';

  @override
  String get aContinuacion => 'Up next';

  @override
  String volumen(Object? p0) {
    return 'Volume $p0%';
  }

  @override
  String get temporizadorActivo2 => 'Sleep timer on';

  @override
  String get mostrarLaCola => 'Show the queue';

  @override
  String get guardarPlaylist => 'Save playlist';

  @override
  String seGuardo(Object? p0) {
    return 'Saved “$p0”';
  }

  @override
  String get noSePudoGuardarElArchivo => 'Couldn\'t save the file.';

  @override
  String get progresoDeLaCancion => 'Song progress';

  @override
  String get pausaDelTemporizador => 'Timer pause';

  @override
  String get sinSesion => 'Not signed in';

  @override
  String get kijiFuncionaSinCuenta =>
      'Kiji works fully without an account. Signing in is optional and only needed for songs that YouTube plays only for accounts (for example, age-restricted ones).';

  @override
  String get todaviaNoHayCopias => 'No backups yet.';

  @override
  String get copiaHecha => 'Backup done';

  @override
  String nCancionesDescargadas(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count downloaded songs',
      one: '1 downloaded song',
    );
    return '$_temp0';
  }

  @override
  String bajandoNCanciones(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Downloading $count songs',
      one: 'Downloading 1 song',
    );
    return '$_temp0';
  }

  @override
  String hoyA(Object? time) {
    return 'today $time';
  }

  @override
  String ayerA(Object? time) {
    return 'yesterday $time';
  }

  @override
  String get noEsUnaImagenQueKijiPuedaLeer =>
      'It\'s not an image Kiji can read';

  @override
  String get elArchivoNoTieneUnaLetra =>
      'The file doesn\'t contain lyrics Kiji can understand';

  @override
  String get puedesBuscarOtraVersionSufijo =>
      ' You can look for another version.';

  @override
  String get oBuscaOtraVersionSufijo => ' or look for another version';

  @override
  String get unTamanoDesconocido => 'an unknown size';

  @override
  String get noSePudoSaberElEspacioLibre =>
      'Couldn\'t find out how much free space is left.';

  @override
  String get listoYaEstaDescargada => 'Done! It\'s downloaded.';

  @override
  String get reintentarIgual => 'Retry anyway';

  @override
  String get noQuedaNingunaConError => 'None left with errors. 🎉';

  @override
  String get falloLaDescarga => 'The download failed';

  @override
  String get enCola => 'Queued';

  @override
  String bytesDe(Object? done, Object? total) {
    return '$done of $total';
  }

  @override
  String get todaviaNoDescargasteNada => 'You haven\'t downloaded anything yet';

  @override
  String nCanciones(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return '$_temp0';
  }

  @override
  String get sinLimite => 'No limit';

  @override
  String get lasBandasAparecenCuandoSuena =>
      'The bands appear when something starts playing.';

  @override
  String get cortaAntesDelFinal =>
      'Cuts off before the end (HTTP 403 on the last byte)';

  @override
  String cancionesNormalesFormas(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Regular songs: ✓ $count methods working',
      one: 'Regular songs: ✓ 1 method working',
    );
    return '$_temp0';
  }

  @override
  String haceNDias(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String anduvoCon(Object? song, Object? ms) {
    return 'Worked with $song ($ms ms)';
  }

  @override
  String get ytDlpListo =>
      'yt-dlp is ready and verified. It\'s used only if engines A and B fail.';

  @override
  String haceNHoras(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String get sinConexionMinuscula => 'no connection';

  @override
  String get ytDlpTardoDemasiado => 'yt-dlp took too long';

  @override
  String ytDlpFallo(Object? error) {
    return 'yt-dlp failed ($error)';
  }

  @override
  String get ytDlpRespondioAlgoRaro => 'yt-dlp returned something strange';

  @override
  String get ytDlpNoDioUrl => 'yt-dlp didn\'t return a URL';

  @override
  String get falloEstaForma => 'This method failed';

  @override
  String get googleTakeoutCsv => 'Google Takeout from YouTube Music (.csv)';

  @override
  String noSePudoBuscarLaLetraPorque(Object? reason) {
    return 'Couldn\'t search for the lyrics ($reason). Try again in a while.';
  }

  @override
  String get quitarLaTraduccion => 'Remove translation';

  @override
  String get elegirLaFuente => 'Choose the source';

  @override
  String get sinDesfase => 'No offset';

  @override
  String get tocaLasLineasQueQuieresCompartir =>
      'Tap the lines you want to share';

  @override
  String nLineasElegidas(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines selected',
      one: '1 line selected',
    );
    return '$_temp0';
  }

  @override
  String preguntandoALasFuentes(Object? pending) {
    return 'Asking the sources… ($pending)';
  }

  @override
  String get enUso => 'In use';

  @override
  String momentoDesde(Object? title, Object? artist, Object? at) {
    return '“$title” by $artist, from $at';
  }

  @override
  String tramoGuardado(Object? from, Object? to) {
    return 'Section saved: $from–$to';
  }

  @override
  String get playlistSinNombre => 'Untitled playlist';

  @override
  String get yaEstanTodasDescargadas => 'They\'re all downloaded already.';

  @override
  String get espacioLibreDesconocido => 'Free space: unknown.';

  @override
  String nDescargadas(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count downloaded',
      one: '1 downloaded',
    );
    return '$_temp0';
  }

  @override
  String nFallaron(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count failed',
      one: '1 failed',
    );
    return '$_temp0';
  }

  @override
  String conErrorSufijo(Object? count) {
    return ' ($count failed)';
  }

  @override
  String yaEstabaEn(Object? name) {
    return 'It was already in “$name”';
  }

  @override
  String get laColaEstaVacia => 'The queue is empty';

  @override
  String get esLaUltimaCancionDeLaCola => 'This is the last song in the queue';

  @override
  String despuesDeEstaN(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs after this one',
      one: '1 song after this one',
    );
    return '$_temp0';
  }

  @override
  String get quitarLaPausaProgramada => 'Remove the scheduled pause';

  @override
  String get conUnEnlaceDeSongLink =>
      'With a song.link link that opens in any music app';

  @override
  String elRegistroGuardadoOcupa(Object? size) {
    return 'The saved log takes up $size. It doesn\'t contain your name, accounts, keys or internet addresses. It only leaves the device if you send it.';
  }

  @override
  String nSegundos(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String get todasPrendidas => 'All on.';

  @override
  String nApagadas(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count off.',
      one: '1 off.',
    );
    return '$_temp0';
  }

  @override
  String get conGemini => 'with Gemini';

  @override
  String get privacidadActualizaciones =>
      'If \"Check for updates\" is on, once a day Kiji asks GitHub for the latest published version. GitHub sees that request as a page visit (your IP and that it\'s Kiji); nothing of yours is sent. You can turn it off in Settings → Updates.';

  @override
  String get soloParaCancionesConCuenta =>
      'Only for songs that YouTube plays only for accounts.';

  @override
  String get todaviaSinCopias => 'no backups yet';

  @override
  String get yaPasoPausaCuandoVuelva =>
      'Already passed: pauses when it gets back there';

  @override
  String get esperandoEsaCancion => 'Waiting for that song';

  @override
  String deDuracion(Object? duration) {
    return 'of $duration';
  }

  @override
  String get cuandoVuelvaAhiSufijo => ' (when it gets back there)';

  @override
  String get motorYModelosDeFirefox =>
      'Engine and models from Firefox Translations (Mozilla, MPL-2.0 license).';

  @override
  String get activadoPierdesAnonimato =>
      'On. You lose some anonymity when using it.';

  @override
  String get laClaveAndaSinModelos =>
      'The key works, but there are no text models.';

  @override
  String get claveGuardadaPegaOtra =>
      'Key saved (paste another one to change it)';

  @override
  String get estaVersionNoTraeNotas => 'This version has no release notes.';

  @override
  String get todaviaNoSeConsulto => 'Not checked yet.';

  @override
  String get noSePuedeReproducir => 'can\'t be played';

  @override
  String get youtubeNoDejaProbarMotorC =>
      'YouTube isn\'t allowing playback right now. You can try engine C (yt-dlp) in Settings → Extractor Health.';

  @override
  String get quitarDeMeGusta => 'Remove from liked';

  @override
  String get aleatorioActivado => 'Shuffle: on';

  @override
  String youtubeFuncionaNFormas(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'YouTube works ($count methods)',
      one: 'YouTube works (1 method)',
    );
    return '$_temp0';
  }

  @override
  String get youtubeConProblemas => 'YouTube has problems';

  @override
  String get ocultarLaCola => 'Hide the queue';

  @override
  String hayVersionNuevaPunto(Object? version) {
    return 'There\'s a new version: $version.';
  }

  @override
  String get informeDeKijiPlayer => 'Kiji Player report';

  @override
  String informeVersion(Object? version) {
    return 'Version: $version';
  }

  @override
  String informeSistema(Object? system) {
    return 'System: $system';
  }

  @override
  String informeFecha(Object? date) {
    return 'Date: $date';
  }

  @override
  String informeQuePaso(Object? summary) {
    return 'What happened: $summary';
  }

  @override
  String informeDonde(Object? where) {
    return 'Where: $where';
  }

  @override
  String informeDetalle(Object? detail) {
    return 'Details: $detail';
  }

  @override
  String get informePila => 'Stack:';

  @override
  String informeRegistro(Object? count) {
    return 'Log (last $count lines, no personal data):';
  }

  @override
  String get informeDeKiji => 'Kiji report';

  @override
  String informeError(Object? summary) {
    return 'Error: $summary';
  }

  @override
  String get laPantalla => 'the screen';

  @override
  String seBorranNDelDispositivo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count songs will be deleted from the device. They stay in your queue: they\'ll play from the internet again.',
      one: '1 song will be deleted from the device. It stays in your queue: it\'ll play from the internet again.',
    );
    return '$_temp0';
  }

  @override
  String encendidoPerfil(Object? profile) {
    return 'On: $profile';
  }

  @override
  String get cable => 'Wired';

  @override
  String perfilDe(Object? profile) {
    return 'PROFILE: $profile';
  }

  @override
  String ahoraLinea(Object? line) {
    return 'Now: $line';
  }

  @override
  String get desfijar => 'Unpin';

  @override
  String get vacio => 'Empty.';

  @override
  String get no => 'No';

  @override
  String nMin(Object? minutes) {
    return '$minutes min';
  }

  @override
  String get recomendadoSufijo => ' (recommended)';

  @override
  String get album => 'Album';

  @override
  String get probando => 'Testing…';

  @override
  String get reproduciendo => 'Playing';

  @override
  String get idioma => 'Language';

  @override
  String get idiomaDescripcion =>
      'System, Spanish or English. Changes instantly.';

  @override
  String get idiomaDelSistema => 'System';
}
