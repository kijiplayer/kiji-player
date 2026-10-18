package com.example.kiji_player.extractor

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** Un solo motor A por proceso (lo comparten la app y la prueba diaria de WorkManager). */
object InnerTubeXHolder {
  @Volatile private var engine: InnerTubeXEngine? = null

  fun get(context: Context): InnerTubeXEngine =
    engine ?: synchronized(this) { engine ?: InnerTubeXEngine(context.applicationContext).also { engine = it } }
}

/**
 * Canal `kiji/innertubex` (Tarea Z8): `extract(videoId, quality, skip)`, `onRefused(url)` y
 * `prewarm()`. Todo corre fuera del hilo principal; la respuesta vuelve en el principal.
 */
object ExtractorChannel {
  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

  fun register(context: Context, messenger: BinaryMessenger) {
    MethodChannel(messenger, "kiji/innertubex").setMethodCallHandler { call, result ->
      val engine = InnerTubeXHolder.get(context)
      scope.launch {
        try {
          when (call.method) {
            "extract" -> {
              val videoId = call.argument<String>("videoId") ?: return@launch result.error("args", "sin videoId", null)
              val quality = call.argument<String>("quality") ?: "auto"
              val skip = call.argument<List<String>>("skip")?.toSet() ?: emptySet()
              result.success(withContext(Dispatchers.IO) { engine.extract(videoId, quality, skip) })
            }
            "onRefused" -> {
              val url = call.argument<String>("url") ?: return@launch result.success(null)
              withContext(Dispatchers.IO) { engine.onRefused(url) }
              result.success(null)
            }
            "prewarm" -> {
              withContext(Dispatchers.IO) { engine.prewarm() }
              result.success(null)
            }
            else -> result.notImplemented()
          }
        } catch (e: Exception) {
          result.error("innertubex", e.javaClass.simpleName, null)
        }
      }
    }
  }
}
