// Adaptado de Echo Music (https://github.com/EchoMusicApp/Echo-Music), GPL-3.0.
// Archivos originales: innertube/src/main/kotlin/com/music/innertube/models/YouTubeClient.kt
// (versiones y datos de cada cliente) y app/.../utils/YTPlayerUtils.kt
// (`STREAM_FALLBACK_CLIENTS`: el orden de respaldo).

/// Una "forma" de pedir el audio a YouTube: qué app dice ser Kiji al pedirlo.
class YtPlayerClient {
  const YtPlayerClient({
    required this.label,
    required this.name,
    required this.id,
    required this.version,
    required this.userAgent,
    this.osName,
    this.osVersion,
    this.deviceMake,
    this.deviceModel,
    this.androidSdkVersion,
    this.host = 'music.youtube.com',
    this.needsPlayerScript = false,
    this.usesPoToken = false,
    this.playerSessionToken = false,
    this.useHls = false,
    this.embedded = false,
    this.retired,
    this.note,
  });

  /// Nombre que se ve en la Salud del Extractor y se guarda en el registro.
  final String label;
  final String name;
  final String id;
  final String version;
  final String userAgent;
  final String? osName;
  final String? osVersion;
  final String? deviceMake;
  final String? deviceModel;
  final int? androidSdkVersion;

  /// Servidor al que se pide `/player` (los clientes web van a www).
  final String host;

  /// Necesita el `signatureTimestamp` del reproductor y descifrar la firma y
  /// el parámetro `n` con el solver de yt-dlp (los formatos vienen cifrados).
  final bool needsPlayerScript;

  /// Manda un PO token (BotGuard) en el pedido y en la URL del audio.
  final bool usesPoToken;

  /// Manda también un PO token ligado a la sesión en el pedido `/player` (TVHTML5_SIMPLY lo
  /// exige; WEB_REMIX no). El de la URL siempre va ligado al video (Tarea Z8).
  final bool playerSessionToken;

  /// Usa la lista HLS (segmentos chicos) en vez del archivo entero.
  final bool useHls;

  /// Reproductor "incrustado" (como en otra página): pide primero la página
  /// `embed` para usar SU visitorData y sus `encryptedHostFlags` (Tarea Z8).
  final bool embedded;

  /// Si no es null, la forma está retirada de la cadena automática y dice por
  /// qué (Tarea Z8, medido con InnerTubeX). Se ve en "Formas retiradas".
  final String? retired;

  bool get isRetired => retired != null;

  /// Para qué está en la lista (se muestra en la Salud del Extractor).
  final String? note;

  Map<String, dynamic> context(String? visitorData) => {
        'clientName': name,
        'clientVersion': version,
        'osName': ?osName,
        'osVersion': ?osVersion,
        'deviceMake': ?deviceMake,
        'deviceModel': ?deviceModel,
        'androidSdkVersion': ?androidSdkVersion,
        'hl': 'es',
        'gl': 'US',
        'visitorData': ?visitorData,
      };
}

const safariUserAgent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 '
    '(KHTML, like Gecko) Version/18.0 Safari/605.1.15';
const _cobaltUserAgent = 'Mozilla/5.0 (ChromiumStylePlatform) Cobalt/Version';
const chromeUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36';
const firefoxUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0';

/// Orden en que Kiji prueba las formas: primero las que funcionan hoy (medido
/// el 16/10/2026 con 20 canciones en un celular Android y en Windows, ver
/// Tarea Z1) y al final las que fallan, por si YouTube
/// vuelve a habilitarlas. Las de respaldo de Echo (`STREAM_FALLBACK_CLIENTS`:
/// VISIONOS, ANDROID_VR 1.65.10, TVHTML5, ANDROID_VR 1.43.32, IPADOS, IOS)
/// mantienen entre sí su orden; `WEB_CREATOR` no está porque exige iniciar
/// sesión y Kiji es anónimo. Las propias de Kiji: la lista HLS de VISIONOS y
/// las que descifran con el solver de yt-dlp y mandan un PO token (BotGuard).
const ytPlayerClients = <YtPlayerClient>[
  YtPlayerClient(
    label: 'VISIONOS',
    name: 'VISIONOS',
    id: '101',
    version: '0.1',
    userAgent: safariUserAgent,
    osName: 'visionOS',
    osVersion: '1.3.21O771',
    deviceMake: 'Apple',
    deviceModel: 'RealityDevice14,1',
    note: 'Audio directo, sin descifrar.',
  ),
  YtPlayerClient(
    label: 'VISIONOS_HLS',
    name: 'VISIONOS',
    id: '101',
    version: '0.1',
    userAgent: safariUserAgent,
    osName: 'visionOS',
    osVersion: '1.3.21O771',
    deviceMake: 'Apple',
    deviceModel: 'RealityDevice14,1',
    useHls: true,
    note: 'Lista HLS de segmentos chicos (otro servidor que VISIONOS directo). No se guarda en la caché.',
  ),
  YtPlayerClient(
    label: 'TVHTML5_SIMPLY',
    name: 'TVHTML5_SIMPLY',
    id: '75',
    version: '1.0',
    userAgent: _cobaltUserAgent,
    host: 'www.youtube.com',
    needsPlayerScript: true,
    usesPoToken: true,
    playerSessionToken: true,
    note: 'Televisor simple; descifra con el solver y manda un PO token.',
  ),
  YtPlayerClient(
    label: 'TVHTML5_SIMPLY_MUSIC',
    name: 'TVHTML5_SIMPLY',
    id: '75',
    version: '1.0',
    userAgent: _cobaltUserAgent,
    needsPlayerScript: true,
    usesPoToken: true,
    playerSessionToken: true,
    note: 'Como TVHTML5_SIMPLY, pero pidiendo a music.youtube.com.',
  ),
  YtPlayerClient(
    label: 'ANDROID_VR',
    name: 'ANDROID_VR',
    id: '28',
    version: '1.65.10',
    userAgent: 'com.google.android.apps.youtube.vr.oculus/1.65.10 '
        '(Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip',
    osName: 'Android',
    osVersion: '12L',
    deviceMake: 'Oculus',
    deviceModel: 'Quest 3',
    androidSdkVersion: 32,
    retired: 'Entrega solo el primer MiB (medido con InnerTubeX, 18/10/2026).',
    note: 'Audio directo, sin descifrar.',
  ),
  YtPlayerClient(
    label: 'TVHTML5',
    name: 'TVHTML5',
    id: '7',
    version: '7.20260213.00.00',
    userAgent: 'Mozilla/5.0(SMART-TV; Linux; Tizen 4.0.0.2) AppleWebkit/605.1.15 '
        '(KHTML, like Gecko) SamsungBrowser/9.2 TV Safari/605.1.15',
    host: 'www.youtube.com',
    needsPlayerScript: true,
    usesPoToken: true,
    retired: 'YouTube responde "volver a cargar la página" (InnerTubeX: solo de prueba).',
    note: 'Televisor; descifra con el solver.',
  ),
  YtPlayerClient(
    label: 'ANDROID_VR_1.43',
    name: 'ANDROID_VR',
    id: '28',
    version: '1.43.32',
    userAgent: 'com.google.android.apps.youtube.vr.oculus/1.43.32 (Linux; U; Android 12; en_US; '
        'Quest 3; Build/SQ3A.220605.009.A1; Cronet/107.0.5284.2)',
    osName: 'Android',
    osVersion: '12',
    deviceMake: 'Oculus',
    deviceModel: 'Quest 3',
    androidSdkVersion: 32,
    retired: 'YouTube ya no le da formatos de audio (InnerTubeX: NO_PLAYABLE_STREAM).',
    note: 'Versión vieja de ANDROID_VR, de control.',
  ),
  YtPlayerClient(
    label: 'IPADOS',
    name: 'IOS',
    id: '5',
    version: '21.03.3',
    userAgent: 'com.google.ios.youtube/21.03.3 (iPad7,6; U; CPU iPadOS 17_7_10 like Mac OS X; en-US)',
    osName: 'iPadOS',
    osVersion: '17.7.10.21H450',
    deviceMake: 'Apple',
    deviceModel: 'iPad7,6',
    retired: 'YouTube ya no le da formatos de audio (InnerTubeX: rota).',
    note: 'Suele dar solo el primer minuto.',
  ),
  YtPlayerClient(
    label: 'IOS',
    name: 'IOS',
    id: '5',
    version: '21.03.1',
    userAgent: 'com.google.ios.youtube/21.03.1 (iPhone16,2; U; CPU iOS 18_2 like Mac OS X;)',
    osVersion: '18.2.22C152',
    retired: 'YouTube ya no le da formatos de audio (InnerTubeX: rota).',
    note: 'Suele dar solo el primer minuto.',
  ),
  YtPlayerClient(
    label: 'WEB_REMIX',
    name: 'WEB_REMIX',
    id: '67',
    version: '1.20260213.01.00',
    userAgent: firefoxUserAgent,
    needsPlayerScript: true,
    usesPoToken: true,
    note: 'La web de YouTube Music; descifra con el solver y manda un PO token.',
  ),
  YtPlayerClient(
    label: 'WEB_EMBEDDED_PLAYER',
    name: 'WEB_EMBEDDED_PLAYER',
    id: '56',
    version: '2.20260708.00.00',
    userAgent: chromeUserAgent,
    host: 'www.youtube.com',
    needsPlayerScript: true,
    embedded: true,
    note: 'El reproductor incrustado; usa el visitor de la página embed (Tarea Z8, como InnerTubeX 0.8.4).',
  ),
  YtPlayerClient(
    label: 'MWEB',
    name: 'MWEB',
    id: '2',
    version: '2.20250925.01.00',
    userAgent: 'Mozilla/5.0 (iPad; CPU OS 16_7_10 like Mac OS X) AppleWebKit/605.1.15 '
        '(KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1,gzip(gfe)',
    host: 'www.youtube.com',
    needsPlayerScript: true,
    usesPoToken: true,
    retired: 'Necesita un PO token ligado a la página, que Kiji no genera (medido el 18/10/2026).',
    note: 'La web para celulares; descifra con el solver y manda un PO token.',
  ),
];

YtPlayerClient? clientByLabel(String label) {
  for (final client in ytPlayerClients) {
    if (client.label == label) return client;
  }
  return null;
}
