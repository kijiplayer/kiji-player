# Novedades de Kiji Player

## 0.8.6 — 26 de noviembre de 2026

**Arreglos**
- En algunos teléfonos (Android 12 y anteriores, como los Infinix con XOS) la notificación de
  música y la pantalla de bloqueo salían sin botones. Ahora siempre muestran anterior,
  play/pausa y siguiente, también con Kiji cerrada y desde los auriculares.
- En Android 10 la música del teléfono no se reproducía («no se puede reproducir»). Ahora sí.

## 0.8.5 — 19 de noviembre de 2026

**Arreglos**
- Los títulos del reproductor ya no se parten a mitad de palabra: se achican si hace falta y
  usan todo el ancho.
- Con Kiji en inglés no quedan textos en español (ecualizador, Teatro, búsqueda).
- El reproductor se cierra deslizando hacia abajo.
- El Teatro entra con su telón, y cambiar de estilo es un fundido suave (sin pantalla negra).
- «Momento guardado»: el aviso va arriba, dura poco y «Ver» abre tus momentos.
- Elegir un preset del ecualizador ya no prende los efectos solo.
- «Estilo de esta canción» muestra la canción que suena y marca el fondo elegido. El fondo de una
  canción se ve solo en su reproductor; el resto de Kiji usa el fondo general.
- La onda arranca con color, y «Reproduciendo desde» no cambia a mitad de la canción.
- La búsqueda muestra resultados antes, y las búsquedas recientes se pueden dejar de guardar.
- Acerca de tiene «Página oficial», y el aviso de una versión nueva, «Ver qué hay de nuevo»: los dos
  solo abren la página de Kiji en el navegador.
- La Biblioteca muestra solo lo que Android marca como música y dura 30 s o más, sin grabaciones,
  tonos ni audios de WhatsApp o Telegram. En Configuración → «Carpetas de música» eliges qué
  carpetas se ven (ocultar no borra nada). Y lee la música del teléfono una sola vez.

## 0.8.4 — 18 de noviembre de 2026

**Actualizar desde Kiji**
- Cuando hay una versión nueva, Kiji muestra sus novedades, el tamaño y un botón "Actualizar":
  la baja (con progreso, y se puede cancelar), comprueba que sea la publicada y abre el
  instalador. Nada se baja sin que toques el botón.
- Comprueba la suma SHA-256 publicada y, en Android, que esté firmada con el mismo certificado que
  la Kiji que tienes. Si algo no coincide, la borra y no instala.
- En Android baja el APK justo para tu teléfono y, la primera vez, te explica por qué pide permiso
  para instalar apps. Con "solo con Wi-Fi" o el ahorro de datos, pregunta antes de usar datos
  móviles. En Windows, Kiji se cierra, se actualiza y vuelve a abrirse, sin tocar tus datos.
- Si algo falla, sigue estando "Descargar desde la página".

**Tu cuenta de YouTube Music**
- "Me gusta" muestra tus me gusta de verdad, y se suma "Agregadas a tu biblioteca".
- Si tu sesión vence, Kiji te lo dice en Configuración y en la Biblioteca, con un botón para volver
  a iniciarla (antes la lectura fallaba sin avisar). "Sincronizar ahora" dice qué leyó.

**Arreglos**
- Arreglado: en Windows, las canciones descargadas no sonaban.
- Arreglado: el inicio de sesión con YouTube se quedaba trabado en la página de Google.

## 0.8.3 — 17 de noviembre de 2026

**Vidrio líquido**
- Las tarjetas, la barra, el mini-reproductor y las hojas son de "vidrio líquido", con el tono de
  cada estilo: Nocturne toma tu acento, Grafito es vidrio ahumado y Papel, papel translúcido cálido.
  Un borde de luz que cambia al deslizar, el fondo un poco ampliado en los bordes (como una lente),
  un brillo que sigue el deslizamiento, y se hunden al tocarlos. Las hojas suben con un rebote.
  Respeta "Reducir animaciones".
- Y pesa menos: ya no se desenfoca nada en cada cuadro (el fondo se prepara una vez). A 120 Hz,
  Inicio y Búsqueda bajan de unos 9,5 ms a unos 2,5 ms por cuadro.

**Vista previa del fondo**
- Al elegir una imagen, un GIF o un video de fondo, una vista previa de Kiji con ese fondo (una
  tarjeta, texto y el mini-reproductor) que cambia al momento con el desenfoque y la opacidad.

**Ícono a juego con el estilo** (opcional, apagado de fábrica)
- El ícono de Kiji puede tomar los colores de tu estilo y de tu acento. En Android el cambio se
  hace al salir de Kiji, nunca en medio de la música; en Windows, al momento.

**Arreglos**
- Con el teléfono en horizontal ya no se desborda ninguna hoja (el menú ⋯, el fondo, las acciones
  de una canción, personalizar, momentos y otras): si no entran, se desplazan.
- El vidrio deja ver tu fondo, como en la 0.8.2 (antes quedaba un panel oscuro detrás).
- Grafito: pasar muchas canciones seguidas ya no da un error.
- Letras y traducción: una fuente caída o Gemini con límite quedan en pausa (y cada vez más larga)
  en lugar de reintentar a cada rato; al pasar canciones rápido solo se traduce la última, y la
  traducción en el teléfono traba menos la pantalla.

**Una disculpa**
- Perdón por el error de la 0.8.1 que a veces dejaba a Kiji sin sonar hasta reiniciarla: quedó
  arreglado en la 0.8.2.

## 0.8.2 — 16 de noviembre de 2026

**Arreglos**
- A veces ninguna canción sonaba hasta reiniciar la app: era el ecualizador. Ahora, si Android no
  puede crearlo en ese momento, la música suena igual, sin él, y Sonido lo avisa con calma. Y si el
  reproductor mismo falla al cargar una canción, Kiji lo reinicia solo y sigue sonando.
- "Bajar la letra con las descargas": las canciones sin letra (instrumentales) frenaban a las demás,
  y muchas descargas se quedaban sin letra. Ahora se guardan todas las que se encuentren.
- YouTube Music con tu cuenta: las playlists largas y "Me gusta" se leen completos (antes, solo la
  primera parte), y una playlist que falla no deja a las demás sin leer.
- La ovación del teatro ya no satura: la música baja un poco mientras suena.
- El fondo de video cambia bien al elegir otro, y los sonidos del teatro y los widgets ya no dejan
  recursos del teléfono tomados (ni se redibujan con la pantalla apagada).
- Más fluidez: con una foto de fondo, la Biblioteca se desliza sin perder cuadros a 120 Hz.
- Al actualizar dentro de la 0.8, "Qué hay de nuevo" muestra lo de esta versión.

## 0.8.1 — 13 de noviembre de 2026

**Arreglos del teatro: tomates y rosas a color en todos los estilos**
- Tomates, manchas, rosas, telón rojo con cenefa dorada y confeti de colores también en Grafito y
  Papel (en Grafito salían blancos y grises).
- El aviso "… fue abucheada" se va al cambiar de canción.
- "¡Siguiente acto!" sale cuando ya se ve la portada de la canción nueva.

## 0.8.0 — 13 de noviembre de 2026

**Reproductor nuevo**
- El play dentro de un anillo con el progreso y la onda de la canción; nombres bajo los botones.
- Modo compacto y pantalla completa. Al cambiar de estilo, un fundido suave en vez de un salto.

**Personaliza Kiji**
- Asistente "Personaliza Kiji" desde cero: estilo, color de acento libre (siempre legible), fuente y
  fondo propio (imagen, GIF o video, también en la PC) con desenfoque y opacidad. El fondo ahora se
  ve de verdad: el velo toma el tono de tu imagen.
- Estilo por canción y temas `.kiji` para exportar y compartir. Grafito, más sobrio.

**Biblioteca y música local**
- Pestañas con cantidad, orden, filtros y vista en cuadrícula que se recuerdan.
- Artistas, álbumes y carpetas con las portadas y los datos de tus archivos; "Elegir portada" para
  un álbum o una carpeta (en Android, con el selector de fotos: sin pedir permiso).
- Selección múltiple (también con Ctrl/Shift + clic en la PC) y descarga de varias con su avance.
- En Android, Kiji lee tu música con su propio código (sin el paquete viejo que ya no se mantenía).

**Sonido y letras**
- Ecualizador también en la PC, presets, bajos, velocidad, tono y mezcla entre canciones.
- Karaoke palabra por palabra (Kiji prefiere las fuentes con tiempos por palabra), pantalla
  completa y letras guardadas junto a las descargas.

**Conexiones**
- Importar playlists con un enlace público de Spotify, Apple Music, SoundCloud o YouTube; las que
  no se encuentran se eligen a mano.
- Copia de seguridad completa (con portadas y fondos) para exportar a un archivo, con vista previa
  antes de restaurar.
- Cuenta de YouTube Music opcional, fácil de encontrar (Configuración → Cuenta, una tarjeta en la
  Biblioteca que se puede cerrar y la opción en Importar): con la sesión, tus Me gusta y playlists en
  Kiji. La sincronización está apagada de fábrica, es solo lectura y Kiji pregunta una sola vez si
  activarla. Cerrar sesión borra todo lo leído de la cuenta.

**Reacciones de teatro**
- 🍅 y 🌹 en el reproductor (o sacudiendo el teléfono mientras suena). Tomates de varias formas que
  dejan una mancha que escurre; con el tercero seguido ("x3 ¡FUERA!") cae un telón rojo y la canción
  sale de escena (en pausa, queda en pausa). Las rosas traen reflector, pétalos y aplausos que
  crecen; con 5, ovación de pie con "¡BRAVO!", confeti y reverencia. Sonidos originales, vibración
  que se puede apagar y una versión simple con "reducir animaciones".
- "Tu Teatro", como un cartel de teatro antiguo: En cartelera, las más abucheadas, las más
  aplaudidas y los premios del público. Todo queda en tu teléfono.

**Plataformas**
- Cinco widgets de Android (en beta) en los tres estilos: Anillo (2x2), Ahora suena (4x2, o 4x4 con la letra),
  Letra (4x2), Teatro (2x2) y Barra (4x1). Con la portada guardada en el teléfono (también sin
  internet) y livianos: se actualizan solo al cambiar de canción o de estado.
- Arranque más rápido, el permiso de notificaciones se pide cuando Kiji ya está a la vista y sin
  conexión no se repiten pedidos inútiles.

## 0.7.0 — 28 de octubre de 2026

**Tres estilos**
- Nocturne (el de siempre), Grafito (blanco y negro, vidrio esmerilado y movimientos con resorte) y
  Papel (claro, como un libro). Las mismas funciones con otro aspecto. Se elige al actualizar y se
  cambia cuando quieras en Configuración → Apariencia → Estilo.
- La onda del reproductor existe en los tres estilos. Con el alto rendimiento salta con el volumen
  real de la canción, que se lee del archivo (nunca del micrófono).

**Letras**
- Tres vistas: Completo, Simple y Escaparate (para grabar y compartir: la portada late con la música
  y la barra se esconde sola).
- Dos columnas en la PC y con el teléfono en horizontal: la letra a la izquierda y la canción a la
  derecha. Se puede elegir una o dos columnas.
- Alineación de la letra (izquierda o centrada) y una marca chica de Kiji opcional en el Escaparate.

**Escuchar sin cortes**
- Si los auriculares Bluetooth se desconectan un momento, Kiji espera unos segundos y retoma sola.
  Nunca sigue sonando por el parlante sin que lo pidas, y el registro dice por qué se pausó.
- El aleatorio es de verdad: la cola muestra el orden en que van a sonar.
- Las canciones descargadas suenan siempre desde el archivo, también en aleatorio.
- Kiji puede pedir que Android no la frene en segundo plano, explicando para qué.

**Más fácil de encontrar**
- Configuración nueva: siete secciones con su descripción y un buscador que entiende sinónimos en
  español e inglés y lleva directo al ajuste.
- Cada playlist tiene su buscador.
- "Tus más escuchadas" en Inicio: un top con cuántas veces escuchaste cada una, calculado en tu
  equipo.
- "Qué hay de nuevo" aparece una vez después de actualizar.

**En la PC**
- Kiji puede quedar en la bandeja del sistema, tiene atajos globales y responde a las teclas
  multimedia, también con Kiji minimizada.
- Las ventanas anchas aprovechan el espacio en la letra y en Configuración.

**Arreglos**
- Abrir Kiji desde los auriculares, con la app cerrada, ya no da error.
- La canción descargada que se restaura al abrir carga en la mitad del tiempo.
- Se arregló un error al cerrar el reproductor ("No active stream to cancel").
- Lo elegido (pestañas, chips, interruptores) se lee bien en los tres estilos, con contraste de 4,5:1.
- Filtros de las playlists que ya no se cortan en celulares angostos; Esc y Ctrl+A en la selección
  múltiple de la PC; espacio libre en Linux y macOS.

## 0.6.0 — 21 de octubre de 2026

**A tu gusto**
- Configuración → Apariencia: tema oscuro, **más oscuro** (negro puro) o **claro**; cinco colores
  de acento; la tipografía de Kiji o la de tu teléfono, y la hora en 12 o 24 horas (de fábrica,
  la del sistema). Todo se aplica al momento, sin reiniciar.
- Las letras de las canciones se pueden ver chicas, normales o grandes.

**Más rápido con muchas canciones**
- Mantén presionada una canción en la Biblioteca, en Descargadas o en una playlist para elegir
  varias: agregarlas a playlists, descargarlas, ponerlas a continuación o al final de la cola, o
  quitarlas (de la playlist se puede deshacer).
- Nueva opción "Descargar lo que me gusta" (apagada de fábrica): al dar me gusta, la canción se
  baja sola. Respeta "solo con WiFi": si no hay WiFi, espera y sigue sola después.

**Letras**
- El menú ⋯ de la letra es nuevo: íconos grandes y agrupados, y "Buscar otra" e "Importar .lrc"
  a un toque.

**Actualizar sin perder nada**
- Antes de poner al día tus datos en una versión nueva, Kiji guarda una copia interna. Si algo
  sale mal, todo vuelve como estaba.
- El aviso de versión nueva muestra las novedades en tu idioma, y después de actualizar aparece
  una vez "Novedades de esta versión" (también en Configuración → Acerca de).
- El buscador de Configuración entiende sinónimos en español e inglés ("dark", "tema", "sleep"…),
  y arriba hay un índice para saltar a cada sección.

**Más cómodo**
- Todas las hojas que suben desde abajo (el menú ⋯, la letra, el temporizador…) se cierran
  deslizando hacia abajo desde cualquier parte, no solo desde la barrita. El scroll de adentro
  sigue funcionando igual.

## 0.5.1 — 20 de octubre de 2026

**Kiji tiene un identificador nuevo: hay que reinstalar una vez**
- En Android, Kiji pasa a llamarse por dentro `io.github.kijiplayer.kiji`, su nombre definitivo.
  Android la ve como otra app, así que esta vez no se actualiza encima: se instala al lado de la
  anterior.
- Para llevarte todo: en la Kiji anterior, Configuración → Copia de seguridad → "Hacer una copia
  ahora". En la nueva, Configuración → Copia de seguridad → elige esa copia (está en
  Documentos/Kiji) y restaúrala. Cuando veas todo bien, desinstala la anterior.
- Las canciones descargadas se vuelven a bajar; las playlists, me gusta, historial y ajustes
  vienen en la copia.

**Descargas**
- Además del APK de siempre, cada versión trae uno por tipo de procesador (arm64-v8a,
  armeabi-v7a, x86_64), más livianos.

## 0.5.0-beta.4 — 20 de octubre de 2026

**Traducir letras, más simple**
- En Letras → ⋯ → Traducir eliges entre dos opciones: **en el teléfono** (privada; sin internet
  después de bajar el idioma) o **con IA** (Gemini, necesita tu clave; está en Beta). Un toque
  elige y traduce. Lo demás está en Ajustes de traducción.

**En Windows**
- Kiji ya tiene instalador: se instala para tu usuario, sin pedir permisos de administrador, y al
  desinstalarlo tus playlists y descargas se quedan.

**Más fluida**
- Con música sonando, Inicio y el reproductor ya no se redibujan enteros varias veces por segundo,
  y las carátulas de las listas ocupan mucha menos memoria.
- Con el celular de costado, el mini-reproductor y las pestañas van en una sola fila y dejan ver
  el contenido.

**Arreglos**
- En inglés, importar y restaurar una copia ya no mezclan palabras en español.
- Si YouTube cambia la forma en que responde, Kiji ya no falla al mostrar resultados, y ningún
  título sale con la palabra "null".
- Salir de una pantalla mientras algo se descarga o se prueba (yt-dlp, la clave de Gemini, una
  importación) ya no muestra un error, y lo que terminaba se guarda bien.
- Las opciones dentro de los paneles de vidrio vuelven a mostrar el efecto al tocarlas.
- Detalles de texto: un punto de más en "Me gusta" y una línea suelta en el menú de la letra.
- Kiji es un poco más liviana: se quitaron partes que ya no se usaban.

## 0.5.0-beta.3 — 20 de octubre de 2026

**Para actualizar desde 0.5.0-beta.1:** Kiji ahora se firma con una clave nueva, así que Android no
deja instalarla encima de la anterior. Haz una copia de seguridad (Configuración → Copia de
seguridad), desinstala la versión vieja, instala esta y restaura la copia.

**En tu idioma**
- Toda la app está en español y en inglés. Se cambia en Configuración → Apariencia → Idioma, al
  instante y sin reiniciar.
- Con la letra del teléfono en grande, ningún texto se corta.

**Bienvenida**
- La primera vez que abres Kiji, cinco pantallas cortas cuentan qué es y te dejan elegir lo básico.
  Se puede saltar, y no aparece si ya usabas Kiji. Para verla otra vez: Configuración → Acerca de.

**Arreglos**
- Salir de Kiji con el gesto de Android (deslizar desde abajo) ya no abre la letra.

## 0.5.0-beta.1 — 19 de octubre de 2026

La primera versión con número. Es todo lo que Kiji aprendió hasta ahora.

**Escuchar**
- Kiji busca el audio de cada canción por varios caminos. Si uno falla, prueba el siguiente sin que
  lo notes, y aprende cuáles funcionan mejor cada día.
- Las canciones pasan de una a otra con una mezcla real: el final de una y el principio de la
  siguiente suenan a la vez.
- Si conectas los auriculares Bluetooth, la canción en pausa sigue sola.
- La interfaz es más fluida: cada cuadro se dibuja unas cuatro veces más rápido que antes.

**Letras**
- La letra se abre a pantalla completa, sobre la portada difuminada y con los colores de la canción.
  Desliza hacia arriba en el reproductor para verla.
- Eliges de qué fuente sale cada letra y en qué orden se buscan.
- Compartes unas líneas como imagen, en cinco formatos y con la traducción si quieres.

**Momentos**
- Guarda un segundo o un tramo de una canción ("de 1:12 a 1:40"). Se ven sobre la barra y un tramo
  se puede repetir.

**Descargas**
- Si una canción no se puede bajar, Kiji te dice por qué en palabras simples y te ofrece otra
  versión.
- Cada lista muestra qué está descargado, qué falta y qué falló.

**Cuenta (opcional)**
- Puedes iniciar sesión con Google solo para las canciones que YouTube entrega a cuentas (por
  ejemplo, con restricción de edad). La sesión queda cifrada en tu teléfono.

**Si algo falla**
- Kiji guarda un registro sin datos personales y, como mucho una vez por sesión, te ofrece mandar
  un informe. Nunca manda nada solo.

**En la PC**
- Kiji abre siempre su ventana, aunque algo tarde en cargar, y no abre dos veces.
