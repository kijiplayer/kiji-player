// Adaptado de Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0, que a su vez lo
// toma de NewPipe (https://github.com/TeamNewPipe/NewPipe), GPL-3.0.
// Archivo original: app/src/main/kotlin/.../utils/potoken/PoTokenGenerator.kt (Echo 1.4.3).
// Cambios de Kiji: contexto inyectado, sin runBlocking (todo suspendido), registros sin tokens.

package com.example.kiji_player.extractor

import android.content.Context
import android.util.Log
import android.webkit.CookieManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout

/** PO tokens de BotGuard ("WEB_BOTGUARD") generados en una WebView invisible (Tarea Z8, motor A). */
class PoTokenGenerator(private val context: Context) {
  private val webViewSupported by lazy { runCatching { CookieManager.getInstance() }.isSuccess }
  private var webViewBroken = false

  private val lock = Mutex()
  private var sessionId: String? = null
  private var sessionPot: String? = null
  private var webView: PoTokenWebView? = null

  class Tokens(val playerRequestPoToken: String, val streamingDataPoToken: String)

  /**
   * Tokens para [videoId] con la sesión [visitorData]. El token de streaming (el `pot=` de la URL
   * de googlevideo) va **ligado a la sesión**, no al video: si no, YouTube corta el audio (ver la
   * explicación en el archivo original de Echo y en yt-dlp `get_webpo_content_binding`).
   */
  suspend fun tokensFor(videoId: String, visitorData: String): Tokens? {
    if (!webViewSupported || webViewBroken) return null
    return try {
      withTimeout(TIMEOUT_MS) { mint(videoId, visitorData, forceRecreate = false) }
    } catch (e: TimeoutCancellationException) {
      Log.w(TAG, "El PO token tardó más de $TIMEOUT_MS ms; se sigue sin él")
      reset()
      null
    } catch (e: BadWebViewException) {
      Log.e(TAG, "La WebView del sistema no sirve para el PO token", e)
      webViewBroken = true
      null
    }
  }

  private suspend fun reset() = lock.withLock {
    runCatching { withContext(Dispatchers.Main) { webView?.close() } }
      .onFailure { Log.w(TAG, "No se pudo cerrar la WebView del PO token: ${it.message}") }
    webView = null
    sessionPot = null
    sessionId = null
  }

  private suspend fun mint(videoId: String, visitorData: String, forceRecreate: Boolean): Tokens {
    val (generator, pot, recreated) =
      lock.withLock {
        val recreate = forceRecreate || webView == null || webView!!.isExpired || sessionId != visitorData
        if (recreate) {
          sessionId = visitorData
          withContext(Dispatchers.Main) { webView?.close() }
          webView = PoTokenWebView.getNewPoTokenGenerator(context)
          // El token de la sesión se genera una sola vez y antes que cualquier otro.
          sessionPot = webView!!.generatePoToken(visitorData)
        }
        Triple(webView!!, sessionPot!!, recreate)
      }
    try {
      // Calienta el minter para el video (lo pide BotGuard), aunque se use el de la sesión.
      generator.generatePoToken(videoId)
    } catch (t: Throwable) {
      if (recreated) throw t
      Log.w(TAG, "Falló el PO token; se recrea la WebView: ${t.message}")
      return mint(videoId, visitorData, forceRecreate = true)
    }
    // WEB_REMIX usa el token de la sesión también en el pedido /player (como yt-dlp).
    return Tokens(playerRequestPoToken = pot, streamingDataPoToken = pot)
  }

  private companion object {
    const val TAG = "KijiPoToken"

    /** Un arranque en frío sano tarda 2-5 s; con 8 s se pasa a otra forma si la WebView se cuelga. */
    const val TIMEOUT_MS = 8_000L
  }
}
