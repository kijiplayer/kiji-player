package io.github.kijiplayer.kiji

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Shader
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import android.view.View
import android.widget.RemoteViews
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Widgets de la pantalla de inicio. Uno solo que se adapta a su tamaño:
 *  - pequeño (2x2): la portada y el play con su anillo de progreso;
 *  - mediano (4x2): portada, título, artista, la onda y los controles (🍅, anterior, play,
 *    siguiente, ❤️);
 *  - grande (4x4): todo eso con la portada grande y la línea de la letra que suena (si la hay).
 * De fondo, la misma portada desenfocada con sus colores y el velo del estilo (Nocturne, Grafito o
 * Papel). Kiji manda el estado por el canal `kiji/widgets` solo si hay algún widget puesto, al
 * cambiar de canción o de estado y cada pocos segundos mientras suena; el último estado queda
 * guardado para dibujarlos con Kiji cerrada. Las imágenes (portada, fondo, onda y anillo) se dibujan
 * acá, del tamaño justo, y la portada y el fondo se guardan en memoria mientras no cambie la canción.
 */
object KijiWidgets {
    private const val TAG = "KijiWidgets"
    private const val PREFS = "kiji_widgets"
    const val ACTION_LIKE = "io.github.kijiplayer.kiji.WIDGET_LIKE"
    const val ACTION_TOMATO = "io.github.kijiplayer.kiji.WIDGET_TOMATO"

    private var channel: MethodChannel? = null
    private val main = Handler(Looper.getMainLooper())

    /** Para la vista previa de las pruebas (solo Kiji Dev): cuenta como si hubiera un widget. */
    @Volatile var previewOn = false

    @JvmStatic
    fun register(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        channel = MethodChannel(messenger, "kiji/widgets").also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "update" -> {
                        save(app, call.arguments as? Map<*, *> ?: emptyMap<String, Any?>())
                        refreshAll(app)
                        result.success(null)
                    }
                    // Cuántos widgets de Kiji hay puestos (con 0, Kiji no les manda nada).
                    "count" -> result.success(count(app) + if (previewOn) 1 else 0)
                    else -> result.notImplemented()
                }
            }
        }
    }

    /** Un botón del widget (❤️ o 🍅): lo hace Kiji, si está andando; si no, se abre Kiji. */
    fun dispatch(context: Context, action: String) {
        val ch = channel
        if (ch == null) {
            openApp(context)?.send()
            return
        }
        main.post {
            try {
                ch.invokeMethod("action", action)
            } catch (e: Exception) {
                Log.w(TAG, "No se pudo avisar a Kiji: ${e.javaClass.simpleName}")
            }
        }
    }

    /** Pide a Kiji que mande el estado ahora (vista previa de las pruebas). */
    fun askRefresh() {
        val ch = channel ?: return
        main.post {
            try {
                ch.invokeMethod("refresh", null)
            } catch (e: Exception) {
                Log.w(TAG, "No se pudo pedir el estado: ${e.javaClass.simpleName}")
            }
        }
    }

    private fun save(context: Context, args: Map<*, *>) {
        fun int(key: String, fallback: Int) = (args[key] as? Number)?.toInt() ?: fallback
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().apply {
            putString("title", args["title"] as? String)
            putString("artist", args["artist"] as? String)
            putBoolean("playing", args["playing"] as? Boolean ?: false)
            putInt("progress", int("progress", 0))
            putString("cover", args["cover"] as? String)
            putBoolean("liked", args["liked"] as? Boolean ?: false)
            putBoolean("theater", args["theater"] as? Boolean ?: true)
            putString("lyric", args["lyric"] as? String)
            putString("bars", (args["bars"] as? List<*>)?.joinToString(",") { "${(it as? Number)?.toInt() ?: 0}" })
            putString("style", args["style"] as? String ?: "nocturne")
            putBoolean("light", args["light"] as? Boolean ?: false)
            putInt("background", int("background", 0xFF0B0B14.toInt()))
            putInt("text", int("text", Color.WHITE))
            putInt("muted", int("muted", 0xFFA9A9C4.toInt()))
            putInt("accent", int("accent", 0xFF7C5CFF.toInt()))
            putInt("accent2", int("accent2", 0xFF3DF5FF.toInt()))
            putInt("onAccent", int("onAccent", Color.WHITE))
            putInt("like", int("like", 0xFFFF4D8D.toInt()))
            apply()
        }
    }

    fun count(context: Context): Int {
        val manager = AppWidgetManager.getInstance(context)
        return providers.sumOf { manager.getAppWidgetIds(ComponentName(context, it)).size }
    }

    private val providers = listOf(KijiWidgetSmall::class.java, KijiWidgetLarge::class.java)

    /** Vuelve a dibujar todos los widgets de Kiji con el último estado. */
    fun refreshAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        for (provider in providers) {
            for (id in manager.getAppWidgetIds(ComponentName(context, provider))) update(context, manager, id)
        }
    }

    fun update(context: Context, manager: AppWidgetManager, id: Int) {
        try {
            val (w, h) = sizeDp(manager.getAppWidgetOptions(id))
            manager.updateAppWidget(id, views(context, w, h))
        } catch (e: Exception) {
            Log.w(TAG, "No se pudo dibujar el widget: ${e.javaClass.simpleName}")
        }
    }

    /** Ancho y alto (dp) del widget en vertical, según el lanzador. */
    private fun sizeDp(options: Bundle?): Pair<Int, Int> {
        val w = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) ?: 0
        val h = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT) ?: 0
        return Pair(if (w > 0) w else 250, if (h > 0) h else 110)
    }

    enum class Size { SMALL, MEDIUM, LARGE }

    fun sizeFor(wDp: Int, hDp: Int): Size = when {
        wDp < 200 -> Size.SMALL
        hDp < 220 -> Size.MEDIUM
        else -> Size.LARGE
    }

    /** Lo guardado, con los colores del estilo. */
    private class State(context: Context) {
        private val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val title: String? = p.getString("title", null)
        val artist: String? = p.getString("artist", null)
        val playing = p.getBoolean("playing", false)
        val progress = p.getInt("progress", 0).coerceIn(0, 1000) / 1000f
        val cover: String? = p.getString("cover", null)
        val liked = p.getBoolean("liked", false)
        val theater = p.getBoolean("theater", true)
        val lyric: String? = p.getString("lyric", null)?.takeIf { it.isNotBlank() }
        val bars: List<Float> = p.getString("bars", null)?.split(',')?.mapNotNull { it.toIntOrNull()?.div(100f) }
            ?.takeIf { it.isNotEmpty() } ?: List(48) { 0.35f + 0.3f * (((it * 37) % 11) / 10f) }
        val style: String = p.getString("style", "nocturne") ?: "nocturne"
        val light = p.getBoolean("light", false)
        val background = p.getInt("background", 0xFF0B0B14.toInt())
        val text = p.getInt("text", Color.WHITE)
        val muted = p.getInt("muted", 0xFFA9A9C4.toInt())
        val accent = p.getInt("accent", 0xFF7C5CFF.toInt())
        val accent2 = p.getInt("accent2", 0xFF3DF5FF.toInt())
        val onAccent = p.getInt("onAccent", Color.WHITE)
        val like = p.getInt("like", 0xFFFF4D8D.toInt())
        val graphite: Boolean get() = style == "graphite"
        val paper: Boolean get() = style == "paper"
    }

    fun views(context: Context, wDp: Int, hDp: Int): RemoteViews {
        val s = State(context)
        val size = sizeFor(wDp, hDp)
        val d = context.resources.displayMetrics.density
        fun px(dp: Float) = (dp * d).roundToInt()
        val layout = when (size) {
            Size.SMALL -> R.layout.kiji_widget_s
            Size.MEDIUM -> R.layout.kiji_widget_m
            Size.LARGE -> R.layout.kiji_widget_l
        }
        val views = RemoteViews(context.packageName, layout)
        val radius = 24f * d
        val coverSource = loadCover(s.cover)

        // Fondo: la portada desenfocada con el velo del estilo, ya redondeada.
        views.setImageViewBitmap(R.id.widget_bg, background(s, coverSource, px(wDp.toFloat()), px(hDp.toFloat()), radius))

        // Portada (redondeada), del lado que le toca.
        val coverDp = when (size) {
            Size.SMALL -> min(wDp, hDp) - 20
            Size.MEDIUM -> min(76, hDp - 82)
            Size.LARGE -> min(wDp - 24, hDp - 210)
        }.coerceAtLeast(40)
        views.setImageViewBitmap(R.id.widget_cover, rounded(coverSource, s, px(coverDp.toFloat()), (if (size == Size.SMALL) 18f else 14f) * d))

        // Play con el anillo de progreso.
        val playDp = when (size) {
            Size.SMALL -> 56
            Size.MEDIUM -> 52
            Size.LARGE -> 64
        }
        views.setImageViewBitmap(R.id.widget_play, playRing(s, px(playDp.toFloat())))
        views.setOnClickPendingIntent(R.id.widget_play, mediaKey(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
        openApp(context)?.let { views.setOnClickPendingIntent(R.id.widget_root, it) }

        if (size != Size.SMALL) {
            views.setTextViewText(R.id.widget_title, s.title ?: context.getString(R.string.kiji_widget_idle))
            views.setTextColor(R.id.widget_title, s.text)
            views.setTextViewText(R.id.widget_artist, s.artist ?: "")
            views.setTextColor(R.id.widget_artist, s.muted)
            views.setInt(R.id.widget_prev, "setColorFilter", s.text)
            views.setInt(R.id.widget_next, "setColorFilter", s.text)
            views.setOnClickPendingIntent(R.id.widget_prev, mediaKey(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS))
            views.setOnClickPendingIntent(R.id.widget_next, mediaKey(context, KeyEvent.KEYCODE_MEDIA_NEXT))
            // ❤️ y 🍅.
            views.setImageViewResource(R.id.widget_like, if (s.liked) R.drawable.kiji_widget_heart_filled else R.drawable.kiji_widget_heart)
            views.setInt(R.id.widget_like, "setColorFilter", if (s.liked) s.like else s.text)
            views.setOnClickPendingIntent(R.id.widget_like, action(context, ACTION_LIKE))
            views.setViewVisibility(R.id.widget_tomato, if (s.theater) View.VISIBLE else View.GONE)
            views.setOnClickPendingIntent(R.id.widget_tomato, action(context, ACTION_TOMATO))
            // La onda: lo que ya sonó en el acento.
            val waveW = when (size) {
                Size.MEDIUM -> wDp - 20 - min(76, hDp - 82).coerceAtLeast(40) - 10
                else -> wDp - 24
            }.coerceAtLeast(60)
            val waveH = if (size == Size.LARGE) 26 else 16
            views.setImageViewBitmap(R.id.widget_wave, wave(s, px(waveW.toFloat()), px(waveH.toFloat()), d))
        }
        if (size == Size.LARGE) {
            val lyric = s.lyric
            views.setViewVisibility(R.id.widget_lyric, if (lyric == null) View.GONE else View.VISIBLE)
            views.setTextViewText(R.id.widget_lyric, lyric ?: "")
            views.setTextColor(R.id.widget_lyric, if (s.graphite) s.text else s.accent)
        }
        return views
    }

    // ---------- Imágenes ----------

    private var coverKey: String? = null
    private var coverCache: Bitmap? = null

    /** La portada del archivo (achicada a ~600 px), o null. Se guarda mientras sea la misma. */
    private fun loadCover(path: String?): Bitmap? {
        if (path == coverKey) return coverCache
        coverKey = path
        coverCache = try {
            if (path == null || !File(path).exists()) null else {
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeFile(path, bounds)
                var sample = 1
                while (bounds.outWidth / (sample * 2) >= 600 && bounds.outHeight / (sample * 2) >= 600) sample *= 2
                BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })
            }
        } catch (e: Exception) {
            Log.w(TAG, "Sin portada para el widget: ${e.javaClass.simpleName}")
            null
        }
        return coverCache
    }

    private fun gradientPaint(s: State, x0: Float, y0: Float, x1: Float, y1: Float) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        if (s.graphite || s.paper) color = s.accent
        else shader = LinearGradient(x0, y0, x1, y1, s.accent, s.accent2, Shader.TileMode.CLAMP)
    }

    /** Fondo: la portada muy achicada y vuelta a agrandar (desenfoque), el velo y el borde. */
    private fun background(s: State, cover: Bitmap?, wPx: Int, hPx: Int, radius: Float): Bitmap {
        val scale = 3
        val w = max(8, wPx / scale)
        val h = max(8, hPx / scale)
        val out = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(out)
        val r = radius / scale
        val shape = Path().apply { addRoundRect(RectF(0f, 0f, w.toFloat(), h.toFloat()), r, r, Path.Direction.CW) }
        c.clipPath(shape)
        c.drawColor(s.background)
        if (cover != null) {
            val tiny = Bitmap.createScaledBitmap(cover, 12, 12, true)
            val paint = Paint(Paint.FILTER_BITMAP_FLAG).apply {
                if (s.graphite) colorFilter = ColorMatrixColorFilter(ColorMatrix().apply { setSaturation(0f) })
                alpha = if (s.paper) 70 else 255
            }
            c.drawBitmap(tiny, null, RectF(-w * 0.15f, -h * 0.15f, w * 1.15f, h * 1.15f), paint)
        }
        // Velo para que el texto se lea (más fuerte en Grafito, crema en Papel).
        val veil = when {
            s.paper -> 0.78f
            s.graphite -> 0.62f
            else -> 0.50f
        }
        c.drawColor(Color.argb((veil * 255).roundToInt(), Color.red(s.background), Color.green(s.background), Color.blue(s.background)))
        if (!s.graphite && !s.paper) {
            // Nocturne: el degradado violeta → cian, suave.
            c.drawRect(0f, 0f, w.toFloat(), h.toFloat(), gradientPaint(s, 0f, 0f, w.toFloat(), h.toFloat()).apply { alpha = 46 })
        }
        // Borde de vidrio (Grafito) o de papel.
        val border = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = max(1f, 1.2f / scale * 3)
            color = if (s.light) Color.argb(28, 0, 0, 0) else Color.argb(if (s.graphite) 46 else 30, 255, 255, 255)
        }
        c.drawRoundRect(RectF(0.5f, 0.5f, w - 0.5f, h - 0.5f), r, r, border)
        return out
    }

    /** La portada cuadrada y redondeada; sin portada, el degradado del estilo con el ícono. */
    private fun rounded(cover: Bitmap?, s: State, sizePx: Int, radius: Float): Bitmap {
        val out = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val c = Canvas(out)
        val rect = RectF(0f, 0f, sizePx.toFloat(), sizePx.toFloat())
        if (cover != null) {
            val side = min(cover.width, cover.height)
            val m = Matrix().apply {
                val k = sizePx.toFloat() / side
                setScale(k, k)
                postTranslate(-(cover.width - side) / 2f * k, -(cover.height - side) / 2f * k)
            }
            val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply {
                shader = BitmapShader(cover, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP).apply { setLocalMatrix(m) }
            }
            c.drawRoundRect(rect, radius, radius, paint)
        } else {
            c.drawRoundRect(rect, radius, radius, gradientPaint(s, 0f, 0f, sizePx.toFloat(), sizePx.toFloat()))
            // Una nota musical simple, en el color sobre el acento.
            val note = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = s.onAccent }
            val k = sizePx / 100f
            c.drawCircle(40 * k, 66 * k, 10 * k, note)
            c.drawRect(47 * k, 30 * k, 52 * k, 66 * k, note)
            c.drawRect(47 * k, 30 * k, 66 * k, 36 * k, note)
        }
        return out
    }

    /** Play o pausa adentro del anillo de progreso (como en el reproductor). */
    private fun playRing(s: State, sizePx: Int): Bitmap {
        val out = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val c = Canvas(out)
        val f = sizePx.toFloat()
        val stroke = f * 0.06f
        val ring = RectF(stroke, stroke, f - stroke, f - stroke)
        c.drawArc(ring, 0f, 360f, false, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = stroke
            color = Color.argb(70, Color.red(s.text), Color.green(s.text), Color.blue(s.text))
        })
        if (s.progress > 0f) {
            c.drawArc(ring, -90f, 360f * s.progress, false, gradientPaint(s, 0f, 0f, f, f).apply {
                style = Paint.Style.STROKE
                strokeWidth = stroke
                strokeCap = Paint.Cap.ROUND
            })
        }
        // El botón, adentro.
        val inner = f / 2 - stroke * 2.2f
        val fill = when {
            s.graphite -> Paint(Paint.ANTI_ALIAS_FLAG).apply { color = s.text }
            else -> gradientPaint(s, 0f, 0f, f, f)
        }
        c.drawCircle(f / 2, f / 2, inner, fill)
        val icon = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = if (s.graphite) s.background else s.onAccent }
        val k = inner / 10f
        if (s.playing) {
            c.drawRoundRect(RectF(f / 2 - 4.2f * k, f / 2 - 4.6f * k, f / 2 - 1.3f * k, f / 2 + 4.6f * k), k, k, icon)
            c.drawRoundRect(RectF(f / 2 + 1.3f * k, f / 2 - 4.6f * k, f / 2 + 4.2f * k, f / 2 + 4.6f * k), k, k, icon)
        } else {
            val tri = Path().apply {
                moveTo(f / 2 - 3.2f * k, f / 2 - 5f * k)
                lineTo(f / 2 + 5.2f * k, f / 2)
                lineTo(f / 2 - 3.2f * k, f / 2 + 5f * k)
                close()
            }
            c.drawPath(tri, icon)
        }
        return out
    }

    /** La onda de Kiji: barras finas, lo reproducido en el acento. */
    private fun wave(s: State, wPx: Int, hPx: Int, density: Float): Bitmap {
        val out = Bitmap.createBitmap(max(1, wPx), max(1, hPx), Bitmap.Config.ARGB_8888)
        val c = Canvas(out)
        val barW = 2.2f * density
        val gap = 2.2f * density
        val count = max(8, ((wPx + gap) / (barW + gap)).toInt())
        val played = gradientPaint(s, 0f, 0f, wPx.toFloat(), 0f)
        val rest = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(if (s.light) 60 else 80, Color.red(s.text), Color.green(s.text), Color.blue(s.text))
        }
        val step = wPx.toFloat() / count
        for (i in 0 until count) {
            val v = s.bars[(i * s.bars.size / count).coerceIn(0, s.bars.size - 1)].coerceIn(0.12f, 1f)
            val bh = max(barW, v * hPx)
            val x = i * step + (step - barW) / 2
            val y = (hPx - bh) / 2
            c.drawRoundRect(RectF(x, y, x + barW, y + bh), barW / 2, barW / 2, if ((i + 0.5f) / count <= s.progress) played else rest)
        }
        return out
    }

    // ---------- Toques ----------

    private fun mediaKey(context: Context, code: Int): PendingIntent {
        val intent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            component = ComponentName(context, "com.ryanheise.audioservice.MediaButtonReceiver")
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, code))
        }
        return PendingIntent.getBroadcast(context, code, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun action(context: Context, name: String): PendingIntent {
        val intent = Intent(context, KijiWidgetActions::class.java).setAction(name)
        return PendingIntent.getBroadcast(context, name.hashCode(), intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun openApp(context: Context): PendingIntent? {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return null
        return PendingIntent.getActivity(context, 0, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
}

/** ❤️ y 🍅 del widget. */
class KijiWidgetActions : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = when (intent.action) {
            KijiWidgets.ACTION_LIKE -> "like"
            KijiWidgets.ACTION_TOMATO -> "tomato"
            else -> return
        }
        KijiWidgets.dispatch(context, action)
    }
}

/** Kiji (empieza en 2x2: portada y play). Se puede agrandar y se adapta. */
class KijiWidgetSmall : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) KijiWidgets.update(context, manager, id)
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, newOptions: Bundle) {
        KijiWidgets.update(context, manager, id)
    }
}

/** Kiji (empieza en 4x2: portada, canción, onda y controles). Se puede agrandar y se adapta. */
class KijiWidgetLarge : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) KijiWidgets.update(context, manager, id)
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, newOptions: Bundle) {
        KijiWidgets.update(context, manager, id)
    }
}
