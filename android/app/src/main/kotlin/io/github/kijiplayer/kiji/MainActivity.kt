package io.github.kijiplayer.kiji

import android.os.Build
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// AudioServiceActivity (en vez de FlutterActivity) comparte el motor de Flutter con el
// servicio de audio, para que la música siga cuando se cierra la pantalla.
// Los demás canales están en KijiChannels (sirven también sin pantalla).
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Modo alto rendimiento: la pantalla a su frecuencia más alta (120/144 Hz) y datos del
        // equipo para sugerir dejarlo apagado en los de gama baja. Reemplaza la versión sin
        // ventana de KijiChannels.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kiji/display")
            .setMethodCallHandler { call, result ->
                @Suppress("DEPRECATION")
                val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display else windowManager.defaultDisplay
                when (call.method) {
                    "setHighRefreshRate" -> {
                        val on = call.arguments as? Boolean ?: false
                        val current = display?.mode
                        val best = display?.supportedModes
                            ?.filter { it.physicalWidth == current?.physicalWidth && it.physicalHeight == current?.physicalHeight }
                            ?.maxByOrNull { it.refreshRate }
                        val params = window.attributes
                        // 0 = lo que decida el sistema (como siempre).
                        params.preferredDisplayModeId = if (on && best != null) best.modeId else 0
                        window.attributes = params
                        result.success((if (on) best?.refreshRate else current?.refreshRate)?.toDouble())
                    }
                    "deviceInfo" -> result.success(KijiChannels.deviceInfo(this, display))
                    else -> result.notImplemented()
                }
            }
    }
}
