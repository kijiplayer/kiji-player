import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../utils/secret_store.dart';
import '../domain/yt_session.dart';
import '../../../models/track.dart';

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
    debugPrint('=== CUENTA: sesión cerrada y borrada ===');
  }

  Future<void> _apply(YtSession? session) async {
    YtSessionHolder.current = session;
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

/// "Esta canción necesita una cuenta" pendiente de ofrecer (una por canción como mucho).
class AccountOffer {
  const AccountOffer({required this.track});
  final Track track;
  String get title => track.title;
}

final accountOfferProvider = StateProvider<AccountOffer?>((ref) => null);

/// Canciones por las que ya se preguntó en esta sesión de Kiji (nunca se insiste).
final askedForAccount = <String>{};
