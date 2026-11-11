package io.github.kijiplayer.kiji

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * La música del teléfono (MediaStore), sin plugins de terceros (reemplaza a on_audio_query).
 * Solo lee la lista con los datos que da el sistema; las etiquetas completas y las portadas las
 * lee Kiji de cada archivo (con caché). El permiso (READ_MEDIA_AUDIO) lo pide permission_handler.
 */
object MediaLibrary {
    private const val TAG = "KijiMusica"
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    @JvmStatic
    fun register(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        MethodChannel(messenger, "kiji/media").setMethodCallHandler { call, result ->
            when (call.method) {
                // En otro hilo: con miles de canciones la consulta tarda.
                "songs" -> worker.execute {
                    val songs = try {
                        songs(app)
                    } catch (e: Exception) {
                        Log.w(TAG, "No se pudo leer el MediaStore: ${e.javaClass.simpleName}")
                        null
                    }
                    main.post { if (songs == null) result.error("media", "no se pudo leer", null) else result.success(songs) }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun songs(context: Context): List<Map<String, Any?>> {
        val columns = mutableListOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.DATE_ADDED,
            MediaStore.Audio.Media.DATE_MODIFIED,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.TRACK,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.IS_MUSIC,
        )
        // El género está en la tabla de audio desde Android 11.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) columns.add(MediaStore.Audio.Media.GENRE)
        val out = ArrayList<Map<String, Any?>>()
        context.contentResolver.query(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            columns.toTypedArray(),
            null,
            null,
            "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC",
        )?.use { c ->
            fun str(name: String): String? = c.getColumnIndex(name).let { if (it < 0 || c.isNull(it)) null else c.getString(it) }
            fun long(name: String): Long? = c.getColumnIndex(name).let { if (it < 0 || c.isNull(it)) null else c.getLong(it) }
            while (c.moveToNext()) {
                val data = str(MediaStore.Audio.Media.DATA) ?: continue
                out.add(
                    mapOf(
                        "id" to long(MediaStore.Audio.Media._ID),
                        "data" to data,
                        "size" to long(MediaStore.Audio.Media.SIZE),
                        "dateAdded" to long(MediaStore.Audio.Media.DATE_ADDED),
                        "dateModified" to long(MediaStore.Audio.Media.DATE_MODIFIED),
                        "title" to str(MediaStore.Audio.Media.TITLE),
                        "artist" to str(MediaStore.Audio.Media.ARTIST),
                        "album" to str(MediaStore.Audio.Media.ALBUM),
                        "track" to long(MediaStore.Audio.Media.TRACK),
                        "duration" to long(MediaStore.Audio.Media.DURATION),
                        "isMusic" to (long(MediaStore.Audio.Media.IS_MUSIC)?.let { it != 0L }),
                        "genre" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) str(MediaStore.Audio.Media.GENRE) else null,
                    ),
                )
            }
        }
        Log.i(TAG, "${out.size} canciones en el MediaStore")
        return out
    }
}
