package io.github.kijiplayer.kiji.channels;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;

/**
 * Flutter registra este plugin en cada motor, también en el que crea audio_service cuando Kiji
 * arranca desde los auriculares o la notificación, sin pantalla (ahí MainActivity no corre).
 * Los canales viven en la app (`io.github.kijiplayer.kiji.KijiChannels`): se llaman por nombre
 * para que este paquete no dependa de ella.
 */
public class KijiChannelsPlugin implements FlutterPlugin {
    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        try {
            Class.forName("io.github.kijiplayer.kiji.KijiChannels")
                    .getMethod("register", Context.class, BinaryMessenger.class)
                    .invoke(null, binding.getApplicationContext(), binding.getBinaryMessenger());
        } catch (Exception e) {
            Log.e("Kiji", "=== CANALES: no se pudieron registrar ===", e);
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {}
}
