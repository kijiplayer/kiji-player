package io.github.kijiplayer.kiji

import android.media.audiofx.AudioEffect
import android.media.audiofx.DynamicsProcessing
import android.os.Build
import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.media.audiofx.PresetReverb
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Los efectos de "Sonido" (ecualizador, refuerzo de bajos y reverb), con los efectos de audio del
 * sistema, enganchados a la sesión de audio del reproductor de Kiji.
 *
 * Reglas (0.8.2: antes el ecualizador lo creaba just_audio al cargar cada canción y, si Android no
 * podía crearlo, ninguna canción sonaba hasta reiniciar la app):
 *  - un solo juego de efectos, el de la sesión actual: al cambiar de sesión se sueltan
 *    (`release()`) y se crean otra vez; también al cerrar el reproductor y al destruir el motor;
 *  - ningún efecto se usa sin comprobar que se creó;
 *  - si uno no se puede crear, la música suena igual, sin él: se registra una sola vez y Dart lo
 *    muestra suave en la pantalla de Sonido.
 */
object SoundEffects {
    private const val TAG = "Kiji"
    private var session = 0
    private var equalizer: Eq? = null
    private var bass: BassBoost? = null
    private var reverb: PresetReverb? = null

    /** Lo que ya se avisó en el registro (cada falla, una sola vez hasta que vuelva a andar). */
    private val warned = mutableSetOf<String>()

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "kiji/sound").setMethodCallHandler { call, result ->
            when (call.method) {
                "capabilities" -> result.success(capabilities())
                "bands" -> result.success(bands(call.argument<Int>("session") ?: 0))
                "apply" -> {
                    val id = call.argument<Int>("session") ?: 0
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val gains = call.argument<List<Double>>("gains") ?: emptyList()
                    val strength = call.argument<Double>("bass") ?: 0.0
                    val mode = call.argument<Int>("reverb") ?: 0
                    result.success(apply(id, enabled, gains, strength, mode))
                }
                "release" -> {
                    release()
                    result.success(null)
                }
                "count" -> result.success(listOfNotNull<Any>(equalizer, bass, reverb).size)
                else -> result.notImplemented()
            }
        }
    }

    private fun capabilities(): Map<String, Boolean> {
        val types = try {
            AudioEffect.queryEffects().map { it.type }
        } catch (e: Exception) {
            Log.w(TAG, "=== SONIDO: no se pudo listar los efectos: ${e.javaClass.simpleName} ===")
            emptyList()
        }
        return mapOf(
            "equalizer" to types.contains(AudioEffect.EFFECT_TYPE_EQUALIZER),
            "bass" to types.contains(AudioEffect.EFFECT_TYPE_BASS_BOOST),
            "reverb" to types.contains(AudioEffect.EFFECT_TYPE_PRESET_REVERB),
        )
    }

    private fun warnOnce(key: String, message: String) {
        if (warned.add(key)) Log.w(TAG, "=== SONIDO: $message ===")
    }

    private fun useSession(id: Int) {
        if (id == session) return
        release()
        session = id
    }

    /**
     * El ecualizador de la sesión, creado una sola vez; null si Android no lo pudo crear.
     * 0.9: 10 bandas con DynamicsProcessing (Android 9+), como en la PC. Si no se puede crear, el
     * ecualizador del sistema (las bandas que dé el teléfono, casi siempre 5), como antes.
     */
    private fun equalizerFor(id: Int): Eq? {
        useSession(id)
        equalizer?.let { return it }
        val tenBands = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                TenBandEq(id)
            } catch (e: Exception) {
                warnOnce("eq10", "sin el ecualizador de 10 bandas, se usa el del sistema: ${e.javaClass.simpleName}")
                null
            }
        } else null
        val eq = tenBands ?: try {
            SystemEq(Equalizer(0, id))
        } catch (e: Exception) {
            warnOnce("eq", "el ecualizador no está disponible (la música suena sin él): ${e.javaClass.simpleName}")
            return null
        }
        equalizer = eq
        warned.remove("eq")
        return eq
    }

    /** Bandas del ecualizador (Hz y dB); null si ahora no hay ecualizador. */
    private fun bands(id: Int): Map<String, Any>? {
        if (id == 0) return null
        val eq = equalizerFor(id) ?: return null
        return try {
            mapOf("centers" to eq.centers(), "minDb" to eq.minDb(), "maxDb" to eq.maxDb())
        } catch (e: Exception) {
            warnOnce("bands", "no se pudieron leer las bandas: ${e.javaClass.simpleName}")
            null
        }
    }

    /** Un ecualizador: el de 10 bandas o el del sistema. */
    private interface Eq {
        fun centers(): List<Double>
        fun minDb(): Double
        fun maxDb(): Double
        fun setGains(gains: List<Double>)
        fun setEnabled(on: Boolean)
        fun release()
    }

    private class SystemEq(private val eq: Equalizer) : Eq {
        override fun centers() = (0 until eq.numberOfBands).map { eq.getCenterFreq(it.toShort()) / 1000.0 }
        override fun minDb() = eq.bandLevelRange[0] / 100.0
        override fun maxDb() = eq.bandLevelRange[1] / 100.0
        override fun setGains(gains: List<Double>) {
            val range = eq.bandLevelRange
            for (i in 0 until minOf(eq.numberOfBands.toInt(), gains.size)) {
                val level = (gains[i] * 100).toInt().coerceIn(range[0].toInt(), range[1].toInt())
                eq.setBandLevel(i.toShort(), level.toShort())
            }
        }
        override fun setEnabled(on: Boolean) {
            eq.enabled = on
        }
        override fun release() = eq.release()
    }

    /** 10 bandas (las mismas que la PC y los presets), con el pre-ecualizador de DynamicsProcessing. */
    @android.annotation.TargetApi(Build.VERSION_CODES.P)
    private class TenBandEq(id: Int) : Eq {
        private val bands = listOf(31.0, 62.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0)
        private val effect: DynamicsProcessing

        init {
            val config = DynamicsProcessing.Config.Builder(
                DynamicsProcessing.VARIANT_FAVOR_FREQUENCY_RESOLUTION,
                2, // canales (estéreo)
                true, bands.size, // pre-ecualizador con 10 bandas
                false, 0, // sin compresor multibanda
                false, 0, // sin post-ecualizador
                false, // sin limitador
            ).build()
            effect = DynamicsProcessing(0, id, config)
            setGains(List(bands.size) { 0.0 })
        }

        /** Cada banda llega hasta la mitad (geométrica) del camino a la siguiente; la última, a 20 kHz. */
        private fun cutoff(i: Int): Float =
            if (i == bands.size - 1) 20000f else Math.sqrt(bands[i] * bands[i + 1]).toFloat()

        override fun centers() = bands
        override fun minDb() = -15.0
        override fun maxDb() = 15.0
        override fun setGains(gains: List<Double>) {
            for (i in bands.indices) {
                val db = gains.getOrElse(i) { 0.0 }.coerceIn(-15.0, 15.0).toFloat()
                effect.setPreEqBandAllChannelsTo(i, DynamicsProcessing.EqBand(true, cutoff(i), db))
            }
        }
        override fun setEnabled(on: Boolean) {
            effect.enabled = on
        }
        override fun release() = effect.release()
    }

    /** Devuelve qué quedó andando ("eq", "bass", "reverb"); con la sesión 0, nada. */
    private fun apply(id: Int, enabled: Boolean, gains: List<Double>, strength: Double, mode: Int): Map<String, Boolean> {
        if (id == 0) {
            release()
            return mapOf("eq" to false, "bass" to false, "reverb" to false)
        }
        useSession(id)
        val eqOn = enabled && gains.any { it != 0.0 }
        val eqOk = if (!eqOn && equalizer == null) true else try {
            val eq = equalizerFor(id)
            if (eq == null) false else {
                eq.setGains(gains)
                eq.setEnabled(eqOn)
                true
            }
        } catch (e: Exception) {
            warnOnce("eq-apply", "no se pudo aplicar el ecualizador: ${e.javaClass.simpleName}")
            false
        }
        val bassOn = enabled && strength > 0
        val bassOk = if (!bassOn && bass == null) true else try {
            val effect = bass ?: BassBoost(0, id).also { bass = it }
            if (effect.strengthSupported) effect.setStrength((strength.coerceIn(0.0, 1.0) * 1000).toInt().toShort())
            effect.enabled = bassOn
            warned.remove("bass")
            true
        } catch (e: Exception) {
            warnOnce("bass", "refuerzo de bajos no disponible: ${e.javaClass.simpleName}")
            false
        }
        val reverbOn = enabled && mode != 0
        val reverbOk = if (!reverbOn && reverb == null) true else try {
            val effect = reverb ?: PresetReverb(0, id).also { reverb = it }
            // Sala: una sala mediana. Estadio: un salón grande (el más amplio que da Android).
            effect.preset = if (mode == 2) PresetReverb.PRESET_LARGEHALL else PresetReverb.PRESET_MEDIUMROOM
            effect.enabled = reverbOn
            warned.remove("reverb")
            true
        } catch (e: Exception) {
            warnOnce("reverb", "reverb no disponible: ${e.javaClass.simpleName}")
            false
        }
        return mapOf("eq" to eqOk, "bass" to bassOk, "reverb" to reverbOk)
    }

    /** Suelta los tres efectos (cambio de sesión, reproductor cerrado o motor destruido). */
    fun release() {
        for (release in listOfNotNull(equalizer?.let { it::release }, bass?.let { it::release }, reverb?.let { it::release })) {
            try {
                release()
            } catch (e: Exception) {
                Log.w(TAG, "=== SONIDO: al soltar un efecto: ${e.javaClass.simpleName} ===")
            }
        }
        equalizer = null
        bass = null
        reverb = null
        session = 0
    }
}
