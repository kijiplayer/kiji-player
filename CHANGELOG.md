# Novedades de Kiji Player

## 0.6.0 — 20 de octubre de 2026

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

## 0.5.1 — 20 de octubre de 2026

**Kiji tiene un identificador nuevo: hay que reinstalar una vez**
- En Android, Kiji pasa a llamarse por dentro `io.github.kijiplayer.kiji`, su nombre definitivo
  para repositorios como IzzyOnDroid. Android la ve como otra app, así que esta vez no se actualiza
  encima: se instala al lado de la anterior.
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
