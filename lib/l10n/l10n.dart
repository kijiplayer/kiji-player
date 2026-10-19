import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// Los textos de Kiji en el idioma de la app (Tarea T5). Si una pantalla se dibuja sin los
/// delegados de idioma (pruebas, diálogos sueltos), vuelve al español en vez de fallar.
AppLocalizations tr(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ?? lookupAppLocalizations(const Locale('es'));
