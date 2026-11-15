package io.github.kijiplayer.kiji

import android.media.audiofx.AudioEffect
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
    private var equalizer: Equalizer? = null
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
                "count" -> result.success(listOfNotNull(equalizer, bass, reverb).size)
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

    /** El ecualizador de la sesión, creado una sola vez; null si Android no lo pudo crear. */
    private fun equalizerFor(id: Int): Equalizer? {
        useSession(id)
        equalizer?.let { return it }
        return try {
            Equalizer(0, id).also {
                equalizer = it
                warned.remove("eq")
            }
        } catch (e: Exception) {
            warnOnce("eq", "el ecualizador no está disponible (la música suena sin él): ${e.javaClass.simpleName}")
            null
        }
    }

    /** Bandas del ecualizador del teléfono (Hz y dB); null si ahora no hay ecualizador. */
    private fun bands(id: Int): Map<String, Any>? {
        if (id == 0) return null
        val eq = equalizerFor(id) ?: return null
        return try {
            val range = eq.bandLevelRange
            mapOf(
                "centers" to (0 until eq.numberOfBands).map { eq.getCenterFreq(it.toShort()) / 1000.0 },
                "minDb" to range[0] / 100.0,
                "maxDb" to range[1] / 100.0,
            )
        } catch (e: Exception) {
            warnOnce("bands", "no se pudieron leer las bandas: ${e.javaClass.simpleName}")
            null
        }
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
                val bands = eq.numberOfBands.toInt()
                val range = eq.bandLevelRange
                for (i in 0 until minOf(bands, gains.size)) {
                    val level = (gains[i] * 100).toInt().coerceIn(range[0].toInt(), range[1].toInt())
                    eq.setBandLevel(i.toShort(), level.toShort())
                }
                eq.enabled = eqOn
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
        for (effect in listOfNotNull(equalizer, bass, reverb)) {
            try {
                effect.release()
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
