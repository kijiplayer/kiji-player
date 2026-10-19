// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get navHome => 'Inicio';

  @override
  String get navSearch => 'Buscar';

  @override
  String get navLibrary => 'Biblioteca';

  @override
  String get settingsTitle => 'Configuración';

  @override
  String get settingsSearchHint => 'Buscar una opción…';

  @override
  String get errorReportTitle => 'Algo falló en Kiji';

  @override
  String errorReportBody(String summary) {
    return '$summary.\n\n¿Quieres avisarle al desarrollador? Se abre GitHub con un informe ya escrito, sin tu nombre, tus archivos ni tus cuentas. Lo puedes leer antes de enviarlo.';
  }

  @override
  String get errorReportSend => 'Enviar al desarrollador';

  @override
  String get errorReportDownload => 'Descargar informe (.txt)';

  @override
  String get errorReportNoThanks => 'No, gracias';
}
