package io.github.kijiplayer.kiji

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteOrder
import java.util.concurrent.Executors
import kotlin.math.log10
import kotlin.math.sqrt

/**
 * Volumen de un archivo de audio del dispositivo (canal `kiji/loudness`), para la onda en vivo del
 * modo alto rendimiento. Decodifica el archivo con MediaCodec: no usa el micrófono ni el
 * Visualizer (que pide ese permiso). Devuelve un valor por cada `stepMs` ms, de 0 a 255
 * (de −60 dBFS a 0 dBFS de RMS), igual que `envelopeFromPcm16` en Dart.
 */
object LoudnessAnalyzer {
    private const val TAG = "KijiOnda"
    private const val DECIMATION = 4

    // Un archivo por vez y fuera del hilo principal.
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "kiji/loudness").setMethodCallHandler { call, result ->
            if (call.method != "analyze") return@setMethodCallHandler result.notImplemented()
            val path = call.argument<String>("path") ?: return@setMethodCallHandler result.error("args", "sin ruta", null)
            val stepMs = call.argument<Int>("stepMs") ?: 40
            worker.execute {
                try {
                    val levels = analyze(path, stepMs)
                    main.post { result.success(levels) }
                } catch (e: Exception) {
                    Log.w(TAG, "No se pudo analizar el volumen: ${e.javaClass.simpleName} ${e.message}")
                    main.post { result.error("onda", "${e.javaClass.simpleName}: ${e.message}", null) }
                }
            }
        }
    }

    private fun analyze(path: String, stepMs: Int): ByteArray {
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        try {
            extractor.setDataSource(path)
            val track = (0 until extractor.trackCount).firstOrNull {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
            } ?: error("sin pista de audio")
            extractor.selectTrack(track)
            val format = extractor.getTrackFormat(track)
            codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
            codec.configure(format, null, null, 0)
            codec.start()

            var sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            val out = java.io.ByteArrayOutputStream()
            var window = sampleRate * stepMs / 1000
            var sum = 0.0
            var count = 0
            val info = MediaCodec.BufferInfo()
            var inputDone = false
            var outputDone = false
            while (!outputDone) {
                // Se llenan todas las entradas libres sin esperar: el decodificador nunca queda ocioso.
                while (!inputDone) {
                    val index = codec.dequeueInputBuffer(0)
                    if (index < 0) break
                    val size = extractor.readSampleData(codec.getInputBuffer(index)!!, 0)
                    if (size < 0) {
                        codec.queueInputBuffer(index, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        inputDone = true
                    } else {
                        codec.queueInputBuffer(index, 0, size, extractor.sampleTime, 0)
                        extractor.advance()
                    }
                }
                val index = codec.dequeueOutputBuffer(info, 2_000)
                when {
                    index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        sampleRate = codec.outputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        channels = codec.outputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                        window = sampleRate * stepMs / 1000
                    }
                    index >= 0 -> {
                        // PCM de 16 bits (lo de siempre de MediaCodec): se mezclan los canales. Para el
                        // volumen alcanza con 1 de cada 4 muestras (4 veces menos trabajo).
                        val pcm = codec.getOutputBuffer(index)!!.order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
                        val end = (info.offset + info.size) / 2
                        var at = info.offset / 2
                        while (at + channels <= end) {
                            var mono = 0.0
                            for (c in 0 until channels) mono += pcm.get(at + c) / 32768.0
                            mono /= channels
                            sum += mono * mono
                            at += channels * DECIMATION
                            count += DECIMATION
                            if (count >= window) {
                                out.write(levelByte(sqrt(sum * DECIMATION / count)))
                                sum = 0.0
                                count = 0
                            }
                        }
                        codec.releaseOutputBuffer(index, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true
                    }
                }
            }
            return out.toByteArray()
        } finally {
            runCatching { codec?.stop() }
            runCatching { codec?.release() }
            extractor.release()
        }
    }

    private fun levelByte(rms: Double): Int {
        if (rms <= 0) return 0
        val db = 20 * log10(rms)
        return (((db + 60) / 60).coerceIn(0.0, 1.0) * 255).toInt()
    }
}
