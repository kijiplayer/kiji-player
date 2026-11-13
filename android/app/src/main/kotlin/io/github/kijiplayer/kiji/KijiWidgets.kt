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
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * Los widgets de Kiji para la pantalla de inicio, en los tres estilos (Nocturne, Grafito y Papel):
 *  - Anillo (2x2): la portada en un círculo con la onda alrededor y play al centro.
 *  - Ahora suena (4x2, se agranda a 4x4 con la línea de la letra): portada, canción, onda y
 *    controles (🍅, anterior, play, siguiente, ❤️).
 *  - Letra (4x2): la línea de la letra que suena, grande, sobre la portada desenfocada.
 *  - Teatro (2x2): 🍅 y 🌹 grandes con lo de hoy.
 *  - Barra (4x1): el logo de onda de Kiji, la canción y play.
 * Kiji manda el estado por `kiji/widgets` solo si hay alguno puesto, al cambiar de canción o de
 * estado (y la letra, una línea a la vez mientras suena y solo con un widget Letra puesto). El
 * último estado queda guardado para dibujarlos con Kiji cerrada. Las imágenes se dibujan acá, del
 * tamaño justo; la portada se guarda en memoria mientras no cambie la canción. Nunca bajan nada.
 */
object KijiWidgets {
    private const val TAG = "KijiWidgets"
    private const val PREFS = "kiji_widgets"
    const val ACTION_LIKE = "io.github.kijiplayer.kiji.WIDGET_LIKE"
    const val ACTION_TOMATO = "io.github.kijiplayer.kiji.WIDGET_TOMATO"
    const val ACTION_ROSE = "io.github.kijiplayer.kiji.WIDGET_ROSE"

    private var channel: MethodChannel? = null
    private val main = Handler(Looper.getMainLooper())

    /** Para la vista previa de las pruebas (solo Kiji Dev): cuenta como si hubiera uno de cada uno. */
    @Volatile var previewOn = false

    /** Los cinco tipos, con su proveedor. */
    enum class Kind(val provider: Class<out AppWidgetProvider>, val key: String) {
        RING(KijiWidgetSmall::class.java, "ring"),
        NOW(KijiWidgetLarge::class.java, "now"),
        LYRICS(KijiWidgetLyrics::class.java, "lyrics"),
        THEATER(KijiWidgetTheater::class.java, "theater"),
        BAR(KijiWidgetBar::class.java, "bar"),
    }

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
                    // Cuántos hay puestos de cada tipo (sin ninguno, Kiji no les manda nada).
                    "counts" -> result.success(Kind.values().associate { it.key to count(app, it) + if (previewOn) 1 else 0 })
                    else -> result.notImplemented()
                }
            }
        }
    }

    /** Un botón del widget (❤️, 🍅 o 🌹): lo hace Kiji, si está andando; si no, se abre Kiji. */
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
            putInt("tomatoesToday", int("tomatoesToday", 0))
            putInt("rosesToday", int("rosesToday", 0))
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
            putInt("curtain", int("curtain", 0xFF8E1B2B.toInt()))
            putInt("gold", int("gold", 0xFFE8C26A.toInt()))
            apply()
        }
    }

    fun count(context: Context, kind: Kind): Int =
        AppWidgetManager.getInstance(context).getAppWidgetIds(ComponentName(context, kind.provider)).size

    fun count(context: Context): Int = Kind.values().sumOf { count(context, it) }

    /** Vuelve a dibujar todos los widgets de Kiji con el último estado. */
    fun refreshAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        for (kind in Kind.values()) {
            for (id in manager.getAppWidgetIds(ComponentName(context, kind.provider))) update(context, manager, id, kind)
        }
    }

    fun update(context: Context, manager: AppWidgetManager, id: Int, kind: Kind) {
        try {
            val (w, h) = sizeDp(manager.getAppWidgetOptions(id), kind)
            manager.updateAppWidget(id, views(context, kind, w, h))
        } catch (e: Exception) {
            Log.w(TAG, "No se pudo dibujar el widget: ${e.javaClass.simpleName}")
        }
    }

    /** Ancho y alto (dp) del widget en vertical, según el lanzador. */
    private fun sizeDp(options: Bundle?, kind: Kind): Pair<Int, Int> {
        val w = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) ?: 0
        val h = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT) ?: 0
        val (dw, dh) = when (kind) {
            Kind.RING, Kind.THEATER -> 150 to 150
            Kind.BAR -> 320 to 64
            else -> 320 to 150
        }
        return Pair(if (w > 0) w else dw, if (h > 0) h else dh)
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
        val tomatoesToday = p.getInt("tomatoesToday", 0)
        val rosesToday = p.getInt("rosesToday", 0)
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
        val curtain = p.getInt("curtain", 0xFF8E1B2B.toInt())
        val gold = p.getInt("gold", 0xFFE8C26A.toInt())
        val graphite: Boolean get() = style == "graphite"
        val paper: Boolean get() = style == "paper"
    }

    fun views(context: Context, kind: Kind, wDp: Int, hDp: Int): RemoteViews = when (kind) {
        Kind.RING -> ring(context, wDp, hDp)
        Kind.NOW -> nowPlaying(context, wDp, hDp)
        Kind.LYRICS -> lyrics(context, wDp, hDp)
        Kind.THEATER -> theater(context, wDp, hDp)
        Kind.BAR -> bar(context, wDp, hDp)
    }

    private fun px(context: Context, dp: Float) = (dp * context.resources.displayMetrics.density).roundToInt()

    // ---------- Los cinco ----------

    /** Anillo: la portada en un círculo, la onda alrededor (lo que sonó en el acento) y play al centro. */
    private fun ring(context: Context, wDp: Int, hDp: Int): RemoteViews {
        val s = State(context)
        val v = RemoteViews(context.packageName, R.layout.kiji_widget_ring)
        val d = context.resources.displayMetrics.density
        v.setImageViewBitmap(R.id.widget_bg, background(s, loadCover(s.cover), px(context, wDp.toFloat()), px(context, hDp.toFloat()), 24f * d, veil = 0.55f))
        v.setImageViewBitmap(R.id.widget_play, ringArt(s, loadCover(s.cover), px(context, (min(wDp, hDp) - 12).toFloat())))
        v.setOnClickPendingIntent(R.id.widget_play, mediaKey(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
        openApp(context)?.let { v.setOnClickPendingIntent(R.id.widget_root, it) }
        return v
    }

    /** Ahora suena: 4x2 (y con más alto, la portada grande y la línea de la letra). */
    private fun nowPlaying(context: Context, wDp: Int, hDp: Int): RemoteViews {
        val s = State(context)
        val large = hDp >= 220
        val v = RemoteViews(context.packageName, if (large) R.layout.kiji_widget_l else R.layout.kiji_widget_m)
        val d = context.resources.displayMetrics.density
        val cover = loadCover(s.cover)
        v.setImageViewBitmap(R.id.widget_bg, background(s, cover, px(context, wDp.toFloat()), px(context, hDp.toFloat()), 24f * d))
        val coverDp = (if (large) min(wDp - 24, hDp - 210) else min(76, hDp - 82)).coerceAtLeast(40)
        v.setImageViewBitmap(R.id.widget_cover, rounded(cover, s, px(context, coverDp.toFloat()), 14f * d))
        v.setImageViewBitmap(R.id.widget_play, playRing(s, px(context, if (large) 64f else 52f)))
        v.setOnClickPendingIntent(R.id.widget_play, mediaKey(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
        openApp(context)?.let { v.setOnClickPendingIntent(R.id.widget_root, it) }
        song(context, v, s)
        controls(context, v, s)
        val waveW = (if (large) wDp - 24 else wDp - 20 - coverDp - 10).coerceAtLeast(60)
        v.setImageViewBitmap(R.id.widget_wave, wave(s, px(context, waveW.toFloat()), px(context, if (large) 26f else 16f), d))
        if (large) {
            v.setViewVisibility(R.id.widget_lyric, if (s.lyric == null) View.GONE else View.VISIBLE)
            v.setTextViewText(R.id.widget_lyric, s.lyric ?: "")
            v.setTextColor(R.id.widget_lyric, if (s.graphite) s.text else s.accent)
        }
        return v
    }

    /** Letra: la línea que suena, grande, sobre la portada desenfocada. */
    private fun lyrics(context: Context, wDp: Int, hDp: Int): RemoteViews {
        val s = State(context)
        val v = RemoteViews(context.packageName, R.layout.kiji_widget_lyrics)
        val d = context.resources.displayMetrics.density
        val cover = loadCover(s.cover)
        v.setImageViewBitmap(R.id.widget_bg, background(s, cover, px(context, wDp.toFloat()), px(context, hDp.toFloat()), 24f * d, veil = if (s.paper) 0.8f else 0.62f))
        v.setImageViewBitmap(R.id.widget_cover, rounded(cover, s, px(context, 30f), 8f * d))
        song(context, v, s)
        v.setTextViewText(R.id.widget_lyric, s.lyric ?: context.getString(R.string.kiji_widget_no_lyrics))
        v.setTextColor(R.id.widget_lyric, if (s.lyric == null) s.muted else s.text)
        v.setImageViewBitmap(R.id.widget_play, playRing(s, px(context, 44f)))
        v.setOnClickPendingIntent(R.id.widget_play, mediaKey(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
        openApp(context)?.let { v.setOnClickPendingIntent(R.id.widget_root, it) }
        return v
    }

    /** Teatro: 🍅 y 🌹 grandes, con cuántos cayeron hoy, sobre el telón. */
    private fun theater(context: Context, wDp: Int, hDp: Int): RemoteViews {
        val s = State(context)
        val v = RemoteViews(context.packageName, R.layout.kiji_widget_theater)
        val d = context.resources.displayMetrics.density
        v.setImageViewBitmap(R.id.widget_bg, curtain(s, px(context, wDp.toFloat()), px(context, hDp.toFloat()), 24f * d))
        val label = if (s.graphite) s.text else s.gold
        v.setTextColor(R.id.widget_theater_title, label)
        v.setTextViewText(R.id.widget_tomato_count, "${s.tomatoesToday}")
        v.setTextViewText(R.id.widget_rose_count, "${s.rosesToday}")
        v.setTextColor(R.id.widget_tomato_count, Color.WHITE)
        v.setTextColor(R.id.widget_rose_count, Color.WHITE)
        v.setTextViewText(R.id.widget_title, s.title ?: context.getString(R.string.kiji_widget_idle))
        v.setTextColor(R.id.widget_title, Color.argb(220, 255, 255, 255))
        v.setOnClickPendingIntent(R.id.widget_tomato, action(context, ACTION_TOMATO))
        v.setOnClickPendingIntent(R.id.widget_rose, action(context, ACTION_ROSE))
        openApp(context)?.let { v.setOnClickPendingIntent(R.id.widget_root, it) }
        return v
    }

    /** Barra: el logo de onda de Kiji, la canción y play. */
    private fun bar(context: Context, wDp: Int, hDp: Int): RemoteViews {
        val s = State(context)
        val v = RemoteViews(context.packageName, R.layout.kiji_widget_bar)
        val d = context.resources.displayMetrics.density
        v.setImageViewBitmap(R.id.widget_bg, background(s, loadCover(s.cover), px(context, wDp.toFloat()), px(context, hDp.toFloat()), min(hDp / 2f, 28f) * d))
        v.setImageViewBitmap(R.id.widget_logo, logo(s, px(context, 30f)))
        song(context, v, s)
        v.setImageViewBitmap(R.id.widget_play, playRing(s, px(context, 44f)))
        v.setOnClickPendingIntent(R.id.widget_play, mediaKey(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
        openApp(context)?.let { v.setOnClickPendingIntent(R.id.widget_root, it) }
        return v
    }

    private fun song(context: Context, v: RemoteViews, s: State) {
        v.setTextViewText(R.id.widget_title, s.title ?: context.getString(R.string.kiji_widget_idle))
        v.setTextColor(R.id.widget_title, s.text)
        v.setTextViewText(R.id.widget_artist, s.artist ?: "")
        v.setTextColor(R.id.widget_artist, s.muted)
    }

    private fun controls(context: Context, v: RemoteViews, s: State) {
        v.setInt(R.id.widget_prev, "setColorFilter", s.text)
        v.setInt(R.id.widget_next, "setColorFilter", s.text)
        v.setOnClickPendingIntent(R.id.widget_prev, mediaKey(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS))
        v.setOnClickPendingIntent(R.id.widget_next, mediaKey(context, KeyEvent.KEYCODE_MEDIA_NEXT))
        v.setImageViewResource(R.id.widget_like, if (s.liked) R.drawable.kiji_widget_heart_filled else R.drawable.kiji_widget_heart)
        v.setInt(R.id.widget_like, "setColorFilter", if (s.liked) s.like else s.text)
        v.setOnClickPendingIntent(R.id.widget_like, action(context, ACTION_LIKE))
        v.setViewVisibility(R.id.widget_tomato, if (s.theater) View.VISIBLE else View.GONE)
        v.setOnClickPendingIntent(R.id.widget_tomato, action(context, ACTION_TOMATO))
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

    /** Fondo: la portada muy achicada y vuelta a agrandar (desenfoque), el velo del estilo y el borde. */
    private fun background(s: State, cover: Bitmap?, wPx: Int, hPx: Int, radius: Float, veil: Float? = null): Bitmap {
        val scale = 3
        val w = max(8, wPx / scale)
        val h = max(8, hPx / scale)
        val out = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(out)
        val r = radius / scale
        c.clipPath(Path().apply { addRoundRect(RectF(0f, 0f, w.toFloat(), h.toFloat()), r, r, Path.Direction.CW) })
        c.drawColor(s.background)
        if (cover != null) {
            val tiny = Bitmap.createScaledBitmap(cover, 12, 12, true)
            val paint = Paint(Paint.FILTER_BITMAP_FLAG).apply {
                if (s.graphite) colorFilter = ColorMatrixColorFilter(ColorMatrix().apply { setSaturation(0f) })
                alpha = if (s.paper) 70 else 255
            }
            c.drawBitmap(tiny, null, RectF(-w * 0.15f, -h * 0.15f, w * 1.15f, h * 1.15f), paint)
        }
        val v = veil ?: when {
            s.paper -> 0.78f
            s.graphite -> 0.62f
            else -> 0.50f
        }
        c.drawColor(Color.argb((v * 255).roundToInt(), Color.red(s.background), Color.green(s.background), Color.blue(s.background)))
        if (!s.graphite && !s.paper) {
            c.drawRect(0f, 0f, w.toFloat(), h.toFloat(), gradientPaint(s, 0f, 0f, w.toFloat(), h.toFloat()).apply { alpha = 46 })
        }
        val border = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 1.2f
            color = if (s.light) Color.argb(28, 0, 0, 0) else Color.argb(if (s.graphite) 46 else 30, 255, 255, 255)
        }
        c.drawRoundRect(RectF(0.5f, 0.5f, w - 0.5f, h - 0.5f), r, r, border)
        return out
    }

    /** El telón del widget Teatro: terciopelo con pliegues y la cenefa con flecos. */
    private fun curtain(s: State, wPx: Int, hPx: Int, radius: Float): Bitmap {
        val out = Bitmap.createBitmap(max(8, wPx), max(8, hPx), Bitmap.Config.ARGB_8888)
        val c = Canvas(out)
        val w = out.width.toFloat()
        val h = out.height.toFloat()
        c.clipPath(Path().apply { addRoundRect(RectF(0f, 0f, w, h), radius, radius, Path.Direction.CW) })
        val shadow = Color.rgb(Color.red(s.curtain) * 45 / 100, Color.green(s.curtain) * 45 / 100, Color.blue(s.curtain) * 45 / 100)
        val folds = IntArray(9) { if (it % 2 == 0) s.curtain else shadow }
        val stops = FloatArray(9) { it / 8f }
        c.drawRect(0f, 0f, w, h, Paint().apply { shader = LinearGradient(0f, 0f, w, 0f, folds, stops, Shader.TileMode.CLAMP) })
        // Sombra abajo, para que se lean los números.
        c.drawRect(0f, h * 0.55f, w, h, Paint().apply {
            shader = LinearGradient(0f, h * 0.55f, 0f, h, Color.argb(0, 0, 0, 0), Color.argb(150, 0, 0, 0), Shader.TileMode.CLAMP)
        })
        val valance = h * 0.13f
        c.drawRect(0f, 0f, w, valance, Paint().apply { color = shadow })
        val gold = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = if (s.graphite) s.text else s.gold }
        val step = w / 14
        for (k in 0 until 14) c.drawCircle(step * (k + 0.5f), valance, step * 0.24f, gold)
        c.drawRect(0f, valance - 2, w, valance, gold)
        return out
    }

    /** La portada cuadrada y redondeada; sin portada, el degradado del estilo con una nota. */
    private fun rounded(cover: Bitmap?, s: State, sizePx: Int, radius: Float): Bitmap {
        val out = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val c = Canvas(out)
        val rect = RectF(0f, 0f, sizePx.toFloat(), sizePx.toFloat())
        if (cover != null) {
            c.drawRoundRect(rect, radius, radius, coverPaint(cover, sizePx))
        } else {
            c.drawRoundRect(rect, radius, radius, gradientPaint(s, 0f, 0f, sizePx.toFloat(), sizePx.toFloat()))
            note(c, sizePx.toFloat(), s.onAccent)
        }
        return out
    }

    private fun coverPaint(cover: Bitmap, sizePx: Int): Paint {
        val side = min(cover.width, cover.height)
        val m = Matrix().apply {
            val k = sizePx.toFloat() / side
            setScale(k, k)
            postTranslate(-(cover.width - side) / 2f * k, -(cover.height - side) / 2f * k)
        }
        return Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply {
            shader = BitmapShader(cover, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP).apply { setLocalMatrix(m) }
        }
    }

    private fun note(c: Canvas, size: Float, color: Int) {
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color }
        val k = size / 100f
        c.drawCircle(40 * k, 66 * k, 10 * k, p)
        c.drawRect(47 * k, 30 * k, 52 * k, 66 * k, p)
        c.drawRect(47 * k, 30 * k, 66 * k, 36 * k, p)
    }

    /** Anillo: la portada en un círculo, la onda en rayos alrededor y play o pausa al centro. */
    private fun ringArt(s: State, cover: Bitmap?, sizePx: Int): Bitmap {
        val out = Bitmap.createBitmap(max(8, sizePx), max(8, sizePx), Bitmap.Config.ARGB_8888)
        val c = Canvas(out)
        val f = out.width.toFloat()
        val cx = f / 2
        val r = f * 0.31f
        // La onda alrededor: rayos finos, lo que ya sonó en el acento.
        val count = 60
        val rest = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(if (s.light) 70 else 90, Color.red(s.text), Color.green(s.text), Color.blue(s.text))
            strokeWidth = f * 0.018f
            strokeCap = Paint.Cap.ROUND
        }
        val played = gradientPaint(s, 0f, 0f, f, f).apply {
            strokeWidth = f * 0.018f
            strokeCap = Paint.Cap.ROUND
        }
        for (i in 0 until count) {
            val a = -PI / 2 + 2 * PI * i / count
            val v = s.bars[(i * s.bars.size / count).coerceIn(0, s.bars.size - 1)].coerceIn(0.15f, 1f)
            val r0 = r + f * 0.04f
            val r1 = r0 + f * 0.13f * v
            c.drawLine(
                (cx + cos(a) * r0).toFloat(), (cx + sin(a) * r0).toFloat(),
                (cx + cos(a) * r1).toFloat(), (cx + sin(a) * r1).toFloat(),
                if ((i + 0.5f) / count <= s.progress) played else rest,
            )
        }
        // La portada en el círculo.
        if (cover != null) {
            c.save()
            c.translate(cx - r, cx - r)
            c.drawCircle(r, r, r, coverPaint(cover, (r * 2).roundToInt()))
            c.restore()
        } else {
            c.drawCircle(cx, cx, r, gradientPaint(s, cx - r, cx - r, cx + r, cx + r))
        }
        // Play o pausa al centro, sobre un disco que deja ver la portada.
        c.drawCircle(cx, cx, r * 0.42f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(150, 0, 0, 0) })
        playIcon(c, cx, r * 0.42f, s.playing, Color.WHITE)
        return out
    }

    private fun playIcon(c: Canvas, center: Float, radius: Float, playing: Boolean, color: Int) {
        val icon = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color }
        val k = radius / 10f
        if (playing) {
            c.drawRoundRect(RectF(center - 4.2f * k, center - 4.6f * k, center - 1.3f * k, center + 4.6f * k), k, k, icon)
            c.drawRoundRect(RectF(center + 1.3f * k, center - 4.6f * k, center + 4.2f * k, center + 4.6f * k), k, k, icon)
        } else {
            c.drawPath(Path().apply {
                moveTo(center - 3.2f * k, center - 5f * k)
                lineTo(center + 5.2f * k, center)
                lineTo(center - 3.2f * k, center + 5f * k)
                close()
            }, icon)
        }
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
        val inner = f / 2 - stroke * 2.2f
        c.drawCircle(f / 2, f / 2, inner, if (s.graphite) Paint(Paint.ANTI_ALIAS_FLAG).apply { color = s.text } else gradientPaint(s, 0f, 0f, f, f))
        playIcon(c, f / 2, inner, s.playing, if (s.graphite) s.background else s.onAccent)
        return out
    }

    /** El logo de onda de Kiji: cinco barras redondeadas en el acento. */
    private fun logo(s: State, sizePx: Int): Bitmap {
        val out = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val c = Canvas(out)
        val f = sizePx.toFloat()
        val paint = gradientPaint(s, 0f, 0f, f, f)
        val heights = floatArrayOf(0.45f, 0.8f, 0.3f, 0.95f, 0.55f)
        val w = f / 9
        for (i in heights.indices) {
            val x = w * (1 + i * 1.6f)
            val h = f * heights[i]
            c.drawRoundRect(RectF(x, (f - h) / 2, x + w, (f + h) / 2), w / 2, w / 2, paint)
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

/** ❤️, 🍅 y 🌹 de los widgets. */
class KijiWidgetActions : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = when (intent.action) {
            KijiWidgets.ACTION_LIKE -> "like"
            KijiWidgets.ACTION_TOMATO -> "tomato"
            KijiWidgets.ACTION_ROSE -> "rose"
            else -> return
        }
        KijiWidgets.dispatch(context, action)
    }
}

/** La base de los cinco: se dibujan al ponerlos y al cambiarles el tamaño. */
abstract class KijiWidgetBase(private val kind: KijiWidgets.Kind) : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) KijiWidgets.update(context, manager, id, kind)
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, newOptions: Bundle) {
        KijiWidgets.update(context, manager, id, kind)
    }
}

/** Anillo (2x2). Conserva el nombre del widget chico de antes para no romper los ya puestos. */
class KijiWidgetSmall : KijiWidgetBase(KijiWidgets.Kind.RING)

/** Ahora suena (4x2, hasta 4x4). Conserva el nombre del widget grande de antes. */
class KijiWidgetLarge : KijiWidgetBase(KijiWidgets.Kind.NOW)

/** Letra (4x2). */
class KijiWidgetLyrics : KijiWidgetBase(KijiWidgets.Kind.LYRICS)

/** Teatro (2x2). */
class KijiWidgetTheater : KijiWidgetBase(KijiWidgets.Kind.THEATER)

/** Barra (4x1). */
class KijiWidgetBar : KijiWidgetBase(KijiWidgets.Kind.BAR)
