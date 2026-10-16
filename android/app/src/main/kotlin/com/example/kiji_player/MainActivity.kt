package com.example.kiji_player

import android.content.Context
import android.database.ContentObserver
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
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

        // Volumen de la música del sistema (0 a 1), para "Pausar al silenciar" (Tarea K).
        // Solo se escucha mientras Dart está suscrito.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "kiji/volume")
            .setStreamHandler(object : EventChannel.StreamHandler {
                private var observer: ContentObserver? = null

                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    fun send() {
                        val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                        val now = audio.getStreamVolume(AudioManager.STREAM_MUSIC)
                        events.success(if (max > 0) now.toDouble() / max else 1.0)
                    }
                    val handler = object : ContentObserver(Handler(Looper.getMainLooper())) {
                        override fun onChange(selfChange: Boolean) = send()
                    }
                    contentResolver.registerContentObserver(Settings.System.CONTENT_URI, true, handler)
                    observer = handler
                    send()
                }

                override fun onCancel(arguments: Any?) {
                    observer?.let { contentResolver.unregisterContentObserver(it) }
                    observer = null
                }
            })
    }
}
