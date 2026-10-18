package com.example.kiji_player.extractor

import android.content.Context
import android.util.Log
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.io.File
import java.util.concurrent.TimeUnit
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject

/**
 * Prueba diaria del motor A (Tarea Z8): una canción de CONTROL por forma (nunca datos del
 * usuario), con la prueba del ÚLTIMO byte. Corre con WorkManager solo con red no medida y
 * batería no baja. Deja el resultado en `extractor_bg.json`, que Kiji suma a la Salud del
 * Extractor la próxima vez que se abre.
 */
class ExtractorTestWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
  override suspend fun doWork(): Result {
    val engine = InnerTubeXHolder.get(applicationContext)
    val http = OkHttpClient()
    val results = JSONArray()
    for ((i, form) in FORMS.withIndex()) {
      val videoId = CONTROL[(i + (System.currentTimeMillis() / DAY_MS).toInt()) % CONTROL.size]
      val start = System.currentTimeMillis()
      val map = engine.extract(videoId, "auto", emptySet(), form)
      val url = map["url"] as? String
      val reason =
        if (url == null) "${map["message"] ?: map["reason"] ?: "sin audio"}"
        else lastByteProblem(http, url, map)
      results.put(
        JSONObject()
          .put("path", "A/$form")
          .put("ok", reason == null)
          .put("reason", reason ?: JSONObject.NULL)
          .put("ms", System.currentTimeMillis() - start)
      )
    }
    val out = File(applicationContext.filesDir, "extractor_bg.json")
    out.writeText(JSONObject().put("at", System.currentTimeMillis()).put("results", results).toString())
    Log.i(TAG, "Prueba diaria: ${(0 until results.length()).count { results.getJSONObject(it).getBoolean("ok") }} de ${results.length()} formas andan")
    return Result.success()
  }

  /** null si el último byte llegó (detecta las formas que cortan en 1 MiB). */
  private fun lastByteProblem(http: OkHttpClient, url: String, map: Map<String, Any?>): String? {
    if (map["isHls"] == true) return null
    @Suppress("UNCHECKED_CAST") val headers = (map["headers"] as? Map<String, String>).orEmpty()
    fun get(range: String) =
      http.newCall(Request.Builder().url(url).apply { headers.forEach { (k, v) -> header(k, v) } }.header("Range", range).build()).execute()
    return try {
      var length = (map["contentLength"] as? Number)?.toLong()
      if (length == null || length <= 0) {
        get("bytes=0-0").use { length = it.header("Content-Range")?.substringAfterLast('/')?.toLongOrNull() }
      }
      val total = length ?: return "YouTube no dijo el tamaño del audio"
      get("bytes=${total - 1}-${total - 1}").use { if (it.code == 206 || it.code == 200) null else "El último byte no llegó (HTTP ${it.code})" }
    } catch (e: Exception) {
      "No se pudo pedir el último byte (${e.javaClass.simpleName})"
    }
  }

  companion object {
    private const val TAG = "KijiSalud"
    private const val NAME = "kiji_prueba_extractor"
    private const val DAY_MS = 24 * 60 * 60 * 1000L
    private val CONTROL = listOf("BSTsnWoslP4", "8Xv_Hg8o1fw", "BycLmWI97Nc")
    private val FORMS = listOf("VISIONOS_0_1", "VISIONOS", "WEB_REMIX", "WEB_EMBEDDED_PLAYER", "TVHTML5_SIMPLY")

    /** Prende o apaga la prueba diaria (Configuración → Salud del Extractor). */
    fun schedule(context: Context, enabled: Boolean) {
      val work = WorkManager.getInstance(context)
      if (!enabled) {
        work.cancelUniqueWork(NAME)
        return
      }
      val request =
        PeriodicWorkRequestBuilder<ExtractorTestWorker>(1, TimeUnit.DAYS)
          .setConstraints(
            Constraints.Builder()
              .setRequiredNetworkType(NetworkType.UNMETERED)
              .setRequiresBatteryNotLow(true)
              .build()
          )
          .build()
      work.enqueueUniquePeriodicWork(NAME, ExistingPeriodicWorkPolicy.KEEP, request)
    }
  }
}
