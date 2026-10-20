import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

AppLocalizations _current = lookupAppLocalizations(const Locale('es'));

/// Los textos de Kiji en el idioma elegido (Configuración → Idioma). Se usa en cualquier parte,
/// también fuera de las pantallas (avisos, errores): `tx.settingsTitle`.
AppLocalizations get tx => _current;

/// El idioma de la app en uso ('es' o 'en').
String get kijiLanguage => _current.localeName;

/// Cambia el idioma de los textos (la app vuelve a dibujar todo; ver KijiApp).
void setKijiLocale(Locale locale) {
  final supported = AppLocalizations.supportedLocales.any((l) => l.languageCode == locale.languageCode);
  _current = lookupAppLocalizations(supported ? Locale(locale.languageCode) : const Locale('en'));
}

/// El idioma que corresponde a la opción de Configuración: 'es', 'en' o el del teléfono
/// ('system'; si no es español ni inglés, inglés).
Locale resolveKijiLocale(String language, Locale system) => switch (language) {
  'es' || 'en' => Locale(language),
  _ => Locale(system.languageCode == 'es' ? 'es' : 'en'),
};

/// Compatibilidad: lo mismo que [tx].
AppLocalizations tr(BuildContext context) => tx;
