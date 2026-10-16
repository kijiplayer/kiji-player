package com.example.kiji_player

import android.os.StatFs
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// AudioServiceActivity (en vez de FlutterActivity) comparte el motor de Flutter con el
// servicio de audio, para que la música siga cuando se cierra la pantalla (Tarea C).
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Espacio libre en disco, para avisar antes de descargar (Tarea B).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kiji/storage")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "freeBytes" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("sin_ruta", "Falta la ruta", null)
                        } else {
                            try {
                                result.success(StatFs(path).availableBytes)
                            } catch (e: Exception) {
                                result.error("statfs", e.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
