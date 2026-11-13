package io.github.kijiplayer.kiji

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Shader
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import java.io.File
import kotlin.math.roundToInt

/**
 * Solo Kiji Dev: dibuja los widgets (los mismos RemoteViews que ve el lanzador) en imágenes, para
 * las capturas de las pruebas, sin tocar la pantalla de inicio ni otras apps.
 *
 *   adb shell am broadcast -n io.github.kijiplayer.kiji.dev/io.github.kijiplayer.kiji.WidgetPreviewReceiver --ez on true
 *     → Kiji manda el estado como si hubiera un widget puesto.
 *   adb shell am broadcast -n ... --ez render true
 *     → files/widget-previews/<estilo>-<widget>.png (anillo, ahora suena, letra, teatro y barra).
 *   adb shell am broadcast -n ... --ez on false
 */
class WidgetPreviewReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.hasExtra("on")) {
            KijiWidgets.previewOn = intent.getBooleanExtra("on", false)
            if (KijiWidgets.previewOn) KijiWidgets.askRefresh()
            Log.i(TAG, "Vista previa: ${KijiWidgets.previewOn}")
        }
        if (intent.getBooleanExtra("render", false)) render(context)
    }

    private fun render(context: Context) {
        val style = context.getSharedPreferences("kiji_widgets", Context.MODE_PRIVATE).getString("style", "nocturne")
        val dir = File(context.filesDir, "widget-previews").apply { mkdirs() }
        val d = context.resources.displayMetrics.density
        // Los cinco, en tamaños típicos de un lanzador de 4 o 5 columnas (dp).
        val all = listOf(
            Triple("anillo", KijiWidgets.Kind.RING, 150 to 150),
            Triple("ahora-suena", KijiWidgets.Kind.NOW, 320 to 150),
            Triple("ahora-suena-grande", KijiWidgets.Kind.NOW, 320 to 330),
            Triple("letra", KijiWidgets.Kind.LYRICS, 320 to 150),
            Triple("teatro", KijiWidgets.Kind.THEATER, 150 to 150),
            Triple("barra", KijiWidgets.Kind.BAR, 320 to 64),
        )
        for ((name, kind, size) in all) {
            val (wDp, hDp) = size
            val w = (wDp * d).roundToInt()
            val h = (hDp * d).roundToInt()
            val margin = (16 * d).roundToInt()
            val views = KijiWidgets.views(context, kind, wDp, hDp)
            val host = FrameLayout(context)
            val view = views.apply(context, host)
            view.measure(View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY), View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY))
            view.layout(0, 0, w, h)
            val out = Bitmap.createBitmap(w + margin * 2, h + margin * 2, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(out)
            // Un fondo de pantalla neutro (degradado gris), como el de un teléfono.
            canvas.drawRect(0f, 0f, out.width.toFloat(), out.height.toFloat(), Paint().apply {
                shader = LinearGradient(0f, 0f, out.width.toFloat(), out.height.toFloat(), 0xFF3B4252.toInt(), 0xFF1C2028.toInt(), Shader.TileMode.CLAMP)
            })
            canvas.translate(margin.toFloat(), margin.toFloat())
            view.draw(canvas)
            File(dir, "$style-$name.png").outputStream().use { out.compress(Bitmap.CompressFormat.PNG, 100, it) }
        }
        Log.i(TAG, "Vista previa guardada ($style)")
    }

    companion object {
        private const val TAG = "KijiWidgets"
    }
}
