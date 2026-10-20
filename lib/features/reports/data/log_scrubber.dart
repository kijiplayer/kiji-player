// l10n-ignore-file: textos técnicos (no se muestran en la interfaz).
/// Saca los datos personales de una línea del registro antes de guardarla o mandarla:
/// correos, nombres de usuario en rutas, claves, tokens, cookies, IPs y las URLs de audio de
/// YouTube (llevan tu IP y firmas). Deja lo que sirve para entender una falla: qué pasó, qué
/// forma, el id del video y los tiempos.
String scrubPersonalData(String text) {
  var t = text;
  for (final (pattern, replacement) in _rules) {
    t = t.replaceAllMapped(pattern, replacement);
  }
  return t;
}

final _rules = <(RegExp, String Function(Match))>[
  // URLs de audio de YouTube: llevan la IP, firmas y tokens.
  (RegExp(r'''https?://[^\s'"]*googlevideo\.com[^\s'"]*'''), (_) => 'https://…googlevideo.com/[url oculta]'),
  // Correos.
  (RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'), (_) => '[correo]'),
  // Claves de Google (Gemini y otras).
  (RegExp(r'AIza[0-9A-Za-z_\-]{30,}'), (_) => '[clave]'),
  // Encabezados y parámetros sensibles.
  (RegExp(r'(Authorization|Cookie|Set-Cookie)\s*[:=]\s*[^\n]*', caseSensitive: false), (m) => '${m[1]}: [oculto]'),
  (
    RegExp(r'\b(key|api_?key|token|pot|po_?token|sig|signature|lsig|ip|cookie|visitor_?data|sapisid|auth|password|pass|n)=[^&\s,;)]+',
        caseSensitive: false),
    (m) => '${m[1]}=[oculto]'
  ),
  (RegExp(r'"(visitorData|poToken|apiKey|cookie|authorization)"\s*:\s*"[^"]*"', caseSensitive: false), (m) => '"${m[1]}": "[oculto]"'),
  // Nombre de usuario en rutas (Windows, Linux, macOS) y la memoria del teléfono.
  (RegExp(r'([A-Za-z]:[\\/]+Users[\\/]+)[^\\/\s]+', caseSensitive: false), (m) => '${m[1]}…'),
  (RegExp(r'(/(?:home|Users)/)[^/\s]+'), (m) => '${m[1]}…'),
  (RegExp(r'/storage/emulated/\d+'), (_) => '[almacenamiento]'),
  (RegExp(r'/data/user/\d+/[^/\s]+'), (_) => '[datos de la app]'),
  // IPs.
  (RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b'), (_) => '[ip]'),
  // Cadenas largas opacas (tokens, cookies, base64): 40 caracteres o más sin espacios.
  (RegExp(r'[A-Za-z0-9_\-+/=%]{40,}'), (_) => '[oculto]'),
];
