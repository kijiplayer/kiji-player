package io.github.kijiplayer.kiji

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger

/**
 * Sabor "play" (Google Play, base de la 1.0): sin actualizador propio. Las actualizaciones las da
 * la tienda; este APK no instala apps ni registra el canal de actualizaciones (la Kiji completa usa
 * src/storeFull/.../AppUpdater.kt).
 */
object AppUpdater {
    @Suppress("UNUSED_PARAMETER")
    fun register(context: Context, messenger: BinaryMessenger) = Unit
}