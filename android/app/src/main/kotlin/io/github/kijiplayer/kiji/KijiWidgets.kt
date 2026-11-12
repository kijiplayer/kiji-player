package io.github.kijiplayer.kiji

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import android.view.KeyEvent
import android.widget.RemoteViews
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Widgets de la pantalla de inicio: chico (anterior, play/pausa, siguiente) y grande (portada,
 * título, artista, progreso y controles). Kiji les manda la canción y los colores del estilo por
 * el canal `kiji/widgets`; el último estado queda guardado para dibujarlos con Kiji cerrada. Los
 * botones son teclas multimedia para el servicio de audio (como los de los auriculares).
 */
object KijiWidgets {
    private const val TAG = "KijiWidgets"
    private const val PREFS = "kiji_widgets"

    @JvmStatic
    fun register(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        MethodChannel(messenger, "kiji/widgets").setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
                    app.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().apply {
                        putString("title", args["title"] as? String)
                        putString("artist", args["artist"] as? String)
                        putBoolean("playing", args["playing"] as? Boolean ?: false)
                        putInt("progress", (args["progress"] as? Number)?.toInt() ?: 0)
                        putString("cover", args["cover"] as? String)
                        putInt("background", (args["background"] as? Number)?.toInt() ?: 0xFF16161A.toInt())
                        putInt("text", (args["text"] as? Number)?.toInt() ?: 0xFFFFFFFF.toInt())
                        putInt("muted", (args["muted"] as? Number)?.toInt() ?: 0xFF9A9A9E.toInt())
                        putInt("accent", (args["accent"] as? Number)?.toInt() ?: 0xFF7C5CFF.toInt())
                        apply()
                    }
                    refreshAll(app)
                    result.success(null)
                }
                // Cuántos widgets de Kiji hay puestos (con 0, Kiji no les manda nada).
                "count" -> result.success(count(app))
                else -> result.notImplemented()
            }
        }
    }

    fun count(context: Context): Int {
        val manager = AppWidgetManager.getInstance(context)
        return listOf(KijiWidgetSmall::class.java, KijiWidgetLarge::class.java).sumOf {
            manager.getAppWidgetIds(ComponentName(context, it)).size
        }
    }

    /** Vuelve a dibujar todos los widgets de Kiji con el último estado. */
    fun refreshAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        for ((provider, large) in listOf(KijiWidgetSmall::class.java to false, KijiWidgetLarge::class.java to true)) {
            val ids = manager.getAppWidgetIds(ComponentName(context, provider))
            if (ids.isNotEmpty()) for (id in ids) manager.updateAppWidget(id, views(context, large))
        }
    }

    fun views(context: Context, large: Boolean): RemoteViews {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val views = RemoteViews(context.packageName, if (large) R.layout.kiji_widget_large else R.layout.kiji_widget_small)
        val text = prefs.getInt("text", 0xFFFFFFFF.toInt())
        val muted = prefs.getInt("muted", 0xFF9A9A9E.toInt())
        val accent = prefs.getInt("accent", 0xFF7C5CFF.toInt())
        val playing = prefs.getBoolean("playing", false)

        views.setInt(R.id.widget_bg, "setColorFilter", prefs.getInt("background", 0xFF16161A.toInt()))
        views.setInt(R.id.widget_prev, "setColorFilter", text)
        views.setInt(R.id.widget_next, "setColorFilter", text)
        views.setInt(R.id.widget_play, "setColorFilter", accent)
        views.setImageViewResource(R.id.widget_play, if (playing) R.drawable.kiji_widget_pause else R.drawable.kiji_widget_play)

        views.setOnClickPendingIntent(R.id.widget_prev, mediaKey(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS))
        views.setOnClickPendingIntent(R.id.widget_play, mediaKey(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
        views.setOnClickPendingIntent(R.id.widget_next, mediaKey(context, KeyEvent.KEYCODE_MEDIA_NEXT))
        openApp(context)?.let { views.setOnClickPendingIntent(R.id.widget_root, it) }

        if (large) {
            views.setTextViewText(R.id.widget_title, prefs.getString("title", null) ?: context.getString(R.string.kiji_widget_idle))
            views.setTextColor(R.id.widget_title, text)
            views.setTextViewText(R.id.widget_artist, prefs.getString("artist", null) ?: "")
            views.setTextColor(R.id.widget_artist, muted)
            views.setProgressBar(R.id.widget_progress, 1000, prefs.getInt("progress", 0).coerceIn(0, 1000), false)
            val cover = prefs.getString("cover", null)?.let { coverBitmap(it) }
            if (cover != null) views.setImageViewBitmap(R.id.widget_cover, cover) else views.setImageViewResource(R.id.widget_cover, R.mipmap.ic_launcher)
        }
        return views
    }

    /** La portada achicada (los widgets tienen un límite de memoria por imagen). */
    private fun coverBitmap(path: String): Bitmap? = try {
        val file = File(path)
        if (!file.exists()) null else {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(path, bounds)
            var sample = 1
            while (bounds.outWidth / (sample * 2) >= 256 && bounds.outHeight / (sample * 2) >= 256) sample *= 2
            BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })
        }
    } catch (e: Exception) {
        Log.w(TAG, "Sin portada para el widget: ${e.javaClass.simpleName}")
        null
    }

    private fun mediaKey(context: Context, code: Int): PendingIntent {
        val intent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            component = ComponentName(context, "com.ryanheise.audioservice.MediaButtonReceiver")
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, code))
        }
        return PendingIntent.getBroadcast(context, code, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun openApp(context: Context): PendingIntent? {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return null
        return PendingIntent.getActivity(context, 0, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
}

/** Widget chico: anterior, play/pausa y siguiente. */
class KijiWidgetSmall : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, KijiWidgets.views(context, false))
    }
}

/** Widget grande: portada, título, artista, progreso y controles. */
class KijiWidgetLarge : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, KijiWidgets.views(context, true))
    }
}
