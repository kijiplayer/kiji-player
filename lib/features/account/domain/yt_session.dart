// l10n-ignore-file: textos técnicos (no se muestran en la interfaz).
// Inspirado en Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivos de referencia: ui/screens/LoginScreen.kt (qué guardar al iniciar sesión) e
// innertube/.../InnerTube.kt (encabezado `SAPISIDHASH`).

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// La sesión de YouTube Music del usuario (opcional). Se guarda SOLO cifrada en el dispositivo y
/// solo viaja a YouTube. Nunca se escribe en el registro: [toString] no muestra nada.
class YtSession {
  const YtSession({required this.cookie, this.visitorData, this.dataSyncId, this.name});

  /// Todas las cookies de music.youtube.com, como las manda el navegador.
  final String cookie;
  final String? visitorData;

  /// Identificador de la cuenta para `onBehalfOfUser`.
  final String? dataSyncId;

  /// Nombre de la cuenta (para mostrar en Configuración), si se pudo leer.
  final String? name;

  static const origin = 'https://music.youtube.com';

  Map<String, String> get cookies => {
        for (final part in cookie.split(';'))
          if (part.contains('=')) part.split('=').first.trim(): part.substring(part.indexOf('=') + 1).trim(),
      };

  /// Una sesión de verdad trae SAPISID (sin ella YouTube no reconoce la cuenta).
  bool get isValid => cookies.containsKey('SAPISID') || cookies.containsKey('__Secure-3PAPISID');

  /// Encabezados para un pedido con la cuenta (como el navegador): la cookie y
  /// `Authorization: SAPISIDHASH <segundos>_<sha1("<segundos> <SAPISID> <origen>")>`.
  Map<String, String> authHeaders({DateTime? now}) {
    final sapisid = cookies['SAPISID'] ?? cookies['__Secure-3PAPISID'];
    final seconds = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    return {
      'Cookie': cookie,
      if (sapisid != null)
        'Authorization': 'SAPISIDHASH ${seconds}_${sha1.convert(utf8.encode('$seconds $sapisid $origin'))}',
      'X-Goog-AuthUser': '0',
    };
  }

  Map<String, dynamic> toJson() => {
        'cookie': cookie,
        'visitorData': ?visitorData,
        'dataSyncId': ?dataSyncId,
        'name': ?name,
      };

  static YtSession? fromJson(Object? json) {
    if (json is! Map || json['cookie'] is! String) return null;
    return YtSession(
      cookie: json['cookie'] as String,
      visitorData: json['visitorData'] as String?,
      dataSyncId: json['dataSyncId'] as String?,
      name: json['name'] as String?,
    );
  }

  @override
  String toString() => 'YtSession(${name ?? 'cuenta'})';
}

/// La sesión activa, para los clientes que no viven en Riverpod (el motor B). La mantiene al día
/// [AccountNotifier].
abstract final class YtSessionHolder {
  static YtSession? current;
  static bool get signedIn => current != null;
}
