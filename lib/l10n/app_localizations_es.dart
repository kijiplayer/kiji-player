// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get navHome => 'Inicio';

  @override
  String get navSearch => 'Buscar';

  @override
  String get navLibrary => 'Biblioteca';

  @override
  String get settingsTitle => 'Configuración';

  @override
  String get settingsSearchHint => 'Buscar una opción…';

  @override
  String get errorReportTitle => 'Algo falló en Kiji';

  @override
  String errorReportBody(String summary) {
    return '$summary.\n\n¿Quieres avisarle al desarrollador? Se abre GitHub con un informe ya escrito, sin tu nombre, tus archivos ni tus cuentas. Lo puedes leer antes de enviarlo.';
  }

  @override
  String get errorReportSend => 'Enviar al desarrollador';

  @override
  String get errorReportDownload => 'Descargar informe (.txt)';

  @override
  String get errorReportNoThanks => 'No, gracias';

  @override
  String get estable => 'Estable';

  @override
  String get youtubePuedeLimitarOSuspenderCuentas =>
      'YouTube puede limitar o suspender cuentas que se usan en apps que no son oficiales. Te recomendamos usar una cuenta secundaria, no la principal.';

  @override
  String get tuSesionSeGuardaCifradaSolo =>
      'Tu sesión se guarda cifrada solo en este dispositivo y solo se envía a YouTube. No se escribe en el registro de Kiji. Al cerrar sesión se borra todo. Kiji no recopila ningún dato tuyo, con o sin sesión.';

  @override
  String get cuenta => 'Cuenta';

  @override
  String sesionIniciada(Object? p0) {
    return 'Sesión iniciada$p0';
  }

  @override
  String get lasCancionesConRestriccionDeEdad =>
      'Las canciones con restricción de edad se piden con tu cuenta.';

  @override
  String get iniciarSesionConGoogle => 'Iniciar sesión con Google';

  @override
  String get cerrarSesionYBorrarla => 'Cerrar sesión y borrarla';

  @override
  String get sesionCerradaYBorrada => 'Sesión cerrada y borrada.';

  @override
  String get ofrecerIniciarSesionCuandoUnaCancion =>
      'Ofrecer iniciar sesión cuando una canción lo necesite';

  @override
  String get comoMuchoUnaVezPorCancion => 'Como mucho una vez por canción.';

  @override
  String get noSePudoCompletarElInicio =>
      'No se pudo completar el inicio de sesión. Prueba de nuevo.';

  @override
  String get estaCancionNecesitaUnaCuenta => 'Esta canción necesita una cuenta';

  @override
  String youtubeMarcoConRestriccionDeEdad(Object? p0, Object? p1) {
    return 'YouTube marcó «$p0» con restricción de edad y solo la entrega a cuentas que iniciaron sesión. Si quieres, puedes iniciar sesión con Google para reproducirla. Es opcional.\n\n$p1';
  }

  @override
  String get noVolverAPreguntar => 'No volver a preguntar';

  @override
  String get iniciarSesion => 'Iniciar sesión';

  @override
  String get esaEsLaCarpetaDeKiji =>
      'Esa es la carpeta de Kiji. Kiji Dev guarda sus copias aparte: elige otra.';

  @override
  String get kijiNoPuedeGuardarEnEsa =>
      'Kiji no puede guardar en esa carpeta. Elige otra.';

  @override
  String noSePudoHacerLaCopia(Object? p0) {
    return 'No se pudo hacer la copia en $p0.';
  }

  @override
  String get elArchivoNoEsUnaCopia =>
      'El archivo no es una copia de Kiji (o es de una versión más nueva).';

  @override
  String get elArchivoEstaDanadoONo =>
      'El archivo está dañado o no es una copia de Kiji.';

  @override
  String get copiaDeSeguridad => 'Copia de seguridad';

  @override
  String get unaCopiaDeTusPlaylistsMe =>
      'Una copia de tus playlists, me gusta, historial, ajustes, carátulas personalizadas y la lista de tus descargas (sin el audio). Es un archivo tuyo, en tu dispositivo: no va a ningún servidor. Se guardan las últimas 7.';

  @override
  String get copiaAutomaticaDiaria => 'Copia automática diaria';

  @override
  String ultimaCopia(Object? p0) {
    return 'Última copia: $p0';
  }

  @override
  String get carpeta => 'Carpeta';

  @override
  String get buscando => 'Buscando…';

  @override
  String get cambiar => 'Cambiar';

  @override
  String get volverALaCarpetaDeFabrica => 'Volver a la carpeta de fábrica';

  @override
  String get noSePudoHacerLaCopia2 => 'No se pudo hacer la copia';

  @override
  String get hacerUnaCopiaAhora => 'Hacer una copia ahora';

  @override
  String get copias => 'COPIAS';

  @override
  String get noHayCopiasEnEstaCarpeta => 'No hay copias en esta carpeta.';

  @override
  String get restaurar => 'Restaurar…';

  @override
  String get restaurarDesdeUnArchivo => 'Restaurar desde un archivo…';

  @override
  String get porEjemploUnaCopiaDeOtro =>
      'Por ejemplo, una copia de otro teléfono o de la PC.';

  @override
  String get carpetaParaLasCopiasDeKiji => 'Carpeta para las copias de Kiji';

  @override
  String lasCopiasSeVanAGuardar(Object? p0) {
    return 'Las copias se van a guardar en $p0';
  }

  @override
  String get eligeUnaCopiaDeKiji => 'Elige una copia de Kiji';

  @override
  String get restaurarEstaCopia => '¿Restaurar esta copia?';

  @override
  String get cancelar => 'Cancelar';

  @override
  String get restaurar2 => 'Restaurar';

  @override
  String noSePudoRestaurar(Object? p0) {
    return 'No se pudo restaurar: $p0';
  }

  @override
  String get listoLoQueTeniasAntesQuedo =>
      'Listo. Lo que tenías antes quedó en una copia \"antes de restaurar\".';

  @override
  String get volverABajarTusDescargas => '¿Volver a bajar tus descargas?';

  @override
  String get cancionesDescargadas => 'canciones descargadas';

  @override
  String laCopiaTieneElAudioNo(Object? p0) {
    return 'La copia tiene $p0. El audio no va en la copia: se puede volver a bajar de YouTube (respeta \"solo con WiFi\").';
  }

  @override
  String get ahoraNo => 'Ahora no';

  @override
  String get volverABajar => 'Volver a bajar';

  @override
  String bajandoLasDemasNo(Object? p0, Object? p1) {
    return 'Bajando $p0. Las demás no: $p1';
  }

  @override
  String get deUnCelularAndroid => ' (de un celular Android)';

  @override
  String get deUnaPcConWindows => ' (de una PC con Windows)';

  @override
  String get meGusta => 'me gusta';

  @override
  String get cancion => 'canción';

  @override
  String get cancionDescargada => 'canción descargada';

  @override
  String get caratulaPersonalizada => 'carátula personalizada';

  @override
  String get caratulasPersonalizadas => 'carátulas personalizadas';

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
    return 'Copia $p0$p1$p2:\n• $p3\n• $p4\n• $p5 en el historial\n• $p6 (el audio se vuelve a bajar)\n$p7\nReemplaza tus playlists, me gusta, historial y ajustes actuales. Antes, Kiji guarda una copia de lo que tienes ahora, así que se puede volver atrás.';
  }

  @override
  String get noSePudoUsarEsaImagen => 'No se pudo usar esa imagen.';

  @override
  String get personalizarCancion => 'Personalizar canción';

  @override
  String get soloCambiaComoSeVeEn =>
      'Solo cambia cómo se ve en Kiji. El archivo de música no se toca.';

  @override
  String get cambiarFoto => 'Cambiar foto';

  @override
  String get titulo => 'Título';

  @override
  String original(Object? p0) {
    return 'Original: $p0';
  }

  @override
  String get artista => 'Artista';

  @override
  String get listo => 'Listo';

  @override
  String get guardar => 'Guardar';

  @override
  String get volvioAComoEra => 'Volvió a como era';

  @override
  String get restaurarOriginal => 'Restaurar original';

  @override
  String get personalizarPlaylist => 'Personalizar playlist';

  @override
  String get nombre => 'Nombre';

  @override
  String get descripcionOpcional => 'Descripción (opcional)';

  @override
  String get color => 'COLOR';

  @override
  String restaurarOriginalSinFotoNiColor(Object? p0) {
    return 'Restaurar original («$p0», sin foto ni color)';
  }

  @override
  String get eligeUnaFoto => 'Elige una foto';

  @override
  String get noSePudoAbrirEsaImagen => 'No se pudo abrir esa imagen.';

  @override
  String get recortar => 'Recortar';

  @override
  String get noSePudoRecortarEsaImagen => 'No se pudo recortar esa imagen.';

  @override
  String kijiBuscoOtraVersionEnYoutube(Object? p0) {
    return '$p0 Kiji buscó otra versión en YouTube Music y no hay.';
  }

  @override
  String get seCortoLaConexionAlReintentar =>
      'Se cortó la conexión. Al reintentar sigue desde donde quedó.';

  @override
  String get youtubeNoEntregoElAudioCon =>
      'YouTube no entregó el audio con ninguna de las formas que probó Kiji. Suele arreglarse solo: reintenta en un rato o busca otra versión.';

  @override
  String get youtubeCortoLaDescargaAMitad =>
      'YouTube cortó la descarga a mitad de camino. Al reintentar se prueba otra forma.';

  @override
  String get noQuedaEspacioEnElDispositivo =>
      'No queda espacio en el dispositivo.';

  @override
  String get noSePudoDescargarReintentaEn =>
      'No se pudo descargar. Reintenta en un rato.';

  @override
  String get tieneRestriccionDeEdadYoutubeNo =>
      'Tiene restricción de edad: YouTube no deja bajarla sin iniciar sesión. Puedes buscar otra versión.';

  @override
  String get youtubeMusicYaNoLaOfrece =>
      'YouTube Music ya no la ofrece (la quitaron o no está en tu país).';

  @override
  String get elVideoEsPrivado => 'El video es privado.';

  @override
  String get elVideoFueBorradoDeYoutube => 'El video fue borrado de YouTube.';

  @override
  String get noEstaDisponibleEnTuPais => 'No está disponible en tu país.';

  @override
  String get descargadas => 'Descargadas';

  @override
  String get borrarTodas => 'Borrar todas';

  @override
  String conErrorVerCuales(Object? p0) {
    return '$p0 con error: ver cuáles';
  }

  @override
  String get descargando => 'Descargando';

  @override
  String get buscaUnaCancionYTocaEl =>
      'Busca una canción y toca el ícono de descarga para escucharla sin conexión.';

  @override
  String get borrarDescarga => 'Borrar descarga';

  @override
  String get borrarTodasLasDescargas => 'Borrar todas las descargas';

  @override
  String get borrarTodasLasDescargas2 => '¿Borrar todas las descargas?';

  @override
  String get descargarSoloConWifi => 'Descargar solo con WiFi';

  @override
  String get noUsaTusDatosMoviles => 'No usa tus datos móviles';

  @override
  String get limiteDeEspacio => 'Límite de espacio';

  @override
  String usadoDe(Object? p0, Object? p1) {
    return 'Usado $p0 de $p1';
  }

  @override
  String get descargada => 'Descargada';

  @override
  String get descargar => 'Descargar';

  @override
  String get noSePudoDescargarVerPor => 'No se pudo descargar: ver por qué';

  @override
  String get cancelarDescarga => 'Cancelar descarga';

  @override
  String get noSePudoDescargar => 'No se pudo descargar.';

  @override
  String get descargarCancion => 'Descargar canción';

  @override
  String teQuedanLibres(Object? p0) {
    return 'Te quedan $p0 libres.';
  }

  @override
  String vaAOcuparSeGuardaDentro(Object? p0, Object? p1, Object? p2) {
    return '«$p0»\n\nVa a ocupar $p1.\n$p2\n\nSe guarda dentro de Kiji, no en tu carpeta de música.';
  }

  @override
  String get cancelarLaDescarga => '¿Cancelar la descarga?';

  @override
  String get seBorraLoQueSeHabia =>
      'Se borra lo que se había bajado de esta canción.';

  @override
  String get seguir => 'Seguir';

  @override
  String get borrarLaDescarga => '¿Borrar la descarga?';

  @override
  String dejaDeOcuparEspacioSiEsta(Object? p0) {
    return '«$p0» deja de ocupar espacio. Si está en tu cola, no se quita: vuelve a sonar desde internet.';
  }

  @override
  String get borrar => 'Borrar';

  @override
  String get enEsperaParaDescargar => 'En espera para descargar';

  @override
  String get laDescargaFallo => 'La descarga falló';

  @override
  String porCiento(Object? p0) {
    return ' $p0 por ciento';
  }

  @override
  String descargando2(Object? p0) {
    return 'Descargando$p0';
  }

  @override
  String get descargandoOtraVez => 'Descargando otra vez…';

  @override
  String get buscarOtraVersion => 'Buscar otra versión';

  @override
  String get noHayOtraVersionDeEsta =>
      'No hay otra versión de esta canción en YouTube Music.';

  @override
  String get iniciarSesionParaBajarla => 'Iniciar sesión para bajarla';

  @override
  String get reintentarPruebaOtrasFormas => 'Reintentar (prueba otras formas)';

  @override
  String get quitarDeLaLista => 'Quitar de la lista';

  @override
  String noSePudieronDescargar(Object? p0) {
    return '$p0 no se pudieron descargar';
  }

  @override
  String get reintentarTodas => 'Reintentar todas';

  @override
  String reintentando(Object? p0) {
    return 'Reintentando $p0';
  }

  @override
  String get parlante => 'Parlante';

  @override
  String get auricularesConCable => 'Auriculares con cable';

  @override
  String get plano => 'Plano';

  @override
  String get masGraves => 'Más graves';

  @override
  String get masAgudos => 'Más agudos';

  @override
  String get voces => 'Voces';

  @override
  String get electronica => 'Electrónica';

  @override
  String get acustica => 'Acústica';

  @override
  String get clasica => 'Clásica';

  @override
  String get nocheSuave => 'Noche (suave)';

  @override
  String get ecualizador2 => 'Ecualizador';

  @override
  String get enLaPcTodaviaNoHay =>
      'En la PC todavía no hay ecualizador: por ahora funciona solo en Android. Lo que elijas aquí se guarda igual.';

  @override
  String get apagadoElSonidoNoCambia => 'Apagado: el sonido no cambia.';

  @override
  String get unPerfilPorDispositivo => 'Un perfil por dispositivo';

  @override
  String elParlanteLosAuricularesConCable(Object? p0) {
    return 'El parlante, los auriculares con cable y el Bluetooth recuerdan cada uno su perfil y cambia solo al conectarlos. Ahora suena: $p0.';
  }

  @override
  String get perfil => 'PERFIL';

  @override
  String get personalizado => 'Personalizado';

  @override
  String get bandas => 'BANDAS';

  @override
  String get enLaPcNoHayBandas =>
      'En la PC no hay bandas para ajustar todavía.';

  @override
  String get sinAlternativa => 'sin alternativa';

  @override
  String get sinConexion => 'Sin conexión';

  @override
  String get ningunaFormaEstaPudiendoBajarCanciones =>
      'Ninguna forma está pudiendo bajar canciones de YouTube ahora. Revisa la Salud del Extractor.';

  @override
  String get falloLaPruebaDiaria => 'Falló la prueba diaria';

  @override
  String elMotorAFallo(Object? p0) {
    return 'El motor A falló ($p0)';
  }

  @override
  String get elMotorANoRespondio => 'El motor A no respondió';

  @override
  String get tieneRestriccionDeEdad => 'Tiene restricción de edad';

  @override
  String get youtubeDiceQueNoEstaDisponible =>
      'YouTube dice que no está disponible';

  @override
  String innertubexNoLaReproduce(Object? p0) {
    return 'InnerTubeX no la reproduce ($p0)';
  }

  @override
  String motorA(Object? p0) {
    return 'Motor A: $p0';
  }

  @override
  String get elMotorANoDioUrl => 'El motor A no dio URL';

  @override
  String laListaHlsNoRespondeHttp(Object? p0) {
    return 'La lista HLS no responde (HTTP $p0)';
  }

  @override
  String youtubeNoDijoElTamanoDel(Object? p0) {
    return 'YouTube no dijo el tamaño del audio (HTTP $p0)';
  }

  @override
  String elUltimoByteNoLlegoHttp(Object? p0) {
    return 'El último byte no llegó (HTTP $p0)';
  }

  @override
  String noSePudoPedirElUltimo(Object? p0) {
    return 'No se pudo pedir el último byte ($p0)';
  }

  @override
  String get falloLaPrueba => 'Falló la prueba';

  @override
  String get sinAudio => 'Sin audio';

  @override
  String get todaviaNoSeProbo => 'Todavía no se probó.';

  @override
  String get cancionesNormalesNingunaFormaFuncionaAho =>
      'Canciones normales: ✗ ninguna forma funciona ahora';

  @override
  String get conRestriccionDeEdadNecesitanCuenta =>
      'Con restricción de edad: necesitan cuenta (no cuentan como falla)';

  @override
  String get fallo => 'falló';

  @override
  String get youtubeCortoElAudioAMitad =>
      'YouTube cortó el audio a mitad de la canción';

  @override
  String get youtubePidioConfirmarQueNoEs =>
      'YouTube pidió confirmar que no es un bot';

  @override
  String get elVideoEsPrivado2 => 'El video es privado';

  @override
  String get elVideoFueBorrado => 'El video fue borrado';

  @override
  String get estaBloqueadoEnTuPais => 'Está bloqueado en tu país';

  @override
  String get sinConexion2 => 'sin conexión';

  @override
  String get requiereCuentaRestriccionDeEdad =>
      '🔞 Requiere cuenta (restricción de edad)';

  @override
  String get noEstaDisponibleEnYoutube => 'No está disponible en YouTube';

  @override
  String get bloqueadaEnTuPais => 'Bloqueada en tu país';

  @override
  String get motorAInnertubex => 'Motor A · InnerTubeX';

  @override
  String get motorBKiji => 'Motor B · Kiji';

  @override
  String get motorCYtDlp => 'Motor C · yt-dlp';

  @override
  String resolvedstreamKbps(Object? p0, Object? p1, Object? p2) {
    return 'ResolvedStream($p0, $p1 kbps$p2)';
  }

  @override
  String noReconozcoElFormatoDeKiji(Object? p0) {
    return 'No reconozco el formato de «$p0». Kiji lee .backup, .m3u, .m3u8 y .csv.';
  }

  @override
  String get elArchivoDeCopiaDeSeguridad =>
      'El archivo de copia de seguridad está dañado.';

  @override
  String get estaCopiaDeSeguridadNoTiene =>
      'Esta copia de seguridad no tiene la base de canciones (song.db).';

  @override
  String get noSePudoLeerLaBase =>
      'No se pudo leer la base de canciones de la copia de seguridad.';

  @override
  String get laBaseNoTieneElFormato =>
      'La base no tiene el formato de Echo / Metrolist.';

  @override
  String laListaNoTieneCanciones(Object? p0) {
    return 'La lista «$p0» no tiene canciones.';
  }

  @override
  String noTieneCanciones(Object? p0) {
    return '«$p0» no tiene canciones.';
  }

  @override
  String noEncontreColumnasDeCancionesEn(Object? p0) {
    return 'No encontré columnas de canciones en «$p0» (busqué \"Track Name\", \"Title\" o \"Video ID\").';
  }

  @override
  String seVanACrear(Object? p0) {
    return 'Se van a crear $p0';
  }

  @override
  String sinEncontrar(Object? p0) {
    return '$p0 sin encontrar';
  }

  @override
  String enElHistorial(Object? p0) {
    return '$p0 en el historial';
  }

  @override
  String tambien(Object? p0) {
    return '. También: $p0';
  }

  @override
  String get artistaDesconocido => 'Artista desconocido';

  @override
  String cancionDeYoutube(Object? p0) {
    return 'Canción de YouTube ($p0)';
  }

  @override
  String get eligeElArchivoDeLaOtra => 'Elige el archivo de la otra app';

  @override
  String get elArchivoNoTieneCancionesPara =>
      'El archivo no tiene canciones para importar.';

  @override
  String get noSePudoLeerElArchivo => 'No se pudo leer el archivo.';

  @override
  String get importacionDeshechaSeQuitoTodoLo =>
      'Importación deshecha: se quitó todo lo que había agregado.';

  @override
  String get importarYExportar => 'Importar y exportar';

  @override
  String get traeTusPlaylistsMeGustaE =>
      'Trae tus playlists, me gusta e historial desde Echo Music, Metrolist, InnerTune u OuterTune (.backup), listas .m3u/.m3u8, o CSV de Exportify (Spotify) y de Google Takeout (YouTube Music). Antes de importar vas a ver qué se agrega; nada de lo que ya tienes se borra ni se cambia.';

  @override
  String get importacionesAnteriores => 'IMPORTACIONES ANTERIORES';

  @override
  String playlistsSinEncontrar(Object? p0, Object? p1, Object? p2) {
    return '$p0 · $p1 playlists · $p2 sin encontrar';
  }

  @override
  String get deshacer => 'Deshacer';

  @override
  String get elegirArchivo => 'Elegir archivo';

  @override
  String leyendo(Object? p0) {
    return 'Leyendo «$p0»…';
  }

  @override
  String buscandoLasCancionesEnKijiDe(Object? p0, Object? p1) {
    return 'Buscando las canciones en Kiji: $p0 de $p1';
  }

  @override
  String vistaPrevia(Object? p0) {
    return 'VISTA PREVIA · $p0';
  }

  @override
  String yMas(Object? p0) {
    return '• y $p0 más';
  }

  @override
  String get siYaTienesUnaPlaylistCon =>
      'Si ya tienes una playlist con el mismo nombre, la nueva se llama \"(importada)\".';

  @override
  String get importar2 => 'Importar';

  @override
  String playlistsCreadasMeGustaYCanciones(Object? p0, Object? p1, Object? p2) {
    return '$p0 playlists creadas, $p1 me gusta y $p2 canciones nuevas en el historial.';
  }

  @override
  String get deshacerLaImportacion => 'Deshacer la importación';

  @override
  String get deshacerLaImportacion2 => '¿Deshacer la importación?';

  @override
  String get seQuitanLasPlaylistsMeGusta =>
      'Se quitan las playlists, me gusta e historial que agregó esa importación. Lo que ya tenías no se toca.';

  @override
  String get exportarTusPlaylists => 'EXPORTAR TUS PLAYLISTS';

  @override
  String get todaviaNoTienesPlaylists => 'Todavía no tienes playlists.';

  @override
  String get eligeUnaCarpetaConMusica => 'Elige una carpeta con música';

  @override
  String get canciones => 'Canciones';

  @override
  String get playlists => 'Playlists';

  @override
  String get carpetas => 'Carpetas';

  @override
  String get eligeLaCarpetaDondeGuardasTu =>
      'Elige la carpeta donde guardas tu música. Kiji solo lee las carpetas que tú elijas.';

  @override
  String get elegirCarpeta => 'Elegir carpeta';

  @override
  String get kijiNecesitaPermisoParaLeerTu =>
      'Kiji necesita permiso para leer tu música local.';

  @override
  String get concederPermiso => 'Conceder permiso';

  @override
  String get noSePudoLeerLaBiblioteca => 'No se pudo leer la biblioteca local.';

  @override
  String get reintentar => 'Reintentar';

  @override
  String get noSeEncontroMusicaEnEste =>
      'No se encontró música en este dispositivo.';

  @override
  String get carpetasQueLeeKiji => 'Carpetas que lee Kiji';

  @override
  String get quitarUnaCarpetaNoBorraNingun =>
      'Quitar una carpeta no borra ningún archivo.';

  @override
  String get dejarDeLeerEstaCarpeta => 'Dejar de leer esta carpeta';

  @override
  String get agregarCarpeta => 'Agregar carpeta';

  @override
  String get espacio => 'ESPACIO';

  @override
  String usadosPorKiji(Object? p0) {
    return '$p0 usados por Kiji';
  }

  @override
  String libresCanciones(Object? p0, Object? p1) {
    return '$p0 libres · $p1 canciones';
  }

  @override
  String get todo => 'Todo';

  @override
  String get local => 'LOCAL';

  @override
  String get elServicioDeLetrasNoRespondio =>
      'el servicio de letras no respondió';

  @override
  String noRespondio(Object? p0) {
    return '$p0 no respondió';
  }

  @override
  String get youlyplusNoRespondio => 'YouLyPlus no respondió';

  @override
  String get youtubeNoRespondio => 'YouTube no respondió';

  @override
  String get incluidaEnElArchivo => 'Incluida en el archivo';

  @override
  String get importadaPorTi => 'Importada por ti';

  @override
  String get subtitulosDeYoutube => 'Subtítulos de YouTube';

  @override
  String get eligeUnaCancion => 'Elige una canción';

  @override
  String get noSePudoBuscarLaLetra => 'No se pudo buscar la letra.';

  @override
  String get instrumental => 'Instrumental ♪';

  @override
  String get noEncontramosLaLetraDeEsta =>
      'No encontramos la letra de esta canción en ninguna fuente.';

  @override
  String get buscarAMano => 'Buscar a mano';

  @override
  String get buscarLaLetraAMano => 'Buscar la letra a mano';

  @override
  String get buscandoEnTodasLasFuentes => 'Buscando en todas las fuentes…';

  @override
  String get tampocoSeEncontroConEsosDatos =>
      'Tampoco se encontró con esos datos.';

  @override
  String get unaFuente => 'una fuente';

  @override
  String encontradaEn(Object? p0) {
    return 'Encontrada en $p0.';
  }

  @override
  String noSePudoBuscar(Object? p0) {
    return 'No se pudo buscar ($p0).';
  }

  @override
  String get eligeUnArchivoLrc => 'Elige un archivo .lrc';

  @override
  String get letraImportada => 'Letra importada.';

  @override
  String get eseArchivoNoTieneUnaLetra =>
      'Ese archivo no tiene una letra que Kiji entienda.';

  @override
  String get cerrarLaLetra => 'Cerrar la letra';

  @override
  String get opcionesDeLaLetra => 'Opciones de la letra';

  @override
  String get traducir => 'Traducir';

  @override
  String get sincronizarAdelantarOAtrasar =>
      'Sincronizar (adelantar o atrasar)';

  @override
  String get compartirLineas => 'Compartir líneas';

  @override
  String fuente(Object? p0) {
    return 'Fuente: $p0';
  }

  @override
  String get laLetraVaDespues => 'La letra va después';

  @override
  String get laLetraVaAntes => 'La letra va antes';

  @override
  String get volverALaCancion => 'Volver a la canción';

  @override
  String get comoTexto => 'Como texto';

  @override
  String get comoImagen => 'Como imagen';

  @override
  String get letraSinSincronizar => 'LETRA SIN SINCRONIZAR';

  @override
  String get historia916 => 'Historia 9:16';

  @override
  String get cuadrado11 => 'Cuadrado 1:1';

  @override
  String get vertical45 => 'Vertical 4:5';

  @override
  String get horizontal169 => 'Horizontal 16:9';

  @override
  String get soloTexto => 'Solo texto';

  @override
  String get portadaDifuminada => 'Portada difuminada';

  @override
  String get colorDeLaCancion => 'Color de la canción';

  @override
  String get oscuro => 'Oscuro';

  @override
  String get traduccion => 'Traducción';

  @override
  String get ambas => 'Ambas';

  @override
  String get compartirComoImagen => 'Compartir como imagen';

  @override
  String get formato => 'Formato';

  @override
  String get fondo => 'Fondo';

  @override
  String get texto => 'Texto';

  @override
  String get logoDeKiji => 'Logo de Kiji';

  @override
  String get compartirImagen => 'Compartir imagen';

  @override
  String get fuenteDeLaLetra => 'Fuente de la letra';

  @override
  String get tocaUnaFuenteQueTengaLa =>
      'Toca una fuente que tenga la letra para usarla en esta canción.';

  @override
  String get buscarConOtroTituloOArtista => 'Buscar con otro título o artista';

  @override
  String get importarUnArchivoLrc => 'Importar un archivo .lrc';

  @override
  String get cambiarElOrdenDeLasFuentes => 'Cambiar el orden de las fuentes';

  @override
  String get sincronizada => 'Sincronizada';

  @override
  String get sinSincronizar => 'Sin sincronizar';

  @override
  String get noLaTiene => 'No la tiene';

  @override
  String get noRespondio2 => 'No respondió';

  @override
  String get apagada => 'Apagada';

  @override
  String get esLaQueVesAhora => 'Es la que ves ahora';

  @override
  String deDeA(Object? p0, Object? p1, Object? p2, Object? p3) {
    return '«$p0» de $p1, de $p2 a $p3';
  }

  @override
  String momentoGuardadoEn(Object? p0) {
    return 'Momento guardado en $p0';
  }

  @override
  String get ver => 'Ver';

  @override
  String get momentos2 => 'Momentos';

  @override
  String get guardaElSegundoExactoDeUna =>
      'Guarda el segundo exacto de una canción (el solo, el estribillo) con el botón \"Momento\" del reproductor. Aparecen aquí para volver a ellos con un toque.';

  @override
  String get repetirEsteTramo => 'Repetir este tramo';

  @override
  String get compartir => 'Compartir';

  @override
  String get seBorroElMomento => 'Se borró el Momento';

  @override
  String tramoDeA(Object? p0, Object? p1) {
    return 'Tramo de $p0 a $p1';
  }

  @override
  String momentoEn(Object? p0) {
    return 'Momento en $p0';
  }

  @override
  String repitiendo(Object? p0, Object? p1) {
    return 'Repitiendo $p0–$p1';
  }

  @override
  String get dejarDeRepetir => 'Dejar de repetir';

  @override
  String repitiendoDeA(Object? p0, Object? p1) {
    return 'Repitiendo de $p0 a $p1';
  }

  @override
  String get guardarUnMomento => 'Guardar un momento';

  @override
  String esteSegundo(Object? p0) {
    return 'Este segundo ($p0)';
  }

  @override
  String get unTramo => 'Un tramo';

  @override
  String deA(Object? p0, Object? p1) {
    return 'De $p0 a $p1';
  }

  @override
  String get vuelveAlPrincipioDelTramoAl =>
      'Vuelve al principio del tramo al llegar al final.';

  @override
  String get meGusta2 => 'Me gusta';

  @override
  String get lasCancionesQueMarcasteCon => 'Las canciones que marcaste con ♥.';

  @override
  String get masEscuchadas => 'Más escuchadas';

  @override
  String get las25QueMasVecesEscuchaste =>
      'Las 25 que más veces escuchaste en Kiji.';

  @override
  String get escuchadasHacePoco => 'Escuchadas hace poco';

  @override
  String get lasUltimas25QueEscuchaste => 'Las últimas 25 que escuchaste.';

  @override
  String get favoritasOlvidadas => 'Favoritas olvidadas';

  @override
  String get conQueNoEscuchasHaceMas =>
      'Con ♥, que no escuchas hace más de un mes.';

  @override
  String get todoLoQueGuardasteParaEscuchar =>
      'Todo lo que guardaste para escuchar sin conexión.';

  @override
  String get nuncaEscuchadas => 'Nunca escuchadas';

  @override
  String get deTuMusicaDelDispositivoLas =>
      'De tu música del dispositivo, las que todavía no escuchaste en Kiji.';

  @override
  String canciones2(Object? p0, Object? p1) {
    return '«$p0» ($p1 canciones)\n';
  }

  @override
  String get reproducir => 'Reproducir';

  @override
  String get aleatorio => 'Aleatorio';

  @override
  String get editar => 'Editar';

  @override
  String get nombreDescripcionYColor => 'Nombre, descripción y color';

  @override
  String get fijarArriba => 'Fijar arriba';

  @override
  String get descargarTodaLaPlaylist => 'Descargar toda la playlist';

  @override
  String get laListaDeCancionesComoTexto => 'La lista de canciones como texto';

  @override
  String get exportar => 'Exportar';

  @override
  String get m3u8OtrasAppsOCsvPlanillas =>
      '.m3u8 (otras apps) o .csv (planillas)';

  @override
  String get borrarLaPlaylist => 'Borrar la playlist';

  @override
  String get sePuedeDeshacer => 'Se puede deshacer';

  @override
  String get exportarComo => 'Exportar como';

  @override
  String get m3u8ParaOtrasAppsDeMusica => '.m3u8 — para otras apps de música';

  @override
  String get csvParaPlanillas => '.csv — para planillas';

  @override
  String get estaPlaylistNoTieneCancionesDe =>
      'Esta playlist no tiene canciones de YouTube para descargar.';

  @override
  String cancionesParaBajar(Object? p0) {
    return '$p0 canciones para bajar.';
  }

  @override
  String yaEstabanDescargadasSeSaltean(Object? p0) {
    return '$p0 ya estaban descargadas: se saltean.';
  }

  @override
  String sonArchivosTuyosNoHaceFalta(Object? p0) {
    return '$p0 son archivos tuyos: no hace falta bajarlas.';
  }

  @override
  String ocupanUnosEstimadoPorLaDuracion(Object? p0) {
    return 'Ocupan unos $p0 (estimado por la duración).';
  }

  @override
  String espacioLibre(Object? p0) {
    return 'Espacio libre: $p0.';
  }

  @override
  String get tienesSoloConWifiSiNo =>
      'Tienes \"solo con WiFi\": si no hay WiFi, la descarga espera en pausa.';

  @override
  String get noEntraEnElEspacioLibre =>
      'No entra en el espacio libre del dispositivo.';

  @override
  String de(Object? p0, Object? p1, Object? p2, Object? p3) {
    return '$p0: $p1 de $p2$p3';
  }

  @override
  String get cerrar => 'Cerrar';

  @override
  String get pausar => 'Pausar';

  @override
  String get verCuales => 'Ver cuáles';

  @override
  String get reintentarLasFallidas => 'Reintentar las fallidas';

  @override
  String get nuevaPlaylist => 'Nueva playlist';

  @override
  String get nombreDeLaPlaylist => 'Nombre de la playlist';

  @override
  String get agregarAPlaylist => 'Agregar a playlist';

  @override
  String seCreo(Object? p0) {
    return 'Se creó «$p0»';
  }

  @override
  String seAgregoA(Object? p0) {
    return 'Se agregó a «$p0»';
  }

  @override
  String get tusPlaylists => 'TUS PLAYLISTS';

  @override
  String get nueva => 'Nueva';

  @override
  String get todaviaNoCreasteNingunaMantenPresionada =>
      'Todavía no creaste ninguna. Mantén presionada una canción → \"Agregar a playlist\".';

  @override
  String get fijada => 'Fijada';

  @override
  String segundosGuardadosDeTusCanciones(Object? p0) {
    return '$p0 segundos guardados de tus canciones';
  }

  @override
  String get listasInteligentesCalculadasEnTuTelefono =>
      'LISTAS INTELIGENTES · CALCULADAS EN TU TELÉFONO';

  @override
  String get masOpciones => 'Más opciones';

  @override
  String get estaPlaylistYaNoExiste => 'Esta playlist ya no existe.';

  @override
  String seBorro(Object? p0) {
    return 'Se borró «$p0»';
  }

  @override
  String get noSePudoDescargar2 => 'No se pudo descargar';

  @override
  String get porQueNoSeDescargo => 'Por qué no se descargó';

  @override
  String get quitarDeLaPlaylist => 'Quitar de la playlist';

  @override
  String seQuito(Object? p0) {
    return 'Se quitó «$p0»';
  }

  @override
  String get arrastrarParaMover => 'Arrastrar para mover';

  @override
  String importadaDe(Object? p0, Object? p1) {
    return '$p0 · importada de $p1';
  }

  @override
  String get ningunaCancionConEsteFiltro => 'Ninguna canción con este filtro.';

  @override
  String deDescargadas(Object? p0, Object? p1) {
    return '$p0 de $p1 descargadas';
  }

  @override
  String conError(Object? p0) {
    return '· $p0 con error';
  }

  @override
  String get todas => 'Todas';

  @override
  String get sinDescargar => 'Sin descargar';

  @override
  String get conError2 => 'Con error';

  @override
  String regla(Object? p0) {
    return 'Regla: $p0';
  }

  @override
  String get porAhoraNoHayCancionesQue =>
      'Por ahora no hay canciones que cumplan la regla.';

  @override
  String get cola => 'Cola';

  @override
  String get eligeUnaCancionParaEmpezar => 'Elige una canción para empezar.';

  @override
  String seQuitoDeLaCola(Object? p0) {
    return 'Se quitó «$p0» de la cola';
  }

  @override
  String get pausarAlTerminarEsta => 'Pausar al terminar esta';

  @override
  String get quitarDeLaCola => 'Quitar de la cola';

  @override
  String get reproducirAContinuacion => 'Reproducir a continuación';

  @override
  String suenaDespuesDeEsta(Object? p0) {
    return '«$p0» suena después de esta';
  }

  @override
  String get agregarALaCola => 'Agregar a la cola';

  @override
  String seAgregoAlFinalDeLa(Object? p0) {
    return '«$p0» se agregó al final de la cola';
  }

  @override
  String get personalizar2 => 'Personalizar';

  @override
  String get fotoTituloYArtistaSoloEn =>
      'Foto, título y artista (solo en Kiji)';

  @override
  String get elTituloYElArtistaEs =>
      'El título y el artista (es un archivo de este dispositivo)';

  @override
  String get elTemporizadorParaCuandoTermineEsta =>
      'El temporizador para cuando termine esta canción';

  @override
  String laMusicaSeVaAPausar(Object? p0) {
    return 'La música se va a pausar al terminar «$p0»';
  }

  @override
  String get reproducirTodo => 'Reproducir todo';

  @override
  String get buscandoMusicaParaTi => 'Buscando música para ti…';

  @override
  String porqueEscuchaste(Object? p0) {
    return 'Porque escuchaste $p0';
  }

  @override
  String get mezclaParaTi => 'Mezcla para ti';

  @override
  String get tusFavoritasNuevas => 'tus favoritas + nuevas';

  @override
  String get descubre => 'Descubre';

  @override
  String get relacionadasDeYoutubeMusic => 'relacionadas de YouTube Music';

  @override
  String get paraEmpezar => 'Para empezar';

  @override
  String get eligeUnEstilo => 'elige un estilo';

  @override
  String get sinConexionLosGenerosAparecenCuando =>
      'Sin conexión: los géneros aparecen cuando vuelva internet.';

  @override
  String get estadosDeAnimo => 'ESTADOS DE ÁNIMO';

  @override
  String get generos => 'GÉNEROS';

  @override
  String get noSePudoCargarRevisaTu => 'No se pudo cargar. Revisa tu conexión.';

  @override
  String seGuardoEnTusPlaylists(Object? p0) {
    return 'Se guardó «$p0» en tus playlists';
  }

  @override
  String get guardarEnKiji => 'Guardar en Kiji';

  @override
  String algoFalloEn(Object? p0) {
    return 'Algo falló en $p0';
  }

  @override
  String get unaCancionNoSePudoReproducir =>
      'Una canción no se pudo reproducir con ninguna forma';

  @override
  String get reproduccion => 'reproducción';

  @override
  String videoCaminosAgotados(Object? p0) {
    return 'video $p0: caminos agotados';
  }

  @override
  String get noSePudoAbrirElNavegador => 'No se pudo abrir el navegador.';

  @override
  String get guardarInforme => 'Guardar informe';

  @override
  String get borrarElRegistro => '¿Borrar el registro?';

  @override
  String get seBorraTodoLoGuardadoSi =>
      'Se borra todo lo guardado. Si el registro está prendido, sigue anotando desde ahora.';

  @override
  String get registrosEInformes => 'Registros e informes';

  @override
  String get elRegistroGuardadoEstaApagadoSolo =>
      'El registro guardado está apagado: solo se usa lo de esta sesión, que se borra al cerrar Kiji.';

  @override
  String get borrarElRegistro2 => 'Borrar el registro';

  @override
  String get erroresDeEstaSesion => 'ERRORES DE ESTA SESIÓN';

  @override
  String get ninguno => 'Ninguno. 🎉';

  @override
  String get elRegistroLoUltimoTalComo =>
      'EL REGISTRO (LO ÚLTIMO, TAL COMO SE MANDA)';

  @override
  String get creditos => 'Créditos';

  @override
  String get noSePudieronLeerLosCreditos => 'No se pudieron leer los créditos.';

  @override
  String get reproductorYAudio => 'Reproductor y audio';

  @override
  String get contenido => 'Contenido';

  @override
  String get letras2 => 'Letras';

  @override
  String get apariencia => 'Apariencia';

  @override
  String get almacenamiento => 'Almacenamiento';

  @override
  String get privacidad => 'Privacidad';

  @override
  String get actualizaciones => 'Actualizaciones';

  @override
  String get acercaDe => 'Acerca de';

  @override
  String get kijiDev => 'Kiji Dev';

  @override
  String get borrarLaBusqueda => 'Borrar la búsqueda';

  @override
  String get noHayNingunaOpcionConEse =>
      'No hay ninguna opción con ese nombre.';

  @override
  String get recordarLaColaAlCerrar => 'Recordar la cola al cerrar';

  @override
  String get alAbrirKijiVolverALa =>
      'Al abrir Kiji, volver a la canción y al segundo donde quedó (en pausa).';

  @override
  String get guardarCola => 'guardar cola';

  @override
  String get alAbrirKijiVuelveALa =>
      'Al abrir Kiji, vuelve a la canción y al segundo donde quedó, en pausa.';

  @override
  String get presetsBandasAManoYUn =>
      'Presets, bandas a mano y un perfil por dispositivo (parlante, auriculares, Bluetooth).';

  @override
  String get apagado => 'Apagado';

  @override
  String get transicionSuaveEntreCanciones =>
      'Transición suave entre canciones';

  @override
  String get elFinalDeUnaCancionY =>
      'El final de una canción y el principio de la siguiente suenan a la vez.';

  @override
  String sElFinalDeUnaCancion(Object? p0) {
    return '$p0 s: el final de una canción y el principio de la siguiente suenan a la vez.';
  }

  @override
  String get transicionSuave => 'Transición suave';

  @override
  String get pausarAlSilenciar => 'Pausar al silenciar';

  @override
  String get siBajasElVolumenACero =>
      'Si bajas el volumen a cero, la música se pausa; al subirlo, sigue.';

  @override
  String get volumenCero => 'volumen cero';

  @override
  String get siBajasElVolumenDelTelefono =>
      'Si bajas el volumen del teléfono a cero, la música se pausa; al subirlo, sigue. Solo en Android.';

  @override
  String get retomarAlConectarElBluetooth => 'Retomar al conectar el Bluetooth';

  @override
  String get alConectarAuricularesOUnParlante =>
      'Al conectar auriculares o un parlante Bluetooth, la canción en pausa sigue sola.';

  @override
  String get alConectarAuricularesOUnParlante2 =>
      'Al conectar auriculares o un parlante Bluetooth, la canción que estaba en pausa sigue sola (como en Echo).';

  @override
  String get ocultarAudiosCortos => 'Ocultar audios cortos';

  @override
  String get noMostrarEnLaBibliotecaLos =>
      'No mostrar en la Biblioteca los audios de menos de 30 segundos.';

  @override
  String get noMuestraEnLaBibliotecaLos =>
      'No muestra en la Biblioteca los audios de menos de 30 segundos (avisos, sonidos de juegos). No borra nada.';

  @override
  String get fuentesDeLetras => 'Fuentes de letras';

  @override
  String get dondeBuscaKijiLasLetrasCada =>
      'Dónde busca Kiji las letras; cada fuente se puede apagar.';

  @override
  String get traduccionDeLetras => 'Traducción de letras';

  @override
  String get enTuTelefonoAnonimaOCon =>
      'En tu teléfono (privada) o con IA (Beta).';

  @override
  String get enTuTelefono => 'en tu teléfono';

  @override
  String al(Object? p0, Object? p1) {
    return 'Al $p0 · $p1';
  }

  @override
  String get reducirAnimaciones => 'Reducir animaciones';

  @override
  String get sinAnimacionesDecorativasComoElAnillo =>
      'Sin animaciones decorativas, como el anillo que respira del botón play.';

  @override
  String get sinAnimacionesDecorativasPorEjemploEl =>
      'Sin animaciones decorativas (por ejemplo, el anillo que respira del botón play).';

  @override
  String get noUsaLosDatosMovilesPara =>
      'No usa los datos móviles para descargar.';

  @override
  String get limiteDeEspacioParaDescargas => 'Límite de espacio para descargas';

  @override
  String usado(Object? p0) {
    return 'Usado: $p0';
  }

  @override
  String get limiteDeLaCache => 'Límite de la caché';

  @override
  String get loQueYaEscuchasteSeGuarda =>
      'Lo que ya escuchaste se guarda para no bajarlo otra vez.';

  @override
  String get loYaEscuchadoSeGuardaPara =>
      'Lo ya escuchado se guarda para no bajarlo otra vez. Lo más viejo se borra solo.';

  @override
  String get vaciarLaCache => 'Vaciar la caché';

  @override
  String get liberaEspacioLasDescargasNoSe =>
      'Libera espacio. Las descargas no se tocan.';

  @override
  String get vaciarLaCache2 => '¿Vaciar la caché?';

  @override
  String get lasCancionesQueYaEscuchasteSe =>
      'Las canciones que ya escuchaste se van a volver a bajar la próxima vez. Las descargas no se tocan.';

  @override
  String get vaciar => 'Vaciar';

  @override
  String get cacheVaciada => 'Caché vaciada';

  @override
  String get ahorroDeDatos => 'Ahorro de datos';

  @override
  String get conDatosMovilesYoutubeSuenaEn =>
      'Con datos móviles, YouTube suena en calidad baja. Con WiFi, en la mejor.';

  @override
  String get conDatosMovilesYoutubeSuenaEn2 =>
      'Con datos móviles, YouTube suena en la calidad más baja (gasta unas 4 veces menos). Con WiFi, siempre en la mejor.';

  @override
  String get verYBorrarDescargas => 'Ver y borrar descargas';

  @override
  String get sinConexion3 => 'sin conexion';

  @override
  String get queGuardaKiji => 'Qué guarda Kiji';

  @override
  String get sinCuentasSinAnunciosYSin =>
      'Sin cuentas, sin anuncios y sin telemetría.';

  @override
  String get sinCuentasSinAnunciosYSin2 =>
      'Sin cuentas, sin anuncios y sin telemetría. Tu cola, tus descargas, tu historial y tus me gusta se guardan solo en este dispositivo.';

  @override
  String get letrasYTraduccion => 'Letras y traducción';

  @override
  String get queSeEnviaAlBuscarO =>
      'Qué se envía al buscar o traducir una letra.';

  @override
  String get alAbrirUnaLetraCadaFuente =>
      'Al abrir una letra, cada fuente recibe solo título, artista, álbum, duración o el id del video. La traducción en el teléfono no envía nada (solo se baja el modelo del idioma, una vez). Gemini es opcional y está apagado: si lo activas, las líneas de la letra van a Google con tu clave, que queda cifrada solo en este dispositivo.';

  @override
  String get actualizacionesYGithub => 'Actualizaciones y GitHub';

  @override
  String get queVeGithubCuandoKijiBusca =>
      'Qué ve GitHub cuando Kiji busca una versión nueva.';

  @override
  String get recomendacionesDeInicio => 'Recomendaciones de Inicio';

  @override
  String get queSeLePideAYoutube =>
      'Qué se le pide a YouTube Music para \"Porque escuchaste\", \"Mezcla\" y \"Descubre\".';

  @override
  String get tuGustoSeCalculaEnEste =>
      'Tu gusto se calcula en este teléfono. A YouTube Music solo se le piden, sin cuenta, las canciones relacionadas con hasta 5 que escuchaste (solo su id). Tu historial no sale de aquí.';

  @override
  String get borrarLasBusquedasRecientes => 'Borrar las búsquedas recientes';

  @override
  String get lasQueAparecenEnBuscarAntes =>
      'Las que aparecen en Buscar antes de escribir.';

  @override
  String guardadasEnEsteDispositivo(Object? p0) {
    return '$p0 guardadas en este dispositivo';
  }

  @override
  String get busquedasBorradas => 'Búsquedas borradas';

  @override
  String get borrarElHistorialDeEscucha => 'Borrar el historial de escucha';

  @override
  String get vaciaEscuchadoRecientementeYParaTi =>
      'Vacía \"Escuchado recientemente\" y \"Para ti\".';

  @override
  String cancionesRecordadas(Object? p0) {
    return '$p0 canciones recordadas';
  }

  @override
  String get borrarElHistorial => '¿Borrar el historial?';

  @override
  String get inicioDejaDeMostrarEscuchadoRecientement =>
      'Inicio deja de mostrar \"Escuchado recientemente\" y \"Para ti\" hasta que vuelvas a escuchar música. No borra canciones ni descargas.';

  @override
  String get historialBorrado => 'Historial borrado';

  @override
  String get datosDelReproductorDeYoutubeGithub =>
      'Datos del reproductor de YouTube (GitHub)';

  @override
  String get queSeConsultaParaPoderDescifrar =>
      'Qué se consulta para poder descifrar el audio.';

  @override
  String get youtubeCambiaSuReproductorCadaPocos =>
      'YouTube cambia su reproductor cada pocos días. Para seguir descifrando el audio, Kiji baja como mucho cada 6 horas una tabla pública (player_configs.json del proyecto libre zemer-cipher, en GitHub), igual que Echo y Metrolist. GitHub ve esa consulta como una visita a una página; no se manda nada tuyo.';

  @override
  String get pruebasAutomaticasDelExtractor =>
      'Pruebas automáticas del extractor';

  @override
  String get cada12HPruebaLasFormas =>
      'Cada 12 h prueba las formas con canciones de control; solo avisa si fallan todas.';

  @override
  String get alAbrirKijiSiPasaron12 =>
      'Al abrir Kiji (si pasaron 12 h), cada 12 h en la PC y una vez por día en Android (solo con WiFi y batería no baja). Usa 3 canciones de control, nunca tus datos. Solo avisa si no funciona ninguna forma.';

  @override
  String get saludDelExtractor => 'Salud del Extractor';

  @override
  String get comoEstaFuncionandoYoutubeHoy =>
      'Cómo está funcionando YouTube hoy.';

  @override
  String get cuentaDeGoogleOpcional => 'Cuenta de Google (opcional)';

  @override
  String get soloParaCancionesQueYoutubeEntrega =>
      'Solo para canciones que YouTube entrega únicamente a cuentas.';

  @override
  String get iniciarSesion2 => 'iniciar sesion';

  @override
  String get cerrarSesion => 'cerrar sesion';

  @override
  String get sesionIniciada2 => 'Sesión iniciada';

  @override
  String get tocaParaVerOCerrarLa => 'Toca para ver o cerrar la sesión.';

  @override
  String get guardarUnRegistroEnEsteDispositivo =>
      'Guardar un registro en este dispositivo';

  @override
  String get ayudaAEntenderUnaFallaSin =>
      'Ayuda a entender una falla. Sin datos personales, ocupa como mucho 1 MB y nunca sale del dispositivo si tú no lo mandas.';

  @override
  String get ofrecerUnInformeCuandoAlgoFalla =>
      'Ofrecer un informe cuando algo falla';

  @override
  String get kijiPreguntaSiQuieresAvisarAl =>
      'Kiji pregunta si quieres avisar al desarrollador. Nunca manda nada solo.';

  @override
  String get verElRegistroYLosInformes => 'Ver el registro y los informes';

  @override
  String get leerElRegistroDescargarUnInforme =>
      'Leer el registro, descargar un informe (.txt) o mandarlo al desarrollador.';

  @override
  String get herramientasDeDesarrollo => 'Herramientas de desarrollo';

  @override
  String get registroEnVivoExtractorCacheY =>
      'Registro en vivo, extractor, caché y descargas.';

  @override
  String get buscarActualizaciones => 'Buscar actualizaciones';

  @override
  String get unaVezPorDiaPreguntaA =>
      'Una vez por día pregunta a GitHub si hay una versión nueva. Nunca baja ni instala nada.';

  @override
  String get unaVezPorDiaPreguntaA2 =>
      'Una vez por día pregunta a GitHub si hay una versión nueva y te muestra sus novedades. Nunca baja ni instala nada por su cuenta.';

  @override
  String get versionDeKiji => 'Versión de Kiji';

  @override
  String get buscarAhoraYVerLasNovedades => 'Buscar ahora y ver las novedades.';

  @override
  String get buscarAhora => 'buscar ahora';

  @override
  String get importarDesdeOtraApp => 'Importar desde otra app';

  @override
  String get echoMetrolistInnertuneOutertuneM3uExport =>
      'Echo, Metrolist, InnerTune, OuterTune, .m3u, Exportify y Google Takeout.';

  @override
  String get playlistsMeGustaEHistorialDe =>
      'Playlists, me gusta e historial de Echo, Metrolist, InnerTune u OuterTune (.backup), .m3u, y CSV de Exportify o Google Takeout. También exportar tus playlists.';

  @override
  String get copiaDeSeguridadDeKiji => 'Copia de seguridad de Kiji';

  @override
  String get copiaDiariaAutomaticaEnDocumentosKiji =>
      'Copia diaria automática en Documentos/Kiji; restaurar con vista previa.';

  @override
  String get copiaAutomaticaApagada => 'Copia automática apagada';

  @override
  String ultima(Object? p0) {
    return 'última: $p0';
  }

  @override
  String get softwareLibreGpl30 => 'Software libre (GPL-3.0).';

  @override
  String canalCompiladaElSoftwareLibreGpl(Object? p0, Object? p1) {
    return 'Canal $p0 · compilada el $p1\nSoftware libre (GPL-3.0). Sin pagos, sin anuncios y sin telemetría.';
  }

  @override
  String get losProyectosLibresEnLosQue =>
      'Los proyectos libres en los que se basa Kiji.';

  @override
  String get temporizadorLaMusicaQuedoEnPausa =>
      'Temporizador: la música quedó en pausa. Que descanses.';

  @override
  String get enUnosMinutos => 'En unos minutos';

  @override
  String get minutos => 'Minutos';

  @override
  String get alTerminarEstaCancion => 'Al terminar esta canción';

  @override
  String get estaCancion => 'Esta canción';

  @override
  String get alTerminarLaCola => 'Al terminar la cola';

  @override
  String get finDeLaCola => 'Fin de la cola';

  @override
  String get hastaUnaCancionDeLaCola => 'Hasta una canción de la cola';

  @override
  String get hastaCancion => 'Hasta canción';

  @override
  String get enUnMomentoExacto => 'En un momento exacto';

  @override
  String get momentoExacto => 'Momento exacto';

  @override
  String get laCancion => 'la canción';

  @override
  String seQuitoDeLaColaEl(Object? p0) {
    return 'Se quitó «$p0» de la cola: el temporizador se apagó.';
  }

  @override
  String get cambioLaCancionElTemporizadorDe =>
      'Cambió la canción: el temporizador de momento exacto se apagó.';

  @override
  String get temporizador => 'Temporizador';

  @override
  String get laMusicaBajaDeAPoco =>
      'La música baja de a poco durante los últimos 30 segundos (o menos, si falta poco) y queda en pausa.';

  @override
  String alTerminar(Object? p0) {
    return 'Al terminar «$p0»';
  }

  @override
  String enElDe(Object? p0, Object? p1) {
    return 'En el $p0 de «$p1»';
  }

  @override
  String get activo => 'ACTIVO';

  @override
  String faltan(Object? p0) {
    return 'Faltan $p0';
  }

  @override
  String get apagarElTemporizador => 'Apagar el temporizador';

  @override
  String get enUnosMinutos2 => 'EN UNOS MINUTOS';

  @override
  String get otroNumeroDeMinutos => 'Otro número de minutos';

  @override
  String get de1A600 => 'De 1 a 600';

  @override
  String get iniciar => 'Iniciar';

  @override
  String get paraHastaUnaCancionEligelaEn =>
      'Para \"hasta una canción\", elígela en la Cola (menú ⋮ → luna).';

  @override
  String get eligeElSegundoDeLaCancion =>
      'Elige el segundo de la canción que suena';

  @override
  String get marcarEnLaOnda => 'Marcar en la onda';

  @override
  String get tocaLaOndaDelReproductorDonde =>
      'Toca la onda del reproductor donde quieres que se pause';

  @override
  String get pausarEnEsteMomento => 'Pausar en este momento';

  @override
  String get eseMomentoYaPasoLaMusica =>
      'Ese momento ya pasó: la música se pausa cuando vuelva ahí (si vuelves atrás o la canción se repite).';

  @override
  String laMusicaSeVaAPausar2(Object? p0, Object? p1) {
    return 'La música se va a pausar en el $p0$p1.';
  }

  @override
  String get tocaLaOndaDondeQuieresQue =>
      'Toca la onda donde quieres que se pause';

  @override
  String get youtubeNoDijoElTamanoDel2 => 'YouTube no dijo el tamaño del audio';

  @override
  String youtubeRechazoElAudioHttpY(Object? p0) {
    return 'YouTube rechazó el audio (HTTP $p0) y no hubo otra URL';
  }

  @override
  String youtubeRechazoElAudioHttp(Object? p0) {
    return 'YouTube rechazó el audio (HTTP $p0)';
  }

  @override
  String get reproduccion2 => 'Reproducción';

  @override
  String get controlesDeLaMusicaQueEsta =>
      'Controles de la música que está sonando';

  @override
  String get sinConexionAInternet => 'Sin conexión a internet.';

  @override
  String get llegasteAlLimiteGratuitoDeGemini =>
      'Llegaste al límite gratuito de Gemini por hoy. Prueba mañana.';

  @override
  String get laClaveNoEsValidaRevisala => 'La clave no es válida. Revisala.';

  @override
  String get googleRechazoLaClaveOEl =>
      'Google rechazó la clave (o el nivel gratuito no está disponible en tu país).';

  @override
  String geminiNoRespondioHttp(Object? p0) {
    return 'Gemini no respondió (HTTP $p0).';
  }

  @override
  String get geminiRespondioAlgoQueKijiNo =>
      'Gemini respondió algo que Kiji no entiende.';

  @override
  String get geminiDevolvioOtraCantidadDeLineas =>
      'Gemini devolvió otra cantidad de líneas. Prueba de nuevo.';

  @override
  String get noSePudoSaberEnQue =>
      'No se pudo saber en qué idioma está la letra.';

  @override
  String laLetraYaEstaEn(Object? p0) {
    return 'La letra ya está en $p0.';
  }

  @override
  String get noSePudoConsultarLaLista =>
      'No se pudo consultar la lista de idiomas (¿sin conexión?).';

  @override
  String todaviaNoHayTraduccionDeA(Object? p0, Object? p1) {
    return 'Todavía no hay traducción de $p0 a $p1.';
  }

  @override
  String get faltaLaClaveDeGeminiConfiguracion =>
      'Falta la clave de Gemini (Configuración → Letras → Traducción).';

  @override
  String get espanol => 'Español';

  @override
  String get ingles => 'Inglés';

  @override
  String get portugues => 'Portugués';

  @override
  String get frances => 'Francés';

  @override
  String get italiano => 'Italiano';

  @override
  String get aleman => 'Alemán';

  @override
  String get neerlandes => 'Neerlandés';

  @override
  String get catalan => 'Catalán';

  @override
  String get polaco => 'Polaco';

  @override
  String get ruso => 'Ruso';

  @override
  String get ucraniano => 'Ucraniano';

  @override
  String get turco => 'Turco';

  @override
  String get arabe => 'Árabe';

  @override
  String get hebreo => 'Hebreo';

  @override
  String get hindi => 'Hindi';

  @override
  String get japones => 'Japonés';

  @override
  String get coreano => 'Coreano';

  @override
  String get chinoSimplificado => 'Chino (simplificado)';

  @override
  String get chinoTradicional => 'Chino (tradicional)';

  @override
  String get indonesio => 'Indonesio';

  @override
  String get vietnamita => 'Vietnamita';

  @override
  String get tailandes => 'Tailandés';

  @override
  String get sueco => 'Sueco';

  @override
  String get danes => 'Danés';

  @override
  String get noruego => 'Noruego';

  @override
  String get fines => 'Finés';

  @override
  String get griego => 'Griego';

  @override
  String get checo => 'Checo';

  @override
  String get rumano => 'Rumano';

  @override
  String get hungaro => 'Húngaro';

  @override
  String get laLetraSeTraduceDentroDe =>
      'La letra se traduce dentro de tu teléfono. No se envía a nadie y no pierdes anonimato. Solo una vez por idioma se descarga el modelo de traducción (el servidor solo sabe que alguien bajó ese idioma, no qué canción). Es buena para entender la letra, aunque a veces suena literal.';

  @override
  String get tituloArtistaAlbumYDuracion => 'título, artista, álbum y duración';

  @override
  String get tituloArtistaAlbumDuracionEId =>
      'título, artista, álbum, duración e id del video';

  @override
  String get tituloYArtista => 'título y artista';

  @override
  String get idDelVideoOTituloArtista =>
      'id del video, o título, artista y duración';

  @override
  String get tituloArtistaYDuracion => 'título, artista y duración';

  @override
  String get idDelVideoAYoutube => 'id del video (a YouTube)';

  @override
  String get idDelVideoAYoutubeMusic => 'id del video (a YouTube Music)';

  @override
  String get kijiBuscaLaLetraPrimeroEn =>
      'Kiji busca la letra primero en el archivo (sin internet) y después en estas fuentes, en este orden, hasta que una la tenga. Arrastra para cambiar el orden. Solo se busca cuando abres la letra, y cada fuente recibe únicamente lo que dice abajo; nada tuyo.';

  @override
  String get arrastrarParaCambiarElOrden => 'Arrastrar para cambiar el orden';

  @override
  String recibe(Object? p0) {
    return 'Recibe: $p0';
  }

  @override
  String get originalYTraduccionSeVenLinea =>
      'Original y traducción se ven línea por línea (en la letra: ⋮ → Traducir la letra). Cada traducción se guarda para no repetirla.';

  @override
  String get traducirAl => 'Traducir al';

  @override
  String get n1EnTuTelefonoAnonimo => '1 · En tu teléfono (anónimo)';

  @override
  String get idiomasBajados => 'IDIOMAS BAJADOS';

  @override
  String get ningunoTodaviaSeBajanSolosAvisando =>
      'Ninguno todavía: se bajan solos (avisando el tamaño) la primera vez que traduces.';

  @override
  String get n2ConIaGemini => '2 · Con IA (Gemini)';

  @override
  String get traducirConGemini => 'Traducir con Gemini';

  @override
  String get apagadoAntesDeActivarloVasA =>
      'Apagado. Antes de activarlo vas a ver qué implica.';

  @override
  String get usarGeminiParaTraducir => 'Usar Gemini para traducir';

  @override
  String get siLoApagasSeTraduceEn =>
      'Si lo apagas, se traduce en el teléfono.';

  @override
  String get pierdesParteDelAnonimatoLasLineas =>
      'Pierdes parte del anonimato: las líneas de la letra se envían a Google, asociadas a tu cuenta de Google (por la clave).';

  @override
  String get enElNivelGratuitoGoogleUsa =>
      'En el nivel gratuito, Google usa ese contenido para mejorar sus productos y personas de Google pueden leerlo (Google dice que lo separa de tu cuenta antes).';

  @override
  String get kijiNoEnviaTuNombreTu =>
      'Kiji NO envía tu nombre, tu historial ni tu biblioteca: solo las líneas de la letra y el idioma de destino.';

  @override
  String get requisitosDeGoogleTener18Anos =>
      'Requisitos de Google: tener 18 años o más. En Europa, Reino Unido y Suiza el nivel gratuito no está permitido para esto.';

  @override
  String get antesDeUsarGemini => 'Antes de usar Gemini';

  @override
  String get queCambiaSiActivasLaTraduccion =>
      'Qué cambia si activas la traducción con Gemini';

  @override
  String get siNoQuieresNadaDeEsto =>
      'Si no quieres nada de esto, la traducción en tu teléfono sigue disponible y es anónima.';

  @override
  String get entiendoActivar => 'Entiendo, activar';

  @override
  String get mejorNo => 'Mejor no';

  @override
  String get pegaLaClavePrimero => 'Pega la clave primero.';

  @override
  String get noSePudoGuardarLaClave =>
      'No se pudo guardar la clave cifrada en este dispositivo.';

  @override
  String get laClaveAndaGuardadaCifrada => 'La clave anda. Guardada cifrada.';

  @override
  String mientrasTantoPuedesTraducirEnEl(Object? p0) {
    return '$p0 Mientras tanto puedes traducir en el teléfono.';
  }

  @override
  String get comoConseguirTuClave => 'CÓMO CONSEGUIR TU CLAVE';

  @override
  String get n1EntraAAistudioGoogleCom =>
      '1. Entra a aistudio.google.com con tu cuenta de Google.';

  @override
  String get abrir => 'Abrir';

  @override
  String get n2TocaGetApiKeyCreate =>
      '2. Toca \"Get API key\" → \"Create API key\" (no pide tarjeta).';

  @override
  String get n3CopiaLaClaveYPegala => '3. Copia la clave y pégala aquí abajo.';

  @override
  String get n4TocaProbar => '4. Toca \"Probar\".';

  @override
  String get n5EligeElModeloKijiRecomienda =>
      '5. Elige el modelo (Kiji recomienda el más liviano, Flash-Lite).';

  @override
  String get claveDeGemini => 'Clave de Gemini';

  @override
  String get pegar => 'Pegar';

  @override
  String get probar => 'Probar';

  @override
  String get borrarClave => 'Borrar clave';

  @override
  String get claveBorradaDeEsteDispositivo =>
      'Clave borrada de este dispositivo.';

  @override
  String get modelo => 'Modelo';

  @override
  String modelo2(Object? p0) {
    return 'Modelo: $p0';
  }

  @override
  String noSePudoTraducir(Object? p0) {
    return 'No se pudo traducir: $p0';
  }

  @override
  String paraTraducirDelEnTuTelefono(Object? p0, Object? p1) {
    return 'Para traducir del $p0 en tu teléfono hace falta bajar $p1 (una sola vez). El servidor solo sabe que alguien bajó ese idioma, no qué canción.';
  }

  @override
  String bajar(Object? p0) {
    return 'Bajar $p0';
  }

  @override
  String get traducirEnElTelefono => 'Traducir en el teléfono';

  @override
  String get recien => 'recién';

  @override
  String haceMin(Object? p0) {
    return 'hace $p0 min';
  }

  @override
  String kiji(Object? p0) {
    return 'Kiji $p0';
  }

  @override
  String get kijiNuncaSeActualizaSoloNi =>
      'Kiji nunca se actualiza solo ni baja nada: la descarga la haces tú desde la página oficial, si quieres.';

  @override
  String get abrirLaPaginaOficial => 'Abrir la página oficial';

  @override
  String hayUnaVersionNueva(Object? p0) {
    return 'Hay una versión nueva: $p0';
  }

  @override
  String ultimaConsulta(Object? p0) {
    return 'Última consulta: $p0.';
  }

  @override
  String get buscarAhora2 => 'Buscar ahora';

  @override
  String get todaviaNoHayVersionesPublicadas =>
      'Todavía no hay versiones publicadas.';

  @override
  String tienesLaUltimaVersion(Object? p0) {
    return 'Tienes la última versión ($p0).';
  }

  @override
  String get noSePudoConsultarRevisaTu =>
      'No se pudo consultar. Revisa tu conexión.';

  @override
  String get sinTitulo => 'Sin título';

  @override
  String get obtenidoOk => 'obtenido OK';

  @override
  String get enLaPcTodaviaNoSe =>
      'En la PC todavía no se pueden reproducir listas HLS';

  @override
  String get noSePudoLeerLaPagina =>
      'No se pudo leer la página del reproductor incrustado';

  @override
  String get enEsteDispositivoNoSePuede =>
      'En este dispositivo no se puede descifrar (no hay WebView)';

  @override
  String get noSePudoUbicarElReproductor =>
      'No se pudo ubicar el reproductor de YouTube';

  @override
  String youtubeRechazoElPedido(Object? p0) {
    return 'YouTube rechazó el pedido ($p0)';
  }

  @override
  String get youtubeRespondioVacio => 'YouTube respondió vacío';

  @override
  String get sinEstado => 'Sin estado';

  @override
  String get sinFormatosDeAudio => 'sin formatos de audio';

  @override
  String get elFormatoNoTraeUrlNi => 'El formato no trae URL ni firma';

  @override
  String get laFirmaCifradaVinoIncompleta => 'La firma cifrada vino incompleta';

  @override
  String get formatoCifradoEnUnaFormaQue =>
      'Formato cifrado en una forma que no descifra';

  @override
  String get sinRespuesta => 'sin respuesta';

  @override
  String noSePudoDescifrarLaFirma(Object? p0) {
    return 'No se pudo descifrar la firma: $p0';
  }

  @override
  String noSePudoTransformarElParametro(Object? p0) {
    return 'No se pudo transformar el parámetro \"n\": $p0';
  }

  @override
  String get youtubeNoEntregoLaListaHls => 'YouTube no entregó la lista HLS';

  @override
  String get laListaHlsNoTraeAudio => 'La lista HLS no trae audio solo';

  @override
  String get laListaDeAudioHlsVino => 'La lista de audio HLS vino vacía';

  @override
  String unSegmentoHlsNoBajaHttp(Object? p0) {
    return 'Un segmento HLS no baja (HTTP $p0)';
  }

  @override
  String laListaHlsFallo(Object? p0) {
    return 'La lista HLS falló: $p0';
  }

  @override
  String get youtubeSoloDejaBajarElPrimer =>
      'YouTube solo deja bajar el primer minuto (HTTP 403 al final del archivo)';

  @override
  String elAudioNoRespondeHttp(Object? p0) {
    return 'El audio no responde (HTTP $p0)';
  }

  @override
  String elAudioNoResponde(Object? p0) {
    return 'El audio no responde ($p0)';
  }

  @override
  String get audioDirectoSinDescifrar => 'Audio directo, sin descifrar.';

  @override
  String get listaHlsDeSegmentosChicosOtro =>
      'Lista HLS de segmentos chicos (otro servidor que VISIONOS directo). No se guarda en la caché.';

  @override
  String get televisorSimpleDescifraConElSolver =>
      'Televisor simple; descifra con el solver y manda un PO token.';

  @override
  String get comoTvhtml5SimplyPeroPidiendoA =>
      'Como TVHTML5_SIMPLY, pero pidiendo a music.youtube.com.';

  @override
  String get entregaSoloElPrimerMibMedido =>
      'Entrega solo el primer MiB (medido con InnerTubeX, 18/10/2026).';

  @override
  String get youtubeRespondeVolverACargarLa =>
      'YouTube responde \"volver a cargar la página\" (InnerTubeX: solo de prueba).';

  @override
  String get televisorDescifraConElSolver =>
      'Televisor; descifra con el solver.';

  @override
  String get youtubeYaNoLeDaFormatos =>
      'YouTube ya no le da formatos de audio (InnerTubeX: NO_PLAYABLE_STREAM).';

  @override
  String get versionViejaDeAndroidVrDe =>
      'Versión vieja de ANDROID_VR, de control.';

  @override
  String get youtubeYaNoLeDaFormatos2 =>
      'YouTube ya no le da formatos de audio (InnerTubeX: rota).';

  @override
  String get sueleDarSoloElPrimerMinuto => 'Suele dar solo el primer minuto.';

  @override
  String get laWebDeYoutubeMusicDescifra =>
      'La web de YouTube Music; descifra con el solver y manda un PO token.';

  @override
  String get elReproductorIncrustadoUsaElVisitor =>
      'El reproductor incrustado; usa el visitor de la página embed (como InnerTubeX 0.8.4).';

  @override
  String get necesitaUnPoTokenLigadoA =>
      'Necesita un PO token ligado a la página, que Kiji no genera (medido el 18/10/2026).';

  @override
  String get laWebParaCelularesDescifraCon =>
      'La web para celulares; descifra con el solver y manda un PO token.';

  @override
  String get enEsteDispositivoNoHayWebview =>
      'En este dispositivo no hay WebView para descifrar';

  @override
  String get aPlaylist => 'A playlist';

  @override
  String get noSePudoAbrirRevisaTu => 'No se pudo abrir. Revisa tu conexión.';

  @override
  String get canciones3 => 'CANCIONES';

  @override
  String get albumesYSingles => 'ÁLBUMES Y SINGLES';

  @override
  String haceH(Object? p0) {
    return 'hace $p0 h';
  }

  @override
  String ultimaPruebaAutomaticaSePruebaCon(Object? p0, Object? p1) {
    return 'Última prueba automática: $p0. Se prueba con $p1 canciones de control, nunca con tu historial; la prueba pide el último byte del audio para descubrir las formas que cortan al minuto.';
  }

  @override
  String get probarTodasLasFormasAhora => 'Probar todas las formas ahora';

  @override
  String formasRetiradasYoutubeYaNoLas(Object? p0) {
    return 'Formas retiradas (YouTube ya no las permite) · $p0';
  }

  @override
  String falloCon(Object? p0, Object? p1) {
    return 'Falló con $p0: $p1';
  }

  @override
  String get sinProbarTodavia => 'Sin probar todavía';

  @override
  String ultimaVezQueAnduvo(Object? p0) {
    return 'Última vez que anduvo: $p0';
  }

  @override
  String ultimoProblema(Object? p0) {
    return 'Último problema: $p0';
  }

  @override
  String noSePudoInstalar(Object? p0) {
    return 'No se pudo instalar: $p0';
  }

  @override
  String get opcionalYSoloEnLaPc =>
      'Opcional y solo en la PC. Si los motores A y B no pueden con una canción, Kiji puede usar yt-dlp, un programa libre muy conocido. Se baja de su página oficial en GitHub (unos 18 MB), se verifica su huella y se actualiza solo una vez por semana. Nada se baja si no lo pides.';

  @override
  String get instalado => 'Instalado';

  @override
  String get quitarYtDlp => 'Quitar yt-dlp';

  @override
  String get bajarYUsarYtDlp18 => 'Bajar y usar yt-dlp (≈18 MB)';

  @override
  String get artistas => 'Artistas';

  @override
  String get albumes => 'Álbumes';

  @override
  String get misArchivos => 'Mis archivos';

  @override
  String get noSePudoBuscarRevisaTu =>
      'No se pudo buscar. Revisa tu conexión a Internet.';

  @override
  String get recientes => 'RECIENTES';

  @override
  String get quitar => 'Quitar';

  @override
  String get tePuedeGustar => 'Te puede gustar';

  @override
  String get segunLoQueEscuchas => 'según lo que escuchas';

  @override
  String get exploraPorEstilo => 'Explora por estilo';

  @override
  String get generosYAnimosDeYoutubeMusic =>
      'géneros y ánimos de YouTube Music';

  @override
  String get noSePudoReproducirEstaCancion =>
      'No se pudo reproducir esta canción.';

  @override
  String get buscarCancionesArtistas => 'Buscar canciones, artistas...';

  @override
  String get sinResultados => 'Sin resultados';

  @override
  String get buscaEntreTuMusicaGuardadaY =>
      'Busca entre tu música guardada y tus descargas';

  @override
  String get noHayCoincidenciasEnTusArchivos =>
      'No hay coincidencias en tus archivos';

  @override
  String get soloSePuedenDescargarCancionesDe =>
      'Solo se pueden descargar canciones de YouTube.';

  @override
  String get estasSinWifiYElegisteDescargar =>
      'Estás sin WiFi y elegiste descargar solo con WiFi. Puedes cambiarlo en Biblioteca → Descargadas.';

  @override
  String get noHayEspacioSuficienteEnEl =>
      'No hay espacio suficiente en el dispositivo.';

  @override
  String get superariaElLimiteDeEspacioPara =>
      'Superaría el límite de espacio para descargas que elegiste. Puedes cambiarlo o borrar descargas en Biblioteca → Descargadas.';

  @override
  String get enPausa => 'En pausa';

  @override
  String terminoAntesDeTiempoEnS(Object? p0, Object? p1) {
    return 'terminó antes de tiempo en $p0 s de $p1 s';
  }

  @override
  String get caminosAgotados => 'caminos agotados';

  @override
  String elVideoTieneRestriccionOEsta(Object? p0) {
    return '«$p0»: el video tiene restricción o está bloqueado; suena su versión «Canción».';
  }

  @override
  String get elAudioNoSePudoAbrir => 'El audio no se pudo abrir';

  @override
  String sinConexionSeguimosConQueEsta(Object? p0) {
    return 'Sin conexión. Seguimos con «$p0», que está guardada en el teléfono.';
  }

  @override
  String get sinConexionLaMusicaQuedoEn =>
      'Sin conexión: la música quedó en pausa. Cuando vuelva internet, toca play.';

  @override
  String get pasamosALaSiguiente => 'Pasamos a la siguiente.';

  @override
  String get youtubeNoEstaDejandoReproducirAhora =>
      'YouTube no está dejando reproducir ahora. Prueba en un rato o escucha tu música guardada.';

  @override
  String noSePudoReproducirPasamosA(Object? p0) {
    return 'No se pudo reproducir «$p0». Pasamos a la siguiente.';
  }

  @override
  String get seCortoDuranteLaReproduccion => 'Se cortó durante la reproducción';

  @override
  String get lasCancionesDeEstaColaYa =>
      'Las canciones de esta cola ya no están en el dispositivo.';

  @override
  String yaNoEstaEnElDispositivo(Object? p0) {
    return '«$p0» ya no está en el dispositivo. Pasamos a la siguiente.';
  }

  @override
  String get lasCancionesDeTuUltimaCola =>
      'Las canciones de tu última cola ya no están en el dispositivo.';

  @override
  String get verDescargadas => 'Ver descargadas';

  @override
  String hayUnaVersionNuevaDeKiji(Object? p0) {
    return 'Hay una versión nueva de Kiji ($p0).';
  }

  @override
  String get buenosDias => 'Buenos días';

  @override
  String get buenasTardes => 'Buenas tardes';

  @override
  String get buenasNoches => 'Buenas noches';

  @override
  String get escuchadoRecientemente => 'Escuchado recientemente';

  @override
  String get tusMasEscuchadas => 'Tus más escuchadas';

  @override
  String get calculadoEnTuTelefono => 'calculado en tu teléfono';

  @override
  String get sinInternet => 'sin internet';

  @override
  String get sigueDondeQuedaste => 'SIGUE DONDE QUEDASTE';

  @override
  String get loQueEscuchesApareceAquiTodo =>
      'Lo que escuches aparece aquí. Todo se calcula en tu teléfono; nada sale de él.';

  @override
  String get buscarMusica => 'Buscar música';

  @override
  String get tusPlaylists2 => 'Tus playlists';

  @override
  String get nueva2 => '+ Nueva';

  @override
  String get tuBiblioteca => 'TU BIBLIOTECA';

  @override
  String get descargadas2 => 'DESCARGADAS';

  @override
  String get minimizar => 'Minimizar';

  @override
  String get reproduciendoDesde => 'REPRODUCIENDO DESDE';

  @override
  String get escucharSinConexion => 'Escuchar sin conexión';

  @override
  String get descargarDentroDeKiji => 'Descargar dentro de Kiji';

  @override
  String get cancionGuardadaEnElDispositivo =>
      'Canción guardada en el dispositivo';

  @override
  String get yaSuenaSinConexion => 'Ya suena sin conexión';

  @override
  String get comoEstaFuncionandoYoutubeHoy2 =>
      'Cómo está funcionando YouTube hoy';

  @override
  String get descargadaSuenaSinConexion => 'Descargada: suena sin conexión';

  @override
  String get repetirApagado => 'Repetir: apagado';

  @override
  String get repetirTodaLaCola => 'Repetir: toda la cola';

  @override
  String get repetirEstaCancion => 'Repetir: esta canción';

  @override
  String get aleatorioApagado => 'Aleatorio: apagado';

  @override
  String get anterior => 'Anterior';

  @override
  String get siguiente => 'Siguiente';

  @override
  String get letra => 'Letra';

  @override
  String temporizadorActivo(Object? p0) {
    return 'Temporizador activo: $p0';
  }

  @override
  String get momento => 'Momento';

  @override
  String get guardarEsteMomento => 'Guardar este momento';

  @override
  String get tusListas => 'TUS LISTAS';

  @override
  String get tusPlaylistsVanAAparecerAqui =>
      'Tus playlists van a aparecer aquí.';

  @override
  String get sinUsarTodavia => 'Sin usar todavía';

  @override
  String get saludDelExtractor2 => 'SALUD DEL EXTRACTOR';

  @override
  String get buscarCancionesArtistas2 => 'Buscar canciones, artistas…';

  @override
  String get aContinuacion => 'A continuación';

  @override
  String volumen(Object? p0) {
    return 'Volumen $p0 %';
  }

  @override
  String get temporizadorActivo2 => 'Temporizador activo';

  @override
  String get mostrarLaCola => 'Mostrar la cola';

  @override
  String get guardarPlaylist => 'Guardar playlist';

  @override
  String seGuardo(Object? p0) {
    return 'Se guardó «$p0»';
  }

  @override
  String get noSePudoGuardarElArchivo => 'No se pudo guardar el archivo.';

  @override
  String get progresoDeLaCancion => 'Progreso de la canción';

  @override
  String get pausaDelTemporizador => 'Pausa del temporizador';

  @override
  String get sinSesion => 'Sin sesión';

  @override
  String get kijiFuncionaSinCuenta =>
      'Kiji funciona entero sin cuenta. Iniciar sesión es opcional y solo sirve para las canciones que YouTube entrega únicamente a cuentas (por ejemplo, con restricción de edad).';

  @override
  String get todaviaNoHayCopias => 'Todavía no hay copias.';

  @override
  String get copiaHecha => 'Copia hecha';

  @override
  String nCancionesDescargadas(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones descargadas',
      one: '1 canción descargada',
    );
    return '$_temp0';
  }

  @override
  String bajandoNCanciones(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bajando $count canciones',
      one: 'Bajando 1 canción',
    );
    return '$_temp0';
  }

  @override
  String hoyA(Object? time) {
    return 'hoy $time';
  }

  @override
  String ayerA(Object? time) {
    return 'ayer $time';
  }

  @override
  String get noEsUnaImagenQueKijiPuedaLeer =>
      'No es una imagen que Kiji pueda leer';

  @override
  String get elArchivoNoTieneUnaLetra =>
      'El archivo no tiene una letra que Kiji entienda';

  @override
  String get puedesBuscarOtraVersionSufijo => ' Puedes buscar otra versión.';

  @override
  String get oBuscaOtraVersionSufijo => ' o busca otra versión';

  @override
  String get unTamanoDesconocido => 'un tamaño desconocido';

  @override
  String get noSePudoSaberElEspacioLibre =>
      'No se pudo saber cuánto espacio libre queda.';

  @override
  String get listoYaEstaDescargada => '¡Listo! Ya está descargada.';

  @override
  String get reintentarIgual => 'Reintentar igual';

  @override
  String get noQuedaNingunaConError => 'No queda ninguna con error. 🎉';

  @override
  String get falloLaDescarga => 'Falló la descarga';

  @override
  String get enCola => 'En cola';

  @override
  String bytesDe(Object? done, Object? total) {
    return '$done de $total';
  }

  @override
  String get todaviaNoDescargasteNada => 'Todavía no descargaste nada';

  @override
  String nCanciones(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones',
      one: '1 canción',
    );
    return '$_temp0';
  }

  @override
  String get sinLimite => 'Sin límite';

  @override
  String get lasBandasAparecenCuandoSuena =>
      'Las bandas aparecen cuando empieza a sonar algo.';

  @override
  String get cortaAntesDelFinal =>
      'Corta antes del final (HTTP 403 en el último byte)';

  @override
  String cancionesNormalesFormas(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Canciones normales: ✓ $count formas funcionando',
      one: 'Canciones normales: ✓ 1 forma funcionando',
    );
    return '$_temp0';
  }

  @override
  String haceNDias(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count días',
      one: 'hace 1 día',
    );
    return '$_temp0';
  }

  @override
  String anduvoCon(Object? song, Object? ms) {
    return 'Anduvo con $song ($ms ms)';
  }

  @override
  String get ytDlpListo =>
      'yt-dlp listo y verificado. Se usa solo si los motores A y B fallan.';

  @override
  String haceNHoras(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count horas',
      one: 'hace 1 hora',
    );
    return '$_temp0';
  }

  @override
  String get sinConexionMinuscula => 'sin conexión';

  @override
  String get ytDlpTardoDemasiado => 'yt-dlp tardó demasiado';

  @override
  String ytDlpFallo(Object? error) {
    return 'yt-dlp falló ($error)';
  }

  @override
  String get ytDlpRespondioAlgoRaro => 'yt-dlp respondió algo raro';

  @override
  String get ytDlpNoDioUrl => 'yt-dlp no dio URL';

  @override
  String get falloEstaForma => 'Falló esta forma';

  @override
  String get googleTakeoutCsv => 'Google Takeout de YouTube Music (.csv)';

  @override
  String noSePudoBuscarLaLetraPorque(Object? reason) {
    return 'No se pudo buscar la letra ($reason). Prueba de nuevo en un rato.';
  }

  @override
  String get quitarLaTraduccion => 'Quitar la traducción';

  @override
  String get elegirLaFuente => 'Elegir la fuente';

  @override
  String get sinDesfase => 'Sin desfase';

  @override
  String get tocaLasLineasQueQuieresCompartir =>
      'Toca las líneas que quieres compartir';

  @override
  String nLineasElegidas(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count líneas elegidas',
      one: '1 línea elegida',
    );
    return '$_temp0';
  }

  @override
  String preguntandoALasFuentes(Object? pending) {
    return 'Preguntando a las fuentes… ($pending)';
  }

  @override
  String get enUso => 'En uso';

  @override
  String momentoDesde(Object? title, Object? artist, Object? at) {
    return '«$title» de $artist, desde el $at';
  }

  @override
  String tramoGuardado(Object? from, Object? to) {
    return 'Tramo guardado: $from–$to';
  }

  @override
  String get playlistSinNombre => 'Playlist sin nombre';

  @override
  String get yaEstanTodasDescargadas => 'Ya están todas descargadas.';

  @override
  String get espacioLibreDesconocido => 'Espacio libre: desconocido.';

  @override
  String nDescargadas(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count descargadas',
      one: '1 descargada',
    );
    return '$_temp0';
  }

  @override
  String nFallaron(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fallaron',
      one: '1 falló',
    );
    return '$_temp0';
  }

  @override
  String conErrorSufijo(Object? count) {
    return ' ($count con error)';
  }

  @override
  String yaEstabaEn(Object? name) {
    return 'Ya estaba en «$name»';
  }

  @override
  String get laColaEstaVacia => 'La cola está vacía';

  @override
  String get esLaUltimaCancionDeLaCola => 'Es la última canción de la cola';

  @override
  String despuesDeEstaN(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones después de esta',
      one: '1 canción después de esta',
    );
    return '$_temp0';
  }

  @override
  String get quitarLaPausaProgramada => 'Quitar la pausa programada';

  @override
  String get conUnEnlaceDeSongLink =>
      'Con un enlace de song.link que abre en cualquier app de música';

  @override
  String elRegistroGuardadoOcupa(Object? size) {
    return 'El registro guardado ocupa $size. No tiene tu nombre, tus cuentas, claves ni direcciones de internet. Solo sale del dispositivo si tú lo mandas.';
  }

  @override
  String nSegundos(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count segundos',
      one: '1 segundo',
    );
    return '$_temp0';
  }

  @override
  String get todasPrendidas => 'Todas prendidas.';

  @override
  String nApagadas(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count apagadas.',
      one: '1 apagada.',
    );
    return '$_temp0';
  }

  @override
  String get conGemini => 'con IA (Beta)';

  @override
  String get privacidadActualizaciones =>
      'Si \"Buscar actualizaciones\" está prendido, una vez por día Kiji le pide a GitHub cuál es la última versión publicada. GitHub ve esa consulta como una visita a una página (tu IP y que es Kiji); no se manda nada tuyo. Se apaga en Configuración → Actualizaciones.';

  @override
  String get soloParaCancionesConCuenta =>
      'Solo para canciones que YouTube entrega únicamente a cuentas.';

  @override
  String get todaviaSinCopias => 'todavía sin copias';

  @override
  String get yaPasoPausaCuandoVuelva => 'Ya pasó: pausa cuando vuelva ahí';

  @override
  String get esperandoEsaCancion => 'Esperando esa canción';

  @override
  String deDuracion(Object? duration) {
    return 'de $duration';
  }

  @override
  String get cuandoVuelvaAhiSufijo => ' (cuando vuelva ahí)';

  @override
  String get motorYModelosDeFirefox =>
      'Motor y modelos de Firefox Translations (Mozilla, licencia MPL-2.0).';

  @override
  String get activadoPierdesAnonimato =>
      'Activado. Pierdes parte del anonimato al usarlo.';

  @override
  String get laClaveAndaSinModelos =>
      'La clave anda, pero no hay modelos de texto.';

  @override
  String get claveGuardadaPegaOtra =>
      'Clave guardada (pega otra para cambiarla)';

  @override
  String get estaVersionNoTraeNotas => 'Esta versión no trae notas.';

  @override
  String get todaviaNoSeConsulto => 'Todavía no se consultó.';

  @override
  String get noSePuedeReproducir => 'no se puede reproducir';

  @override
  String get youtubeNoDejaProbarMotorC =>
      'YouTube no está dejando reproducir ahora. Puedes probar el motor C (yt-dlp) en Configuración → Salud del Extractor.';

  @override
  String get quitarDeMeGusta => 'Quitar de me gusta';

  @override
  String get aleatorioActivado => 'Aleatorio: activado';

  @override
  String youtubeFuncionaNFormas(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'YouTube funciona ($count formas)',
      one: 'YouTube funciona (1 forma)',
    );
    return '$_temp0';
  }

  @override
  String get youtubeConProblemas => 'YouTube con problemas';

  @override
  String get ocultarLaCola => 'Ocultar la cola';

  @override
  String hayVersionNuevaPunto(Object? version) {
    return 'Hay una versión nueva: $version.';
  }

  @override
  String get informeDeKijiPlayer => 'Informe de Kiji Player';

  @override
  String informeVersion(Object? version) {
    return 'Versión: $version';
  }

  @override
  String informeSistema(Object? system) {
    return 'Sistema: $system';
  }

  @override
  String informeFecha(Object? date) {
    return 'Fecha: $date';
  }

  @override
  String informeQuePaso(Object? summary) {
    return 'Qué pasó: $summary';
  }

  @override
  String informeDonde(Object? where) {
    return 'Dónde: $where';
  }

  @override
  String informeDetalle(Object? detail) {
    return 'Detalle: $detail';
  }

  @override
  String get informePila => 'Pila:';

  @override
  String informeRegistro(Object? count) {
    return 'Registro (últimas $count líneas, sin datos personales):';
  }

  @override
  String get informeDeKiji => 'Informe de Kiji';

  @override
  String informeError(Object? summary) {
    return 'Error: $summary';
  }

  @override
  String get laPantalla => 'la pantalla';

  @override
  String seBorranNDelDispositivo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Se borran $count canciones del dispositivo. No se quitan de tu cola: vuelven a sonar desde internet.',
      one: 'Se borra 1 canción del dispositivo. No se quita de tu cola: vuelve a sonar desde internet.',
    );
    return '$_temp0';
  }

  @override
  String encendidoPerfil(Object? profile) {
    return 'Encendido: $profile';
  }

  @override
  String get cable => 'Cable';

  @override
  String perfilDe(Object? profile) {
    return 'PERFIL: $profile';
  }

  @override
  String ahoraLinea(Object? line) {
    return 'Ahora: $line';
  }

  @override
  String get desfijar => 'Desfijar';

  @override
  String get vacio => 'Vacío.';

  @override
  String get no => 'No';

  @override
  String nMin(Object? minutes) {
    return '$minutes min';
  }

  @override
  String get recomendadoSufijo => ' (recomendado)';

  @override
  String get album => 'Álbum';

  @override
  String get probando => 'Probando…';

  @override
  String get idioma => 'Idioma';

  @override
  String get idiomaDescripcion =>
      'Sistema, español o inglés. Cambia al instante.';

  @override
  String get idiomaDelSistema => 'Sistema';

  @override
  String get bienvenidaSaltar => 'Saltar';

  @override
  String get bienvenidaSiguiente => 'Siguiente';

  @override
  String get bienvenidaEmpezar => 'Empezar';

  @override
  String get bienvenidaSilenciar => 'Silenciar';

  @override
  String get bienvenidaActivarSonido => 'Activar el sonido';

  @override
  String get bienvenidaHola => 'Hola';

  @override
  String get bienvenidaSoyKiji => 'Esto es Kiji, tu reproductor de música.';

  @override
  String get bienvenidaEligeTuIdioma => 'Elige tu idioma';

  @override
  String get bienvenidaQueEsKiji => 'Qué es Kiji';

  @override
  String get bienvenidaQueEsKijiNota =>
      'Un reproductor libre, para Android y Windows.';

  @override
  String get bienvenidaTarjeta1Titulo =>
      'Sin anuncios, sin pagos y sin rastreo';

  @override
  String get bienvenidaTarjeta1Texto =>
      'Nada que comprar, nada que te siga. Solo música.';

  @override
  String get bienvenidaTarjeta2Titulo => 'YouTube Music y tu música';

  @override
  String get bienvenidaTarjeta2Texto =>
      'Busca en YouTube Music sin cuenta y escucha también los archivos de tu dispositivo, todo en un solo lugar.';

  @override
  String get bienvenidaTarjeta3Titulo => 'Letras, descargas y temporizador';

  @override
  String get bienvenidaTarjeta3Texto =>
      'Letras sincronizadas (y traducidas), canciones para escuchar sin conexión y un temporizador para dormir.';

  @override
  String get bienvenidaHistoriaTitulo => 'La historia';

  @override
  String get bienvenidaHistoria1 =>
      'Kiji es un proyecto independiente. Nació de algo simple: querer escuchar música tranquilo, sin anuncios que interrumpan y sin tener que pagar ni crear una cuenta.';

  @override
  String get bienvenidaHistoria2 =>
      'Es software libre, con licencia GPL-3.0: el código está abierto para que cualquiera lo lea, lo mejore o aprenda de él.';

  @override
  String get bienvenidaHistoria3 =>
      'Kiji se programa con ayuda de inteligencia artificial, y cada cambio lo revisa y aprueba una persona antes de llegar a ti.';

  @override
  String get bienvenidaHistoria4 =>
      'Gracias a Echo Music y a Metrolist: Kiji aprende mucho de su trabajo libre.';

  @override
  String get bienvenidaAjustaATuGusto => 'A tu gusto';

  @override
  String get bienvenidaOpcionalNota =>
      'Todo esto es opcional. Si no tocas nada, Kiji funciona igual de bien.';

  @override
  String get bienvenidaTraducirLetrasAl => 'Traducir las letras al';

  @override
  String get bienvenidaCalidad => 'Mejor calidad con datos móviles';

  @override
  String get bienvenidaCalidadMejor => 'Siempre la mejor calidad disponible.';

  @override
  String get bienvenidaCalidadAhorro =>
      'Con datos móviles, calidad baja (unas 4 veces menos datos). Con WiFi, la mejor.';

  @override
  String get bienvenidaAhorroDeDatos => 'Descargar solo con WiFi';

  @override
  String get bienvenidaAhorroDeDatosTexto =>
      'Las descargas no usan tus datos móviles.';

  @override
  String get bienvenidaSeCambiaEnConfiguracion =>
      'Se puede cambiar después en Configuración.';

  @override
  String get bienvenidaKijiNoRecopilaNada => 'Kiji no recopila nada';

  @override
  String get bienvenidaPrivacidadTexto =>
      'Sin estadísticas de uso, sin anuncios y sin cuentas obligatorias. Tu música, tu historial y tus ajustes se quedan en este dispositivo.';

  @override
  String bienvenidaPaginaDe(Object? page, Object? total) {
    return 'Página $page de $total';
  }

  @override
  String get verBienvenidaOtraVez => 'Ver bienvenida otra vez';

  @override
  String get verBienvenidaOtraVezTexto => 'Las pantallas del primer inicio.';

  @override
  String get traducirLaLetra => 'Traducir la letra';

  @override
  String get traduccionEnElTelefono => 'Traducción en el teléfono';

  @override
  String get traduccionEnElTelefonoTexto =>
      'Privada: se hace en tu teléfono y, después de bajar el idioma, sin internet.';

  @override
  String get traduccionConIa => 'Traducción con IA';

  @override
  String get traduccionConIaTexto =>
      'Usa Gemini de Google y tu clave. Las líneas de la letra salen del teléfono.';

  @override
  String get traduccionConIaPreparar =>
      'Primero hay que activarla y poner tu clave.';

  @override
  String get beta => 'Beta';

  @override
  String get ajustesDeTraduccion => 'Ajustes de traducción';

  @override
  String nPlaylists(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlists',
      one: '1 playlist',
    );
    return '$_temp0';
  }

  @override
  String nMeGusta(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count me gusta',
      one: '1 me gusta',
    );
    return '$_temp0';
  }

  @override
  String unoYOtro(String a, String b) {
    return '$a y $b';
  }

  @override
  String get copiaArticuloDiaRelativo => 'de ';

  @override
  String get copiaArticuloFecha => 'del ';

  @override
  String get formatoDeHora => 'Formato de hora';

  @override
  String get formatoDeHoraDescripcion =>
      '12 o 24 horas; de fábrica, el del sistema';

  @override
  String horaDelSistema(String ejemplo) {
    return 'Según el sistema ($ejemplo)';
  }

  @override
  String hora12(String ejemplo) {
    return '12 horas ($ejemplo)';
  }

  @override
  String hora24(String ejemplo) {
    return '24 horas ($ejemplo)';
  }

  @override
  String get descargarLoQueMeGusta => 'Descargar lo que me gusta';

  @override
  String get descargarLoQueMeGustaDescripcion =>
      'Al dar me gusta a una canción de YouTube, se baja sola para escucharla sin conexión. Respeta \"solo con WiFi\".';

  @override
  String nEsperandoParaBajarse(int n, String motivo) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n canciones esperan para bajarse: $motivo',
      one: '1 canción espera para bajarse: $motivo',
    );
    return '$_temp0';
  }

  @override
  String nBajandoseSolas(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n canciones por bajarse',
      one: '1 canción por bajarse',
    );
    return '$_temp0';
  }

  @override
  String get tambienLasQueYaTeGustan => '¿También las que ya te gustan?';

  @override
  String tambienLasQueYaTeGustanTexto(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other:
          'Hay $n canciones de YouTube con me gusta que todavía no están descargadas.',
      one: 'Hay 1 canción de YouTube con me gusta que todavía no está descargada.',
    );
    return '$_temp0';
  }

  @override
  String get soloLasNuevas => 'Solo las nuevas';

  @override
  String tambienEsasN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Bajar también esas $n',
      one: 'Bajar también esa',
    );
    return '$_temp0';
  }

  @override
  String get novedadesDeEstaVersion => 'Novedades de esta versión';

  @override
  String novedadesDeEstaVersionDescripcion(String version) {
    return 'Lo que cambió en Kiji $version';
  }

  @override
  String get estaVersionNoTraeNovedades =>
      'Esta versión no trae una lista de novedades.';

  @override
  String get menuLetraLeer => 'Leer';

  @override
  String get menuLetraAjustar => 'Ajustar y compartir';

  @override
  String get menuLetraSincronizar => 'Sincronizar';

  @override
  String get menuLetraBuscarOtra => 'Buscar otra';

  @override
  String get menuLetraImportar => 'Importar .lrc';

  @override
  String get menuLetraElegirFuente => 'Elegir fuente';

  @override
  String get tamanoDeLasLetras => 'Tamaño de las letras';

  @override
  String get tamanoDeLasLetrasDescripcion =>
      'Qué tan grande se ve la letra de las canciones';

  @override
  String get tamanoChico => 'Chico';

  @override
  String get tamanoNormal => 'Normal';

  @override
  String get tamanoGrande => 'Grande';

  @override
  String nSeleccionadas(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n seleccionadas',
      one: '1 seleccionada',
    );
    return '$_temp0';
  }

  @override
  String get seleccionarTodas => 'Seleccionar todas';

  @override
  String get quitarSeleccion => 'Quitar la selección';

  @override
  String get seleccionAPlaylist => 'A playlist';

  @override
  String get seleccionDescargar => 'Descargar';

  @override
  String get seleccionAContinuacion => 'A continuación';

  @override
  String get seleccionAlFinal => 'Al final';

  @override
  String get seleccionMas => 'Más';

  @override
  String get seleccionQuitar => 'Quitar';

  @override
  String get seleccionBorrarDescargas => 'Borrar descargas';

  @override
  String nSuenanDespues(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n canciones suenan después de esta',
      one: '1 canción suena después de esta',
    );
    return '$_temp0';
  }

  @override
  String nAlFinalDeLaCola(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Se agregaron $n canciones al final de la cola',
      one: 'Se agregó 1 canción al final de la cola',
    );
    return '$_temp0';
  }

  @override
  String descargarNCanciones(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '¿Descargar $n canciones?',
      one: '¿Descargar 1 canción?',
    );
    return '$_temp0';
  }

  @override
  String get descargarNCancionesTexto =>
      'Se bajan de a dos, en segundo plano. Si falta el WiFi (con \"solo con WiFi\") o el espacio, esperan y siguen solas.';

  @override
  String nSeSaltean(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ya estaban descargadas o no son de YouTube: se saltean.',
      one: '1 ya estaba descargada o no es de YouTube: se saltea.',
    );
    return '$_temp0';
  }

  @override
  String get nadaParaDescargar => 'Ya están descargadas o no son de YouTube.';

  @override
  String nPorBajarse(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n canciones en camino',
      one: '1 canción en camino',
    );
    return '$_temp0';
  }

  @override
  String nQuitadasDeLaPlaylist(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Se quitaron $n canciones',
      one: 'Se quitó 1 canción',
    );
    return '$_temp0';
  }

  @override
  String borrarNDescargas(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '¿Borrar $n descargas?',
      one: '¿Borrar 1 descarga?',
    );
    return '$_temp0';
  }

  @override
  String get borrarNDescargasTexto =>
      'Se borra solo el audio guardado en Kiji; las canciones siguen en tus playlists y se pueden volver a bajar. Tus archivos de música no se tocan.';

  @override
  String nDescargasBorradas(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Se borraron $n descargas',
      one: 'Se borró 1 descarga',
    );
    return '$_temp0';
  }

  @override
  String get tema => 'Tema';

  @override
  String get temaDescripcion => 'Oscuro, más oscuro (negro puro) o claro';

  @override
  String get temaOscuro => 'Oscuro';

  @override
  String get temaMasOscuro => 'Más oscuro (negro puro)';

  @override
  String get temaClaro => 'Claro';

  @override
  String get colorDeAcento => 'Color de acento';

  @override
  String get colorDeAcentoDescripcion =>
      'El degradado de los botones, la onda y lo elegido';

  @override
  String get acentoNocturne => 'Nocturne (violeta y cian)';

  @override
  String get acentoAurora => 'Aurora (verde y violeta)';

  @override
  String get acentoEmber => 'Brasa (naranja y rosa)';

  @override
  String get acentoMint => 'Menta (verde y celeste)';

  @override
  String get acentoOcean => 'Océano (azul y cian)';

  @override
  String get tipografia => 'Tipografía';

  @override
  String get tipografiaDescripcion =>
      'La del estilo (Space Grotesk en Nocturne, Inter en Grafito, Newsreader e Inter en Papel) o la del sistema';

  @override
  String get tipografiaKiji => 'La de Kiji';

  @override
  String get tipografiaSistema => 'La del sistema';

  @override
  String nEmpiezanASonar(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'No sonaba nada: empiezan a sonar $n canciones',
      one: 'No sonaba nada: empieza a sonar 1 canción',
    );
    return '$_temp0';
  }

  @override
  String get seccionPc => 'En la PC';

  @override
  String get alCerrarLaVentana => 'Al cerrar la ventana';

  @override
  String get alCerrarDescripcion =>
      'Seguir sonando en la bandeja del sistema o cerrar Kiji del todo';

  @override
  String get alCerrarPreguntar => 'Preguntar';

  @override
  String get alCerrarBandeja => 'Minimizar a la bandeja';

  @override
  String get alCerrarSalir => 'Salir de Kiji';

  @override
  String get cerrarDialogoTitulo => '¿Qué hace la ✕?';

  @override
  String get cerrarDialogoTexto =>
      'Kiji puede seguir sonando en la bandeja del sistema, junto al reloj, o cerrarse del todo. Puedes cambiarlo en Configuración → En la PC.';

  @override
  String get bandejaAbrir => 'Abrir Kiji';

  @override
  String get bandejaSalir => 'Salir';

  @override
  String get atajosGlobales => 'Atajos globales';

  @override
  String get atajosGlobalesDescripcion =>
      'Controlan la música aunque Kiji no esté al frente o esté en la bandeja';

  @override
  String get atajoPlayPausa => 'Reproducir o pausar';

  @override
  String get atajoSiguiente => 'Canción siguiente';

  @override
  String get atajoAnterior => 'Canción anterior';

  @override
  String get atajoSinAsignar => 'Sin asignar';

  @override
  String get atajoGrabar =>
      'Presiona la combinación, con Ctrl, Alt, Shift o Win';

  @override
  String get atajoNecesitaModificador =>
      'Tiene que llevar Ctrl, Alt, Shift o Win (o ser una tecla F)';

  @override
  String get atajoEnUso => 'Ese atajo ya lo usa otra acción';

  @override
  String get atajosDeFabrica => 'Volver a los de fábrica';

  @override
  String get atajosAviso =>
      'Si otro programa ya usa la misma combinación, en Kiji no va a funcionar: elige otra.';

  @override
  String get controlesDeWindows => 'Controles multimedia de Windows';

  @override
  String get controlesDeWindowsDescripcion =>
      'La canción aparece en el control de volumen y la pantalla de bloqueo; las teclas multimedia funcionan siempre';

  @override
  String get teclaEspacio => 'Espacio';

  @override
  String get atajoOcupado => 'Otro programa ya usa este atajo: elige otro';

  @override
  String get modoAltoRendimiento => 'Modo alto rendimiento';

  @override
  String get modoAltoRendimientoDescripcion =>
      'Animaciones a la máxima frecuencia de la pantalla, más partículas, desenfoques reales y colores más intensos. Gasta más batería.';

  @override
  String get modoAltoRendimientoGamaBaja =>
      'Este equipo es de gama baja: te conviene dejarlo apagado.';

  @override
  String modoAltoRendimientoPantalla(int hz) {
    return 'Tu pantalla llega a $hz Hz.';
  }

  @override
  String get modoAltoRendimientoConfirmar => '¿Prenderlo igual?';

  @override
  String get modoAltoRendimientoConfirmarTexto =>
      'En este equipo puede ir más lento y gastar más batería. Puedes apagarlo cuando quieras.';

  @override
  String get prenderIgual => 'Prender igual';

  @override
  String get bateriaTitulo => 'Música sin cortes en segundo plano';

  @override
  String get bateriaExplicacion =>
      'Con la pantalla apagada, Android puede frenar a Kiji para ahorrar batería y la música se corta (pasa mucho en Motorola, Xiaomi y Samsung). Si lo permites, Android deja a Kiji seguir sonando. Puedes cambiarlo cuando quieras en Configuración → Reproductor y audio.';

  @override
  String get bateriaPermitir => 'Permitir';

  @override
  String get bateriaActiva =>
      'Listo: Android no frena a Kiji en segundo plano.';

  @override
  String get bateriaPendiente =>
      'Android puede frenar a Kiji con la pantalla apagada. Toca para permitir que siga sonando.';

  @override
  String get buscarEnLaPlaylist => 'Buscar en la playlist';

  @override
  String get borrarBusqueda => 'Borrar la búsqueda';

  @override
  String get estilo => 'Estilo';

  @override
  String get estiloDescripcion => 'Las mismas funciones con otro aspecto';

  @override
  String get estiloPregunta => '¿Cómo quieres que se vea Kiji?';

  @override
  String get estiloPreguntaTexto =>
      'Las funciones son las mismas; solo cambia el aspecto. Puedes cambiarlo cuando quieras en Configuración → Apariencia.';

  @override
  String get estiloNocturne => 'Nocturne';

  @override
  String get estiloNocturneFrase =>
      'Oscuro, con vidrio, brillos y la aurora del color de cada canción.';

  @override
  String get estiloGrafito => 'Grafito';

  @override
  String get estiloGrafitoFrase =>
      'Minimalista y serio: grises, blanco y nada que distraiga.';

  @override
  String get estiloPapel => 'Papel';

  @override
  String get estiloPapelFrase => 'Claro y tranquilo, como leer un libro.';

  @override
  String continuarConEstilo(String estilo) {
    return 'Continuar con $estilo';
  }

  @override
  String get soloEnNocturne => 'Solo en el estilo Nocturne';
}
