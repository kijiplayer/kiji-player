package io.github.kijiplayer.kiji

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

/**
 * "Actualizar" desde Kiji (0.8.4): la arquitectura del teléfono, el permiso de instalar apps, el
 * certificado del APK bajado comparado con el de la app instalada y el instalador del sistema.
 * El APK se comparte con el instalador por un FileProvider propio, solo la carpeta `cache/updates`.
 */
object AppUpdater {
    private const val TAG = "Kiji"

    fun register(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        MethodChannel(messenger, "kiji/update").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "abis" -> result.success(Build.SUPPORTED_ABIS.toList())
                    "canInstall" -> result.success(canInstall(app))
                    "openInstallPermission" -> {
                        openInstallPermission(app)
                        result.success(null)
                    }
                    "sameSigner" -> result.success(sameSigner(app, call.arguments as String))
                    "install" -> {
                        install(app, call.arguments as String)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                Log.w(TAG, "=== ACTUALIZAR: ${call.method} falló: ${e.javaClass.simpleName} ===")
                result.error("update", e.javaClass.simpleName, null)
            }
        }
    }

    private fun canInstall(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || context.packageManager.canRequestPackageInstalls()

    private fun openInstallPermission(context: Context) {
        val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${context.packageName}"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(intent)
        } catch (e: ActivityNotFoundException) {
            // Algunos teléfonos no tienen la pantalla de esta app: la lista general.
            context.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }

    /** SHA-256 de los certificados con que está firmado un paquete. */
    @Suppress("DEPRECATION")
    private fun signers(info: PackageInfo?): Set<String> {
        if (info == null) return emptySet()
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signing = info.signingInfo ?: return emptySet()
            if (signing.hasMultipleSigners()) signing.apkContentsSigners else signing.signingCertificateHistory
        } else {
            info.signatures
        } ?: return emptySet()
        val digest = MessageDigest.getInstance("SHA-256")
        return signatures.map { sig -> digest.digest(sig.toByteArray()).joinToString("") { "%02x".format(it) } }.toSet()
    }

    /** El APK es de Kiji (mismo paquete) y lo firmó el mismo certificado que la app instalada. */
    @Suppress("DEPRECATION")
    private fun sameSigner(context: Context, path: String): Boolean {
        val pm = context.packageManager
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
        val archive = pm.getPackageArchiveInfo(path, flags)
        if (archive == null || archive.packageName != context.packageName) {
            Log.w(TAG, "=== ACTUALIZAR: el APK no es de este paquete ===")
            return false
        }
        val installed = signers(pm.getPackageInfo(context.packageName, flags))
        // Exactamente los mismos certificados (Kiji nunca rotó su clave; si un día lo hace, esto se
        // revisa junto con la rotación).
        val downloaded = signers(archive)
        val same = downloaded.isNotEmpty() && downloaded == installed
        Log.i(TAG, "=== ACTUALIZAR: certificado ${if (same) "igual" else "DISTINTO"} ===")
        return same
    }

    private fun install(context: Context, path: String) {
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.updates", File(path))
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, "application/vnd.android.package-archive")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
        Log.i(TAG, "=== ACTUALIZAR: instalador del sistema abierto ===")
    }
}
