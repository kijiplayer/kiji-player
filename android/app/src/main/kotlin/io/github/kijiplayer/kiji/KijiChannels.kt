package io.github.kijiplayer.kiji

import android.app.ActivityManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.database.ContentObserver
import android.net.Uri
import android.os.PowerManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.hardware.display.DisplayManager
import android.media.AudioManager
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.view.Display
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.github.kijiplayer.kiji.extractor.ExtractorChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Canales que no necesitan pantalla. Los registra el plugin local `kiji_channels` en cada motor
 * de Flutter, también en el del servicio de audio cuando Kiji arranca desde los auriculares o la
 * notificación (antes vivían en MainActivity y ahí fallaban con MissingPluginException).
 */
object KijiChannels {
    @JvmStatic
    fun register(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext

        // Datos del equipo para el modo alto rendimiento. Sin pantalla no hay ventana para cambiar
        // la frecuencia: MainActivity reemplaza este canal al abrirse.
        MethodChannel(messenger, "kiji/display").setMethodCallHandler { call, result ->
            when (call.method) {
                "setHighRefreshRate" -> result.success(null)
                "deviceInfo" -> result.success(deviceInfo(app))
                else -> result.notImplemented()
            }
        }

        // Espacio libre en disco, para avisar antes de descargar.
        MethodChannel(messenger, "kiji/storage").setMethodCallHandler { call, result ->
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
                // Carpeta pública Documentos, para la copia de seguridad.
                "documentsDir" -> result.success(
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS).absolutePath
                )
                else -> result.notImplemented()
            }
        }

        // Optimización de batería: con ella, Android (y más Motorola y otras marcas) puede cortar la
        // música en segundo plano. Kiji lo explica y abre el pedido del sistema; nunca lo cambia sola.
        MethodChannel(messenger, "kiji/battery").setMethodCallHandler { call, result ->
            val power = app.getSystemService(Context.POWER_SERVICE) as PowerManager
            when (call.method) {
                "isIgnoring" -> result.success(power.isIgnoringBatteryOptimizations(app.packageName))
                "request" -> try {
                    val ask = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:${app.packageName}"))
                    try {
                        app.startActivity(ask.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    } catch (e: ActivityNotFoundException) {
                        // Algunas marcas no tienen el diálogo: la lista de apps de la batería.
                        app.startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    }
                    result.success(null)
                } catch (e: Exception) {
                    result.error("bateria", e.javaClass.simpleName, null)
                }
                else -> result.notImplemented()
            }
        }

        // Secretos cifrados con una clave AES-GCM del Android Keystore (clave de
        // Gemini). La clave nunca sale del Keystore; Dart guarda solo lo cifrado.
        MethodChannel(messenger, "kiji/secrets").setMethodCallHandler { call, result ->
            try {
                val data = call.argument<ByteArray>("data") ?: ByteArray(0)
                when (call.method) {
                    "encrypt" -> {
                        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                        cipher.init(Cipher.ENCRYPT_MODE, secretKey())
                        result.success(cipher.iv + cipher.doFinal(data))
                    }
                    "decrypt" -> {
                        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                        cipher.init(Cipher.DECRYPT_MODE, secretKey(), GCMParameterSpec(128, data.copyOfRange(0, 12)))
                        result.success(cipher.doFinal(data.copyOfRange(12, data.size)))
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("secretos", e.javaClass.simpleName, null)
            }
        }

        // Motor A de extracción: InnerTubeX (solo Android).
        ExtractorChannel.register(app, messenger)

        // Volumen del archivo para la onda en vivo (alto rendimiento).
        LoudnessAnalyzer.register(messenger)

        // Volumen de la música del sistema (0 a 1), para "Pausar al silenciar".
        // Solo se escucha mientras Dart está suscrito.
        EventChannel(messenger, "kiji/volume").setStreamHandler(object : EventChannel.StreamHandler {
            private var observer: ContentObserver? = null

            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                // Si quedaba un oyente de antes, se suelta primero (nunca dos a la vez).
                onCancel(null)
                val audio = app.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                fun send() {
                    val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    val now = audio.getStreamVolume(AudioManager.STREAM_MUSIC)
                    events.success(if (max > 0) now.toDouble() / max else 1.0)
                }
                val handler = object : ContentObserver(Handler(Looper.getMainLooper())) {
                    override fun onChange(selfChange: Boolean) = send()
                }
                app.contentResolver.registerContentObserver(Settings.System.CONTENT_URI, true, handler)
                observer = handler
                send()
            }

            // Se puede llamar dos veces (o sin haber escuchado): la segunda no hace nada.
            override fun onCancel(arguments: Any?) {
                val current = observer ?: return
                observer = null
                app.contentResolver.unregisterContentObserver(current)
            }
        })

        // Inclinación del teléfono (gravedad x/y, -1..1) para el reflejo del vidrio de Grafito. Los
        // sensores de movimiento no piden permiso. Solo se escucha mientras Dart está suscrito
        // (reproductor abierto, sonando y en primer plano), a ~30 por segundo.
        EventChannel(messenger, "kiji/tilt").setStreamHandler(object : EventChannel.StreamHandler {
            private var listener: SensorEventListener? = null

            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                // Si quedaba un oyente de antes, se suelta primero (nunca dos a la vez).
                onCancel(null)
                val sensors = app.getSystemService(Context.SENSOR_SERVICE) as SensorManager
                val sensor = sensors.getDefaultSensor(Sensor.TYPE_GRAVITY)
                    ?: sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
                if (sensor == null) {
                    events.endOfStream()
                    return
                }
                val handler = object : SensorEventListener {
                    override fun onSensorChanged(event: SensorEvent) {
                        val g = SensorManager.GRAVITY_EARTH
                        events.success(
                            doubleArrayOf(
                                (event.values[0] / g).toDouble().coerceIn(-1.0, 1.0),
                                (event.values[1] / g).toDouble().coerceIn(-1.0, 1.0),
                            )
                        )
                    }

                    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
                }
                sensors.registerListener(handler, sensor, 33_000, Handler(Looper.getMainLooper()))
                listener = handler
            }

            // Se puede llamar dos veces (o sin haber escuchado): la segunda no hace nada.
            override fun onCancel(arguments: Any?) {
                val current = listener ?: return
                listener = null
                (app.getSystemService(Context.SENSOR_SERVICE) as SensorManager).unregisterListener(current)
            }
        })
    }

    fun deviceInfo(context: Context, display: Display? = null): Map<String, Any> {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memory = ActivityManager.MemoryInfo().also { am.getMemoryInfo(it) }
        val shown = display
            ?: (context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager).getDisplay(Display.DEFAULT_DISPLAY)
        return mapOf(
            "totalRam" to memory.totalMem,
            "lowRam" to am.isLowRamDevice,
            "maxRefresh" to (shown?.supportedModes?.maxOfOrNull { it.refreshRate }?.toDouble() ?: 60.0),
        )
    }

    private fun secretKey(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getEntry("kiji_secrets", null) as? KeyStore.SecretKeyEntry)?.let { return it.secretKey }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder("kiji_secrets", KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build()
        )
        return generator.generateKey()
    }
}
