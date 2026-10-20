import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// Pestaña principal de la navegación
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get navHome;

  /// Pestaña de búsqueda
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get navSearch;

  /// Pestaña de la biblioteca (música guardada, playlists y descargas)
  ///
  /// In es, this message translates to:
  /// **'Biblioteca'**
  String get navLibrary;

  /// Título de la pantalla de ajustes
  ///
  /// In es, this message translates to:
  /// **'Configuración'**
  String get settingsTitle;

  /// Texto de ayuda del buscador de Configuración
  ///
  /// In es, this message translates to:
  /// **'Buscar una opción…'**
  String get settingsSearchHint;

  /// Título del aviso cuando ocurre un error
  ///
  /// In es, this message translates to:
  /// **'Algo falló en Kiji'**
  String get errorReportTitle;

  /// Texto del aviso de error; summary explica qué falló
  ///
  /// In es, this message translates to:
  /// **'{summary}.\n\n¿Quieres avisarle al desarrollador? Se abre GitHub con un informe ya escrito, sin tu nombre, tus archivos ni tus cuentas. Lo puedes leer antes de enviarlo.'**
  String errorReportBody(String summary);

  /// Botón que abre GitHub con el informe
  ///
  /// In es, this message translates to:
  /// **'Enviar al desarrollador'**
  String get errorReportSend;

  /// Botón que guarda el informe en un archivo
  ///
  /// In es, this message translates to:
  /// **'Descargar informe (.txt)'**
  String get errorReportDownload;

  /// Botón para cerrar el aviso sin hacer nada
  ///
  /// In es, this message translates to:
  /// **'No, gracias'**
  String get errorReportNoThanks;

  /// No description provided for @estable.
  ///
  /// In es, this message translates to:
  /// **'Estable'**
  String get estable;

  /// No description provided for @youtubePuedeLimitarOSuspenderCuentas.
  ///
  /// In es, this message translates to:
  /// **'YouTube puede limitar o suspender cuentas que se usan en apps que no son oficiales. Te recomendamos usar una cuenta secundaria, no la principal.'**
  String get youtubePuedeLimitarOSuspenderCuentas;

  /// No description provided for @tuSesionSeGuardaCifradaSolo.
  ///
  /// In es, this message translates to:
  /// **'Tu sesión se guarda cifrada solo en este dispositivo y solo se envía a YouTube. No se escribe en el registro de Kiji. Al cerrar sesión se borra todo. Kiji no recopila ningún dato tuyo, con o sin sesión.'**
  String get tuSesionSeGuardaCifradaSolo;

  /// No description provided for @cuenta.
  ///
  /// In es, this message translates to:
  /// **'Cuenta'**
  String get cuenta;

  /// No description provided for @sesionIniciada.
  ///
  /// In es, this message translates to:
  /// **'Sesión iniciada{p0}'**
  String sesionIniciada(Object? p0);

  /// No description provided for @lasCancionesConRestriccionDeEdad.
  ///
  /// In es, this message translates to:
  /// **'Las canciones con restricción de edad se piden con tu cuenta.'**
  String get lasCancionesConRestriccionDeEdad;

  /// No description provided for @iniciarSesionConGoogle.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión con Google'**
  String get iniciarSesionConGoogle;

  /// No description provided for @cerrarSesionYBorrarla.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión y borrarla'**
  String get cerrarSesionYBorrarla;

  /// No description provided for @sesionCerradaYBorrada.
  ///
  /// In es, this message translates to:
  /// **'Sesión cerrada y borrada.'**
  String get sesionCerradaYBorrada;

  /// No description provided for @ofrecerIniciarSesionCuandoUnaCancion.
  ///
  /// In es, this message translates to:
  /// **'Ofrecer iniciar sesión cuando una canción lo necesite'**
  String get ofrecerIniciarSesionCuandoUnaCancion;

  /// No description provided for @comoMuchoUnaVezPorCancion.
  ///
  /// In es, this message translates to:
  /// **'Como mucho una vez por canción.'**
  String get comoMuchoUnaVezPorCancion;

  /// No description provided for @noSePudoCompletarElInicio.
  ///
  /// In es, this message translates to:
  /// **'No se pudo completar el inicio de sesión. Prueba de nuevo.'**
  String get noSePudoCompletarElInicio;

  /// No description provided for @estaCancionNecesitaUnaCuenta.
  ///
  /// In es, this message translates to:
  /// **'Esta canción necesita una cuenta'**
  String get estaCancionNecesitaUnaCuenta;

  /// No description provided for @youtubeMarcoConRestriccionDeEdad.
  ///
  /// In es, this message translates to:
  /// **'YouTube marcó «{p0}» con restricción de edad y solo la entrega a cuentas que iniciaron sesión. Si quieres, puedes iniciar sesión con Google para reproducirla. Es opcional.\n\n{p1}'**
  String youtubeMarcoConRestriccionDeEdad(Object? p0, Object? p1);

  /// No description provided for @noVolverAPreguntar.
  ///
  /// In es, this message translates to:
  /// **'No volver a preguntar'**
  String get noVolverAPreguntar;

  /// No description provided for @iniciarSesion.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get iniciarSesion;

  /// No description provided for @esaEsLaCarpetaDeKiji.
  ///
  /// In es, this message translates to:
  /// **'Esa es la carpeta de Kiji. Kiji Dev guarda sus copias aparte: elige otra.'**
  String get esaEsLaCarpetaDeKiji;

  /// No description provided for @kijiNoPuedeGuardarEnEsa.
  ///
  /// In es, this message translates to:
  /// **'Kiji no puede guardar en esa carpeta. Elige otra.'**
  String get kijiNoPuedeGuardarEnEsa;

  /// No description provided for @noSePudoHacerLaCopia.
  ///
  /// In es, this message translates to:
  /// **'No se pudo hacer la copia en {p0}.'**
  String noSePudoHacerLaCopia(Object? p0);

  /// No description provided for @elArchivoNoEsUnaCopia.
  ///
  /// In es, this message translates to:
  /// **'El archivo no es una copia de Kiji (o es de una versión más nueva).'**
  String get elArchivoNoEsUnaCopia;

  /// No description provided for @elArchivoEstaDanadoONo.
  ///
  /// In es, this message translates to:
  /// **'El archivo está dañado o no es una copia de Kiji.'**
  String get elArchivoEstaDanadoONo;

  /// No description provided for @copiaDeSeguridad.
  ///
  /// In es, this message translates to:
  /// **'Copia de seguridad'**
  String get copiaDeSeguridad;

  /// No description provided for @unaCopiaDeTusPlaylistsMe.
  ///
  /// In es, this message translates to:
  /// **'Una copia de tus playlists, me gusta, historial, ajustes, carátulas personalizadas y la lista de tus descargas (sin el audio). Es un archivo tuyo, en tu dispositivo: no va a ningún servidor. Se guardan las últimas 7.'**
  String get unaCopiaDeTusPlaylistsMe;

  /// No description provided for @copiaAutomaticaDiaria.
  ///
  /// In es, this message translates to:
  /// **'Copia automática diaria'**
  String get copiaAutomaticaDiaria;

  /// No description provided for @ultimaCopia.
  ///
  /// In es, this message translates to:
  /// **'Última copia: {p0}'**
  String ultimaCopia(Object? p0);

  /// No description provided for @carpeta.
  ///
  /// In es, this message translates to:
  /// **'Carpeta'**
  String get carpeta;

  /// No description provided for @buscando.
  ///
  /// In es, this message translates to:
  /// **'Buscando…'**
  String get buscando;

  /// No description provided for @cambiar.
  ///
  /// In es, this message translates to:
  /// **'Cambiar'**
  String get cambiar;

  /// No description provided for @volverALaCarpetaDeFabrica.
  ///
  /// In es, this message translates to:
  /// **'Volver a la carpeta de fábrica'**
  String get volverALaCarpetaDeFabrica;

  /// No description provided for @noSePudoHacerLaCopia2.
  ///
  /// In es, this message translates to:
  /// **'No se pudo hacer la copia'**
  String get noSePudoHacerLaCopia2;

  /// No description provided for @hacerUnaCopiaAhora.
  ///
  /// In es, this message translates to:
  /// **'Hacer una copia ahora'**
  String get hacerUnaCopiaAhora;

  /// No description provided for @copias.
  ///
  /// In es, this message translates to:
  /// **'COPIAS'**
  String get copias;

  /// No description provided for @noHayCopiasEnEstaCarpeta.
  ///
  /// In es, this message translates to:
  /// **'No hay copias en esta carpeta.'**
  String get noHayCopiasEnEstaCarpeta;

  /// No description provided for @restaurar.
  ///
  /// In es, this message translates to:
  /// **'Restaurar…'**
  String get restaurar;

  /// No description provided for @restaurarDesdeUnArchivo.
  ///
  /// In es, this message translates to:
  /// **'Restaurar desde un archivo…'**
  String get restaurarDesdeUnArchivo;

  /// No description provided for @porEjemploUnaCopiaDeOtro.
  ///
  /// In es, this message translates to:
  /// **'Por ejemplo, una copia de otro teléfono o de la PC.'**
  String get porEjemploUnaCopiaDeOtro;

  /// No description provided for @carpetaParaLasCopiasDeKiji.
  ///
  /// In es, this message translates to:
  /// **'Carpeta para las copias de Kiji'**
  String get carpetaParaLasCopiasDeKiji;

  /// No description provided for @lasCopiasSeVanAGuardar.
  ///
  /// In es, this message translates to:
  /// **'Las copias se van a guardar en {p0}'**
  String lasCopiasSeVanAGuardar(Object? p0);

  /// No description provided for @eligeUnaCopiaDeKiji.
  ///
  /// In es, this message translates to:
  /// **'Elige una copia de Kiji'**
  String get eligeUnaCopiaDeKiji;

  /// No description provided for @restaurarEstaCopia.
  ///
  /// In es, this message translates to:
  /// **'¿Restaurar esta copia?'**
  String get restaurarEstaCopia;

  /// No description provided for @cancelar.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancelar;

  /// No description provided for @restaurar2.
  ///
  /// In es, this message translates to:
  /// **'Restaurar'**
  String get restaurar2;

  /// No description provided for @noSePudoRestaurar.
  ///
  /// In es, this message translates to:
  /// **'No se pudo restaurar: {p0}'**
  String noSePudoRestaurar(Object? p0);

  /// No description provided for @listoLoQueTeniasAntesQuedo.
  ///
  /// In es, this message translates to:
  /// **'Listo. Lo que tenías antes quedó en una copia \"antes de restaurar\".'**
  String get listoLoQueTeniasAntesQuedo;

  /// No description provided for @volverABajarTusDescargas.
  ///
  /// In es, this message translates to:
  /// **'¿Volver a bajar tus descargas?'**
  String get volverABajarTusDescargas;

  /// No description provided for @cancionesDescargadas.
  ///
  /// In es, this message translates to:
  /// **'canciones descargadas'**
  String get cancionesDescargadas;

  /// No description provided for @laCopiaTieneElAudioNo.
  ///
  /// In es, this message translates to:
  /// **'La copia tiene {p0}. El audio no va en la copia: se puede volver a bajar de YouTube (respeta \"solo con WiFi\").'**
  String laCopiaTieneElAudioNo(Object? p0);

  /// No description provided for @ahoraNo.
  ///
  /// In es, this message translates to:
  /// **'Ahora no'**
  String get ahoraNo;

  /// No description provided for @volverABajar.
  ///
  /// In es, this message translates to:
  /// **'Volver a bajar'**
  String get volverABajar;

  /// No description provided for @bajandoLasDemasNo.
  ///
  /// In es, this message translates to:
  /// **'Bajando {p0}. Las demás no: {p1}'**
  String bajandoLasDemasNo(Object? p0, Object? p1);

  /// No description provided for @deUnCelularAndroid.
  ///
  /// In es, this message translates to:
  /// **' (de un celular Android)'**
  String get deUnCelularAndroid;

  /// No description provided for @deUnaPcConWindows.
  ///
  /// In es, this message translates to:
  /// **' (de una PC con Windows)'**
  String get deUnaPcConWindows;

  /// No description provided for @meGusta.
  ///
  /// In es, this message translates to:
  /// **'me gusta'**
  String get meGusta;

  /// No description provided for @cancion.
  ///
  /// In es, this message translates to:
  /// **'canción'**
  String get cancion;

  /// No description provided for @cancionDescargada.
  ///
  /// In es, this message translates to:
  /// **'canción descargada'**
  String get cancionDescargada;

  /// No description provided for @caratulaPersonalizada.
  ///
  /// In es, this message translates to:
  /// **'carátula personalizada'**
  String get caratulaPersonalizada;

  /// No description provided for @caratulasPersonalizadas.
  ///
  /// In es, this message translates to:
  /// **'carátulas personalizadas'**
  String get caratulasPersonalizadas;

  /// No description provided for @copiaEnElHistorialElAudio.
  ///
  /// In es, this message translates to:
  /// **'Copia {p0}{p1}{p2}:\n• {p3}\n• {p4}\n• {p5} en el historial\n• {p6} (el audio se vuelve a bajar)\n{p7}\nReemplaza tus playlists, me gusta, historial y ajustes actuales. Antes, Kiji guarda una copia de lo que tienes ahora, así que se puede volver atrás.'**
  String copiaEnElHistorialElAudio(
    Object? p0,
    Object? p1,
    Object? p2,
    Object? p3,
    Object? p4,
    Object? p5,
    Object? p6,
    Object? p7,
  );

  /// No description provided for @noSePudoUsarEsaImagen.
  ///
  /// In es, this message translates to:
  /// **'No se pudo usar esa imagen.'**
  String get noSePudoUsarEsaImagen;

  /// No description provided for @personalizarCancion.
  ///
  /// In es, this message translates to:
  /// **'Personalizar canción'**
  String get personalizarCancion;

  /// No description provided for @soloCambiaComoSeVeEn.
  ///
  /// In es, this message translates to:
  /// **'Solo cambia cómo se ve en Kiji. El archivo de música no se toca.'**
  String get soloCambiaComoSeVeEn;

  /// No description provided for @cambiarFoto.
  ///
  /// In es, this message translates to:
  /// **'Cambiar foto'**
  String get cambiarFoto;

  /// No description provided for @titulo.
  ///
  /// In es, this message translates to:
  /// **'Título'**
  String get titulo;

  /// No description provided for @original.
  ///
  /// In es, this message translates to:
  /// **'Original: {p0}'**
  String original(Object? p0);

  /// No description provided for @artista.
  ///
  /// In es, this message translates to:
  /// **'Artista'**
  String get artista;

  /// No description provided for @listo.
  ///
  /// In es, this message translates to:
  /// **'Listo'**
  String get listo;

  /// No description provided for @guardar.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get guardar;

  /// No description provided for @volvioAComoEra.
  ///
  /// In es, this message translates to:
  /// **'Volvió a como era'**
  String get volvioAComoEra;

  /// No description provided for @restaurarOriginal.
  ///
  /// In es, this message translates to:
  /// **'Restaurar original'**
  String get restaurarOriginal;

  /// No description provided for @personalizarPlaylist.
  ///
  /// In es, this message translates to:
  /// **'Personalizar playlist'**
  String get personalizarPlaylist;

  /// No description provided for @nombre.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get nombre;

  /// No description provided for @descripcionOpcional.
  ///
  /// In es, this message translates to:
  /// **'Descripción (opcional)'**
  String get descripcionOpcional;

  /// No description provided for @color.
  ///
  /// In es, this message translates to:
  /// **'COLOR'**
  String get color;

  /// No description provided for @restaurarOriginalSinFotoNiColor.
  ///
  /// In es, this message translates to:
  /// **'Restaurar original («{p0}», sin foto ni color)'**
  String restaurarOriginalSinFotoNiColor(Object? p0);

  /// No description provided for @eligeUnaFoto.
  ///
  /// In es, this message translates to:
  /// **'Elige una foto'**
  String get eligeUnaFoto;

  /// No description provided for @noSePudoAbrirEsaImagen.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir esa imagen.'**
  String get noSePudoAbrirEsaImagen;

  /// No description provided for @recortar.
  ///
  /// In es, this message translates to:
  /// **'Recortar'**
  String get recortar;

  /// No description provided for @noSePudoRecortarEsaImagen.
  ///
  /// In es, this message translates to:
  /// **'No se pudo recortar esa imagen.'**
  String get noSePudoRecortarEsaImagen;

  /// No description provided for @kijiBuscoOtraVersionEnYoutube.
  ///
  /// In es, this message translates to:
  /// **'{p0} Kiji buscó otra versión en YouTube Music y no hay.'**
  String kijiBuscoOtraVersionEnYoutube(Object? p0);

  /// No description provided for @seCortoLaConexionAlReintentar.
  ///
  /// In es, this message translates to:
  /// **'Se cortó la conexión. Al reintentar sigue desde donde quedó.'**
  String get seCortoLaConexionAlReintentar;

  /// No description provided for @youtubeNoEntregoElAudioCon.
  ///
  /// In es, this message translates to:
  /// **'YouTube no entregó el audio con ninguna de las formas que probó Kiji. Suele arreglarse solo: reintenta en un rato o busca otra versión.'**
  String get youtubeNoEntregoElAudioCon;

  /// No description provided for @youtubeCortoLaDescargaAMitad.
  ///
  /// In es, this message translates to:
  /// **'YouTube cortó la descarga a mitad de camino. Al reintentar se prueba otra forma.'**
  String get youtubeCortoLaDescargaAMitad;

  /// No description provided for @noQuedaEspacioEnElDispositivo.
  ///
  /// In es, this message translates to:
  /// **'No queda espacio en el dispositivo.'**
  String get noQuedaEspacioEnElDispositivo;

  /// No description provided for @noSePudoDescargarReintentaEn.
  ///
  /// In es, this message translates to:
  /// **'No se pudo descargar. Reintenta en un rato.'**
  String get noSePudoDescargarReintentaEn;

  /// No description provided for @tieneRestriccionDeEdadYoutubeNo.
  ///
  /// In es, this message translates to:
  /// **'Tiene restricción de edad: YouTube no deja bajarla sin iniciar sesión. Puedes buscar otra versión.'**
  String get tieneRestriccionDeEdadYoutubeNo;

  /// No description provided for @youtubeMusicYaNoLaOfrece.
  ///
  /// In es, this message translates to:
  /// **'YouTube Music ya no la ofrece (la quitaron o no está en tu país).'**
  String get youtubeMusicYaNoLaOfrece;

  /// No description provided for @elVideoEsPrivado.
  ///
  /// In es, this message translates to:
  /// **'El video es privado.'**
  String get elVideoEsPrivado;

  /// No description provided for @elVideoFueBorradoDeYoutube.
  ///
  /// In es, this message translates to:
  /// **'El video fue borrado de YouTube.'**
  String get elVideoFueBorradoDeYoutube;

  /// No description provided for @noEstaDisponibleEnTuPais.
  ///
  /// In es, this message translates to:
  /// **'No está disponible en tu país.'**
  String get noEstaDisponibleEnTuPais;

  /// No description provided for @descargadas.
  ///
  /// In es, this message translates to:
  /// **'Descargadas'**
  String get descargadas;

  /// No description provided for @borrarTodas.
  ///
  /// In es, this message translates to:
  /// **'Borrar todas'**
  String get borrarTodas;

  /// No description provided for @conErrorVerCuales.
  ///
  /// In es, this message translates to:
  /// **'{p0} con error: ver cuáles'**
  String conErrorVerCuales(Object? p0);

  /// No description provided for @descargando.
  ///
  /// In es, this message translates to:
  /// **'Descargando'**
  String get descargando;

  /// No description provided for @buscaUnaCancionYTocaEl.
  ///
  /// In es, this message translates to:
  /// **'Busca una canción y toca el ícono de descarga para escucharla sin conexión.'**
  String get buscaUnaCancionYTocaEl;

  /// No description provided for @borrarDescarga.
  ///
  /// In es, this message translates to:
  /// **'Borrar descarga'**
  String get borrarDescarga;

  /// No description provided for @borrarTodasLasDescargas.
  ///
  /// In es, this message translates to:
  /// **'Borrar todas las descargas'**
  String get borrarTodasLasDescargas;

  /// No description provided for @borrarTodasLasDescargas2.
  ///
  /// In es, this message translates to:
  /// **'¿Borrar todas las descargas?'**
  String get borrarTodasLasDescargas2;

  /// No description provided for @descargarSoloConWifi.
  ///
  /// In es, this message translates to:
  /// **'Descargar solo con WiFi'**
  String get descargarSoloConWifi;

  /// No description provided for @noUsaTusDatosMoviles.
  ///
  /// In es, this message translates to:
  /// **'No usa tus datos móviles'**
  String get noUsaTusDatosMoviles;

  /// No description provided for @limiteDeEspacio.
  ///
  /// In es, this message translates to:
  /// **'Límite de espacio'**
  String get limiteDeEspacio;

  /// No description provided for @usadoDe.
  ///
  /// In es, this message translates to:
  /// **'Usado {p0} de {p1}'**
  String usadoDe(Object? p0, Object? p1);

  /// No description provided for @descargada.
  ///
  /// In es, this message translates to:
  /// **'Descargada'**
  String get descargada;

  /// No description provided for @descargar.
  ///
  /// In es, this message translates to:
  /// **'Descargar'**
  String get descargar;

  /// No description provided for @noSePudoDescargarVerPor.
  ///
  /// In es, this message translates to:
  /// **'No se pudo descargar: ver por qué'**
  String get noSePudoDescargarVerPor;

  /// No description provided for @cancelarDescarga.
  ///
  /// In es, this message translates to:
  /// **'Cancelar descarga'**
  String get cancelarDescarga;

  /// No description provided for @noSePudoDescargar.
  ///
  /// In es, this message translates to:
  /// **'No se pudo descargar.'**
  String get noSePudoDescargar;

  /// No description provided for @descargarCancion.
  ///
  /// In es, this message translates to:
  /// **'Descargar canción'**
  String get descargarCancion;

  /// No description provided for @teQuedanLibres.
  ///
  /// In es, this message translates to:
  /// **'Te quedan {p0} libres.'**
  String teQuedanLibres(Object? p0);

  /// No description provided for @vaAOcuparSeGuardaDentro.
  ///
  /// In es, this message translates to:
  /// **'«{p0}»\n\nVa a ocupar {p1}.\n{p2}\n\nSe guarda dentro de Kiji, no en tu carpeta de música.'**
  String vaAOcuparSeGuardaDentro(Object? p0, Object? p1, Object? p2);

  /// No description provided for @cancelarLaDescarga.
  ///
  /// In es, this message translates to:
  /// **'¿Cancelar la descarga?'**
  String get cancelarLaDescarga;

  /// No description provided for @seBorraLoQueSeHabia.
  ///
  /// In es, this message translates to:
  /// **'Se borra lo que se había bajado de esta canción.'**
  String get seBorraLoQueSeHabia;

  /// No description provided for @seguir.
  ///
  /// In es, this message translates to:
  /// **'Seguir'**
  String get seguir;

  /// No description provided for @borrarLaDescarga.
  ///
  /// In es, this message translates to:
  /// **'¿Borrar la descarga?'**
  String get borrarLaDescarga;

  /// No description provided for @dejaDeOcuparEspacioSiEsta.
  ///
  /// In es, this message translates to:
  /// **'«{p0}» deja de ocupar espacio. Si está en tu cola, no se quita: vuelve a sonar desde internet.'**
  String dejaDeOcuparEspacioSiEsta(Object? p0);

  /// No description provided for @borrar.
  ///
  /// In es, this message translates to:
  /// **'Borrar'**
  String get borrar;

  /// No description provided for @enEsperaParaDescargar.
  ///
  /// In es, this message translates to:
  /// **'En espera para descargar'**
  String get enEsperaParaDescargar;

  /// No description provided for @laDescargaFallo.
  ///
  /// In es, this message translates to:
  /// **'La descarga falló'**
  String get laDescargaFallo;

  /// No description provided for @porCiento.
  ///
  /// In es, this message translates to:
  /// **' {p0} por ciento'**
  String porCiento(Object? p0);

  /// No description provided for @descargando2.
  ///
  /// In es, this message translates to:
  /// **'Descargando{p0}'**
  String descargando2(Object? p0);

  /// No description provided for @descargandoOtraVez.
  ///
  /// In es, this message translates to:
  /// **'Descargando otra vez…'**
  String get descargandoOtraVez;

  /// No description provided for @buscarOtraVersion.
  ///
  /// In es, this message translates to:
  /// **'Buscar otra versión'**
  String get buscarOtraVersion;

  /// No description provided for @noHayOtraVersionDeEsta.
  ///
  /// In es, this message translates to:
  /// **'No hay otra versión de esta canción en YouTube Music.'**
  String get noHayOtraVersionDeEsta;

  /// No description provided for @iniciarSesionParaBajarla.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión para bajarla'**
  String get iniciarSesionParaBajarla;

  /// No description provided for @reintentarPruebaOtrasFormas.
  ///
  /// In es, this message translates to:
  /// **'Reintentar (prueba otras formas)'**
  String get reintentarPruebaOtrasFormas;

  /// No description provided for @quitarDeLaLista.
  ///
  /// In es, this message translates to:
  /// **'Quitar de la lista'**
  String get quitarDeLaLista;

  /// No description provided for @noSePudieronDescargar.
  ///
  /// In es, this message translates to:
  /// **'{p0} no se pudieron descargar'**
  String noSePudieronDescargar(Object? p0);

  /// No description provided for @reintentarTodas.
  ///
  /// In es, this message translates to:
  /// **'Reintentar todas'**
  String get reintentarTodas;

  /// No description provided for @reintentando.
  ///
  /// In es, this message translates to:
  /// **'Reintentando {p0}'**
  String reintentando(Object? p0);

  /// No description provided for @parlante.
  ///
  /// In es, this message translates to:
  /// **'Parlante'**
  String get parlante;

  /// No description provided for @auricularesConCable.
  ///
  /// In es, this message translates to:
  /// **'Auriculares con cable'**
  String get auricularesConCable;

  /// No description provided for @plano.
  ///
  /// In es, this message translates to:
  /// **'Plano'**
  String get plano;

  /// No description provided for @masGraves.
  ///
  /// In es, this message translates to:
  /// **'Más graves'**
  String get masGraves;

  /// No description provided for @masAgudos.
  ///
  /// In es, this message translates to:
  /// **'Más agudos'**
  String get masAgudos;

  /// No description provided for @voces.
  ///
  /// In es, this message translates to:
  /// **'Voces'**
  String get voces;

  /// No description provided for @electronica.
  ///
  /// In es, this message translates to:
  /// **'Electrónica'**
  String get electronica;

  /// No description provided for @acustica.
  ///
  /// In es, this message translates to:
  /// **'Acústica'**
  String get acustica;

  /// No description provided for @clasica.
  ///
  /// In es, this message translates to:
  /// **'Clásica'**
  String get clasica;

  /// No description provided for @nocheSuave.
  ///
  /// In es, this message translates to:
  /// **'Noche (suave)'**
  String get nocheSuave;

  /// No description provided for @ecualizador2.
  ///
  /// In es, this message translates to:
  /// **'Ecualizador'**
  String get ecualizador2;

  /// No description provided for @enLaPcTodaviaNoHay.
  ///
  /// In es, this message translates to:
  /// **'En la PC todavía no hay ecualizador: por ahora funciona solo en Android. Lo que elijas aquí se guarda igual.'**
  String get enLaPcTodaviaNoHay;

  /// No description provided for @apagadoElSonidoNoCambia.
  ///
  /// In es, this message translates to:
  /// **'Apagado: el sonido no cambia.'**
  String get apagadoElSonidoNoCambia;

  /// No description provided for @unPerfilPorDispositivo.
  ///
  /// In es, this message translates to:
  /// **'Un perfil por dispositivo'**
  String get unPerfilPorDispositivo;

  /// No description provided for @elParlanteLosAuricularesConCable.
  ///
  /// In es, this message translates to:
  /// **'El parlante, los auriculares con cable y el Bluetooth recuerdan cada uno su perfil y cambia solo al conectarlos. Ahora suena: {p0}.'**
  String elParlanteLosAuricularesConCable(Object? p0);

  /// No description provided for @perfil.
  ///
  /// In es, this message translates to:
  /// **'PERFIL'**
  String get perfil;

  /// No description provided for @personalizado.
  ///
  /// In es, this message translates to:
  /// **'Personalizado'**
  String get personalizado;

  /// No description provided for @bandas.
  ///
  /// In es, this message translates to:
  /// **'BANDAS'**
  String get bandas;

  /// No description provided for @enLaPcNoHayBandas.
  ///
  /// In es, this message translates to:
  /// **'En la PC no hay bandas para ajustar todavía.'**
  String get enLaPcNoHayBandas;

  /// No description provided for @sinAlternativa.
  ///
  /// In es, this message translates to:
  /// **'sin alternativa'**
  String get sinAlternativa;

  /// No description provided for @sinConexion.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión'**
  String get sinConexion;

  /// No description provided for @ningunaFormaEstaPudiendoBajarCanciones.
  ///
  /// In es, this message translates to:
  /// **'Ninguna forma está pudiendo bajar canciones de YouTube ahora. Revisa la Salud del Extractor.'**
  String get ningunaFormaEstaPudiendoBajarCanciones;

  /// No description provided for @falloLaPruebaDiaria.
  ///
  /// In es, this message translates to:
  /// **'Falló la prueba diaria'**
  String get falloLaPruebaDiaria;

  /// No description provided for @elMotorAFallo.
  ///
  /// In es, this message translates to:
  /// **'El motor A falló ({p0})'**
  String elMotorAFallo(Object? p0);

  /// No description provided for @elMotorANoRespondio.
  ///
  /// In es, this message translates to:
  /// **'El motor A no respondió'**
  String get elMotorANoRespondio;

  /// No description provided for @tieneRestriccionDeEdad.
  ///
  /// In es, this message translates to:
  /// **'Tiene restricción de edad'**
  String get tieneRestriccionDeEdad;

  /// No description provided for @youtubeDiceQueNoEstaDisponible.
  ///
  /// In es, this message translates to:
  /// **'YouTube dice que no está disponible'**
  String get youtubeDiceQueNoEstaDisponible;

  /// No description provided for @innertubexNoLaReproduce.
  ///
  /// In es, this message translates to:
  /// **'InnerTubeX no la reproduce ({p0})'**
  String innertubexNoLaReproduce(Object? p0);

  /// No description provided for @motorA.
  ///
  /// In es, this message translates to:
  /// **'Motor A: {p0}'**
  String motorA(Object? p0);

  /// No description provided for @elMotorANoDioUrl.
  ///
  /// In es, this message translates to:
  /// **'El motor A no dio URL'**
  String get elMotorANoDioUrl;

  /// No description provided for @laListaHlsNoRespondeHttp.
  ///
  /// In es, this message translates to:
  /// **'La lista HLS no responde (HTTP {p0})'**
  String laListaHlsNoRespondeHttp(Object? p0);

  /// No description provided for @youtubeNoDijoElTamanoDel.
  ///
  /// In es, this message translates to:
  /// **'YouTube no dijo el tamaño del audio (HTTP {p0})'**
  String youtubeNoDijoElTamanoDel(Object? p0);

  /// No description provided for @elUltimoByteNoLlegoHttp.
  ///
  /// In es, this message translates to:
  /// **'El último byte no llegó (HTTP {p0})'**
  String elUltimoByteNoLlegoHttp(Object? p0);

  /// No description provided for @noSePudoPedirElUltimo.
  ///
  /// In es, this message translates to:
  /// **'No se pudo pedir el último byte ({p0})'**
  String noSePudoPedirElUltimo(Object? p0);

  /// No description provided for @falloLaPrueba.
  ///
  /// In es, this message translates to:
  /// **'Falló la prueba'**
  String get falloLaPrueba;

  /// No description provided for @sinAudio.
  ///
  /// In es, this message translates to:
  /// **'Sin audio'**
  String get sinAudio;

  /// No description provided for @todaviaNoSeProbo.
  ///
  /// In es, this message translates to:
  /// **'Todavía no se probó.'**
  String get todaviaNoSeProbo;

  /// No description provided for @cancionesNormalesNingunaFormaFuncionaAho.
  ///
  /// In es, this message translates to:
  /// **'Canciones normales: ✗ ninguna forma funciona ahora'**
  String get cancionesNormalesNingunaFormaFuncionaAho;

  /// No description provided for @conRestriccionDeEdadNecesitanCuenta.
  ///
  /// In es, this message translates to:
  /// **'Con restricción de edad: necesitan cuenta (no cuentan como falla)'**
  String get conRestriccionDeEdadNecesitanCuenta;

  /// No description provided for @fallo.
  ///
  /// In es, this message translates to:
  /// **'falló'**
  String get fallo;

  /// No description provided for @youtubeCortoElAudioAMitad.
  ///
  /// In es, this message translates to:
  /// **'YouTube cortó el audio a mitad de la canción'**
  String get youtubeCortoElAudioAMitad;

  /// No description provided for @youtubePidioConfirmarQueNoEs.
  ///
  /// In es, this message translates to:
  /// **'YouTube pidió confirmar que no es un bot'**
  String get youtubePidioConfirmarQueNoEs;

  /// No description provided for @elVideoEsPrivado2.
  ///
  /// In es, this message translates to:
  /// **'El video es privado'**
  String get elVideoEsPrivado2;

  /// No description provided for @elVideoFueBorrado.
  ///
  /// In es, this message translates to:
  /// **'El video fue borrado'**
  String get elVideoFueBorrado;

  /// No description provided for @estaBloqueadoEnTuPais.
  ///
  /// In es, this message translates to:
  /// **'Está bloqueado en tu país'**
  String get estaBloqueadoEnTuPais;

  /// No description provided for @sinConexion2.
  ///
  /// In es, this message translates to:
  /// **'sin conexión'**
  String get sinConexion2;

  /// No description provided for @requiereCuentaRestriccionDeEdad.
  ///
  /// In es, this message translates to:
  /// **'🔞 Requiere cuenta (restricción de edad)'**
  String get requiereCuentaRestriccionDeEdad;

  /// No description provided for @noEstaDisponibleEnYoutube.
  ///
  /// In es, this message translates to:
  /// **'No está disponible en YouTube'**
  String get noEstaDisponibleEnYoutube;

  /// No description provided for @bloqueadaEnTuPais.
  ///
  /// In es, this message translates to:
  /// **'Bloqueada en tu país'**
  String get bloqueadaEnTuPais;

  /// No description provided for @motorAInnertubex.
  ///
  /// In es, this message translates to:
  /// **'Motor A · InnerTubeX'**
  String get motorAInnertubex;

  /// No description provided for @motorBKiji.
  ///
  /// In es, this message translates to:
  /// **'Motor B · Kiji'**
  String get motorBKiji;

  /// No description provided for @motorCYtDlp.
  ///
  /// In es, this message translates to:
  /// **'Motor C · yt-dlp'**
  String get motorCYtDlp;

  /// No description provided for @resolvedstreamKbps.
  ///
  /// In es, this message translates to:
  /// **'ResolvedStream({p0}, {p1} kbps{p2})'**
  String resolvedstreamKbps(Object? p0, Object? p1, Object? p2);

  /// No description provided for @noReconozcoElFormatoDeKiji.
  ///
  /// In es, this message translates to:
  /// **'No reconozco el formato de «{p0}». Kiji lee .backup, .m3u, .m3u8 y .csv.'**
  String noReconozcoElFormatoDeKiji(Object? p0);

  /// No description provided for @elArchivoDeCopiaDeSeguridad.
  ///
  /// In es, this message translates to:
  /// **'El archivo de copia de seguridad está dañado.'**
  String get elArchivoDeCopiaDeSeguridad;

  /// No description provided for @estaCopiaDeSeguridadNoTiene.
  ///
  /// In es, this message translates to:
  /// **'Esta copia de seguridad no tiene la base de canciones (song.db).'**
  String get estaCopiaDeSeguridadNoTiene;

  /// No description provided for @noSePudoLeerLaBase.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer la base de canciones de la copia de seguridad.'**
  String get noSePudoLeerLaBase;

  /// No description provided for @laBaseNoTieneElFormato.
  ///
  /// In es, this message translates to:
  /// **'La base no tiene el formato de Echo / Metrolist.'**
  String get laBaseNoTieneElFormato;

  /// No description provided for @laListaNoTieneCanciones.
  ///
  /// In es, this message translates to:
  /// **'La lista «{p0}» no tiene canciones.'**
  String laListaNoTieneCanciones(Object? p0);

  /// No description provided for @noTieneCanciones.
  ///
  /// In es, this message translates to:
  /// **'«{p0}» no tiene canciones.'**
  String noTieneCanciones(Object? p0);

  /// No description provided for @noEncontreColumnasDeCancionesEn.
  ///
  /// In es, this message translates to:
  /// **'No encontré columnas de canciones en «{p0}» (busqué \"Track Name\", \"Title\" o \"Video ID\").'**
  String noEncontreColumnasDeCancionesEn(Object? p0);

  /// No description provided for @seVanACrear.
  ///
  /// In es, this message translates to:
  /// **'Se van a crear {p0}'**
  String seVanACrear(Object? p0);

  /// No description provided for @sinEncontrar.
  ///
  /// In es, this message translates to:
  /// **'{p0} sin encontrar'**
  String sinEncontrar(Object? p0);

  /// No description provided for @enElHistorial.
  ///
  /// In es, this message translates to:
  /// **'{p0} en el historial'**
  String enElHistorial(Object? p0);

  /// No description provided for @tambien.
  ///
  /// In es, this message translates to:
  /// **'. También: {p0}'**
  String tambien(Object? p0);

  /// No description provided for @artistaDesconocido.
  ///
  /// In es, this message translates to:
  /// **'Artista desconocido'**
  String get artistaDesconocido;

  /// No description provided for @cancionDeYoutube.
  ///
  /// In es, this message translates to:
  /// **'Canción de YouTube ({p0})'**
  String cancionDeYoutube(Object? p0);

  /// No description provided for @eligeElArchivoDeLaOtra.
  ///
  /// In es, this message translates to:
  /// **'Elige el archivo de la otra app'**
  String get eligeElArchivoDeLaOtra;

  /// No description provided for @elArchivoNoTieneCancionesPara.
  ///
  /// In es, this message translates to:
  /// **'El archivo no tiene canciones para importar.'**
  String get elArchivoNoTieneCancionesPara;

  /// No description provided for @noSePudoLeerElArchivo.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer el archivo.'**
  String get noSePudoLeerElArchivo;

  /// No description provided for @importacionDeshechaSeQuitoTodoLo.
  ///
  /// In es, this message translates to:
  /// **'Importación deshecha: se quitó todo lo que había agregado.'**
  String get importacionDeshechaSeQuitoTodoLo;

  /// No description provided for @importarYExportar.
  ///
  /// In es, this message translates to:
  /// **'Importar y exportar'**
  String get importarYExportar;

  /// No description provided for @traeTusPlaylistsMeGustaE.
  ///
  /// In es, this message translates to:
  /// **'Trae tus playlists, me gusta e historial desde Echo Music, Metrolist, InnerTune u OuterTune (.backup), listas .m3u/.m3u8, o CSV de Exportify (Spotify) y de Google Takeout (YouTube Music). Antes de importar vas a ver qué se agrega; nada de lo que ya tienes se borra ni se cambia.'**
  String get traeTusPlaylistsMeGustaE;

  /// No description provided for @importacionesAnteriores.
  ///
  /// In es, this message translates to:
  /// **'IMPORTACIONES ANTERIORES'**
  String get importacionesAnteriores;

  /// No description provided for @playlistsSinEncontrar.
  ///
  /// In es, this message translates to:
  /// **'{p0} · {p1} playlists · {p2} sin encontrar'**
  String playlistsSinEncontrar(Object? p0, Object? p1, Object? p2);

  /// No description provided for @deshacer.
  ///
  /// In es, this message translates to:
  /// **'Deshacer'**
  String get deshacer;

  /// No description provided for @elegirArchivo.
  ///
  /// In es, this message translates to:
  /// **'Elegir archivo'**
  String get elegirArchivo;

  /// No description provided for @leyendo.
  ///
  /// In es, this message translates to:
  /// **'Leyendo «{p0}»…'**
  String leyendo(Object? p0);

  /// No description provided for @buscandoLasCancionesEnKijiDe.
  ///
  /// In es, this message translates to:
  /// **'Buscando las canciones en Kiji: {p0} de {p1}'**
  String buscandoLasCancionesEnKijiDe(Object? p0, Object? p1);

  /// No description provided for @vistaPrevia.
  ///
  /// In es, this message translates to:
  /// **'VISTA PREVIA · {p0}'**
  String vistaPrevia(Object? p0);

  /// No description provided for @yMas.
  ///
  /// In es, this message translates to:
  /// **'• y {p0} más'**
  String yMas(Object? p0);

  /// No description provided for @siYaTienesUnaPlaylistCon.
  ///
  /// In es, this message translates to:
  /// **'Si ya tienes una playlist con el mismo nombre, la nueva se llama \"(importada)\".'**
  String get siYaTienesUnaPlaylistCon;

  /// No description provided for @importar2.
  ///
  /// In es, this message translates to:
  /// **'Importar'**
  String get importar2;

  /// No description provided for @playlistsCreadasMeGustaYCanciones.
  ///
  /// In es, this message translates to:
  /// **'{p0} playlists creadas, {p1} me gusta y {p2} canciones nuevas en el historial.'**
  String playlistsCreadasMeGustaYCanciones(Object? p0, Object? p1, Object? p2);

  /// No description provided for @deshacerLaImportacion.
  ///
  /// In es, this message translates to:
  /// **'Deshacer la importación'**
  String get deshacerLaImportacion;

  /// No description provided for @deshacerLaImportacion2.
  ///
  /// In es, this message translates to:
  /// **'¿Deshacer la importación?'**
  String get deshacerLaImportacion2;

  /// No description provided for @seQuitanLasPlaylistsMeGusta.
  ///
  /// In es, this message translates to:
  /// **'Se quitan las playlists, me gusta e historial que agregó esa importación. Lo que ya tenías no se toca.'**
  String get seQuitanLasPlaylistsMeGusta;

  /// No description provided for @exportarTusPlaylists.
  ///
  /// In es, this message translates to:
  /// **'EXPORTAR TUS PLAYLISTS'**
  String get exportarTusPlaylists;

  /// No description provided for @todaviaNoTienesPlaylists.
  ///
  /// In es, this message translates to:
  /// **'Todavía no tienes playlists.'**
  String get todaviaNoTienesPlaylists;

  /// No description provided for @eligeUnaCarpetaConMusica.
  ///
  /// In es, this message translates to:
  /// **'Elige una carpeta con música'**
  String get eligeUnaCarpetaConMusica;

  /// No description provided for @canciones.
  ///
  /// In es, this message translates to:
  /// **'Canciones'**
  String get canciones;

  /// No description provided for @playlists.
  ///
  /// In es, this message translates to:
  /// **'Playlists'**
  String get playlists;

  /// No description provided for @carpetas.
  ///
  /// In es, this message translates to:
  /// **'Carpetas'**
  String get carpetas;

  /// No description provided for @eligeLaCarpetaDondeGuardasTu.
  ///
  /// In es, this message translates to:
  /// **'Elige la carpeta donde guardas tu música. Kiji solo lee las carpetas que tú elijas.'**
  String get eligeLaCarpetaDondeGuardasTu;

  /// No description provided for @elegirCarpeta.
  ///
  /// In es, this message translates to:
  /// **'Elegir carpeta'**
  String get elegirCarpeta;

  /// No description provided for @kijiNecesitaPermisoParaLeerTu.
  ///
  /// In es, this message translates to:
  /// **'Kiji necesita permiso para leer tu música local.'**
  String get kijiNecesitaPermisoParaLeerTu;

  /// No description provided for @concederPermiso.
  ///
  /// In es, this message translates to:
  /// **'Conceder permiso'**
  String get concederPermiso;

  /// No description provided for @noSePudoLeerLaBiblioteca.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer la biblioteca local.'**
  String get noSePudoLeerLaBiblioteca;

  /// No description provided for @reintentar.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get reintentar;

  /// No description provided for @noSeEncontroMusicaEnEste.
  ///
  /// In es, this message translates to:
  /// **'No se encontró música en este dispositivo.'**
  String get noSeEncontroMusicaEnEste;

  /// No description provided for @carpetasQueLeeKiji.
  ///
  /// In es, this message translates to:
  /// **'Carpetas que lee Kiji'**
  String get carpetasQueLeeKiji;

  /// No description provided for @quitarUnaCarpetaNoBorraNingun.
  ///
  /// In es, this message translates to:
  /// **'Quitar una carpeta no borra ningún archivo.'**
  String get quitarUnaCarpetaNoBorraNingun;

  /// No description provided for @dejarDeLeerEstaCarpeta.
  ///
  /// In es, this message translates to:
  /// **'Dejar de leer esta carpeta'**
  String get dejarDeLeerEstaCarpeta;

  /// No description provided for @agregarCarpeta.
  ///
  /// In es, this message translates to:
  /// **'Agregar carpeta'**
  String get agregarCarpeta;

  /// No description provided for @espacio.
  ///
  /// In es, this message translates to:
  /// **'ESPACIO'**
  String get espacio;

  /// No description provided for @usadosPorKiji.
  ///
  /// In es, this message translates to:
  /// **'{p0} usados por Kiji'**
  String usadosPorKiji(Object? p0);

  /// No description provided for @libresCanciones.
  ///
  /// In es, this message translates to:
  /// **'{p0} libres · {p1} canciones'**
  String libresCanciones(Object? p0, Object? p1);

  /// No description provided for @todo.
  ///
  /// In es, this message translates to:
  /// **'Todo'**
  String get todo;

  /// No description provided for @local.
  ///
  /// In es, this message translates to:
  /// **'LOCAL'**
  String get local;

  /// No description provided for @elServicioDeLetrasNoRespondio.
  ///
  /// In es, this message translates to:
  /// **'el servicio de letras no respondió'**
  String get elServicioDeLetrasNoRespondio;

  /// No description provided for @noRespondio.
  ///
  /// In es, this message translates to:
  /// **'{p0} no respondió'**
  String noRespondio(Object? p0);

  /// No description provided for @youlyplusNoRespondio.
  ///
  /// In es, this message translates to:
  /// **'YouLyPlus no respondió'**
  String get youlyplusNoRespondio;

  /// No description provided for @youtubeNoRespondio.
  ///
  /// In es, this message translates to:
  /// **'YouTube no respondió'**
  String get youtubeNoRespondio;

  /// No description provided for @incluidaEnElArchivo.
  ///
  /// In es, this message translates to:
  /// **'Incluida en el archivo'**
  String get incluidaEnElArchivo;

  /// No description provided for @importadaPorTi.
  ///
  /// In es, this message translates to:
  /// **'Importada por ti'**
  String get importadaPorTi;

  /// No description provided for @subtitulosDeYoutube.
  ///
  /// In es, this message translates to:
  /// **'Subtítulos de YouTube'**
  String get subtitulosDeYoutube;

  /// No description provided for @eligeUnaCancion.
  ///
  /// In es, this message translates to:
  /// **'Elige una canción'**
  String get eligeUnaCancion;

  /// No description provided for @noSePudoBuscarLaLetra.
  ///
  /// In es, this message translates to:
  /// **'No se pudo buscar la letra.'**
  String get noSePudoBuscarLaLetra;

  /// No description provided for @instrumental.
  ///
  /// In es, this message translates to:
  /// **'Instrumental ♪'**
  String get instrumental;

  /// No description provided for @noEncontramosLaLetraDeEsta.
  ///
  /// In es, this message translates to:
  /// **'No encontramos la letra de esta canción en ninguna fuente.'**
  String get noEncontramosLaLetraDeEsta;

  /// No description provided for @buscarAMano.
  ///
  /// In es, this message translates to:
  /// **'Buscar a mano'**
  String get buscarAMano;

  /// No description provided for @buscarLaLetraAMano.
  ///
  /// In es, this message translates to:
  /// **'Buscar la letra a mano'**
  String get buscarLaLetraAMano;

  /// No description provided for @buscandoEnTodasLasFuentes.
  ///
  /// In es, this message translates to:
  /// **'Buscando en todas las fuentes…'**
  String get buscandoEnTodasLasFuentes;

  /// No description provided for @tampocoSeEncontroConEsosDatos.
  ///
  /// In es, this message translates to:
  /// **'Tampoco se encontró con esos datos.'**
  String get tampocoSeEncontroConEsosDatos;

  /// No description provided for @unaFuente.
  ///
  /// In es, this message translates to:
  /// **'una fuente'**
  String get unaFuente;

  /// No description provided for @encontradaEn.
  ///
  /// In es, this message translates to:
  /// **'Encontrada en {p0}.'**
  String encontradaEn(Object? p0);

  /// No description provided for @noSePudoBuscar.
  ///
  /// In es, this message translates to:
  /// **'No se pudo buscar ({p0}).'**
  String noSePudoBuscar(Object? p0);

  /// No description provided for @eligeUnArchivoLrc.
  ///
  /// In es, this message translates to:
  /// **'Elige un archivo .lrc'**
  String get eligeUnArchivoLrc;

  /// No description provided for @letraImportada.
  ///
  /// In es, this message translates to:
  /// **'Letra importada.'**
  String get letraImportada;

  /// No description provided for @eseArchivoNoTieneUnaLetra.
  ///
  /// In es, this message translates to:
  /// **'Ese archivo no tiene una letra que Kiji entienda.'**
  String get eseArchivoNoTieneUnaLetra;

  /// No description provided for @cerrarLaLetra.
  ///
  /// In es, this message translates to:
  /// **'Cerrar la letra'**
  String get cerrarLaLetra;

  /// No description provided for @opcionesDeLaLetra.
  ///
  /// In es, this message translates to:
  /// **'Opciones de la letra'**
  String get opcionesDeLaLetra;

  /// No description provided for @traducir.
  ///
  /// In es, this message translates to:
  /// **'Traducir'**
  String get traducir;

  /// No description provided for @sincronizarAdelantarOAtrasar.
  ///
  /// In es, this message translates to:
  /// **'Sincronizar (adelantar o atrasar)'**
  String get sincronizarAdelantarOAtrasar;

  /// No description provided for @compartirLineas.
  ///
  /// In es, this message translates to:
  /// **'Compartir líneas'**
  String get compartirLineas;

  /// No description provided for @fuente.
  ///
  /// In es, this message translates to:
  /// **'Fuente: {p0}'**
  String fuente(Object? p0);

  /// No description provided for @laLetraVaDespues.
  ///
  /// In es, this message translates to:
  /// **'La letra va después'**
  String get laLetraVaDespues;

  /// No description provided for @laLetraVaAntes.
  ///
  /// In es, this message translates to:
  /// **'La letra va antes'**
  String get laLetraVaAntes;

  /// No description provided for @volverALaCancion.
  ///
  /// In es, this message translates to:
  /// **'Volver a la canción'**
  String get volverALaCancion;

  /// No description provided for @comoTexto.
  ///
  /// In es, this message translates to:
  /// **'Como texto'**
  String get comoTexto;

  /// No description provided for @comoImagen.
  ///
  /// In es, this message translates to:
  /// **'Como imagen'**
  String get comoImagen;

  /// No description provided for @letraSinSincronizar.
  ///
  /// In es, this message translates to:
  /// **'LETRA SIN SINCRONIZAR'**
  String get letraSinSincronizar;

  /// No description provided for @historia916.
  ///
  /// In es, this message translates to:
  /// **'Historia 9:16'**
  String get historia916;

  /// No description provided for @cuadrado11.
  ///
  /// In es, this message translates to:
  /// **'Cuadrado 1:1'**
  String get cuadrado11;

  /// No description provided for @vertical45.
  ///
  /// In es, this message translates to:
  /// **'Vertical 4:5'**
  String get vertical45;

  /// No description provided for @horizontal169.
  ///
  /// In es, this message translates to:
  /// **'Horizontal 16:9'**
  String get horizontal169;

  /// No description provided for @soloTexto.
  ///
  /// In es, this message translates to:
  /// **'Solo texto'**
  String get soloTexto;

  /// No description provided for @portadaDifuminada.
  ///
  /// In es, this message translates to:
  /// **'Portada difuminada'**
  String get portadaDifuminada;

  /// No description provided for @colorDeLaCancion.
  ///
  /// In es, this message translates to:
  /// **'Color de la canción'**
  String get colorDeLaCancion;

  /// No description provided for @oscuro.
  ///
  /// In es, this message translates to:
  /// **'Oscuro'**
  String get oscuro;

  /// No description provided for @traduccion.
  ///
  /// In es, this message translates to:
  /// **'Traducción'**
  String get traduccion;

  /// No description provided for @ambas.
  ///
  /// In es, this message translates to:
  /// **'Ambas'**
  String get ambas;

  /// No description provided for @compartirComoImagen.
  ///
  /// In es, this message translates to:
  /// **'Compartir como imagen'**
  String get compartirComoImagen;

  /// No description provided for @formato.
  ///
  /// In es, this message translates to:
  /// **'Formato'**
  String get formato;

  /// No description provided for @fondo.
  ///
  /// In es, this message translates to:
  /// **'Fondo'**
  String get fondo;

  /// No description provided for @texto.
  ///
  /// In es, this message translates to:
  /// **'Texto'**
  String get texto;

  /// No description provided for @logoDeKiji.
  ///
  /// In es, this message translates to:
  /// **'Logo de Kiji'**
  String get logoDeKiji;

  /// No description provided for @compartirImagen.
  ///
  /// In es, this message translates to:
  /// **'Compartir imagen'**
  String get compartirImagen;

  /// No description provided for @fuenteDeLaLetra.
  ///
  /// In es, this message translates to:
  /// **'Fuente de la letra'**
  String get fuenteDeLaLetra;

  /// No description provided for @tocaUnaFuenteQueTengaLa.
  ///
  /// In es, this message translates to:
  /// **'Toca una fuente que tenga la letra para usarla en esta canción.'**
  String get tocaUnaFuenteQueTengaLa;

  /// No description provided for @buscarConOtroTituloOArtista.
  ///
  /// In es, this message translates to:
  /// **'Buscar con otro título o artista'**
  String get buscarConOtroTituloOArtista;

  /// No description provided for @importarUnArchivoLrc.
  ///
  /// In es, this message translates to:
  /// **'Importar un archivo .lrc'**
  String get importarUnArchivoLrc;

  /// No description provided for @cambiarElOrdenDeLasFuentes.
  ///
  /// In es, this message translates to:
  /// **'Cambiar el orden de las fuentes'**
  String get cambiarElOrdenDeLasFuentes;

  /// No description provided for @sincronizada.
  ///
  /// In es, this message translates to:
  /// **'Sincronizada'**
  String get sincronizada;

  /// No description provided for @sinSincronizar.
  ///
  /// In es, this message translates to:
  /// **'Sin sincronizar'**
  String get sinSincronizar;

  /// No description provided for @noLaTiene.
  ///
  /// In es, this message translates to:
  /// **'No la tiene'**
  String get noLaTiene;

  /// No description provided for @noRespondio2.
  ///
  /// In es, this message translates to:
  /// **'No respondió'**
  String get noRespondio2;

  /// No description provided for @apagada.
  ///
  /// In es, this message translates to:
  /// **'Apagada'**
  String get apagada;

  /// No description provided for @esLaQueVesAhora.
  ///
  /// In es, this message translates to:
  /// **'Es la que ves ahora'**
  String get esLaQueVesAhora;

  /// No description provided for @deDeA.
  ///
  /// In es, this message translates to:
  /// **'«{p0}» de {p1}, de {p2} a {p3}'**
  String deDeA(Object? p0, Object? p1, Object? p2, Object? p3);

  /// No description provided for @momentoGuardadoEn.
  ///
  /// In es, this message translates to:
  /// **'Momento guardado en {p0}'**
  String momentoGuardadoEn(Object? p0);

  /// No description provided for @ver.
  ///
  /// In es, this message translates to:
  /// **'Ver'**
  String get ver;

  /// No description provided for @momentos2.
  ///
  /// In es, this message translates to:
  /// **'Momentos'**
  String get momentos2;

  /// No description provided for @guardaElSegundoExactoDeUna.
  ///
  /// In es, this message translates to:
  /// **'Guarda el segundo exacto de una canción (el solo, el estribillo) con el botón \"Momento\" del reproductor. Aparecen aquí para volver a ellos con un toque.'**
  String get guardaElSegundoExactoDeUna;

  /// No description provided for @repetirEsteTramo.
  ///
  /// In es, this message translates to:
  /// **'Repetir este tramo'**
  String get repetirEsteTramo;

  /// No description provided for @compartir.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get compartir;

  /// No description provided for @seBorroElMomento.
  ///
  /// In es, this message translates to:
  /// **'Se borró el Momento'**
  String get seBorroElMomento;

  /// No description provided for @tramoDeA.
  ///
  /// In es, this message translates to:
  /// **'Tramo de {p0} a {p1}'**
  String tramoDeA(Object? p0, Object? p1);

  /// No description provided for @momentoEn.
  ///
  /// In es, this message translates to:
  /// **'Momento en {p0}'**
  String momentoEn(Object? p0);

  /// No description provided for @repitiendo.
  ///
  /// In es, this message translates to:
  /// **'Repitiendo {p0}–{p1}'**
  String repitiendo(Object? p0, Object? p1);

  /// No description provided for @dejarDeRepetir.
  ///
  /// In es, this message translates to:
  /// **'Dejar de repetir'**
  String get dejarDeRepetir;

  /// No description provided for @repitiendoDeA.
  ///
  /// In es, this message translates to:
  /// **'Repitiendo de {p0} a {p1}'**
  String repitiendoDeA(Object? p0, Object? p1);

  /// No description provided for @guardarUnMomento.
  ///
  /// In es, this message translates to:
  /// **'Guardar un momento'**
  String get guardarUnMomento;

  /// No description provided for @esteSegundo.
  ///
  /// In es, this message translates to:
  /// **'Este segundo ({p0})'**
  String esteSegundo(Object? p0);

  /// No description provided for @unTramo.
  ///
  /// In es, this message translates to:
  /// **'Un tramo'**
  String get unTramo;

  /// No description provided for @deA.
  ///
  /// In es, this message translates to:
  /// **'De {p0} a {p1}'**
  String deA(Object? p0, Object? p1);

  /// No description provided for @vuelveAlPrincipioDelTramoAl.
  ///
  /// In es, this message translates to:
  /// **'Vuelve al principio del tramo al llegar al final.'**
  String get vuelveAlPrincipioDelTramoAl;

  /// No description provided for @meGusta2.
  ///
  /// In es, this message translates to:
  /// **'Me gusta'**
  String get meGusta2;

  /// No description provided for @lasCancionesQueMarcasteCon.
  ///
  /// In es, this message translates to:
  /// **'Las canciones que marcaste con ♥.'**
  String get lasCancionesQueMarcasteCon;

  /// No description provided for @masEscuchadas.
  ///
  /// In es, this message translates to:
  /// **'Más escuchadas'**
  String get masEscuchadas;

  /// No description provided for @las25QueMasVecesEscuchaste.
  ///
  /// In es, this message translates to:
  /// **'Las 25 que más veces escuchaste en Kiji.'**
  String get las25QueMasVecesEscuchaste;

  /// No description provided for @escuchadasHacePoco.
  ///
  /// In es, this message translates to:
  /// **'Escuchadas hace poco'**
  String get escuchadasHacePoco;

  /// No description provided for @lasUltimas25QueEscuchaste.
  ///
  /// In es, this message translates to:
  /// **'Las últimas 25 que escuchaste.'**
  String get lasUltimas25QueEscuchaste;

  /// No description provided for @favoritasOlvidadas.
  ///
  /// In es, this message translates to:
  /// **'Favoritas olvidadas'**
  String get favoritasOlvidadas;

  /// No description provided for @conQueNoEscuchasHaceMas.
  ///
  /// In es, this message translates to:
  /// **'Con ♥, que no escuchas hace más de un mes.'**
  String get conQueNoEscuchasHaceMas;

  /// No description provided for @todoLoQueGuardasteParaEscuchar.
  ///
  /// In es, this message translates to:
  /// **'Todo lo que guardaste para escuchar sin conexión.'**
  String get todoLoQueGuardasteParaEscuchar;

  /// No description provided for @nuncaEscuchadas.
  ///
  /// In es, this message translates to:
  /// **'Nunca escuchadas'**
  String get nuncaEscuchadas;

  /// No description provided for @deTuMusicaDelDispositivoLas.
  ///
  /// In es, this message translates to:
  /// **'De tu música del dispositivo, las que todavía no escuchaste en Kiji.'**
  String get deTuMusicaDelDispositivoLas;

  /// No description provided for @canciones2.
  ///
  /// In es, this message translates to:
  /// **'«{p0}» ({p1} canciones)\n'**
  String canciones2(Object? p0, Object? p1);

  /// No description provided for @reproducir.
  ///
  /// In es, this message translates to:
  /// **'Reproducir'**
  String get reproducir;

  /// No description provided for @aleatorio.
  ///
  /// In es, this message translates to:
  /// **'Aleatorio'**
  String get aleatorio;

  /// No description provided for @editar.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get editar;

  /// No description provided for @nombreDescripcionYColor.
  ///
  /// In es, this message translates to:
  /// **'Nombre, descripción y color'**
  String get nombreDescripcionYColor;

  /// No description provided for @fijarArriba.
  ///
  /// In es, this message translates to:
  /// **'Fijar arriba'**
  String get fijarArriba;

  /// No description provided for @descargarTodaLaPlaylist.
  ///
  /// In es, this message translates to:
  /// **'Descargar toda la playlist'**
  String get descargarTodaLaPlaylist;

  /// No description provided for @laListaDeCancionesComoTexto.
  ///
  /// In es, this message translates to:
  /// **'La lista de canciones como texto'**
  String get laListaDeCancionesComoTexto;

  /// No description provided for @exportar.
  ///
  /// In es, this message translates to:
  /// **'Exportar'**
  String get exportar;

  /// No description provided for @m3u8OtrasAppsOCsvPlanillas.
  ///
  /// In es, this message translates to:
  /// **'.m3u8 (otras apps) o .csv (planillas)'**
  String get m3u8OtrasAppsOCsvPlanillas;

  /// No description provided for @borrarLaPlaylist.
  ///
  /// In es, this message translates to:
  /// **'Borrar la playlist'**
  String get borrarLaPlaylist;

  /// No description provided for @sePuedeDeshacer.
  ///
  /// In es, this message translates to:
  /// **'Se puede deshacer'**
  String get sePuedeDeshacer;

  /// No description provided for @exportarComo.
  ///
  /// In es, this message translates to:
  /// **'Exportar como'**
  String get exportarComo;

  /// No description provided for @m3u8ParaOtrasAppsDeMusica.
  ///
  /// In es, this message translates to:
  /// **'.m3u8 — para otras apps de música'**
  String get m3u8ParaOtrasAppsDeMusica;

  /// No description provided for @csvParaPlanillas.
  ///
  /// In es, this message translates to:
  /// **'.csv — para planillas'**
  String get csvParaPlanillas;

  /// No description provided for @estaPlaylistNoTieneCancionesDe.
  ///
  /// In es, this message translates to:
  /// **'Esta playlist no tiene canciones de YouTube para descargar.'**
  String get estaPlaylistNoTieneCancionesDe;

  /// No description provided for @cancionesParaBajar.
  ///
  /// In es, this message translates to:
  /// **'{p0} canciones para bajar.'**
  String cancionesParaBajar(Object? p0);

  /// No description provided for @yaEstabanDescargadasSeSaltean.
  ///
  /// In es, this message translates to:
  /// **'{p0} ya estaban descargadas: se saltean.'**
  String yaEstabanDescargadasSeSaltean(Object? p0);

  /// No description provided for @sonArchivosTuyosNoHaceFalta.
  ///
  /// In es, this message translates to:
  /// **'{p0} son archivos tuyos: no hace falta bajarlas.'**
  String sonArchivosTuyosNoHaceFalta(Object? p0);

  /// No description provided for @ocupanUnosEstimadoPorLaDuracion.
  ///
  /// In es, this message translates to:
  /// **'Ocupan unos {p0} (estimado por la duración).'**
  String ocupanUnosEstimadoPorLaDuracion(Object? p0);

  /// No description provided for @espacioLibre.
  ///
  /// In es, this message translates to:
  /// **'Espacio libre: {p0}.'**
  String espacioLibre(Object? p0);

  /// No description provided for @tienesSoloConWifiSiNo.
  ///
  /// In es, this message translates to:
  /// **'Tienes \"solo con WiFi\": si no hay WiFi, la descarga espera en pausa.'**
  String get tienesSoloConWifiSiNo;

  /// No description provided for @noEntraEnElEspacioLibre.
  ///
  /// In es, this message translates to:
  /// **'No entra en el espacio libre del dispositivo.'**
  String get noEntraEnElEspacioLibre;

  /// No description provided for @de.
  ///
  /// In es, this message translates to:
  /// **'{p0}: {p1} de {p2}{p3}'**
  String de(Object? p0, Object? p1, Object? p2, Object? p3);

  /// No description provided for @cerrar.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get cerrar;

  /// No description provided for @pausar.
  ///
  /// In es, this message translates to:
  /// **'Pausar'**
  String get pausar;

  /// No description provided for @verCuales.
  ///
  /// In es, this message translates to:
  /// **'Ver cuáles'**
  String get verCuales;

  /// No description provided for @reintentarLasFallidas.
  ///
  /// In es, this message translates to:
  /// **'Reintentar las fallidas'**
  String get reintentarLasFallidas;

  /// No description provided for @nuevaPlaylist.
  ///
  /// In es, this message translates to:
  /// **'Nueva playlist'**
  String get nuevaPlaylist;

  /// No description provided for @nombreDeLaPlaylist.
  ///
  /// In es, this message translates to:
  /// **'Nombre de la playlist'**
  String get nombreDeLaPlaylist;

  /// No description provided for @agregarAPlaylist.
  ///
  /// In es, this message translates to:
  /// **'Agregar a playlist'**
  String get agregarAPlaylist;

  /// No description provided for @seCreo.
  ///
  /// In es, this message translates to:
  /// **'Se creó «{p0}»'**
  String seCreo(Object? p0);

  /// No description provided for @seAgregoA.
  ///
  /// In es, this message translates to:
  /// **'Se agregó a «{p0}»'**
  String seAgregoA(Object? p0);

  /// No description provided for @tusPlaylists.
  ///
  /// In es, this message translates to:
  /// **'TUS PLAYLISTS'**
  String get tusPlaylists;

  /// No description provided for @nueva.
  ///
  /// In es, this message translates to:
  /// **'Nueva'**
  String get nueva;

  /// No description provided for @todaviaNoCreasteNingunaMantenPresionada.
  ///
  /// In es, this message translates to:
  /// **'Todavía no creaste ninguna. Mantén presionada una canción → \"Agregar a playlist\".'**
  String get todaviaNoCreasteNingunaMantenPresionada;

  /// No description provided for @fijada.
  ///
  /// In es, this message translates to:
  /// **'Fijada'**
  String get fijada;

  /// No description provided for @segundosGuardadosDeTusCanciones.
  ///
  /// In es, this message translates to:
  /// **'{p0} segundos guardados de tus canciones'**
  String segundosGuardadosDeTusCanciones(Object? p0);

  /// No description provided for @listasInteligentesCalculadasEnTuTelefono.
  ///
  /// In es, this message translates to:
  /// **'LISTAS INTELIGENTES · CALCULADAS EN TU TELÉFONO'**
  String get listasInteligentesCalculadasEnTuTelefono;

  /// No description provided for @masOpciones.
  ///
  /// In es, this message translates to:
  /// **'Más opciones'**
  String get masOpciones;

  /// No description provided for @estaPlaylistYaNoExiste.
  ///
  /// In es, this message translates to:
  /// **'Esta playlist ya no existe.'**
  String get estaPlaylistYaNoExiste;

  /// No description provided for @seBorro.
  ///
  /// In es, this message translates to:
  /// **'Se borró «{p0}»'**
  String seBorro(Object? p0);

  /// No description provided for @noSePudoDescargar2.
  ///
  /// In es, this message translates to:
  /// **'No se pudo descargar'**
  String get noSePudoDescargar2;

  /// No description provided for @porQueNoSeDescargo.
  ///
  /// In es, this message translates to:
  /// **'Por qué no se descargó'**
  String get porQueNoSeDescargo;

  /// No description provided for @quitarDeLaPlaylist.
  ///
  /// In es, this message translates to:
  /// **'Quitar de la playlist'**
  String get quitarDeLaPlaylist;

  /// No description provided for @seQuito.
  ///
  /// In es, this message translates to:
  /// **'Se quitó «{p0}»'**
  String seQuito(Object? p0);

  /// No description provided for @arrastrarParaMover.
  ///
  /// In es, this message translates to:
  /// **'Arrastrar para mover'**
  String get arrastrarParaMover;

  /// No description provided for @importadaDe.
  ///
  /// In es, this message translates to:
  /// **'{p0} · importada de {p1}'**
  String importadaDe(Object? p0, Object? p1);

  /// No description provided for @ningunaCancionConEsteFiltro.
  ///
  /// In es, this message translates to:
  /// **'Ninguna canción con este filtro.'**
  String get ningunaCancionConEsteFiltro;

  /// No description provided for @deDescargadas.
  ///
  /// In es, this message translates to:
  /// **'{p0} de {p1} descargadas'**
  String deDescargadas(Object? p0, Object? p1);

  /// No description provided for @conError.
  ///
  /// In es, this message translates to:
  /// **'· {p0} con error'**
  String conError(Object? p0);

  /// No description provided for @todas.
  ///
  /// In es, this message translates to:
  /// **'Todas'**
  String get todas;

  /// No description provided for @sinDescargar.
  ///
  /// In es, this message translates to:
  /// **'Sin descargar'**
  String get sinDescargar;

  /// No description provided for @conError2.
  ///
  /// In es, this message translates to:
  /// **'Con error'**
  String get conError2;

  /// No description provided for @regla.
  ///
  /// In es, this message translates to:
  /// **'Regla: {p0}'**
  String regla(Object? p0);

  /// No description provided for @porAhoraNoHayCancionesQue.
  ///
  /// In es, this message translates to:
  /// **'Por ahora no hay canciones que cumplan la regla.'**
  String get porAhoraNoHayCancionesQue;

  /// No description provided for @cola.
  ///
  /// In es, this message translates to:
  /// **'Cola'**
  String get cola;

  /// No description provided for @eligeUnaCancionParaEmpezar.
  ///
  /// In es, this message translates to:
  /// **'Elige una canción para empezar.'**
  String get eligeUnaCancionParaEmpezar;

  /// No description provided for @seQuitoDeLaCola.
  ///
  /// In es, this message translates to:
  /// **'Se quitó «{p0}» de la cola'**
  String seQuitoDeLaCola(Object? p0);

  /// No description provided for @pausarAlTerminarEsta.
  ///
  /// In es, this message translates to:
  /// **'Pausar al terminar esta'**
  String get pausarAlTerminarEsta;

  /// No description provided for @quitarDeLaCola.
  ///
  /// In es, this message translates to:
  /// **'Quitar de la cola'**
  String get quitarDeLaCola;

  /// No description provided for @reproducirAContinuacion.
  ///
  /// In es, this message translates to:
  /// **'Reproducir a continuación'**
  String get reproducirAContinuacion;

  /// No description provided for @suenaDespuesDeEsta.
  ///
  /// In es, this message translates to:
  /// **'«{p0}» suena después de esta'**
  String suenaDespuesDeEsta(Object? p0);

  /// No description provided for @agregarALaCola.
  ///
  /// In es, this message translates to:
  /// **'Agregar a la cola'**
  String get agregarALaCola;

  /// No description provided for @seAgregoAlFinalDeLa.
  ///
  /// In es, this message translates to:
  /// **'«{p0}» se agregó al final de la cola'**
  String seAgregoAlFinalDeLa(Object? p0);

  /// No description provided for @personalizar2.
  ///
  /// In es, this message translates to:
  /// **'Personalizar'**
  String get personalizar2;

  /// No description provided for @fotoTituloYArtistaSoloEn.
  ///
  /// In es, this message translates to:
  /// **'Foto, título y artista (solo en Kiji)'**
  String get fotoTituloYArtistaSoloEn;

  /// No description provided for @elTituloYElArtistaEs.
  ///
  /// In es, this message translates to:
  /// **'El título y el artista (es un archivo de este dispositivo)'**
  String get elTituloYElArtistaEs;

  /// No description provided for @elTemporizadorParaCuandoTermineEsta.
  ///
  /// In es, this message translates to:
  /// **'El temporizador para cuando termine esta canción'**
  String get elTemporizadorParaCuandoTermineEsta;

  /// No description provided for @laMusicaSeVaAPausar.
  ///
  /// In es, this message translates to:
  /// **'La música se va a pausar al terminar «{p0}»'**
  String laMusicaSeVaAPausar(Object? p0);

  /// No description provided for @reproducirTodo.
  ///
  /// In es, this message translates to:
  /// **'Reproducir todo'**
  String get reproducirTodo;

  /// No description provided for @buscandoMusicaParaTi.
  ///
  /// In es, this message translates to:
  /// **'Buscando música para ti…'**
  String get buscandoMusicaParaTi;

  /// No description provided for @porqueEscuchaste.
  ///
  /// In es, this message translates to:
  /// **'Porque escuchaste {p0}'**
  String porqueEscuchaste(Object? p0);

  /// No description provided for @mezclaParaTi.
  ///
  /// In es, this message translates to:
  /// **'Mezcla para ti'**
  String get mezclaParaTi;

  /// No description provided for @tusFavoritasNuevas.
  ///
  /// In es, this message translates to:
  /// **'tus favoritas + nuevas'**
  String get tusFavoritasNuevas;

  /// No description provided for @descubre.
  ///
  /// In es, this message translates to:
  /// **'Descubre'**
  String get descubre;

  /// No description provided for @relacionadasDeYoutubeMusic.
  ///
  /// In es, this message translates to:
  /// **'relacionadas de YouTube Music'**
  String get relacionadasDeYoutubeMusic;

  /// No description provided for @paraEmpezar.
  ///
  /// In es, this message translates to:
  /// **'Para empezar'**
  String get paraEmpezar;

  /// No description provided for @eligeUnEstilo.
  ///
  /// In es, this message translates to:
  /// **'elige un estilo'**
  String get eligeUnEstilo;

  /// No description provided for @sinConexionLosGenerosAparecenCuando.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión: los géneros aparecen cuando vuelva internet.'**
  String get sinConexionLosGenerosAparecenCuando;

  /// No description provided for @estadosDeAnimo.
  ///
  /// In es, this message translates to:
  /// **'ESTADOS DE ÁNIMO'**
  String get estadosDeAnimo;

  /// No description provided for @generos.
  ///
  /// In es, this message translates to:
  /// **'GÉNEROS'**
  String get generos;

  /// No description provided for @noSePudoCargarRevisaTu.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar. Revisa tu conexión.'**
  String get noSePudoCargarRevisaTu;

  /// No description provided for @seGuardoEnTusPlaylists.
  ///
  /// In es, this message translates to:
  /// **'Se guardó «{p0}» en tus playlists'**
  String seGuardoEnTusPlaylists(Object? p0);

  /// No description provided for @guardarEnKiji.
  ///
  /// In es, this message translates to:
  /// **'Guardar en Kiji'**
  String get guardarEnKiji;

  /// No description provided for @algoFalloEn.
  ///
  /// In es, this message translates to:
  /// **'Algo falló en {p0}'**
  String algoFalloEn(Object? p0);

  /// No description provided for @unaCancionNoSePudoReproducir.
  ///
  /// In es, this message translates to:
  /// **'Una canción no se pudo reproducir con ninguna forma'**
  String get unaCancionNoSePudoReproducir;

  /// No description provided for @reproduccion.
  ///
  /// In es, this message translates to:
  /// **'reproducción'**
  String get reproduccion;

  /// No description provided for @videoCaminosAgotados.
  ///
  /// In es, this message translates to:
  /// **'video {p0}: caminos agotados'**
  String videoCaminosAgotados(Object? p0);

  /// No description provided for @noSePudoAbrirElNavegador.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el navegador.'**
  String get noSePudoAbrirElNavegador;

  /// No description provided for @guardarInforme.
  ///
  /// In es, this message translates to:
  /// **'Guardar informe'**
  String get guardarInforme;

  /// No description provided for @borrarElRegistro.
  ///
  /// In es, this message translates to:
  /// **'¿Borrar el registro?'**
  String get borrarElRegistro;

  /// No description provided for @seBorraTodoLoGuardadoSi.
  ///
  /// In es, this message translates to:
  /// **'Se borra todo lo guardado. Si el registro está prendido, sigue anotando desde ahora.'**
  String get seBorraTodoLoGuardadoSi;

  /// No description provided for @registrosEInformes.
  ///
  /// In es, this message translates to:
  /// **'Registros e informes'**
  String get registrosEInformes;

  /// No description provided for @elRegistroGuardadoEstaApagadoSolo.
  ///
  /// In es, this message translates to:
  /// **'El registro guardado está apagado: solo se usa lo de esta sesión, que se borra al cerrar Kiji.'**
  String get elRegistroGuardadoEstaApagadoSolo;

  /// No description provided for @borrarElRegistro2.
  ///
  /// In es, this message translates to:
  /// **'Borrar el registro'**
  String get borrarElRegistro2;

  /// No description provided for @erroresDeEstaSesion.
  ///
  /// In es, this message translates to:
  /// **'ERRORES DE ESTA SESIÓN'**
  String get erroresDeEstaSesion;

  /// No description provided for @ninguno.
  ///
  /// In es, this message translates to:
  /// **'Ninguno. 🎉'**
  String get ninguno;

  /// No description provided for @elRegistroLoUltimoTalComo.
  ///
  /// In es, this message translates to:
  /// **'EL REGISTRO (LO ÚLTIMO, TAL COMO SE MANDA)'**
  String get elRegistroLoUltimoTalComo;

  /// No description provided for @creditos.
  ///
  /// In es, this message translates to:
  /// **'Créditos'**
  String get creditos;

  /// No description provided for @noSePudieronLeerLosCreditos.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron leer los créditos.'**
  String get noSePudieronLeerLosCreditos;

  /// No description provided for @reproductorYAudio.
  ///
  /// In es, this message translates to:
  /// **'Reproductor y audio'**
  String get reproductorYAudio;

  /// No description provided for @contenido.
  ///
  /// In es, this message translates to:
  /// **'Contenido'**
  String get contenido;

  /// No description provided for @letras2.
  ///
  /// In es, this message translates to:
  /// **'Letras'**
  String get letras2;

  /// No description provided for @apariencia.
  ///
  /// In es, this message translates to:
  /// **'Apariencia'**
  String get apariencia;

  /// No description provided for @almacenamiento.
  ///
  /// In es, this message translates to:
  /// **'Almacenamiento'**
  String get almacenamiento;

  /// No description provided for @privacidad.
  ///
  /// In es, this message translates to:
  /// **'Privacidad'**
  String get privacidad;

  /// No description provided for @actualizaciones.
  ///
  /// In es, this message translates to:
  /// **'Actualizaciones'**
  String get actualizaciones;

  /// No description provided for @acercaDe.
  ///
  /// In es, this message translates to:
  /// **'Acerca de'**
  String get acercaDe;

  /// No description provided for @kijiDev.
  ///
  /// In es, this message translates to:
  /// **'Kiji Dev'**
  String get kijiDev;

  /// No description provided for @borrarLaBusqueda.
  ///
  /// In es, this message translates to:
  /// **'Borrar la búsqueda'**
  String get borrarLaBusqueda;

  /// No description provided for @noHayNingunaOpcionConEse.
  ///
  /// In es, this message translates to:
  /// **'No hay ninguna opción con ese nombre.'**
  String get noHayNingunaOpcionConEse;

  /// No description provided for @recordarLaColaAlCerrar.
  ///
  /// In es, this message translates to:
  /// **'Recordar la cola al cerrar'**
  String get recordarLaColaAlCerrar;

  /// No description provided for @alAbrirKijiVolverALa.
  ///
  /// In es, this message translates to:
  /// **'Al abrir Kiji, volver a la canción y al segundo donde quedó (en pausa).'**
  String get alAbrirKijiVolverALa;

  /// No description provided for @guardarCola.
  ///
  /// In es, this message translates to:
  /// **'guardar cola'**
  String get guardarCola;

  /// No description provided for @alAbrirKijiVuelveALa.
  ///
  /// In es, this message translates to:
  /// **'Al abrir Kiji, vuelve a la canción y al segundo donde quedó, en pausa.'**
  String get alAbrirKijiVuelveALa;

  /// No description provided for @presetsBandasAManoYUn.
  ///
  /// In es, this message translates to:
  /// **'Presets, bandas a mano y un perfil por dispositivo (parlante, auriculares, Bluetooth).'**
  String get presetsBandasAManoYUn;

  /// No description provided for @apagado.
  ///
  /// In es, this message translates to:
  /// **'Apagado'**
  String get apagado;

  /// No description provided for @transicionSuaveEntreCanciones.
  ///
  /// In es, this message translates to:
  /// **'Transición suave entre canciones'**
  String get transicionSuaveEntreCanciones;

  /// No description provided for @elFinalDeUnaCancionY.
  ///
  /// In es, this message translates to:
  /// **'El final de una canción y el principio de la siguiente suenan a la vez.'**
  String get elFinalDeUnaCancionY;

  /// No description provided for @sElFinalDeUnaCancion.
  ///
  /// In es, this message translates to:
  /// **'{p0} s: el final de una canción y el principio de la siguiente suenan a la vez.'**
  String sElFinalDeUnaCancion(Object? p0);

  /// No description provided for @transicionSuave.
  ///
  /// In es, this message translates to:
  /// **'Transición suave'**
  String get transicionSuave;

  /// No description provided for @pausarAlSilenciar.
  ///
  /// In es, this message translates to:
  /// **'Pausar al silenciar'**
  String get pausarAlSilenciar;

  /// No description provided for @siBajasElVolumenACero.
  ///
  /// In es, this message translates to:
  /// **'Si bajas el volumen a cero, la música se pausa; al subirlo, sigue.'**
  String get siBajasElVolumenACero;

  /// No description provided for @volumenCero.
  ///
  /// In es, this message translates to:
  /// **'volumen cero'**
  String get volumenCero;

  /// No description provided for @siBajasElVolumenDelTelefono.
  ///
  /// In es, this message translates to:
  /// **'Si bajas el volumen del teléfono a cero, la música se pausa; al subirlo, sigue. Solo en Android.'**
  String get siBajasElVolumenDelTelefono;

  /// No description provided for @retomarAlConectarElBluetooth.
  ///
  /// In es, this message translates to:
  /// **'Retomar al conectar el Bluetooth'**
  String get retomarAlConectarElBluetooth;

  /// No description provided for @alConectarAuricularesOUnParlante.
  ///
  /// In es, this message translates to:
  /// **'Al conectar auriculares o un parlante Bluetooth, la canción en pausa sigue sola.'**
  String get alConectarAuricularesOUnParlante;

  /// No description provided for @alConectarAuricularesOUnParlante2.
  ///
  /// In es, this message translates to:
  /// **'Al conectar auriculares o un parlante Bluetooth, la canción que estaba en pausa sigue sola (como en Echo).'**
  String get alConectarAuricularesOUnParlante2;

  /// No description provided for @ocultarAudiosCortos.
  ///
  /// In es, this message translates to:
  /// **'Ocultar audios cortos'**
  String get ocultarAudiosCortos;

  /// No description provided for @noMostrarEnLaBibliotecaLos.
  ///
  /// In es, this message translates to:
  /// **'No mostrar en la Biblioteca los audios de menos de 30 segundos.'**
  String get noMostrarEnLaBibliotecaLos;

  /// No description provided for @noMuestraEnLaBibliotecaLos.
  ///
  /// In es, this message translates to:
  /// **'No muestra en la Biblioteca los audios de menos de 30 segundos (avisos, sonidos de juegos). No borra nada.'**
  String get noMuestraEnLaBibliotecaLos;

  /// No description provided for @fuentesDeLetras.
  ///
  /// In es, this message translates to:
  /// **'Fuentes de letras'**
  String get fuentesDeLetras;

  /// No description provided for @dondeBuscaKijiLasLetrasCada.
  ///
  /// In es, this message translates to:
  /// **'Dónde busca Kiji las letras; cada fuente se puede apagar.'**
  String get dondeBuscaKijiLasLetrasCada;

  /// No description provided for @traduccionDeLetras.
  ///
  /// In es, this message translates to:
  /// **'Traducción de letras'**
  String get traduccionDeLetras;

  /// No description provided for @enTuTelefonoAnonimaOCon.
  ///
  /// In es, this message translates to:
  /// **'En tu teléfono (privada) o con IA (Beta).'**
  String get enTuTelefonoAnonimaOCon;

  /// No description provided for @enTuTelefono.
  ///
  /// In es, this message translates to:
  /// **'en tu teléfono'**
  String get enTuTelefono;

  /// No description provided for @al.
  ///
  /// In es, this message translates to:
  /// **'Al {p0} · {p1}'**
  String al(Object? p0, Object? p1);

  /// No description provided for @reducirAnimaciones.
  ///
  /// In es, this message translates to:
  /// **'Reducir animaciones'**
  String get reducirAnimaciones;

  /// No description provided for @sinAnimacionesDecorativasComoElAnillo.
  ///
  /// In es, this message translates to:
  /// **'Sin animaciones decorativas, como el anillo que respira del botón play.'**
  String get sinAnimacionesDecorativasComoElAnillo;

  /// No description provided for @sinAnimacionesDecorativasPorEjemploEl.
  ///
  /// In es, this message translates to:
  /// **'Sin animaciones decorativas (por ejemplo, el anillo que respira del botón play).'**
  String get sinAnimacionesDecorativasPorEjemploEl;

  /// No description provided for @noUsaLosDatosMovilesPara.
  ///
  /// In es, this message translates to:
  /// **'No usa los datos móviles para descargar.'**
  String get noUsaLosDatosMovilesPara;

  /// No description provided for @limiteDeEspacioParaDescargas.
  ///
  /// In es, this message translates to:
  /// **'Límite de espacio para descargas'**
  String get limiteDeEspacioParaDescargas;

  /// No description provided for @usado.
  ///
  /// In es, this message translates to:
  /// **'Usado: {p0}'**
  String usado(Object? p0);

  /// No description provided for @limiteDeLaCache.
  ///
  /// In es, this message translates to:
  /// **'Límite de la caché'**
  String get limiteDeLaCache;

  /// No description provided for @loQueYaEscuchasteSeGuarda.
  ///
  /// In es, this message translates to:
  /// **'Lo que ya escuchaste se guarda para no bajarlo otra vez.'**
  String get loQueYaEscuchasteSeGuarda;

  /// No description provided for @loYaEscuchadoSeGuardaPara.
  ///
  /// In es, this message translates to:
  /// **'Lo ya escuchado se guarda para no bajarlo otra vez. Lo más viejo se borra solo.'**
  String get loYaEscuchadoSeGuardaPara;

  /// No description provided for @vaciarLaCache.
  ///
  /// In es, this message translates to:
  /// **'Vaciar la caché'**
  String get vaciarLaCache;

  /// No description provided for @liberaEspacioLasDescargasNoSe.
  ///
  /// In es, this message translates to:
  /// **'Libera espacio. Las descargas no se tocan.'**
  String get liberaEspacioLasDescargasNoSe;

  /// No description provided for @vaciarLaCache2.
  ///
  /// In es, this message translates to:
  /// **'¿Vaciar la caché?'**
  String get vaciarLaCache2;

  /// No description provided for @lasCancionesQueYaEscuchasteSe.
  ///
  /// In es, this message translates to:
  /// **'Las canciones que ya escuchaste se van a volver a bajar la próxima vez. Las descargas no se tocan.'**
  String get lasCancionesQueYaEscuchasteSe;

  /// No description provided for @vaciar.
  ///
  /// In es, this message translates to:
  /// **'Vaciar'**
  String get vaciar;

  /// No description provided for @cacheVaciada.
  ///
  /// In es, this message translates to:
  /// **'Caché vaciada'**
  String get cacheVaciada;

  /// No description provided for @ahorroDeDatos.
  ///
  /// In es, this message translates to:
  /// **'Ahorro de datos'**
  String get ahorroDeDatos;

  /// No description provided for @conDatosMovilesYoutubeSuenaEn.
  ///
  /// In es, this message translates to:
  /// **'Con datos móviles, YouTube suena en calidad baja. Con WiFi, en la mejor.'**
  String get conDatosMovilesYoutubeSuenaEn;

  /// No description provided for @conDatosMovilesYoutubeSuenaEn2.
  ///
  /// In es, this message translates to:
  /// **'Con datos móviles, YouTube suena en la calidad más baja (gasta unas 4 veces menos). Con WiFi, siempre en la mejor.'**
  String get conDatosMovilesYoutubeSuenaEn2;

  /// No description provided for @verYBorrarDescargas.
  ///
  /// In es, this message translates to:
  /// **'Ver y borrar descargas'**
  String get verYBorrarDescargas;

  /// No description provided for @sinConexion3.
  ///
  /// In es, this message translates to:
  /// **'sin conexion'**
  String get sinConexion3;

  /// No description provided for @queGuardaKiji.
  ///
  /// In es, this message translates to:
  /// **'Qué guarda Kiji'**
  String get queGuardaKiji;

  /// No description provided for @sinCuentasSinAnunciosYSin.
  ///
  /// In es, this message translates to:
  /// **'Sin cuentas, sin anuncios y sin telemetría.'**
  String get sinCuentasSinAnunciosYSin;

  /// No description provided for @sinCuentasSinAnunciosYSin2.
  ///
  /// In es, this message translates to:
  /// **'Sin cuentas, sin anuncios y sin telemetría. Tu cola, tus descargas, tu historial y tus me gusta se guardan solo en este dispositivo.'**
  String get sinCuentasSinAnunciosYSin2;

  /// No description provided for @letrasYTraduccion.
  ///
  /// In es, this message translates to:
  /// **'Letras y traducción'**
  String get letrasYTraduccion;

  /// No description provided for @queSeEnviaAlBuscarO.
  ///
  /// In es, this message translates to:
  /// **'Qué se envía al buscar o traducir una letra.'**
  String get queSeEnviaAlBuscarO;

  /// No description provided for @alAbrirUnaLetraCadaFuente.
  ///
  /// In es, this message translates to:
  /// **'Al abrir una letra, cada fuente recibe solo título, artista, álbum, duración o el id del video. La traducción en el teléfono no envía nada (solo se baja el modelo del idioma, una vez). Gemini es opcional y está apagado: si lo activas, las líneas de la letra van a Google con tu clave, que queda cifrada solo en este dispositivo.'**
  String get alAbrirUnaLetraCadaFuente;

  /// No description provided for @actualizacionesYGithub.
  ///
  /// In es, this message translates to:
  /// **'Actualizaciones y GitHub'**
  String get actualizacionesYGithub;

  /// No description provided for @queVeGithubCuandoKijiBusca.
  ///
  /// In es, this message translates to:
  /// **'Qué ve GitHub cuando Kiji busca una versión nueva.'**
  String get queVeGithubCuandoKijiBusca;

  /// No description provided for @recomendacionesDeInicio.
  ///
  /// In es, this message translates to:
  /// **'Recomendaciones de Inicio'**
  String get recomendacionesDeInicio;

  /// No description provided for @queSeLePideAYoutube.
  ///
  /// In es, this message translates to:
  /// **'Qué se le pide a YouTube Music para \"Porque escuchaste\", \"Mezcla\" y \"Descubre\".'**
  String get queSeLePideAYoutube;

  /// No description provided for @tuGustoSeCalculaEnEste.
  ///
  /// In es, this message translates to:
  /// **'Tu gusto se calcula en este teléfono. A YouTube Music solo se le piden, sin cuenta, las canciones relacionadas con hasta 5 que escuchaste (solo su id). Tu historial no sale de aquí.'**
  String get tuGustoSeCalculaEnEste;

  /// No description provided for @borrarLasBusquedasRecientes.
  ///
  /// In es, this message translates to:
  /// **'Borrar las búsquedas recientes'**
  String get borrarLasBusquedasRecientes;

  /// No description provided for @lasQueAparecenEnBuscarAntes.
  ///
  /// In es, this message translates to:
  /// **'Las que aparecen en Buscar antes de escribir.'**
  String get lasQueAparecenEnBuscarAntes;

  /// No description provided for @guardadasEnEsteDispositivo.
  ///
  /// In es, this message translates to:
  /// **'{p0} guardadas en este dispositivo'**
  String guardadasEnEsteDispositivo(Object? p0);

  /// No description provided for @busquedasBorradas.
  ///
  /// In es, this message translates to:
  /// **'Búsquedas borradas'**
  String get busquedasBorradas;

  /// No description provided for @borrarElHistorialDeEscucha.
  ///
  /// In es, this message translates to:
  /// **'Borrar el historial de escucha'**
  String get borrarElHistorialDeEscucha;

  /// No description provided for @vaciaEscuchadoRecientementeYParaTi.
  ///
  /// In es, this message translates to:
  /// **'Vacía \"Escuchado recientemente\" y \"Para ti\".'**
  String get vaciaEscuchadoRecientementeYParaTi;

  /// No description provided for @cancionesRecordadas.
  ///
  /// In es, this message translates to:
  /// **'{p0} canciones recordadas'**
  String cancionesRecordadas(Object? p0);

  /// No description provided for @borrarElHistorial.
  ///
  /// In es, this message translates to:
  /// **'¿Borrar el historial?'**
  String get borrarElHistorial;

  /// No description provided for @inicioDejaDeMostrarEscuchadoRecientement.
  ///
  /// In es, this message translates to:
  /// **'Inicio deja de mostrar \"Escuchado recientemente\" y \"Para ti\" hasta que vuelvas a escuchar música. No borra canciones ni descargas.'**
  String get inicioDejaDeMostrarEscuchadoRecientement;

  /// No description provided for @historialBorrado.
  ///
  /// In es, this message translates to:
  /// **'Historial borrado'**
  String get historialBorrado;

  /// No description provided for @datosDelReproductorDeYoutubeGithub.
  ///
  /// In es, this message translates to:
  /// **'Datos del reproductor de YouTube (GitHub)'**
  String get datosDelReproductorDeYoutubeGithub;

  /// No description provided for @queSeConsultaParaPoderDescifrar.
  ///
  /// In es, this message translates to:
  /// **'Qué se consulta para poder descifrar el audio.'**
  String get queSeConsultaParaPoderDescifrar;

  /// No description provided for @youtubeCambiaSuReproductorCadaPocos.
  ///
  /// In es, this message translates to:
  /// **'YouTube cambia su reproductor cada pocos días. Para seguir descifrando el audio, Kiji baja como mucho cada 6 horas una tabla pública (player_configs.json del proyecto libre zemer-cipher, en GitHub), igual que Echo y Metrolist. GitHub ve esa consulta como una visita a una página; no se manda nada tuyo.'**
  String get youtubeCambiaSuReproductorCadaPocos;

  /// No description provided for @pruebasAutomaticasDelExtractor.
  ///
  /// In es, this message translates to:
  /// **'Pruebas automáticas del extractor'**
  String get pruebasAutomaticasDelExtractor;

  /// No description provided for @cada12HPruebaLasFormas.
  ///
  /// In es, this message translates to:
  /// **'Cada 12 h prueba las formas con canciones de control; solo avisa si fallan todas.'**
  String get cada12HPruebaLasFormas;

  /// No description provided for @alAbrirKijiSiPasaron12.
  ///
  /// In es, this message translates to:
  /// **'Al abrir Kiji (si pasaron 12 h), cada 12 h en la PC y una vez por día en Android (solo con WiFi y batería no baja). Usa 3 canciones de control, nunca tus datos. Solo avisa si no funciona ninguna forma.'**
  String get alAbrirKijiSiPasaron12;

  /// No description provided for @saludDelExtractor.
  ///
  /// In es, this message translates to:
  /// **'Salud del Extractor'**
  String get saludDelExtractor;

  /// No description provided for @comoEstaFuncionandoYoutubeHoy.
  ///
  /// In es, this message translates to:
  /// **'Cómo está funcionando YouTube hoy.'**
  String get comoEstaFuncionandoYoutubeHoy;

  /// No description provided for @cuentaDeGoogleOpcional.
  ///
  /// In es, this message translates to:
  /// **'Cuenta de Google (opcional)'**
  String get cuentaDeGoogleOpcional;

  /// No description provided for @soloParaCancionesQueYoutubeEntrega.
  ///
  /// In es, this message translates to:
  /// **'Solo para canciones que YouTube entrega únicamente a cuentas.'**
  String get soloParaCancionesQueYoutubeEntrega;

  /// No description provided for @iniciarSesion2.
  ///
  /// In es, this message translates to:
  /// **'iniciar sesion'**
  String get iniciarSesion2;

  /// No description provided for @cerrarSesion.
  ///
  /// In es, this message translates to:
  /// **'cerrar sesion'**
  String get cerrarSesion;

  /// No description provided for @sesionIniciada2.
  ///
  /// In es, this message translates to:
  /// **'Sesión iniciada'**
  String get sesionIniciada2;

  /// No description provided for @tocaParaVerOCerrarLa.
  ///
  /// In es, this message translates to:
  /// **'Toca para ver o cerrar la sesión.'**
  String get tocaParaVerOCerrarLa;

  /// No description provided for @guardarUnRegistroEnEsteDispositivo.
  ///
  /// In es, this message translates to:
  /// **'Guardar un registro en este dispositivo'**
  String get guardarUnRegistroEnEsteDispositivo;

  /// No description provided for @ayudaAEntenderUnaFallaSin.
  ///
  /// In es, this message translates to:
  /// **'Ayuda a entender una falla. Sin datos personales, ocupa como mucho 1 MB y nunca sale del dispositivo si tú no lo mandas.'**
  String get ayudaAEntenderUnaFallaSin;

  /// No description provided for @ofrecerUnInformeCuandoAlgoFalla.
  ///
  /// In es, this message translates to:
  /// **'Ofrecer un informe cuando algo falla'**
  String get ofrecerUnInformeCuandoAlgoFalla;

  /// No description provided for @kijiPreguntaSiQuieresAvisarAl.
  ///
  /// In es, this message translates to:
  /// **'Kiji pregunta si quieres avisar al desarrollador. Nunca manda nada solo.'**
  String get kijiPreguntaSiQuieresAvisarAl;

  /// No description provided for @verElRegistroYLosInformes.
  ///
  /// In es, this message translates to:
  /// **'Ver el registro y los informes'**
  String get verElRegistroYLosInformes;

  /// No description provided for @leerElRegistroDescargarUnInforme.
  ///
  /// In es, this message translates to:
  /// **'Leer el registro, descargar un informe (.txt) o mandarlo al desarrollador.'**
  String get leerElRegistroDescargarUnInforme;

  /// No description provided for @herramientasDeDesarrollo.
  ///
  /// In es, this message translates to:
  /// **'Herramientas de desarrollo'**
  String get herramientasDeDesarrollo;

  /// No description provided for @registroEnVivoExtractorCacheY.
  ///
  /// In es, this message translates to:
  /// **'Registro en vivo, extractor, caché y descargas.'**
  String get registroEnVivoExtractorCacheY;

  /// No description provided for @buscarActualizaciones.
  ///
  /// In es, this message translates to:
  /// **'Buscar actualizaciones'**
  String get buscarActualizaciones;

  /// No description provided for @unaVezPorDiaPreguntaA.
  ///
  /// In es, this message translates to:
  /// **'Una vez por día pregunta a GitHub si hay una versión nueva. Nunca baja ni instala nada.'**
  String get unaVezPorDiaPreguntaA;

  /// No description provided for @unaVezPorDiaPreguntaA2.
  ///
  /// In es, this message translates to:
  /// **'Una vez por día pregunta a GitHub si hay una versión nueva y te muestra sus novedades. Nunca baja ni instala nada por su cuenta.'**
  String get unaVezPorDiaPreguntaA2;

  /// No description provided for @versionDeKiji.
  ///
  /// In es, this message translates to:
  /// **'Versión de Kiji'**
  String get versionDeKiji;

  /// No description provided for @buscarAhoraYVerLasNovedades.
  ///
  /// In es, this message translates to:
  /// **'Buscar ahora y ver las novedades.'**
  String get buscarAhoraYVerLasNovedades;

  /// No description provided for @buscarAhora.
  ///
  /// In es, this message translates to:
  /// **'buscar ahora'**
  String get buscarAhora;

  /// No description provided for @importarDesdeOtraApp.
  ///
  /// In es, this message translates to:
  /// **'Importar desde otra app'**
  String get importarDesdeOtraApp;

  /// No description provided for @echoMetrolistInnertuneOutertuneM3uExport.
  ///
  /// In es, this message translates to:
  /// **'Echo, Metrolist, InnerTune, OuterTune, .m3u, Exportify y Google Takeout.'**
  String get echoMetrolistInnertuneOutertuneM3uExport;

  /// No description provided for @playlistsMeGustaEHistorialDe.
  ///
  /// In es, this message translates to:
  /// **'Playlists, me gusta e historial de Echo, Metrolist, InnerTune u OuterTune (.backup), .m3u, y CSV de Exportify o Google Takeout. También exportar tus playlists.'**
  String get playlistsMeGustaEHistorialDe;

  /// No description provided for @copiaDeSeguridadDeKiji.
  ///
  /// In es, this message translates to:
  /// **'Copia de seguridad de Kiji'**
  String get copiaDeSeguridadDeKiji;

  /// No description provided for @copiaDiariaAutomaticaEnDocumentosKiji.
  ///
  /// In es, this message translates to:
  /// **'Copia diaria automática en Documentos/Kiji; restaurar con vista previa.'**
  String get copiaDiariaAutomaticaEnDocumentosKiji;

  /// No description provided for @copiaAutomaticaApagada.
  ///
  /// In es, this message translates to:
  /// **'Copia automática apagada'**
  String get copiaAutomaticaApagada;

  /// No description provided for @ultima.
  ///
  /// In es, this message translates to:
  /// **'última: {p0}'**
  String ultima(Object? p0);

  /// No description provided for @softwareLibreGpl30.
  ///
  /// In es, this message translates to:
  /// **'Software libre (GPL-3.0).'**
  String get softwareLibreGpl30;

  /// No description provided for @canalCompiladaElSoftwareLibreGpl.
  ///
  /// In es, this message translates to:
  /// **'Canal {p0} · compilada el {p1}\nSoftware libre (GPL-3.0). Sin pagos, sin anuncios y sin telemetría.'**
  String canalCompiladaElSoftwareLibreGpl(Object? p0, Object? p1);

  /// No description provided for @losProyectosLibresEnLosQue.
  ///
  /// In es, this message translates to:
  /// **'Los proyectos libres en los que se basa Kiji.'**
  String get losProyectosLibresEnLosQue;

  /// No description provided for @temporizadorLaMusicaQuedoEnPausa.
  ///
  /// In es, this message translates to:
  /// **'Temporizador: la música quedó en pausa. Que descanses.'**
  String get temporizadorLaMusicaQuedoEnPausa;

  /// No description provided for @enUnosMinutos.
  ///
  /// In es, this message translates to:
  /// **'En unos minutos'**
  String get enUnosMinutos;

  /// No description provided for @minutos.
  ///
  /// In es, this message translates to:
  /// **'Minutos'**
  String get minutos;

  /// No description provided for @alTerminarEstaCancion.
  ///
  /// In es, this message translates to:
  /// **'Al terminar esta canción'**
  String get alTerminarEstaCancion;

  /// No description provided for @estaCancion.
  ///
  /// In es, this message translates to:
  /// **'Esta canción'**
  String get estaCancion;

  /// No description provided for @alTerminarLaCola.
  ///
  /// In es, this message translates to:
  /// **'Al terminar la cola'**
  String get alTerminarLaCola;

  /// No description provided for @finDeLaCola.
  ///
  /// In es, this message translates to:
  /// **'Fin de la cola'**
  String get finDeLaCola;

  /// No description provided for @hastaUnaCancionDeLaCola.
  ///
  /// In es, this message translates to:
  /// **'Hasta una canción de la cola'**
  String get hastaUnaCancionDeLaCola;

  /// No description provided for @hastaCancion.
  ///
  /// In es, this message translates to:
  /// **'Hasta canción'**
  String get hastaCancion;

  /// No description provided for @enUnMomentoExacto.
  ///
  /// In es, this message translates to:
  /// **'En un momento exacto'**
  String get enUnMomentoExacto;

  /// No description provided for @momentoExacto.
  ///
  /// In es, this message translates to:
  /// **'Momento exacto'**
  String get momentoExacto;

  /// No description provided for @laCancion.
  ///
  /// In es, this message translates to:
  /// **'la canción'**
  String get laCancion;

  /// No description provided for @seQuitoDeLaColaEl.
  ///
  /// In es, this message translates to:
  /// **'Se quitó «{p0}» de la cola: el temporizador se apagó.'**
  String seQuitoDeLaColaEl(Object? p0);

  /// No description provided for @cambioLaCancionElTemporizadorDe.
  ///
  /// In es, this message translates to:
  /// **'Cambió la canción: el temporizador de momento exacto se apagó.'**
  String get cambioLaCancionElTemporizadorDe;

  /// No description provided for @temporizador.
  ///
  /// In es, this message translates to:
  /// **'Temporizador'**
  String get temporizador;

  /// No description provided for @laMusicaBajaDeAPoco.
  ///
  /// In es, this message translates to:
  /// **'La música baja de a poco durante los últimos 30 segundos (o menos, si falta poco) y queda en pausa.'**
  String get laMusicaBajaDeAPoco;

  /// No description provided for @alTerminar.
  ///
  /// In es, this message translates to:
  /// **'Al terminar «{p0}»'**
  String alTerminar(Object? p0);

  /// No description provided for @enElDe.
  ///
  /// In es, this message translates to:
  /// **'En el {p0} de «{p1}»'**
  String enElDe(Object? p0, Object? p1);

  /// No description provided for @activo.
  ///
  /// In es, this message translates to:
  /// **'ACTIVO'**
  String get activo;

  /// No description provided for @faltan.
  ///
  /// In es, this message translates to:
  /// **'Faltan {p0}'**
  String faltan(Object? p0);

  /// No description provided for @apagarElTemporizador.
  ///
  /// In es, this message translates to:
  /// **'Apagar el temporizador'**
  String get apagarElTemporizador;

  /// No description provided for @enUnosMinutos2.
  ///
  /// In es, this message translates to:
  /// **'EN UNOS MINUTOS'**
  String get enUnosMinutos2;

  /// No description provided for @otroNumeroDeMinutos.
  ///
  /// In es, this message translates to:
  /// **'Otro número de minutos'**
  String get otroNumeroDeMinutos;

  /// No description provided for @de1A600.
  ///
  /// In es, this message translates to:
  /// **'De 1 a 600'**
  String get de1A600;

  /// No description provided for @iniciar.
  ///
  /// In es, this message translates to:
  /// **'Iniciar'**
  String get iniciar;

  /// No description provided for @paraHastaUnaCancionEligelaEn.
  ///
  /// In es, this message translates to:
  /// **'Para \"hasta una canción\", elígela en la Cola (menú ⋮ → luna).'**
  String get paraHastaUnaCancionEligelaEn;

  /// No description provided for @eligeElSegundoDeLaCancion.
  ///
  /// In es, this message translates to:
  /// **'Elige el segundo de la canción que suena'**
  String get eligeElSegundoDeLaCancion;

  /// No description provided for @marcarEnLaOnda.
  ///
  /// In es, this message translates to:
  /// **'Marcar en la onda'**
  String get marcarEnLaOnda;

  /// No description provided for @tocaLaOndaDelReproductorDonde.
  ///
  /// In es, this message translates to:
  /// **'Toca la onda del reproductor donde quieres que se pause'**
  String get tocaLaOndaDelReproductorDonde;

  /// No description provided for @pausarEnEsteMomento.
  ///
  /// In es, this message translates to:
  /// **'Pausar en este momento'**
  String get pausarEnEsteMomento;

  /// No description provided for @eseMomentoYaPasoLaMusica.
  ///
  /// In es, this message translates to:
  /// **'Ese momento ya pasó: la música se pausa cuando vuelva ahí (si vuelves atrás o la canción se repite).'**
  String get eseMomentoYaPasoLaMusica;

  /// No description provided for @laMusicaSeVaAPausar2.
  ///
  /// In es, this message translates to:
  /// **'La música se va a pausar en el {p0}{p1}.'**
  String laMusicaSeVaAPausar2(Object? p0, Object? p1);

  /// No description provided for @tocaLaOndaDondeQuieresQue.
  ///
  /// In es, this message translates to:
  /// **'Toca la onda donde quieres que se pause'**
  String get tocaLaOndaDondeQuieresQue;

  /// No description provided for @youtubeNoDijoElTamanoDel2.
  ///
  /// In es, this message translates to:
  /// **'YouTube no dijo el tamaño del audio'**
  String get youtubeNoDijoElTamanoDel2;

  /// No description provided for @youtubeRechazoElAudioHttpY.
  ///
  /// In es, this message translates to:
  /// **'YouTube rechazó el audio (HTTP {p0}) y no hubo otra URL'**
  String youtubeRechazoElAudioHttpY(Object? p0);

  /// No description provided for @youtubeRechazoElAudioHttp.
  ///
  /// In es, this message translates to:
  /// **'YouTube rechazó el audio (HTTP {p0})'**
  String youtubeRechazoElAudioHttp(Object? p0);

  /// No description provided for @reproduccion2.
  ///
  /// In es, this message translates to:
  /// **'Reproducción'**
  String get reproduccion2;

  /// No description provided for @controlesDeLaMusicaQueEsta.
  ///
  /// In es, this message translates to:
  /// **'Controles de la música que está sonando'**
  String get controlesDeLaMusicaQueEsta;

  /// No description provided for @sinConexionAInternet.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión a internet.'**
  String get sinConexionAInternet;

  /// No description provided for @llegasteAlLimiteGratuitoDeGemini.
  ///
  /// In es, this message translates to:
  /// **'Llegaste al límite gratuito de Gemini por hoy. Prueba mañana.'**
  String get llegasteAlLimiteGratuitoDeGemini;

  /// No description provided for @laClaveNoEsValidaRevisala.
  ///
  /// In es, this message translates to:
  /// **'La clave no es válida. Revisala.'**
  String get laClaveNoEsValidaRevisala;

  /// No description provided for @googleRechazoLaClaveOEl.
  ///
  /// In es, this message translates to:
  /// **'Google rechazó la clave (o el nivel gratuito no está disponible en tu país).'**
  String get googleRechazoLaClaveOEl;

  /// No description provided for @geminiNoRespondioHttp.
  ///
  /// In es, this message translates to:
  /// **'Gemini no respondió (HTTP {p0}).'**
  String geminiNoRespondioHttp(Object? p0);

  /// No description provided for @geminiRespondioAlgoQueKijiNo.
  ///
  /// In es, this message translates to:
  /// **'Gemini respondió algo que Kiji no entiende.'**
  String get geminiRespondioAlgoQueKijiNo;

  /// No description provided for @geminiDevolvioOtraCantidadDeLineas.
  ///
  /// In es, this message translates to:
  /// **'Gemini devolvió otra cantidad de líneas. Prueba de nuevo.'**
  String get geminiDevolvioOtraCantidadDeLineas;

  /// No description provided for @noSePudoSaberEnQue.
  ///
  /// In es, this message translates to:
  /// **'No se pudo saber en qué idioma está la letra.'**
  String get noSePudoSaberEnQue;

  /// No description provided for @laLetraYaEstaEn.
  ///
  /// In es, this message translates to:
  /// **'La letra ya está en {p0}.'**
  String laLetraYaEstaEn(Object? p0);

  /// No description provided for @noSePudoConsultarLaLista.
  ///
  /// In es, this message translates to:
  /// **'No se pudo consultar la lista de idiomas (¿sin conexión?).'**
  String get noSePudoConsultarLaLista;

  /// No description provided for @todaviaNoHayTraduccionDeA.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay traducción de {p0} a {p1}.'**
  String todaviaNoHayTraduccionDeA(Object? p0, Object? p1);

  /// No description provided for @faltaLaClaveDeGeminiConfiguracion.
  ///
  /// In es, this message translates to:
  /// **'Falta la clave de Gemini (Configuración → Letras → Traducción).'**
  String get faltaLaClaveDeGeminiConfiguracion;

  /// No description provided for @espanol.
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get espanol;

  /// No description provided for @ingles.
  ///
  /// In es, this message translates to:
  /// **'Inglés'**
  String get ingles;

  /// No description provided for @portugues.
  ///
  /// In es, this message translates to:
  /// **'Portugués'**
  String get portugues;

  /// No description provided for @frances.
  ///
  /// In es, this message translates to:
  /// **'Francés'**
  String get frances;

  /// No description provided for @italiano.
  ///
  /// In es, this message translates to:
  /// **'Italiano'**
  String get italiano;

  /// No description provided for @aleman.
  ///
  /// In es, this message translates to:
  /// **'Alemán'**
  String get aleman;

  /// No description provided for @neerlandes.
  ///
  /// In es, this message translates to:
  /// **'Neerlandés'**
  String get neerlandes;

  /// No description provided for @catalan.
  ///
  /// In es, this message translates to:
  /// **'Catalán'**
  String get catalan;

  /// No description provided for @polaco.
  ///
  /// In es, this message translates to:
  /// **'Polaco'**
  String get polaco;

  /// No description provided for @ruso.
  ///
  /// In es, this message translates to:
  /// **'Ruso'**
  String get ruso;

  /// No description provided for @ucraniano.
  ///
  /// In es, this message translates to:
  /// **'Ucraniano'**
  String get ucraniano;

  /// No description provided for @turco.
  ///
  /// In es, this message translates to:
  /// **'Turco'**
  String get turco;

  /// No description provided for @arabe.
  ///
  /// In es, this message translates to:
  /// **'Árabe'**
  String get arabe;

  /// No description provided for @hebreo.
  ///
  /// In es, this message translates to:
  /// **'Hebreo'**
  String get hebreo;

  /// No description provided for @hindi.
  ///
  /// In es, this message translates to:
  /// **'Hindi'**
  String get hindi;

  /// No description provided for @japones.
  ///
  /// In es, this message translates to:
  /// **'Japonés'**
  String get japones;

  /// No description provided for @coreano.
  ///
  /// In es, this message translates to:
  /// **'Coreano'**
  String get coreano;

  /// No description provided for @chinoSimplificado.
  ///
  /// In es, this message translates to:
  /// **'Chino (simplificado)'**
  String get chinoSimplificado;

  /// No description provided for @chinoTradicional.
  ///
  /// In es, this message translates to:
  /// **'Chino (tradicional)'**
  String get chinoTradicional;

  /// No description provided for @indonesio.
  ///
  /// In es, this message translates to:
  /// **'Indonesio'**
  String get indonesio;

  /// No description provided for @vietnamita.
  ///
  /// In es, this message translates to:
  /// **'Vietnamita'**
  String get vietnamita;

  /// No description provided for @tailandes.
  ///
  /// In es, this message translates to:
  /// **'Tailandés'**
  String get tailandes;

  /// No description provided for @sueco.
  ///
  /// In es, this message translates to:
  /// **'Sueco'**
  String get sueco;

  /// No description provided for @danes.
  ///
  /// In es, this message translates to:
  /// **'Danés'**
  String get danes;

  /// No description provided for @noruego.
  ///
  /// In es, this message translates to:
  /// **'Noruego'**
  String get noruego;

  /// No description provided for @fines.
  ///
  /// In es, this message translates to:
  /// **'Finés'**
  String get fines;

  /// No description provided for @griego.
  ///
  /// In es, this message translates to:
  /// **'Griego'**
  String get griego;

  /// No description provided for @checo.
  ///
  /// In es, this message translates to:
  /// **'Checo'**
  String get checo;

  /// No description provided for @rumano.
  ///
  /// In es, this message translates to:
  /// **'Rumano'**
  String get rumano;

  /// No description provided for @hungaro.
  ///
  /// In es, this message translates to:
  /// **'Húngaro'**
  String get hungaro;

  /// No description provided for @laLetraSeTraduceDentroDe.
  ///
  /// In es, this message translates to:
  /// **'La letra se traduce dentro de tu teléfono. No se envía a nadie y no pierdes anonimato. Solo una vez por idioma se descarga el modelo de traducción (el servidor solo sabe que alguien bajó ese idioma, no qué canción). Es buena para entender la letra, aunque a veces suena literal.'**
  String get laLetraSeTraduceDentroDe;

  /// No description provided for @tituloArtistaAlbumYDuracion.
  ///
  /// In es, this message translates to:
  /// **'título, artista, álbum y duración'**
  String get tituloArtistaAlbumYDuracion;

  /// No description provided for @tituloArtistaAlbumDuracionEId.
  ///
  /// In es, this message translates to:
  /// **'título, artista, álbum, duración e id del video'**
  String get tituloArtistaAlbumDuracionEId;

  /// No description provided for @tituloYArtista.
  ///
  /// In es, this message translates to:
  /// **'título y artista'**
  String get tituloYArtista;

  /// No description provided for @idDelVideoOTituloArtista.
  ///
  /// In es, this message translates to:
  /// **'id del video, o título, artista y duración'**
  String get idDelVideoOTituloArtista;

  /// No description provided for @tituloArtistaYDuracion.
  ///
  /// In es, this message translates to:
  /// **'título, artista y duración'**
  String get tituloArtistaYDuracion;

  /// No description provided for @idDelVideoAYoutube.
  ///
  /// In es, this message translates to:
  /// **'id del video (a YouTube)'**
  String get idDelVideoAYoutube;

  /// No description provided for @idDelVideoAYoutubeMusic.
  ///
  /// In es, this message translates to:
  /// **'id del video (a YouTube Music)'**
  String get idDelVideoAYoutubeMusic;

  /// No description provided for @kijiBuscaLaLetraPrimeroEn.
  ///
  /// In es, this message translates to:
  /// **'Kiji busca la letra primero en el archivo (sin internet) y después en estas fuentes, en este orden, hasta que una la tenga. Arrastra para cambiar el orden. Solo se busca cuando abres la letra, y cada fuente recibe únicamente lo que dice abajo; nada tuyo.'**
  String get kijiBuscaLaLetraPrimeroEn;

  /// No description provided for @arrastrarParaCambiarElOrden.
  ///
  /// In es, this message translates to:
  /// **'Arrastrar para cambiar el orden'**
  String get arrastrarParaCambiarElOrden;

  /// No description provided for @recibe.
  ///
  /// In es, this message translates to:
  /// **'Recibe: {p0}'**
  String recibe(Object? p0);

  /// No description provided for @originalYTraduccionSeVenLinea.
  ///
  /// In es, this message translates to:
  /// **'Original y traducción se ven línea por línea (en la letra: ⋮ → Traducir la letra). Cada traducción se guarda para no repetirla.'**
  String get originalYTraduccionSeVenLinea;

  /// No description provided for @traducirAl.
  ///
  /// In es, this message translates to:
  /// **'Traducir al'**
  String get traducirAl;

  /// No description provided for @n1EnTuTelefonoAnonimo.
  ///
  /// In es, this message translates to:
  /// **'1 · En tu teléfono (anónimo)'**
  String get n1EnTuTelefonoAnonimo;

  /// No description provided for @idiomasBajados.
  ///
  /// In es, this message translates to:
  /// **'IDIOMAS BAJADOS'**
  String get idiomasBajados;

  /// No description provided for @ningunoTodaviaSeBajanSolosAvisando.
  ///
  /// In es, this message translates to:
  /// **'Ninguno todavía: se bajan solos (avisando el tamaño) la primera vez que traduces.'**
  String get ningunoTodaviaSeBajanSolosAvisando;

  /// No description provided for @n2ConIaGemini.
  ///
  /// In es, this message translates to:
  /// **'2 · Con IA (Gemini)'**
  String get n2ConIaGemini;

  /// No description provided for @traducirConGemini.
  ///
  /// In es, this message translates to:
  /// **'Traducir con Gemini'**
  String get traducirConGemini;

  /// No description provided for @apagadoAntesDeActivarloVasA.
  ///
  /// In es, this message translates to:
  /// **'Apagado. Antes de activarlo vas a ver qué implica.'**
  String get apagadoAntesDeActivarloVasA;

  /// No description provided for @usarGeminiParaTraducir.
  ///
  /// In es, this message translates to:
  /// **'Usar Gemini para traducir'**
  String get usarGeminiParaTraducir;

  /// No description provided for @siLoApagasSeTraduceEn.
  ///
  /// In es, this message translates to:
  /// **'Si lo apagas, se traduce en el teléfono.'**
  String get siLoApagasSeTraduceEn;

  /// No description provided for @pierdesParteDelAnonimatoLasLineas.
  ///
  /// In es, this message translates to:
  /// **'Pierdes parte del anonimato: las líneas de la letra se envían a Google, asociadas a tu cuenta de Google (por la clave).'**
  String get pierdesParteDelAnonimatoLasLineas;

  /// No description provided for @enElNivelGratuitoGoogleUsa.
  ///
  /// In es, this message translates to:
  /// **'En el nivel gratuito, Google usa ese contenido para mejorar sus productos y personas de Google pueden leerlo (Google dice que lo separa de tu cuenta antes).'**
  String get enElNivelGratuitoGoogleUsa;

  /// No description provided for @kijiNoEnviaTuNombreTu.
  ///
  /// In es, this message translates to:
  /// **'Kiji NO envía tu nombre, tu historial ni tu biblioteca: solo las líneas de la letra y el idioma de destino.'**
  String get kijiNoEnviaTuNombreTu;

  /// No description provided for @requisitosDeGoogleTener18Anos.
  ///
  /// In es, this message translates to:
  /// **'Requisitos de Google: tener 18 años o más. En Europa, Reino Unido y Suiza el nivel gratuito no está permitido para esto.'**
  String get requisitosDeGoogleTener18Anos;

  /// No description provided for @antesDeUsarGemini.
  ///
  /// In es, this message translates to:
  /// **'Antes de usar Gemini'**
  String get antesDeUsarGemini;

  /// No description provided for @queCambiaSiActivasLaTraduccion.
  ///
  /// In es, this message translates to:
  /// **'Qué cambia si activas la traducción con Gemini'**
  String get queCambiaSiActivasLaTraduccion;

  /// No description provided for @siNoQuieresNadaDeEsto.
  ///
  /// In es, this message translates to:
  /// **'Si no quieres nada de esto, la traducción en tu teléfono sigue disponible y es anónima.'**
  String get siNoQuieresNadaDeEsto;

  /// No description provided for @entiendoActivar.
  ///
  /// In es, this message translates to:
  /// **'Entiendo, activar'**
  String get entiendoActivar;

  /// No description provided for @mejorNo.
  ///
  /// In es, this message translates to:
  /// **'Mejor no'**
  String get mejorNo;

  /// No description provided for @pegaLaClavePrimero.
  ///
  /// In es, this message translates to:
  /// **'Pega la clave primero.'**
  String get pegaLaClavePrimero;

  /// No description provided for @noSePudoGuardarLaClave.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar la clave cifrada en este dispositivo.'**
  String get noSePudoGuardarLaClave;

  /// No description provided for @laClaveAndaGuardadaCifrada.
  ///
  /// In es, this message translates to:
  /// **'La clave anda. Guardada cifrada.'**
  String get laClaveAndaGuardadaCifrada;

  /// No description provided for @mientrasTantoPuedesTraducirEnEl.
  ///
  /// In es, this message translates to:
  /// **'{p0} Mientras tanto puedes traducir en el teléfono.'**
  String mientrasTantoPuedesTraducirEnEl(Object? p0);

  /// No description provided for @comoConseguirTuClave.
  ///
  /// In es, this message translates to:
  /// **'CÓMO CONSEGUIR TU CLAVE'**
  String get comoConseguirTuClave;

  /// No description provided for @n1EntraAAistudioGoogleCom.
  ///
  /// In es, this message translates to:
  /// **'1. Entra a aistudio.google.com con tu cuenta de Google.'**
  String get n1EntraAAistudioGoogleCom;

  /// No description provided for @abrir.
  ///
  /// In es, this message translates to:
  /// **'Abrir'**
  String get abrir;

  /// No description provided for @n2TocaGetApiKeyCreate.
  ///
  /// In es, this message translates to:
  /// **'2. Toca \"Get API key\" → \"Create API key\" (no pide tarjeta).'**
  String get n2TocaGetApiKeyCreate;

  /// No description provided for @n3CopiaLaClaveYPegala.
  ///
  /// In es, this message translates to:
  /// **'3. Copia la clave y pégala aquí abajo.'**
  String get n3CopiaLaClaveYPegala;

  /// No description provided for @n4TocaProbar.
  ///
  /// In es, this message translates to:
  /// **'4. Toca \"Probar\".'**
  String get n4TocaProbar;

  /// No description provided for @n5EligeElModeloKijiRecomienda.
  ///
  /// In es, this message translates to:
  /// **'5. Elige el modelo (Kiji recomienda el más liviano, Flash-Lite).'**
  String get n5EligeElModeloKijiRecomienda;

  /// No description provided for @claveDeGemini.
  ///
  /// In es, this message translates to:
  /// **'Clave de Gemini'**
  String get claveDeGemini;

  /// No description provided for @pegar.
  ///
  /// In es, this message translates to:
  /// **'Pegar'**
  String get pegar;

  /// No description provided for @probar.
  ///
  /// In es, this message translates to:
  /// **'Probar'**
  String get probar;

  /// No description provided for @borrarClave.
  ///
  /// In es, this message translates to:
  /// **'Borrar clave'**
  String get borrarClave;

  /// No description provided for @claveBorradaDeEsteDispositivo.
  ///
  /// In es, this message translates to:
  /// **'Clave borrada de este dispositivo.'**
  String get claveBorradaDeEsteDispositivo;

  /// No description provided for @modelo.
  ///
  /// In es, this message translates to:
  /// **'Modelo'**
  String get modelo;

  /// No description provided for @modelo2.
  ///
  /// In es, this message translates to:
  /// **'Modelo: {p0}'**
  String modelo2(Object? p0);

  /// No description provided for @noSePudoTraducir.
  ///
  /// In es, this message translates to:
  /// **'No se pudo traducir: {p0}'**
  String noSePudoTraducir(Object? p0);

  /// No description provided for @paraTraducirDelEnTuTelefono.
  ///
  /// In es, this message translates to:
  /// **'Para traducir del {p0} en tu teléfono hace falta bajar {p1} (una sola vez). El servidor solo sabe que alguien bajó ese idioma, no qué canción.'**
  String paraTraducirDelEnTuTelefono(Object? p0, Object? p1);

  /// No description provided for @bajar.
  ///
  /// In es, this message translates to:
  /// **'Bajar {p0}'**
  String bajar(Object? p0);

  /// No description provided for @traducirEnElTelefono.
  ///
  /// In es, this message translates to:
  /// **'Traducir en el teléfono'**
  String get traducirEnElTelefono;

  /// No description provided for @recien.
  ///
  /// In es, this message translates to:
  /// **'recién'**
  String get recien;

  /// No description provided for @haceMin.
  ///
  /// In es, this message translates to:
  /// **'hace {p0} min'**
  String haceMin(Object? p0);

  /// No description provided for @kiji.
  ///
  /// In es, this message translates to:
  /// **'Kiji {p0}'**
  String kiji(Object? p0);

  /// No description provided for @kijiNuncaSeActualizaSoloNi.
  ///
  /// In es, this message translates to:
  /// **'Kiji nunca se actualiza solo ni baja nada: la descarga la haces tú desde la página oficial, si quieres.'**
  String get kijiNuncaSeActualizaSoloNi;

  /// No description provided for @abrirLaPaginaOficial.
  ///
  /// In es, this message translates to:
  /// **'Abrir la página oficial'**
  String get abrirLaPaginaOficial;

  /// No description provided for @hayUnaVersionNueva.
  ///
  /// In es, this message translates to:
  /// **'Hay una versión nueva: {p0}'**
  String hayUnaVersionNueva(Object? p0);

  /// No description provided for @ultimaConsulta.
  ///
  /// In es, this message translates to:
  /// **'Última consulta: {p0}.'**
  String ultimaConsulta(Object? p0);

  /// No description provided for @buscarAhora2.
  ///
  /// In es, this message translates to:
  /// **'Buscar ahora'**
  String get buscarAhora2;

  /// No description provided for @todaviaNoHayVersionesPublicadas.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay versiones publicadas.'**
  String get todaviaNoHayVersionesPublicadas;

  /// No description provided for @tienesLaUltimaVersion.
  ///
  /// In es, this message translates to:
  /// **'Tienes la última versión ({p0}).'**
  String tienesLaUltimaVersion(Object? p0);

  /// No description provided for @noSePudoConsultarRevisaTu.
  ///
  /// In es, this message translates to:
  /// **'No se pudo consultar. Revisa tu conexión.'**
  String get noSePudoConsultarRevisaTu;

  /// No description provided for @sinTitulo.
  ///
  /// In es, this message translates to:
  /// **'Sin título'**
  String get sinTitulo;

  /// No description provided for @obtenidoOk.
  ///
  /// In es, this message translates to:
  /// **'obtenido OK'**
  String get obtenidoOk;

  /// No description provided for @enLaPcTodaviaNoSe.
  ///
  /// In es, this message translates to:
  /// **'En la PC todavía no se pueden reproducir listas HLS'**
  String get enLaPcTodaviaNoSe;

  /// No description provided for @noSePudoLeerLaPagina.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer la página del reproductor incrustado'**
  String get noSePudoLeerLaPagina;

  /// No description provided for @enEsteDispositivoNoSePuede.
  ///
  /// In es, this message translates to:
  /// **'En este dispositivo no se puede descifrar (no hay WebView)'**
  String get enEsteDispositivoNoSePuede;

  /// No description provided for @noSePudoUbicarElReproductor.
  ///
  /// In es, this message translates to:
  /// **'No se pudo ubicar el reproductor de YouTube'**
  String get noSePudoUbicarElReproductor;

  /// No description provided for @youtubeRechazoElPedido.
  ///
  /// In es, this message translates to:
  /// **'YouTube rechazó el pedido ({p0})'**
  String youtubeRechazoElPedido(Object? p0);

  /// No description provided for @youtubeRespondioVacio.
  ///
  /// In es, this message translates to:
  /// **'YouTube respondió vacío'**
  String get youtubeRespondioVacio;

  /// No description provided for @sinEstado.
  ///
  /// In es, this message translates to:
  /// **'Sin estado'**
  String get sinEstado;

  /// No description provided for @sinFormatosDeAudio.
  ///
  /// In es, this message translates to:
  /// **'sin formatos de audio'**
  String get sinFormatosDeAudio;

  /// No description provided for @elFormatoNoTraeUrlNi.
  ///
  /// In es, this message translates to:
  /// **'El formato no trae URL ni firma'**
  String get elFormatoNoTraeUrlNi;

  /// No description provided for @laFirmaCifradaVinoIncompleta.
  ///
  /// In es, this message translates to:
  /// **'La firma cifrada vino incompleta'**
  String get laFirmaCifradaVinoIncompleta;

  /// No description provided for @formatoCifradoEnUnaFormaQue.
  ///
  /// In es, this message translates to:
  /// **'Formato cifrado en una forma que no descifra'**
  String get formatoCifradoEnUnaFormaQue;

  /// No description provided for @sinRespuesta.
  ///
  /// In es, this message translates to:
  /// **'sin respuesta'**
  String get sinRespuesta;

  /// No description provided for @noSePudoDescifrarLaFirma.
  ///
  /// In es, this message translates to:
  /// **'No se pudo descifrar la firma: {p0}'**
  String noSePudoDescifrarLaFirma(Object? p0);

  /// No description provided for @noSePudoTransformarElParametro.
  ///
  /// In es, this message translates to:
  /// **'No se pudo transformar el parámetro \"n\": {p0}'**
  String noSePudoTransformarElParametro(Object? p0);

  /// No description provided for @youtubeNoEntregoLaListaHls.
  ///
  /// In es, this message translates to:
  /// **'YouTube no entregó la lista HLS'**
  String get youtubeNoEntregoLaListaHls;

  /// No description provided for @laListaHlsNoTraeAudio.
  ///
  /// In es, this message translates to:
  /// **'La lista HLS no trae audio solo'**
  String get laListaHlsNoTraeAudio;

  /// No description provided for @laListaDeAudioHlsVino.
  ///
  /// In es, this message translates to:
  /// **'La lista de audio HLS vino vacía'**
  String get laListaDeAudioHlsVino;

  /// No description provided for @unSegmentoHlsNoBajaHttp.
  ///
  /// In es, this message translates to:
  /// **'Un segmento HLS no baja (HTTP {p0})'**
  String unSegmentoHlsNoBajaHttp(Object? p0);

  /// No description provided for @laListaHlsFallo.
  ///
  /// In es, this message translates to:
  /// **'La lista HLS falló: {p0}'**
  String laListaHlsFallo(Object? p0);

  /// No description provided for @youtubeSoloDejaBajarElPrimer.
  ///
  /// In es, this message translates to:
  /// **'YouTube solo deja bajar el primer minuto (HTTP 403 al final del archivo)'**
  String get youtubeSoloDejaBajarElPrimer;

  /// No description provided for @elAudioNoRespondeHttp.
  ///
  /// In es, this message translates to:
  /// **'El audio no responde (HTTP {p0})'**
  String elAudioNoRespondeHttp(Object? p0);

  /// No description provided for @elAudioNoResponde.
  ///
  /// In es, this message translates to:
  /// **'El audio no responde ({p0})'**
  String elAudioNoResponde(Object? p0);

  /// No description provided for @audioDirectoSinDescifrar.
  ///
  /// In es, this message translates to:
  /// **'Audio directo, sin descifrar.'**
  String get audioDirectoSinDescifrar;

  /// No description provided for @listaHlsDeSegmentosChicosOtro.
  ///
  /// In es, this message translates to:
  /// **'Lista HLS de segmentos chicos (otro servidor que VISIONOS directo). No se guarda en la caché.'**
  String get listaHlsDeSegmentosChicosOtro;

  /// No description provided for @televisorSimpleDescifraConElSolver.
  ///
  /// In es, this message translates to:
  /// **'Televisor simple; descifra con el solver y manda un PO token.'**
  String get televisorSimpleDescifraConElSolver;

  /// No description provided for @comoTvhtml5SimplyPeroPidiendoA.
  ///
  /// In es, this message translates to:
  /// **'Como TVHTML5_SIMPLY, pero pidiendo a music.youtube.com.'**
  String get comoTvhtml5SimplyPeroPidiendoA;

  /// No description provided for @entregaSoloElPrimerMibMedido.
  ///
  /// In es, this message translates to:
  /// **'Entrega solo el primer MiB (medido con InnerTubeX, 18/10/2026).'**
  String get entregaSoloElPrimerMibMedido;

  /// No description provided for @youtubeRespondeVolverACargarLa.
  ///
  /// In es, this message translates to:
  /// **'YouTube responde \"volver a cargar la página\" (InnerTubeX: solo de prueba).'**
  String get youtubeRespondeVolverACargarLa;

  /// No description provided for @televisorDescifraConElSolver.
  ///
  /// In es, this message translates to:
  /// **'Televisor; descifra con el solver.'**
  String get televisorDescifraConElSolver;

  /// No description provided for @youtubeYaNoLeDaFormatos.
  ///
  /// In es, this message translates to:
  /// **'YouTube ya no le da formatos de audio (InnerTubeX: NO_PLAYABLE_STREAM).'**
  String get youtubeYaNoLeDaFormatos;

  /// No description provided for @versionViejaDeAndroidVrDe.
  ///
  /// In es, this message translates to:
  /// **'Versión vieja de ANDROID_VR, de control.'**
  String get versionViejaDeAndroidVrDe;

  /// No description provided for @youtubeYaNoLeDaFormatos2.
  ///
  /// In es, this message translates to:
  /// **'YouTube ya no le da formatos de audio (InnerTubeX: rota).'**
  String get youtubeYaNoLeDaFormatos2;

  /// No description provided for @sueleDarSoloElPrimerMinuto.
  ///
  /// In es, this message translates to:
  /// **'Suele dar solo el primer minuto.'**
  String get sueleDarSoloElPrimerMinuto;

  /// No description provided for @laWebDeYoutubeMusicDescifra.
  ///
  /// In es, this message translates to:
  /// **'La web de YouTube Music; descifra con el solver y manda un PO token.'**
  String get laWebDeYoutubeMusicDescifra;

  /// No description provided for @elReproductorIncrustadoUsaElVisitor.
  ///
  /// In es, this message translates to:
  /// **'El reproductor incrustado; usa el visitor de la página embed (como InnerTubeX 0.8.4).'**
  String get elReproductorIncrustadoUsaElVisitor;

  /// No description provided for @necesitaUnPoTokenLigadoA.
  ///
  /// In es, this message translates to:
  /// **'Necesita un PO token ligado a la página, que Kiji no genera (medido el 18/10/2026).'**
  String get necesitaUnPoTokenLigadoA;

  /// No description provided for @laWebParaCelularesDescifraCon.
  ///
  /// In es, this message translates to:
  /// **'La web para celulares; descifra con el solver y manda un PO token.'**
  String get laWebParaCelularesDescifraCon;

  /// No description provided for @enEsteDispositivoNoHayWebview.
  ///
  /// In es, this message translates to:
  /// **'En este dispositivo no hay WebView para descifrar'**
  String get enEsteDispositivoNoHayWebview;

  /// No description provided for @aPlaylist.
  ///
  /// In es, this message translates to:
  /// **'A playlist'**
  String get aPlaylist;

  /// No description provided for @noSePudoAbrirRevisaTu.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir. Revisa tu conexión.'**
  String get noSePudoAbrirRevisaTu;

  /// No description provided for @canciones3.
  ///
  /// In es, this message translates to:
  /// **'CANCIONES'**
  String get canciones3;

  /// No description provided for @albumesYSingles.
  ///
  /// In es, this message translates to:
  /// **'ÁLBUMES Y SINGLES'**
  String get albumesYSingles;

  /// No description provided for @haceH.
  ///
  /// In es, this message translates to:
  /// **'hace {p0} h'**
  String haceH(Object? p0);

  /// No description provided for @ultimaPruebaAutomaticaSePruebaCon.
  ///
  /// In es, this message translates to:
  /// **'Última prueba automática: {p0}. Se prueba con {p1} canciones de control, nunca con tu historial; la prueba pide el último byte del audio para descubrir las formas que cortan al minuto.'**
  String ultimaPruebaAutomaticaSePruebaCon(Object? p0, Object? p1);

  /// No description provided for @probarTodasLasFormasAhora.
  ///
  /// In es, this message translates to:
  /// **'Probar todas las formas ahora'**
  String get probarTodasLasFormasAhora;

  /// No description provided for @formasRetiradasYoutubeYaNoLas.
  ///
  /// In es, this message translates to:
  /// **'Formas retiradas (YouTube ya no las permite) · {p0}'**
  String formasRetiradasYoutubeYaNoLas(Object? p0);

  /// No description provided for @falloCon.
  ///
  /// In es, this message translates to:
  /// **'Falló con {p0}: {p1}'**
  String falloCon(Object? p0, Object? p1);

  /// No description provided for @sinProbarTodavia.
  ///
  /// In es, this message translates to:
  /// **'Sin probar todavía'**
  String get sinProbarTodavia;

  /// No description provided for @ultimaVezQueAnduvo.
  ///
  /// In es, this message translates to:
  /// **'Última vez que anduvo: {p0}'**
  String ultimaVezQueAnduvo(Object? p0);

  /// No description provided for @ultimoProblema.
  ///
  /// In es, this message translates to:
  /// **'Último problema: {p0}'**
  String ultimoProblema(Object? p0);

  /// No description provided for @noSePudoInstalar.
  ///
  /// In es, this message translates to:
  /// **'No se pudo instalar: {p0}'**
  String noSePudoInstalar(Object? p0);

  /// No description provided for @opcionalYSoloEnLaPc.
  ///
  /// In es, this message translates to:
  /// **'Opcional y solo en la PC. Si los motores A y B no pueden con una canción, Kiji puede usar yt-dlp, un programa libre muy conocido. Se baja de su página oficial en GitHub (unos 18 MB), se verifica su huella y se actualiza solo una vez por semana. Nada se baja si no lo pides.'**
  String get opcionalYSoloEnLaPc;

  /// No description provided for @instalado.
  ///
  /// In es, this message translates to:
  /// **'Instalado'**
  String get instalado;

  /// No description provided for @quitarYtDlp.
  ///
  /// In es, this message translates to:
  /// **'Quitar yt-dlp'**
  String get quitarYtDlp;

  /// No description provided for @bajarYUsarYtDlp18.
  ///
  /// In es, this message translates to:
  /// **'Bajar y usar yt-dlp (≈18 MB)'**
  String get bajarYUsarYtDlp18;

  /// No description provided for @artistas.
  ///
  /// In es, this message translates to:
  /// **'Artistas'**
  String get artistas;

  /// No description provided for @albumes.
  ///
  /// In es, this message translates to:
  /// **'Álbumes'**
  String get albumes;

  /// No description provided for @misArchivos.
  ///
  /// In es, this message translates to:
  /// **'Mis archivos'**
  String get misArchivos;

  /// No description provided for @noSePudoBuscarRevisaTu.
  ///
  /// In es, this message translates to:
  /// **'No se pudo buscar. Revisa tu conexión a Internet.'**
  String get noSePudoBuscarRevisaTu;

  /// No description provided for @recientes.
  ///
  /// In es, this message translates to:
  /// **'RECIENTES'**
  String get recientes;

  /// No description provided for @quitar.
  ///
  /// In es, this message translates to:
  /// **'Quitar'**
  String get quitar;

  /// No description provided for @tePuedeGustar.
  ///
  /// In es, this message translates to:
  /// **'Te puede gustar'**
  String get tePuedeGustar;

  /// No description provided for @segunLoQueEscuchas.
  ///
  /// In es, this message translates to:
  /// **'según lo que escuchas'**
  String get segunLoQueEscuchas;

  /// No description provided for @exploraPorEstilo.
  ///
  /// In es, this message translates to:
  /// **'Explora por estilo'**
  String get exploraPorEstilo;

  /// No description provided for @generosYAnimosDeYoutubeMusic.
  ///
  /// In es, this message translates to:
  /// **'géneros y ánimos de YouTube Music'**
  String get generosYAnimosDeYoutubeMusic;

  /// No description provided for @noSePudoReproducirEstaCancion.
  ///
  /// In es, this message translates to:
  /// **'No se pudo reproducir esta canción.'**
  String get noSePudoReproducirEstaCancion;

  /// No description provided for @buscarCancionesArtistas.
  ///
  /// In es, this message translates to:
  /// **'Buscar canciones, artistas...'**
  String get buscarCancionesArtistas;

  /// No description provided for @sinResultados.
  ///
  /// In es, this message translates to:
  /// **'Sin resultados'**
  String get sinResultados;

  /// No description provided for @buscaEntreTuMusicaGuardadaY.
  ///
  /// In es, this message translates to:
  /// **'Busca entre tu música guardada y tus descargas'**
  String get buscaEntreTuMusicaGuardadaY;

  /// No description provided for @noHayCoincidenciasEnTusArchivos.
  ///
  /// In es, this message translates to:
  /// **'No hay coincidencias en tus archivos'**
  String get noHayCoincidenciasEnTusArchivos;

  /// No description provided for @soloSePuedenDescargarCancionesDe.
  ///
  /// In es, this message translates to:
  /// **'Solo se pueden descargar canciones de YouTube.'**
  String get soloSePuedenDescargarCancionesDe;

  /// No description provided for @estasSinWifiYElegisteDescargar.
  ///
  /// In es, this message translates to:
  /// **'Estás sin WiFi y elegiste descargar solo con WiFi. Puedes cambiarlo en Biblioteca → Descargadas.'**
  String get estasSinWifiYElegisteDescargar;

  /// No description provided for @noHayEspacioSuficienteEnEl.
  ///
  /// In es, this message translates to:
  /// **'No hay espacio suficiente en el dispositivo.'**
  String get noHayEspacioSuficienteEnEl;

  /// No description provided for @superariaElLimiteDeEspacioPara.
  ///
  /// In es, this message translates to:
  /// **'Superaría el límite de espacio para descargas que elegiste. Puedes cambiarlo o borrar descargas en Biblioteca → Descargadas.'**
  String get superariaElLimiteDeEspacioPara;

  /// No description provided for @enPausa.
  ///
  /// In es, this message translates to:
  /// **'En pausa'**
  String get enPausa;

  /// No description provided for @terminoAntesDeTiempoEnS.
  ///
  /// In es, this message translates to:
  /// **'terminó antes de tiempo en {p0} s de {p1} s'**
  String terminoAntesDeTiempoEnS(Object? p0, Object? p1);

  /// No description provided for @caminosAgotados.
  ///
  /// In es, this message translates to:
  /// **'caminos agotados'**
  String get caminosAgotados;

  /// No description provided for @elVideoTieneRestriccionOEsta.
  ///
  /// In es, this message translates to:
  /// **'«{p0}»: el video tiene restricción o está bloqueado; suena su versión «Canción».'**
  String elVideoTieneRestriccionOEsta(Object? p0);

  /// No description provided for @elAudioNoSePudoAbrir.
  ///
  /// In es, this message translates to:
  /// **'El audio no se pudo abrir'**
  String get elAudioNoSePudoAbrir;

  /// No description provided for @sinConexionSeguimosConQueEsta.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión. Seguimos con «{p0}», que está guardada en el teléfono.'**
  String sinConexionSeguimosConQueEsta(Object? p0);

  /// No description provided for @sinConexionLaMusicaQuedoEn.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión: la música quedó en pausa. Cuando vuelva internet, toca play.'**
  String get sinConexionLaMusicaQuedoEn;

  /// No description provided for @pasamosALaSiguiente.
  ///
  /// In es, this message translates to:
  /// **'Pasamos a la siguiente.'**
  String get pasamosALaSiguiente;

  /// No description provided for @youtubeNoEstaDejandoReproducirAhora.
  ///
  /// In es, this message translates to:
  /// **'YouTube no está dejando reproducir ahora. Prueba en un rato o escucha tu música guardada.'**
  String get youtubeNoEstaDejandoReproducirAhora;

  /// No description provided for @noSePudoReproducirPasamosA.
  ///
  /// In es, this message translates to:
  /// **'No se pudo reproducir «{p0}». Pasamos a la siguiente.'**
  String noSePudoReproducirPasamosA(Object? p0);

  /// No description provided for @seCortoDuranteLaReproduccion.
  ///
  /// In es, this message translates to:
  /// **'Se cortó durante la reproducción'**
  String get seCortoDuranteLaReproduccion;

  /// No description provided for @lasCancionesDeEstaColaYa.
  ///
  /// In es, this message translates to:
  /// **'Las canciones de esta cola ya no están en el dispositivo.'**
  String get lasCancionesDeEstaColaYa;

  /// No description provided for @yaNoEstaEnElDispositivo.
  ///
  /// In es, this message translates to:
  /// **'«{p0}» ya no está en el dispositivo. Pasamos a la siguiente.'**
  String yaNoEstaEnElDispositivo(Object? p0);

  /// No description provided for @lasCancionesDeTuUltimaCola.
  ///
  /// In es, this message translates to:
  /// **'Las canciones de tu última cola ya no están en el dispositivo.'**
  String get lasCancionesDeTuUltimaCola;

  /// No description provided for @verDescargadas.
  ///
  /// In es, this message translates to:
  /// **'Ver descargadas'**
  String get verDescargadas;

  /// No description provided for @hayUnaVersionNuevaDeKiji.
  ///
  /// In es, this message translates to:
  /// **'Hay una versión nueva de Kiji ({p0}).'**
  String hayUnaVersionNuevaDeKiji(Object? p0);

  /// No description provided for @buenosDias.
  ///
  /// In es, this message translates to:
  /// **'Buenos días'**
  String get buenosDias;

  /// No description provided for @buenasTardes.
  ///
  /// In es, this message translates to:
  /// **'Buenas tardes'**
  String get buenasTardes;

  /// No description provided for @buenasNoches.
  ///
  /// In es, this message translates to:
  /// **'Buenas noches'**
  String get buenasNoches;

  /// No description provided for @escuchadoRecientemente.
  ///
  /// In es, this message translates to:
  /// **'Escuchado recientemente'**
  String get escuchadoRecientemente;

  /// No description provided for @tusMasEscuchadas.
  ///
  /// In es, this message translates to:
  /// **'Tus más escuchadas'**
  String get tusMasEscuchadas;

  /// No description provided for @calculadoEnTuTelefono.
  ///
  /// In es, this message translates to:
  /// **'calculado en tu teléfono'**
  String get calculadoEnTuTelefono;

  /// No description provided for @sinInternet.
  ///
  /// In es, this message translates to:
  /// **'sin internet'**
  String get sinInternet;

  /// No description provided for @sigueDondeQuedaste.
  ///
  /// In es, this message translates to:
  /// **'SIGUE DONDE QUEDASTE'**
  String get sigueDondeQuedaste;

  /// No description provided for @loQueEscuchesApareceAquiTodo.
  ///
  /// In es, this message translates to:
  /// **'Lo que escuches aparece aquí. Todo se calcula en tu teléfono; nada sale de él.'**
  String get loQueEscuchesApareceAquiTodo;

  /// No description provided for @buscarMusica.
  ///
  /// In es, this message translates to:
  /// **'Buscar música'**
  String get buscarMusica;

  /// No description provided for @tusPlaylists2.
  ///
  /// In es, this message translates to:
  /// **'Tus playlists'**
  String get tusPlaylists2;

  /// No description provided for @nueva2.
  ///
  /// In es, this message translates to:
  /// **'+ Nueva'**
  String get nueva2;

  /// No description provided for @tuBiblioteca.
  ///
  /// In es, this message translates to:
  /// **'TU BIBLIOTECA'**
  String get tuBiblioteca;

  /// No description provided for @descargadas2.
  ///
  /// In es, this message translates to:
  /// **'DESCARGADAS'**
  String get descargadas2;

  /// No description provided for @minimizar.
  ///
  /// In es, this message translates to:
  /// **'Minimizar'**
  String get minimizar;

  /// No description provided for @reproduciendoDesde.
  ///
  /// In es, this message translates to:
  /// **'REPRODUCIENDO DESDE'**
  String get reproduciendoDesde;

  /// No description provided for @escucharSinConexion.
  ///
  /// In es, this message translates to:
  /// **'Escuchar sin conexión'**
  String get escucharSinConexion;

  /// No description provided for @descargarDentroDeKiji.
  ///
  /// In es, this message translates to:
  /// **'Descargar dentro de Kiji'**
  String get descargarDentroDeKiji;

  /// No description provided for @cancionGuardadaEnElDispositivo.
  ///
  /// In es, this message translates to:
  /// **'Canción guardada en el dispositivo'**
  String get cancionGuardadaEnElDispositivo;

  /// No description provided for @yaSuenaSinConexion.
  ///
  /// In es, this message translates to:
  /// **'Ya suena sin conexión'**
  String get yaSuenaSinConexion;

  /// No description provided for @comoEstaFuncionandoYoutubeHoy2.
  ///
  /// In es, this message translates to:
  /// **'Cómo está funcionando YouTube hoy'**
  String get comoEstaFuncionandoYoutubeHoy2;

  /// No description provided for @descargadaSuenaSinConexion.
  ///
  /// In es, this message translates to:
  /// **'Descargada: suena sin conexión'**
  String get descargadaSuenaSinConexion;

  /// No description provided for @repetirApagado.
  ///
  /// In es, this message translates to:
  /// **'Repetir: apagado'**
  String get repetirApagado;

  /// No description provided for @repetirTodaLaCola.
  ///
  /// In es, this message translates to:
  /// **'Repetir: toda la cola'**
  String get repetirTodaLaCola;

  /// No description provided for @repetirEstaCancion.
  ///
  /// In es, this message translates to:
  /// **'Repetir: esta canción'**
  String get repetirEstaCancion;

  /// No description provided for @aleatorioApagado.
  ///
  /// In es, this message translates to:
  /// **'Aleatorio: apagado'**
  String get aleatorioApagado;

  /// No description provided for @anterior.
  ///
  /// In es, this message translates to:
  /// **'Anterior'**
  String get anterior;

  /// No description provided for @siguiente.
  ///
  /// In es, this message translates to:
  /// **'Siguiente'**
  String get siguiente;

  /// No description provided for @letra.
  ///
  /// In es, this message translates to:
  /// **'Letra'**
  String get letra;

  /// No description provided for @temporizadorActivo.
  ///
  /// In es, this message translates to:
  /// **'Temporizador activo: {p0}'**
  String temporizadorActivo(Object? p0);

  /// No description provided for @momento.
  ///
  /// In es, this message translates to:
  /// **'Momento'**
  String get momento;

  /// No description provided for @guardarEsteMomento.
  ///
  /// In es, this message translates to:
  /// **'Guardar este momento'**
  String get guardarEsteMomento;

  /// No description provided for @tusListas.
  ///
  /// In es, this message translates to:
  /// **'TUS LISTAS'**
  String get tusListas;

  /// No description provided for @tusPlaylistsVanAAparecerAqui.
  ///
  /// In es, this message translates to:
  /// **'Tus playlists van a aparecer aquí.'**
  String get tusPlaylistsVanAAparecerAqui;

  /// No description provided for @sinUsarTodavia.
  ///
  /// In es, this message translates to:
  /// **'Sin usar todavía'**
  String get sinUsarTodavia;

  /// No description provided for @saludDelExtractor2.
  ///
  /// In es, this message translates to:
  /// **'SALUD DEL EXTRACTOR'**
  String get saludDelExtractor2;

  /// No description provided for @buscarCancionesArtistas2.
  ///
  /// In es, this message translates to:
  /// **'Buscar canciones, artistas…'**
  String get buscarCancionesArtistas2;

  /// No description provided for @aContinuacion.
  ///
  /// In es, this message translates to:
  /// **'A continuación'**
  String get aContinuacion;

  /// No description provided for @volumen.
  ///
  /// In es, this message translates to:
  /// **'Volumen {p0} %'**
  String volumen(Object? p0);

  /// No description provided for @temporizadorActivo2.
  ///
  /// In es, this message translates to:
  /// **'Temporizador activo'**
  String get temporizadorActivo2;

  /// No description provided for @mostrarLaCola.
  ///
  /// In es, this message translates to:
  /// **'Mostrar la cola'**
  String get mostrarLaCola;

  /// No description provided for @guardarPlaylist.
  ///
  /// In es, this message translates to:
  /// **'Guardar playlist'**
  String get guardarPlaylist;

  /// No description provided for @seGuardo.
  ///
  /// In es, this message translates to:
  /// **'Se guardó «{p0}»'**
  String seGuardo(Object? p0);

  /// No description provided for @noSePudoGuardarElArchivo.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar el archivo.'**
  String get noSePudoGuardarElArchivo;

  /// No description provided for @progresoDeLaCancion.
  ///
  /// In es, this message translates to:
  /// **'Progreso de la canción'**
  String get progresoDeLaCancion;

  /// No description provided for @pausaDelTemporizador.
  ///
  /// In es, this message translates to:
  /// **'Pausa del temporizador'**
  String get pausaDelTemporizador;

  /// No description provided for @sinSesion.
  ///
  /// In es, this message translates to:
  /// **'Sin sesión'**
  String get sinSesion;

  /// No description provided for @kijiFuncionaSinCuenta.
  ///
  /// In es, this message translates to:
  /// **'Kiji funciona entero sin cuenta. Iniciar sesión es opcional y solo sirve para las canciones que YouTube entrega únicamente a cuentas (por ejemplo, con restricción de edad).'**
  String get kijiFuncionaSinCuenta;

  /// No description provided for @todaviaNoHayCopias.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay copias.'**
  String get todaviaNoHayCopias;

  /// No description provided for @copiaHecha.
  ///
  /// In es, this message translates to:
  /// **'Copia hecha'**
  String get copiaHecha;

  /// No description provided for @nCancionesDescargadas.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 canción descargada} other{{count} canciones descargadas}}'**
  String nCancionesDescargadas(num count);

  /// No description provided for @bajandoNCanciones.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Bajando 1 canción} other{Bajando {count} canciones}}'**
  String bajandoNCanciones(num count);

  /// No description provided for @hoyA.
  ///
  /// In es, this message translates to:
  /// **'hoy {time}'**
  String hoyA(Object? time);

  /// No description provided for @ayerA.
  ///
  /// In es, this message translates to:
  /// **'ayer {time}'**
  String ayerA(Object? time);

  /// No description provided for @noEsUnaImagenQueKijiPuedaLeer.
  ///
  /// In es, this message translates to:
  /// **'No es una imagen que Kiji pueda leer'**
  String get noEsUnaImagenQueKijiPuedaLeer;

  /// No description provided for @elArchivoNoTieneUnaLetra.
  ///
  /// In es, this message translates to:
  /// **'El archivo no tiene una letra que Kiji entienda'**
  String get elArchivoNoTieneUnaLetra;

  /// No description provided for @puedesBuscarOtraVersionSufijo.
  ///
  /// In es, this message translates to:
  /// **' Puedes buscar otra versión.'**
  String get puedesBuscarOtraVersionSufijo;

  /// No description provided for @oBuscaOtraVersionSufijo.
  ///
  /// In es, this message translates to:
  /// **' o busca otra versión'**
  String get oBuscaOtraVersionSufijo;

  /// No description provided for @unTamanoDesconocido.
  ///
  /// In es, this message translates to:
  /// **'un tamaño desconocido'**
  String get unTamanoDesconocido;

  /// No description provided for @noSePudoSaberElEspacioLibre.
  ///
  /// In es, this message translates to:
  /// **'No se pudo saber cuánto espacio libre queda.'**
  String get noSePudoSaberElEspacioLibre;

  /// No description provided for @listoYaEstaDescargada.
  ///
  /// In es, this message translates to:
  /// **'¡Listo! Ya está descargada.'**
  String get listoYaEstaDescargada;

  /// No description provided for @reintentarIgual.
  ///
  /// In es, this message translates to:
  /// **'Reintentar igual'**
  String get reintentarIgual;

  /// No description provided for @noQuedaNingunaConError.
  ///
  /// In es, this message translates to:
  /// **'No queda ninguna con error. 🎉'**
  String get noQuedaNingunaConError;

  /// No description provided for @falloLaDescarga.
  ///
  /// In es, this message translates to:
  /// **'Falló la descarga'**
  String get falloLaDescarga;

  /// No description provided for @enCola.
  ///
  /// In es, this message translates to:
  /// **'En cola'**
  String get enCola;

  /// No description provided for @bytesDe.
  ///
  /// In es, this message translates to:
  /// **'{done} de {total}'**
  String bytesDe(Object? done, Object? total);

  /// No description provided for @todaviaNoDescargasteNada.
  ///
  /// In es, this message translates to:
  /// **'Todavía no descargaste nada'**
  String get todaviaNoDescargasteNada;

  /// No description provided for @nCanciones.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 canción} other{{count} canciones}}'**
  String nCanciones(num count);

  /// No description provided for @sinLimite.
  ///
  /// In es, this message translates to:
  /// **'Sin límite'**
  String get sinLimite;

  /// No description provided for @lasBandasAparecenCuandoSuena.
  ///
  /// In es, this message translates to:
  /// **'Las bandas aparecen cuando empieza a sonar algo.'**
  String get lasBandasAparecenCuandoSuena;

  /// No description provided for @cortaAntesDelFinal.
  ///
  /// In es, this message translates to:
  /// **'Corta antes del final (HTTP 403 en el último byte)'**
  String get cortaAntesDelFinal;

  /// No description provided for @cancionesNormalesFormas.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Canciones normales: ✓ 1 forma funcionando} other{Canciones normales: ✓ {count} formas funcionando}}'**
  String cancionesNormalesFormas(num count);

  /// No description provided for @haceNDias.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{hace 1 día} other{hace {count} días}}'**
  String haceNDias(num count);

  /// No description provided for @anduvoCon.
  ///
  /// In es, this message translates to:
  /// **'Anduvo con {song} ({ms} ms)'**
  String anduvoCon(Object? song, Object? ms);

  /// No description provided for @ytDlpListo.
  ///
  /// In es, this message translates to:
  /// **'yt-dlp listo y verificado. Se usa solo si los motores A y B fallan.'**
  String get ytDlpListo;

  /// No description provided for @haceNHoras.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{hace 1 hora} other{hace {count} horas}}'**
  String haceNHoras(num count);

  /// No description provided for @sinConexionMinuscula.
  ///
  /// In es, this message translates to:
  /// **'sin conexión'**
  String get sinConexionMinuscula;

  /// No description provided for @ytDlpTardoDemasiado.
  ///
  /// In es, this message translates to:
  /// **'yt-dlp tardó demasiado'**
  String get ytDlpTardoDemasiado;

  /// No description provided for @ytDlpFallo.
  ///
  /// In es, this message translates to:
  /// **'yt-dlp falló ({error})'**
  String ytDlpFallo(Object? error);

  /// No description provided for @ytDlpRespondioAlgoRaro.
  ///
  /// In es, this message translates to:
  /// **'yt-dlp respondió algo raro'**
  String get ytDlpRespondioAlgoRaro;

  /// No description provided for @ytDlpNoDioUrl.
  ///
  /// In es, this message translates to:
  /// **'yt-dlp no dio URL'**
  String get ytDlpNoDioUrl;

  /// No description provided for @falloEstaForma.
  ///
  /// In es, this message translates to:
  /// **'Falló esta forma'**
  String get falloEstaForma;

  /// No description provided for @googleTakeoutCsv.
  ///
  /// In es, this message translates to:
  /// **'Google Takeout de YouTube Music (.csv)'**
  String get googleTakeoutCsv;

  /// No description provided for @noSePudoBuscarLaLetraPorque.
  ///
  /// In es, this message translates to:
  /// **'No se pudo buscar la letra ({reason}). Prueba de nuevo en un rato.'**
  String noSePudoBuscarLaLetraPorque(Object? reason);

  /// No description provided for @quitarLaTraduccion.
  ///
  /// In es, this message translates to:
  /// **'Quitar la traducción'**
  String get quitarLaTraduccion;

  /// No description provided for @elegirLaFuente.
  ///
  /// In es, this message translates to:
  /// **'Elegir la fuente'**
  String get elegirLaFuente;

  /// No description provided for @sinDesfase.
  ///
  /// In es, this message translates to:
  /// **'Sin desfase'**
  String get sinDesfase;

  /// No description provided for @tocaLasLineasQueQuieresCompartir.
  ///
  /// In es, this message translates to:
  /// **'Toca las líneas que quieres compartir'**
  String get tocaLasLineasQueQuieresCompartir;

  /// No description provided for @nLineasElegidas.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 línea elegida} other{{count} líneas elegidas}}'**
  String nLineasElegidas(num count);

  /// No description provided for @preguntandoALasFuentes.
  ///
  /// In es, this message translates to:
  /// **'Preguntando a las fuentes… ({pending})'**
  String preguntandoALasFuentes(Object? pending);

  /// No description provided for @enUso.
  ///
  /// In es, this message translates to:
  /// **'En uso'**
  String get enUso;

  /// No description provided for @momentoDesde.
  ///
  /// In es, this message translates to:
  /// **'«{title}» de {artist}, desde el {at}'**
  String momentoDesde(Object? title, Object? artist, Object? at);

  /// No description provided for @tramoGuardado.
  ///
  /// In es, this message translates to:
  /// **'Tramo guardado: {from}–{to}'**
  String tramoGuardado(Object? from, Object? to);

  /// No description provided for @playlistSinNombre.
  ///
  /// In es, this message translates to:
  /// **'Playlist sin nombre'**
  String get playlistSinNombre;

  /// No description provided for @yaEstanTodasDescargadas.
  ///
  /// In es, this message translates to:
  /// **'Ya están todas descargadas.'**
  String get yaEstanTodasDescargadas;

  /// No description provided for @espacioLibreDesconocido.
  ///
  /// In es, this message translates to:
  /// **'Espacio libre: desconocido.'**
  String get espacioLibreDesconocido;

  /// No description provided for @nDescargadas.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 descargada} other{{count} descargadas}}'**
  String nDescargadas(num count);

  /// No description provided for @nFallaron.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 falló} other{{count} fallaron}}'**
  String nFallaron(num count);

  /// No description provided for @conErrorSufijo.
  ///
  /// In es, this message translates to:
  /// **' ({count} con error)'**
  String conErrorSufijo(Object? count);

  /// No description provided for @yaEstabaEn.
  ///
  /// In es, this message translates to:
  /// **'Ya estaba en «{name}»'**
  String yaEstabaEn(Object? name);

  /// No description provided for @laColaEstaVacia.
  ///
  /// In es, this message translates to:
  /// **'La cola está vacía'**
  String get laColaEstaVacia;

  /// No description provided for @esLaUltimaCancionDeLaCola.
  ///
  /// In es, this message translates to:
  /// **'Es la última canción de la cola'**
  String get esLaUltimaCancionDeLaCola;

  /// No description provided for @despuesDeEstaN.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 canción después de esta} other{{count} canciones después de esta}}'**
  String despuesDeEstaN(num count);

  /// No description provided for @quitarLaPausaProgramada.
  ///
  /// In es, this message translates to:
  /// **'Quitar la pausa programada'**
  String get quitarLaPausaProgramada;

  /// No description provided for @conUnEnlaceDeSongLink.
  ///
  /// In es, this message translates to:
  /// **'Con un enlace de song.link que abre en cualquier app de música'**
  String get conUnEnlaceDeSongLink;

  /// No description provided for @elRegistroGuardadoOcupa.
  ///
  /// In es, this message translates to:
  /// **'El registro guardado ocupa {size}. No tiene tu nombre, tus cuentas, claves ni direcciones de internet. Solo sale del dispositivo si tú lo mandas.'**
  String elRegistroGuardadoOcupa(Object? size);

  /// No description provided for @nSegundos.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 segundo} other{{count} segundos}}'**
  String nSegundos(num count);

  /// No description provided for @todasPrendidas.
  ///
  /// In es, this message translates to:
  /// **'Todas prendidas.'**
  String get todasPrendidas;

  /// No description provided for @nApagadas.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 apagada.} other{{count} apagadas.}}'**
  String nApagadas(num count);

  /// No description provided for @conGemini.
  ///
  /// In es, this message translates to:
  /// **'con IA (Beta)'**
  String get conGemini;

  /// No description provided for @privacidadActualizaciones.
  ///
  /// In es, this message translates to:
  /// **'Si \"Buscar actualizaciones\" está prendido, una vez por día Kiji le pide a GitHub cuál es la última versión publicada. GitHub ve esa consulta como una visita a una página (tu IP y que es Kiji); no se manda nada tuyo. Se apaga en Configuración → Actualizaciones.'**
  String get privacidadActualizaciones;

  /// No description provided for @soloParaCancionesConCuenta.
  ///
  /// In es, this message translates to:
  /// **'Solo para canciones que YouTube entrega únicamente a cuentas.'**
  String get soloParaCancionesConCuenta;

  /// No description provided for @todaviaSinCopias.
  ///
  /// In es, this message translates to:
  /// **'todavía sin copias'**
  String get todaviaSinCopias;

  /// No description provided for @yaPasoPausaCuandoVuelva.
  ///
  /// In es, this message translates to:
  /// **'Ya pasó: pausa cuando vuelva ahí'**
  String get yaPasoPausaCuandoVuelva;

  /// No description provided for @esperandoEsaCancion.
  ///
  /// In es, this message translates to:
  /// **'Esperando esa canción'**
  String get esperandoEsaCancion;

  /// No description provided for @deDuracion.
  ///
  /// In es, this message translates to:
  /// **'de {duration}'**
  String deDuracion(Object? duration);

  /// No description provided for @cuandoVuelvaAhiSufijo.
  ///
  /// In es, this message translates to:
  /// **' (cuando vuelva ahí)'**
  String get cuandoVuelvaAhiSufijo;

  /// No description provided for @motorYModelosDeFirefox.
  ///
  /// In es, this message translates to:
  /// **'Motor y modelos de Firefox Translations (Mozilla, licencia MPL-2.0).'**
  String get motorYModelosDeFirefox;

  /// No description provided for @activadoPierdesAnonimato.
  ///
  /// In es, this message translates to:
  /// **'Activado. Pierdes parte del anonimato al usarlo.'**
  String get activadoPierdesAnonimato;

  /// No description provided for @laClaveAndaSinModelos.
  ///
  /// In es, this message translates to:
  /// **'La clave anda, pero no hay modelos de texto.'**
  String get laClaveAndaSinModelos;

  /// No description provided for @claveGuardadaPegaOtra.
  ///
  /// In es, this message translates to:
  /// **'Clave guardada (pega otra para cambiarla)'**
  String get claveGuardadaPegaOtra;

  /// No description provided for @estaVersionNoTraeNotas.
  ///
  /// In es, this message translates to:
  /// **'Esta versión no trae notas.'**
  String get estaVersionNoTraeNotas;

  /// No description provided for @todaviaNoSeConsulto.
  ///
  /// In es, this message translates to:
  /// **'Todavía no se consultó.'**
  String get todaviaNoSeConsulto;

  /// No description provided for @noSePuedeReproducir.
  ///
  /// In es, this message translates to:
  /// **'no se puede reproducir'**
  String get noSePuedeReproducir;

  /// No description provided for @youtubeNoDejaProbarMotorC.
  ///
  /// In es, this message translates to:
  /// **'YouTube no está dejando reproducir ahora. Puedes probar el motor C (yt-dlp) en Configuración → Salud del Extractor.'**
  String get youtubeNoDejaProbarMotorC;

  /// No description provided for @quitarDeMeGusta.
  ///
  /// In es, this message translates to:
  /// **'Quitar de me gusta'**
  String get quitarDeMeGusta;

  /// No description provided for @aleatorioActivado.
  ///
  /// In es, this message translates to:
  /// **'Aleatorio: activado'**
  String get aleatorioActivado;

  /// No description provided for @youtubeFuncionaNFormas.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{YouTube funciona (1 forma)} other{YouTube funciona ({count} formas)}}'**
  String youtubeFuncionaNFormas(num count);

  /// No description provided for @youtubeConProblemas.
  ///
  /// In es, this message translates to:
  /// **'YouTube con problemas'**
  String get youtubeConProblemas;

  /// No description provided for @ocultarLaCola.
  ///
  /// In es, this message translates to:
  /// **'Ocultar la cola'**
  String get ocultarLaCola;

  /// No description provided for @hayVersionNuevaPunto.
  ///
  /// In es, this message translates to:
  /// **'Hay una versión nueva: {version}.'**
  String hayVersionNuevaPunto(Object? version);

  /// No description provided for @informeDeKijiPlayer.
  ///
  /// In es, this message translates to:
  /// **'Informe de Kiji Player'**
  String get informeDeKijiPlayer;

  /// No description provided for @informeVersion.
  ///
  /// In es, this message translates to:
  /// **'Versión: {version}'**
  String informeVersion(Object? version);

  /// No description provided for @informeSistema.
  ///
  /// In es, this message translates to:
  /// **'Sistema: {system}'**
  String informeSistema(Object? system);

  /// No description provided for @informeFecha.
  ///
  /// In es, this message translates to:
  /// **'Fecha: {date}'**
  String informeFecha(Object? date);

  /// No description provided for @informeQuePaso.
  ///
  /// In es, this message translates to:
  /// **'Qué pasó: {summary}'**
  String informeQuePaso(Object? summary);

  /// No description provided for @informeDonde.
  ///
  /// In es, this message translates to:
  /// **'Dónde: {where}'**
  String informeDonde(Object? where);

  /// No description provided for @informeDetalle.
  ///
  /// In es, this message translates to:
  /// **'Detalle: {detail}'**
  String informeDetalle(Object? detail);

  /// No description provided for @informePila.
  ///
  /// In es, this message translates to:
  /// **'Pila:'**
  String get informePila;

  /// No description provided for @informeRegistro.
  ///
  /// In es, this message translates to:
  /// **'Registro (últimas {count} líneas, sin datos personales):'**
  String informeRegistro(Object? count);

  /// No description provided for @informeDeKiji.
  ///
  /// In es, this message translates to:
  /// **'Informe de Kiji'**
  String get informeDeKiji;

  /// No description provided for @informeError.
  ///
  /// In es, this message translates to:
  /// **'Error: {summary}'**
  String informeError(Object? summary);

  /// No description provided for @laPantalla.
  ///
  /// In es, this message translates to:
  /// **'la pantalla'**
  String get laPantalla;

  /// No description provided for @seBorranNDelDispositivo.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Se borra 1 canción del dispositivo. No se quita de tu cola: vuelve a sonar desde internet.} other{Se borran {count} canciones del dispositivo. No se quitan de tu cola: vuelven a sonar desde internet.}}'**
  String seBorranNDelDispositivo(num count);

  /// No description provided for @encendidoPerfil.
  ///
  /// In es, this message translates to:
  /// **'Encendido: {profile}'**
  String encendidoPerfil(Object? profile);

  /// No description provided for @cable.
  ///
  /// In es, this message translates to:
  /// **'Cable'**
  String get cable;

  /// No description provided for @perfilDe.
  ///
  /// In es, this message translates to:
  /// **'PERFIL: {profile}'**
  String perfilDe(Object? profile);

  /// No description provided for @ahoraLinea.
  ///
  /// In es, this message translates to:
  /// **'Ahora: {line}'**
  String ahoraLinea(Object? line);

  /// No description provided for @desfijar.
  ///
  /// In es, this message translates to:
  /// **'Desfijar'**
  String get desfijar;

  /// No description provided for @vacio.
  ///
  /// In es, this message translates to:
  /// **'Vacío.'**
  String get vacio;

  /// No description provided for @no.
  ///
  /// In es, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @nMin.
  ///
  /// In es, this message translates to:
  /// **'{minutes} min'**
  String nMin(Object? minutes);

  /// No description provided for @recomendadoSufijo.
  ///
  /// In es, this message translates to:
  /// **' (recomendado)'**
  String get recomendadoSufijo;

  /// No description provided for @album.
  ///
  /// In es, this message translates to:
  /// **'Álbum'**
  String get album;

  /// No description provided for @probando.
  ///
  /// In es, this message translates to:
  /// **'Probando…'**
  String get probando;

  /// No description provided for @idioma.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get idioma;

  /// No description provided for @idiomaDescripcion.
  ///
  /// In es, this message translates to:
  /// **'Sistema, español o inglés. Cambia al instante.'**
  String get idiomaDescripcion;

  /// No description provided for @idiomaDelSistema.
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get idiomaDelSistema;

  /// No description provided for @bienvenidaSaltar.
  ///
  /// In es, this message translates to:
  /// **'Saltar'**
  String get bienvenidaSaltar;

  /// No description provided for @bienvenidaSiguiente.
  ///
  /// In es, this message translates to:
  /// **'Siguiente'**
  String get bienvenidaSiguiente;

  /// No description provided for @bienvenidaEmpezar.
  ///
  /// In es, this message translates to:
  /// **'Empezar'**
  String get bienvenidaEmpezar;

  /// No description provided for @bienvenidaSilenciar.
  ///
  /// In es, this message translates to:
  /// **'Silenciar'**
  String get bienvenidaSilenciar;

  /// No description provided for @bienvenidaActivarSonido.
  ///
  /// In es, this message translates to:
  /// **'Activar el sonido'**
  String get bienvenidaActivarSonido;

  /// No description provided for @bienvenidaHola.
  ///
  /// In es, this message translates to:
  /// **'Hola'**
  String get bienvenidaHola;

  /// No description provided for @bienvenidaSoyKiji.
  ///
  /// In es, this message translates to:
  /// **'Esto es Kiji, tu reproductor de música.'**
  String get bienvenidaSoyKiji;

  /// No description provided for @bienvenidaEligeTuIdioma.
  ///
  /// In es, this message translates to:
  /// **'Elige tu idioma'**
  String get bienvenidaEligeTuIdioma;

  /// No description provided for @bienvenidaQueEsKiji.
  ///
  /// In es, this message translates to:
  /// **'Qué es Kiji'**
  String get bienvenidaQueEsKiji;

  /// No description provided for @bienvenidaQueEsKijiNota.
  ///
  /// In es, this message translates to:
  /// **'Un reproductor libre, para Android y Windows.'**
  String get bienvenidaQueEsKijiNota;

  /// No description provided for @bienvenidaTarjeta1Titulo.
  ///
  /// In es, this message translates to:
  /// **'Sin anuncios, sin pagos y sin rastreo'**
  String get bienvenidaTarjeta1Titulo;

  /// No description provided for @bienvenidaTarjeta1Texto.
  ///
  /// In es, this message translates to:
  /// **'Nada que comprar, nada que te siga. Solo música.'**
  String get bienvenidaTarjeta1Texto;

  /// No description provided for @bienvenidaTarjeta2Titulo.
  ///
  /// In es, this message translates to:
  /// **'YouTube Music y tu música'**
  String get bienvenidaTarjeta2Titulo;

  /// No description provided for @bienvenidaTarjeta2Texto.
  ///
  /// In es, this message translates to:
  /// **'Busca en YouTube Music sin cuenta y escucha también los archivos de tu dispositivo, todo en un solo lugar.'**
  String get bienvenidaTarjeta2Texto;

  /// No description provided for @bienvenidaTarjeta3Titulo.
  ///
  /// In es, this message translates to:
  /// **'Letras, descargas y temporizador'**
  String get bienvenidaTarjeta3Titulo;

  /// No description provided for @bienvenidaTarjeta3Texto.
  ///
  /// In es, this message translates to:
  /// **'Letras sincronizadas (y traducidas), canciones para escuchar sin conexión y un temporizador para dormir.'**
  String get bienvenidaTarjeta3Texto;

  /// No description provided for @bienvenidaHistoriaTitulo.
  ///
  /// In es, this message translates to:
  /// **'La historia'**
  String get bienvenidaHistoriaTitulo;

  /// No description provided for @bienvenidaHistoria1.
  ///
  /// In es, this message translates to:
  /// **'Kiji es un proyecto independiente. Nació de algo simple: querer escuchar música tranquilo, sin anuncios que interrumpan y sin tener que pagar ni crear una cuenta.'**
  String get bienvenidaHistoria1;

  /// No description provided for @bienvenidaHistoria2.
  ///
  /// In es, this message translates to:
  /// **'Es software libre, con licencia GPL-3.0: el código está abierto para que cualquiera lo lea, lo mejore o aprenda de él.'**
  String get bienvenidaHistoria2;

  /// No description provided for @bienvenidaHistoria3.
  ///
  /// In es, this message translates to:
  /// **'Kiji se programa con ayuda de inteligencia artificial, y cada cambio lo revisa y aprueba una persona antes de llegar a ti.'**
  String get bienvenidaHistoria3;

  /// No description provided for @bienvenidaHistoria4.
  ///
  /// In es, this message translates to:
  /// **'Gracias a Echo Music y a Metrolist: Kiji aprende mucho de su trabajo libre.'**
  String get bienvenidaHistoria4;

  /// No description provided for @bienvenidaAjustaATuGusto.
  ///
  /// In es, this message translates to:
  /// **'A tu gusto'**
  String get bienvenidaAjustaATuGusto;

  /// No description provided for @bienvenidaOpcionalNota.
  ///
  /// In es, this message translates to:
  /// **'Todo esto es opcional. Si no tocas nada, Kiji funciona igual de bien.'**
  String get bienvenidaOpcionalNota;

  /// No description provided for @bienvenidaTraducirLetrasAl.
  ///
  /// In es, this message translates to:
  /// **'Traducir las letras al'**
  String get bienvenidaTraducirLetrasAl;

  /// No description provided for @bienvenidaCalidad.
  ///
  /// In es, this message translates to:
  /// **'Mejor calidad con datos móviles'**
  String get bienvenidaCalidad;

  /// No description provided for @bienvenidaCalidadMejor.
  ///
  /// In es, this message translates to:
  /// **'Siempre la mejor calidad disponible.'**
  String get bienvenidaCalidadMejor;

  /// No description provided for @bienvenidaCalidadAhorro.
  ///
  /// In es, this message translates to:
  /// **'Con datos móviles, calidad baja (unas 4 veces menos datos). Con WiFi, la mejor.'**
  String get bienvenidaCalidadAhorro;

  /// No description provided for @bienvenidaAhorroDeDatos.
  ///
  /// In es, this message translates to:
  /// **'Descargar solo con WiFi'**
  String get bienvenidaAhorroDeDatos;

  /// No description provided for @bienvenidaAhorroDeDatosTexto.
  ///
  /// In es, this message translates to:
  /// **'Las descargas no usan tus datos móviles.'**
  String get bienvenidaAhorroDeDatosTexto;

  /// No description provided for @bienvenidaSeCambiaEnConfiguracion.
  ///
  /// In es, this message translates to:
  /// **'Se puede cambiar después en Configuración.'**
  String get bienvenidaSeCambiaEnConfiguracion;

  /// No description provided for @bienvenidaKijiNoRecopilaNada.
  ///
  /// In es, this message translates to:
  /// **'Kiji no recopila nada'**
  String get bienvenidaKijiNoRecopilaNada;

  /// No description provided for @bienvenidaPrivacidadTexto.
  ///
  /// In es, this message translates to:
  /// **'Sin estadísticas de uso, sin anuncios y sin cuentas obligatorias. Tu música, tu historial y tus ajustes se quedan en este dispositivo.'**
  String get bienvenidaPrivacidadTexto;

  /// No description provided for @bienvenidaPaginaDe.
  ///
  /// In es, this message translates to:
  /// **'Página {page} de {total}'**
  String bienvenidaPaginaDe(Object? page, Object? total);

  /// No description provided for @verBienvenidaOtraVez.
  ///
  /// In es, this message translates to:
  /// **'Ver bienvenida otra vez'**
  String get verBienvenidaOtraVez;

  /// No description provided for @verBienvenidaOtraVezTexto.
  ///
  /// In es, this message translates to:
  /// **'Las pantallas del primer inicio.'**
  String get verBienvenidaOtraVezTexto;

  /// No description provided for @traducirLaLetra.
  ///
  /// In es, this message translates to:
  /// **'Traducir la letra'**
  String get traducirLaLetra;

  /// No description provided for @traduccionEnElTelefono.
  ///
  /// In es, this message translates to:
  /// **'Traducción en el teléfono'**
  String get traduccionEnElTelefono;

  /// No description provided for @traduccionEnElTelefonoTexto.
  ///
  /// In es, this message translates to:
  /// **'Privada: se hace en tu teléfono y, después de bajar el idioma, sin internet.'**
  String get traduccionEnElTelefonoTexto;

  /// No description provided for @traduccionConIa.
  ///
  /// In es, this message translates to:
  /// **'Traducción con IA'**
  String get traduccionConIa;

  /// No description provided for @traduccionConIaTexto.
  ///
  /// In es, this message translates to:
  /// **'Usa Gemini de Google y tu clave. Las líneas de la letra salen del teléfono.'**
  String get traduccionConIaTexto;

  /// No description provided for @traduccionConIaPreparar.
  ///
  /// In es, this message translates to:
  /// **'Primero hay que activarla y poner tu clave.'**
  String get traduccionConIaPreparar;

  /// No description provided for @beta.
  ///
  /// In es, this message translates to:
  /// **'Beta'**
  String get beta;

  /// No description provided for @ajustesDeTraduccion.
  ///
  /// In es, this message translates to:
  /// **'Ajustes de traducción'**
  String get ajustesDeTraduccion;

  /// No description provided for @nPlaylists.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 playlist} other{{count} playlists}}'**
  String nPlaylists(num count);

  /// No description provided for @nMeGusta.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 me gusta} other{{count} me gusta}}'**
  String nMeGusta(num count);

  /// No description provided for @unoYOtro.
  ///
  /// In es, this message translates to:
  /// **'{a} y {b}'**
  String unoYOtro(String a, String b);

  /// No description provided for @copiaArticuloDiaRelativo.
  ///
  /// In es, this message translates to:
  /// **'de '**
  String get copiaArticuloDiaRelativo;

  /// No description provided for @copiaArticuloFecha.
  ///
  /// In es, this message translates to:
  /// **'del '**
  String get copiaArticuloFecha;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
