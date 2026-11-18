import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../utils/secret_store.dart';
import '../../settings/data/settings_store.dart';
import 'yt_sync.dart';
import '../domain/yt_session.dart';
import '../../../models/track.dart';

/// Qué dijo YouTube Music al comprobar una sesión.
enum SessionCheck {
  ok,

  /// 401/403 o "sin sesión": YouTube no la acepta.
  rejected,

  /// Sin conexión o sin respuesta: no se sabe.
  failed,
}

/// Nombre del secreto donde va la sesión (cifrado con el Keystore o DPAPI).
const ytSessionSecret = 'yt_session';

/// La cuenta de Google opcional (Configuración → Cuenta). Sin sesión, Kiji funciona igual.
class AccountNotifier extends Notifier<YtSession?> {
  AccountNotifier({SecretStore? secrets, MethodChannel? engineChannel})
      : _secrets = secrets ?? createSecretStore(),
        _engine = engineChannel ?? const MethodChannel('kiji/innertubex');

  final SecretStore _secrets;
  final MethodChannel _engine;
  final Completer<void> _loaded = Completer();

  Future<void> get loaded => _loaded.future;

  @override
  YtSession? build() {
    unawaited(Future.microtask(_load));
    return null;
  }

  Future<void> _load() async {
    try {
      final saved = YtSession.fromJson(jsonDecode(await _secrets.read(ytSessionSecret) ?? 'null'));
      if (saved != null) await _apply(saved);
    } catch (error) {
      // Nunca se registra el contenido: solo que no se pudo leer.
      debugPrint('=== CUENTA: no se pudo leer la sesión guardada (${error.runtimeType}) ===');
    } finally {
      if (!_loaded.isCompleted) _loaded.complete();
    }
  }

  /// ¿YouTube Music acepta [session]? Un pedido real y liviano: leer las playlists de la biblioteca
  /// (solo lectura). No guarda nada.
  Future<SessionCheck> check(YtSession session) async {
    if (!session.isValid) return SessionCheck.rejected;
    try {
      final page = await ref
          .read(ytAccountReaderProvider)
          .browse('FEmusic_liked_playlists', session)
          .timeout(const Duration(seconds: 20));
      if (isLoggedOutResponse(page)) return SessionCheck.rejected;
      return SessionCheck.ok;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      debugPrint('=== CUENTA: la comprobación de la sesión falló (${error.type.name} ${status ?? ''}) ===');
      return status == 401 || status == 403 ? SessionCheck.rejected : SessionCheck.failed;
    } catch (error) {
      debugPrint('=== CUENTA: la comprobación de la sesión falló (${error.runtimeType}) ===');
      return SessionCheck.failed;
    }
  }

  /// Guarda la sesión (cifrada, solo en el dispositivo) y la empieza a usar.
  Future<bool> signIn(YtSession session) async {
    if (!session.isValid) return false;
    final saved = await _secrets.write(ytSessionSecret, jsonEncode(session.toJson()));
    if (!saved) return false;
    await _apply(session);
    debugPrint('=== CUENTA: sesión iniciada ===');
    return true;
  }

  /// Borra todo: la sesión guardada, las cookies de la WebView y la sesión de los motores.
  Future<void> signOut() async {
    await _secrets.delete(ytSessionSecret);
    try {
      await CookieManager.instance().deleteAllCookies();
    } catch (error) {
      debugPrint('=== CUENTA: no se pudieron borrar las cookies de la WebView (${error.runtimeType}) ===');
    }
    await _apply(null);
    // Lo leído de la cuenta (Me gusta y playlists) también se borra y la sincronización se apaga:
    // sin sesión no queda nada de la cuenta en Kiji.
    try {
      await ref.read(ytSyncProvider.notifier).forget();
      if (ref.read(settingsProvider).ytSync) {
        await ref.read(settingsProvider.notifier).update((s) => s.copyWith(ytSync: false));
      }
    } catch (error) {
      debugPrint('=== CUENTA: no se pudo borrar lo leído de la cuenta (${error.runtimeType}) ===');
    }
    debugPrint('=== CUENTA: sesión cerrada y borrada ===');
  }

  Future<void> _apply(YtSession? session) async {
    YtSessionHolder.current = session;
    // Sesión nueva (o sin cuenta): vuelve a valer, aunque YouTube hubiera rechazado la anterior.
    YtSessionHolder.rejected = false;
    YtSessionHolder.streamRefused = false;
    state = session;
    // Motor A (InnerTubeX, Android) usa la misma sesión.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _engine.invokeMethod<void>('setSession', session == null
            ? null
            : {'cookie': session.cookie, 'visitorData': session.visitorData, 'dataSyncId': session.dataSyncId});
      } catch (error) {
        // Pruebas o plataforma sin el motor A: la cuenta sigue sirviendo para el motor B.
        debugPrint('=== CUENTA: el motor A no recibió la sesión (${error.runtimeType}) ===');
      }
    }
  }
}

final accountProvider = NotifierProvider<AccountNotifier, YtSession?>(AccountNotifier.new);

/// "Esta canción necesita una cuenta", para ofrecer (una por canción como mucho).
class AccountOffer {
  const AccountOffer({required this.track});
  final Track track;
  String get title => track.title;
}

final accountOfferProvider = StateProvider<AccountOffer?>((ref) => null);

/// Canciones por las que ya se preguntó en esta sesión de Kiji (nunca se insiste).
final askedForAccount = <String>{};

/// ¿YouTube rechazó la sesión? (Sigue a [YtSessionHolder.rejectedListenable]: la interfaz se
/// redibuja cuando cambia.)
final ytSessionRejectedProvider = NotifierProvider<_SessionRejectedNotifier, bool>(_SessionRejectedNotifier.new);

class _SessionRejectedNotifier extends Notifier<bool> {
  @override
  bool build() {
    void changed() => state = YtSessionHolder.rejected;
    YtSessionHolder.rejectedListenable.addListener(changed);
    ref.onDispose(() => YtSessionHolder.rejectedListenable.removeListener(changed));
    return YtSessionHolder.rejected;
  }
}
