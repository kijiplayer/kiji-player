// Adaptado de Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0, que a su vez
// lo toma de NewPipe (https://github.com/TeamNewPipe/NewPipe), GPL-3.0.
// Archivo original: app/src/main/kotlin/.../utils/potoken/PoTokenException.kt (Echo 1.4.3).
// Cambios de Kiji: paquete propio, registros con android.util.Log y sin dependencias de Echo.

package com.example.kiji_player.extractor

class PoTokenException(message: String) : Exception(message)

// to be thrown if the WebView provided by the system is broken
class BadWebViewException(message: String) : Exception(message)

fun buildExceptionForJsError(error: String): Exception {
  return if (error.contains("SyntaxError")) BadWebViewException(error) else PoTokenException(error)
}
