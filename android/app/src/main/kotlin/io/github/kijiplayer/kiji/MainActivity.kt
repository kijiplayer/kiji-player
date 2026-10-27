package io.github.kijiplayer.kiji

import android.app.ActivityManager
import android.content.Context
import android.database.ContentObserver
import android.media.AudioManager
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import io.github.kijiplayer.kiji.extractor.ExtractorChannel
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

// AudioServiceActivity (en vez de FlutterActivity) comparte el motor de Flutter con el
// servicio de audio, para que la música siga cuando se cierra la pantalla.
class MainActivity : AudioServiceActivity() {
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Modo alto rendimiento: la pantalla a su frecuencia más alta (120/144 Hz) y datos del
        // equipo para sugerir dejarlo apagado en los de gama baja.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kiji/display")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setHighRefreshRate" -> {
                        val on = call.arguments as? Boolean ?: false
                        @Suppress("DEPRECATION")
                        val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display else windowManager.defaultDisplay
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
                    "deviceInfo" -> {
                        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        val memory = ActivityManager.MemoryInfo().also { am.getMemoryInfo(it) }
                        @Suppress("DEPRECATION")
                        val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display else windowManager.defaultDisplay
                        result.success(
                            mapOf(
                                "totalRam" to memory.totalMem,
                                "lowRam" to am.isLowRamDevice,
                                "maxRefresh" to (display?.supportedModes?.maxOfOrNull { it.refreshRate }?.toDouble() ?: 60.0),
                            )
                        )
                    }
                    else -> result.notImplemented()
                }
            }

        // Espacio libre en disco, para avisar antes de descargar.
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
                    // Carpeta pública Documentos, para la copia de seguridad.
                    "documentsDir" -> result.success(
                        Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS).absolutePath
                    )
                    else -> result.notImplemented()
                }
            }

        // Secretos cifrados con una clave AES-GCM del Android Keystore (clave de
        // Gemini). La clave nunca sale del Keystore; Dart guarda solo lo cifrado.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kiji/secrets")
            .setMethodCallHandler { call, result ->
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
        ExtractorChannel.register(this, flutterEngine.dartExecutor.binaryMessenger)

        // Volumen de la música del sistema (0 a 1), para "Pausar al silenciar".
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
