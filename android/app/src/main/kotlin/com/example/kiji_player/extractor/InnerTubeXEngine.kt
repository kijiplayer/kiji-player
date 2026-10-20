// Adaptado de Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivo original: app/src/main/kotlin/.../utils/InnerTubeXResolver.kt (Echo 1.4.3).
// Usa InnerTubeX (https://github.com/MetrolistGroup/innertubex), GPL-3.0, de MetrolistGroup.
// Cambios de Kiji: sin cuenta (anónimo), clasificación de errores para la Salud del Extractor,
// HLS permitido (just_audio lo reproduce) y respuesta en un mapa para el canal `kiji/innertubex`.

package com.example.kiji_player.extractor

import android.content.Context
import android.content.SharedPreferences
import android.os.SystemClock
import android.util.Log
import com.metrolist.innertubex.InnerTube
import com.metrolist.innertubex.InnerTubeLogLevel
import com.metrolist.innertubex.InnerTubeLogger
import com.metrolist.innertubex.cipher.PlayerConfigRepository
import com.metrolist.innertubex.cipher.RemotePlayerConfigStore
import com.metrolist.innertubex.cipher.YouTubeCipherService
import com.metrolist.innertubex.extraction.AudioQuality
import com.metrolist.innertubex.extraction.ContentHints
import com.metrolist.innertubex.extraction.InnerTubeExtractor
import com.metrolist.innertubex.extraction.PoTokenResult
import com.metrolist.innertubex.extraction.StreamResolveException
import com.metrolist.innertubex.extraction.TokenProvider
import com.metrolist.innertubex.extraction.TokenProviderCapabilities
import com.metrolist.innertubex.extraction.YtConfigParserImpl
import com.metrolist.innertubex.extraction.generateClientPlaybackNonce
import com.metrolist.innertubex.extraction.strategy.PoTokenProviderKind
import com.metrolist.innertubex.models.YouTubeLocale
import io.ktor.client.HttpClient
import io.ktor.client.engine.okhttp.OkHttp
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.serialization.kotlinx.json.json
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.CancellationException
import kotlinx.serialization.json.Json

/**
 * Motor A de extracción (solo Android): InnerTubeX elige el cliente según su catálogo
 * medido, descifra con Zemer/EJS y genera el PO token con BotGuard.
 */
class InnerTubeXEngine(context: Context) {
  private val app = context.applicationContext
  private val prefs: SharedPreferences = app.getSharedPreferences("innertubex_player_config", Context.MODE_PRIVATE)
  private val poTokens = PoTokenGenerator(app)

  /** Formas que YouTube rechazó a mitad de canción, por videoId y hasta cuándo. */
  private val excluded = ConcurrentHashMap<String, ConcurrentHashMap<String, Long>>()

  /** Qué forma entregó cada URL, para saber a quién culpar si después la rechazan. */
  private val minted = ConcurrentHashMap<String, Pair<String, String>>()

  private val http =
    HttpClient(OkHttp) {
      install(ContentNegotiation) {
        json(Json { ignoreUnknownKeys = true; explicitNulls = false; encodeDefaults = true })
      }
      install(HttpTimeout) {
        requestTimeoutMillis = 30_000
        connectTimeoutMillis = 15_000
        socketTimeoutMillis = 20_000
      }
      expectSuccess = false
    }

  // Nunca se registran URLs firmadas, tokens ni cookies (InnerTubeX ya los oculta).
  private val logger = InnerTubeLogger { event ->
    if (event.level == InnerTubeLogLevel.DEBUG) return@InnerTubeLogger
    val details = if (event.details.isEmpty()) "" else event.details.entries.joinToString(prefix = " [", postfix = "]") { "${it.key}=${it.value}" }
    Log.i(TAG, "ITX ${event.tag}: ${event.message}$details")
  }

  /**
   * `player_configs.json` remoto de ZemerTeam/zemer-cipher (como Echo y Metrolist), con caché de
   * 6 h y ETag; se fuerza otra consulta si aparece un reproductor desconocido o YouTube rechaza un
   * audio descifrado. GitHub ve esa consulta (lo explica Configuración → Privacidad).
   */
  private val repository =
    object : PlayerConfigRepository {
      override val enabled = true
      override val sourceUrl = PLAYER_CONFIG_URL
      override val defaultSourceUrl = PLAYER_CONFIG_URL
      override var cachedJson: String
        get() = prefs.getString("json", "").orEmpty()
        set(value) = prefs.edit().putString("json", value).apply()
      override var cachedAtMs: Long
        get() = prefs.getLong("cached_at_ms", 0L)
        set(value) = prefs.edit().putLong("cached_at_ms", value).apply()
      override var cachedSourceUrl: String
        get() = prefs.getString("source_url", "").orEmpty()
        set(value) = prefs.edit().putString("source_url", value).apply()
      override var cachedEtag: String
        get() = prefs.getString("etag", "").orEmpty()
        set(value) = prefs.edit().putString("etag", value).apply()
    }

  private val tokenProvider =
    object : TokenProvider {
      override val capabilities = TokenProviderCapabilities(providers = setOf(PoTokenProviderKind.WEB_BOTGUARD), usesWebView = true)

      override suspend fun getPoToken(videoId: String, visitorData: String, cookie: String?): PoTokenResult? =
        poTokens.tokensFor(videoId, visitorData)?.let {
          PoTokenResult(playerRequestToken = it.playerRequestPoToken, streamingDataToken = it.streamingDataPoToken, visitorData = visitorData)
        }

      override suspend fun close() {}
    }

  private val innerTube = InnerTube(http, logger = logger).apply { locale = YouTubeLocale(gl = "US", hl = "en") }
  private val remoteStore = RemotePlayerConfigStore(http, repository, logger)
  private val cipherService = YouTubeCipherService(http, remoteStore, logger)
  private val extractor =
    InnerTubeExtractor(
      configParser = YtConfigParserImpl(http, innerTube, remoteStore, logger, cipherService),
      cipherService = cipherService,
      innerTube = innerTube,
      tokenProvider = tokenProvider,
      logger = logger,
    )

  /** Paga los costos en frío (config, solver EJS, WebView de BotGuard) antes de la primera canción. */
  /** Cuenta opcional (Configuración → Cuenta): null = sin sesión. Solo vive en memoria. */
  fun setSession(cookie: String?, visitorData: String?, dataSyncId: String?) {
    innerTube.cookie = cookie
    innerTube.dataSyncId = dataSyncId
    if (visitorData != null) innerTube.visitorData = visitorData
  }

  suspend fun prewarm() {
    val start = SystemClock.elapsedRealtime()
    try {
      extractor.prewarm()
      Log.i(TAG, "InnerTubeX listo en ${SystemClock.elapsedRealtime() - start} ms")
    } catch (e: CancellationException) {
      throw e
    } catch (e: Exception) {
      Log.w(TAG, "No se pudo precalentar InnerTubeX: ${e.message}")
    }
  }

  /**
   * Busca el audio de [videoId]. Devuelve un mapa para Dart: si salió bien, `url`, `headers`,
   * `mime`, `kbps`, `client`, `profileId`, `expiresAtMs`, `contentLength`, `chunkSize` y `isHls`;
   * si no, `error` con `kind` = `content` (la canción) o `form` (la forma) y `reason`.
   */
  suspend fun extract(videoId: String, quality: String, skip: Set<String>, onlyProfile: String? = null): Map<String, Any?> {
    return try {
      val stream =
        extractor.extract(
          videoId = videoId,
          // SABR todavía no (just_audio no lo entiende); HLS sí; rangos acotados sí (la fuente de Kiji pide por pedazos).
          // [onlyProfile]: para la Salud del Extractor, probar una forma sola (sin las demás).
          hints = ContentHints(playbackClientOverrideId = onlyProfile)
            .withStreamCapabilities(allowHls = true, allowSabr = false, allowBoundedRange = true),
          excludedClients = excludedFor(videoId) + skip,
          audioQuality = if (quality == "low") AudioQuality.LOW else AudioQuality.AUTO,
          clientPlaybackNonce = generateClientPlaybackNonce(),
        ) ?: return mapOf("error" to "form", "reason" to "no_stream", "message" to "Ninguna forma de InnerTubeX dio audio")
      if (stream.sabrBootstrap != null) {
        return mapOf("error" to "form", "reason" to "sabr_only", "message" to "Solo ofrece SABR")
      }
      if (minted.size >= MAX_REMEMBERED) minted.clear()
      minted[stream.audioUrl] = videoId to stream.profileId
      val mime = stream.mimeType.orEmpty()
      val isHls = stream.audioUrl.contains(".m3u8") || mime.contains("mpegurl", ignoreCase = true)
      mapOf(
        "url" to stream.audioUrl,
        "headers" to stream.headers,
        "mime" to if (stream.codecs.isNullOrBlank()) mime else "$mime; codecs=\"${stream.codecs}\"",
        "kbps" to (stream.bitrate ?: 0) / 1000,
        "client" to stream.clientName,
        "profileId" to stream.profileId,
        "expiresAtMs" to stream.expiresAt?.toEpochMilliseconds(),
        "contentLength" to stream.contentLengthBytes,
        "chunkSize" to if (stream.requireBoundedRange || stream.useRangeChunks) stream.rangeChunkSizeBytes else null,
        "isHls" to isHls,
      )
    } catch (e: CancellationException) {
      throw e
    } catch (e: StreamResolveException) {
      val content = e.reason in CONTENT_REASONS
      Log.w(TAG, "InnerTubeX no encontró audio para $videoId: ${e.reason}")
      mapOf("error" to if (content) "content" else "form", "reason" to e.reason.name.lowercase(), "message" to e.message)
    } catch (e: Exception) {
      Log.w(TAG, "InnerTubeX falló con $videoId: ${e.javaClass.simpleName}")
      mapOf("error" to "form", "reason" to "exception", "message" to e.javaClass.simpleName)
    }
  }

  /** googlevideo rechazó [url] a mitad de la canción: esa forma queda fuera 10 min para ese video. */
  suspend fun onRefused(url: String) {
    val (videoId, profileId) = minted.remove(url) ?: return
    Log.w(TAG, "$profileId fue rechazado a mitad de $videoId; se saltea 10 min")
    excluded.getOrPut(videoId) { ConcurrentHashMap() }[profileId] = SystemClock.elapsedRealtime() + EXCLUDE_MS
    // Un audio descifrado rechazado puede indicar que la config remota quedó vieja.
    runCatching { cipherService.refreshAfterStreamRejection() }
      .onFailure { Log.w(TAG, "No se pudo refrescar la config remota: ${it.message}") }
  }

  private fun excludedFor(videoId: String): Set<String> {
    val entries = excluded[videoId] ?: return emptySet()
    val now = SystemClock.elapsedRealtime()
    entries.entries.removeAll { it.value <= now }
    return entries.keys.toSet()
  }

  companion object {
    private const val TAG = "KijiInnerTubeX"
    const val PLAYER_CONFIG_URL =
      "https://raw.githubusercontent.com/ZemerTeam/zemer-cipher/master/library/src/main/assets/player_configs.json"
    private const val EXCLUDE_MS = 10 * 60 * 1000L
    private const val MAX_REMEMBERED = 64

    /** Errores del CONTENIDO (marcan la canción, nunca la forma). */
    private val CONTENT_REASONS =
      setOf(
        StreamResolveException.Reason.UNAVAILABLE,
        StreamResolveException.Reason.AGE_RESTRICTED,
        StreamResolveException.Reason.EXPLICIT_UNSUPPORTED,
        StreamResolveException.Reason.NO_MUSIC_VIDEO,
      )
  }
}
