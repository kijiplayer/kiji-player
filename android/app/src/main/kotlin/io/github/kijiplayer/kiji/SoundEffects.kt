package io.github.kijiplayer.kiji

import android.media.audiofx.AudioEffect
import android.media.audiofx.BassBoost
import android.media.audiofx.PresetReverb
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Refuerzo de bajos y reverb de "Sonido", con los efectos de audio del sistema (el ecualizador
 * lo maneja just_audio). Se enganchan a la sesión de audio del reproductor de Kiji; si la sesión
 * cambia, se sueltan y se crean otra vez. Lo que el teléfono no tenga se informa en
 * `capabilities` y Kiji no lo muestra.
 */
object SoundEffects {
    private const val TAG = "Kiji"
    private var session = 0
    private var bass: BassBoost? = null
    private var reverb: PresetReverb? = null

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "kiji/sound").setMethodCallHandler { call, result ->
            when (call.method) {
                "capabilities" -> result.success(capabilities())
                "apply" -> {
                    val id = call.argument<Int>("session") ?: 0
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val strength = call.argument<Double>("bass") ?: 0.0
                    val mode = call.argument<Int>("reverb") ?: 0
                    result.success(apply(id, enabled, strength, mode))
                }
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
            "bass" to types.contains(AudioEffect.EFFECT_TYPE_BASS_BOOST),
            "reverb" to types.contains(AudioEffect.EFFECT_TYPE_PRESET_REVERB),
        )
    }

    /** Devuelve qué quedó andando (para el registro). */
    private fun apply(id: Int, enabled: Boolean, strength: Double, mode: Int): Map<String, Boolean> {
        if (id == 0) return mapOf("bass" to false, "reverb" to false)
        if (id != session) {
            release()
            session = id
        }
        val bassOn = enabled && strength > 0
        val bassOk = try {
            if (bassOn || bass != null) {
                val effect = bass ?: BassBoost(0, id).also { bass = it }
                if (effect.strengthSupported) effect.setStrength((strength.coerceIn(0.0, 1.0) * 1000).toInt().toShort())
                effect.enabled = bassOn
            }
            true
        } catch (e: Exception) {
            Log.w(TAG, "=== SONIDO: refuerzo de bajos no disponible: ${e.javaClass.simpleName} ===")
            bass = null
            false
        }
        val reverbOn = enabled && mode != 0
        val reverbOk = try {
            if (reverbOn || reverb != null) {
                val effect = reverb ?: PresetReverb(0, id).also { reverb = it }
                // Sala: una sala mediana. Estadio: un salón grande (el más amplio que da Android).
                effect.preset = if (mode == 2) PresetReverb.PRESET_LARGEHALL else PresetReverb.PRESET_MEDIUMROOM
                effect.enabled = reverbOn
            }
            true
        } catch (e: Exception) {
            Log.w(TAG, "=== SONIDO: reverb no disponible: ${e.javaClass.simpleName} ===")
            reverb = null
            false
        }
        return mapOf("bass" to bassOk, "reverb" to reverbOk)
    }

    private fun release() {
        try {
            bass?.release()
            reverb?.release()
        } catch (e: Exception) {
            Log.w(TAG, "=== SONIDO: al soltar los efectos: ${e.javaClass.simpleName} ===")
        }
        bass = null
        reverb = null
    }
}
