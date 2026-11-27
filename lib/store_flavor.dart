// Sabor de tienda (0.9, base de la 1.0). "full": la Kiji de siempre (GitHub y tiendas), sin
// cambios. "play": Google Play (todavía sin publicar), con --dart-define=KIJI_STORE=play. Ver
// kiji-interno\SABORES.md.

/// El sabor elegido al compilar.
const kijiStore = String.fromEnvironment('KIJI_STORE', defaultValue: 'full'); // l10n-ignore

/// Google Play: sin YouTube en segundo plano, sin descargas ni cuenta de YouTube, sin actualizador
/// propio ni enlaces a la Kiji completa. Es `const`: lo apagado ni siquiera entra al APK.
const isPlayStore = kijiStore == 'play'; // l10n-ignore