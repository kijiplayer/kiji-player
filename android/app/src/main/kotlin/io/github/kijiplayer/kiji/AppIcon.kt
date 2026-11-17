package io.github.kijiplayer.kiji

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * "Ícono a juego con el estilo" (0.8.3): cada variante es un `activity-alias` del manifiesto con
 * su ícono (mismo logo de onda, colores del estilo). Se prende uno y se apagan los demás; ".MainActivity"
 * es el de siempre. Dart lo pide solo al salir de Kiji y sin música sonando (en algunos teléfonos el
 * lanzador cierra la app un momento al cambiar el ícono).
 */
object AppIcon {
    private const val TAG = "Kiji"

    /** variante → nombre del alias (sin el paquete). */
    private val aliases = linkedMapOf(
        "default" to "MainActivity",
        "nocturne" to "IconNocturne",
        "aurora" to "IconAurora",
        "ember" to "IconEmber",
        "mint" to "IconMint",
        "ocean" to "IconOcean",
        "graphite" to "IconGraphite",
        "paper" to "IconPaper",
    )

    fun register(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        MethodChannel(messenger, "kiji/icon").setMethodCallHandler { call, result ->
            when (call.method) {
                "current" -> result.success(current(app))
                "apply" -> result.success(apply(app, call.arguments as? String ?: "default"))
                else -> result.notImplemented()
            }
        }
    }

    private fun component(context: Context, alias: String) =
        ComponentName(context.packageName, "io.github.kijiplayer.kiji.$alias")

    private fun enabled(context: Context, alias: String): Boolean {
        val state = context.packageManager.getComponentEnabledSetting(component(context, alias))
        // "Por defecto" es lo que dice el manifiesto: solo ".MainActivity" viene prendido.
        return when (state) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> alias == "MainActivity"
            else -> false
        }
    }

    /** La variante prendida ahora ("default" si es la de siempre). */
    fun current(context: Context): String =
        aliases.entries.firstOrNull { enabled(context, it.value) }?.key ?: "default"

    /** Prende [variant] y apaga las demás. Primero prende (nunca queda Kiji sin ícono). */
    fun apply(context: Context, variant: String): Boolean {
        val target = aliases[variant] ?: aliases.getValue("default")
        return try {
            val pm = context.packageManager
            // Solo se saltea si el alias pedido está prendido de verdad y es el único: si no hay
            // ninguno prendido (estado raro, p. ej. tras instalar una versión vieja), se arregla.
            val on = aliases.values.filter { enabled(context, it) }
            if (on == listOf(target)) return true
            pm.setComponentEnabledSetting(
                component(context, target),
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP,
            )
            for (alias in aliases.values) {
                if (alias == target) continue
                pm.setComponentEnabledSetting(
                    component(context, alias),
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP,
                )
            }
            Log.i(TAG, "=== ICONO: ahora $variant ===")
            true
        } catch (e: Exception) {
            Log.w(TAG, "=== ICONO: no se pudo cambiar a $variant: ${e.javaClass.simpleName} ===")
            false
        }
    }
}
