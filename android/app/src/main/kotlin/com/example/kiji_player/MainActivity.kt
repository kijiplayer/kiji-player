package com.example.kiji_player

import android.content.Context
import android.database.ContentObserver
import android.media.AudioManager
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
import com.example.kiji_player.extractor.ExtractorChannel
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

// AudioServiceActivity (en vez de FlutterActivity) comparte el motor de Flutter con el
// servicio de audio, para que la música siga cuando se cierra la pantalla (Tarea C).
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
                    // Carpeta pública Documentos, para la copia de seguridad (Tarea U).
                    "documentsDir" -> result.success(
                        Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS).absolutePath
                    )
                    else -> result.notImplemented()
                }
            }

        // Secretos cifrados con una clave AES-GCM del Android Keystore (Tarea Z4: clave de
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

        // Motor A de extracción: InnerTubeX (Tarea Z8, solo Android).
        ExtractorChannel.register(this, flutterEngine.dartExecutor.binaryMessenger)

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
