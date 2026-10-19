// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navSearch => 'Search';

  @override
  String get navLibrary => 'Library';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSearchHint => 'Search a setting…';

  @override
  String get errorReportTitle => 'Something went wrong in Kiji';

  @override
  String errorReportBody(String summary) {
    return '$summary.\n\nWould you like to let the developer know? GitHub opens with a report already written, without your name, your files or your accounts. You can read it before sending it.';
  }

  @override
  String get errorReportSend => 'Send to the developer';

  @override
  String get errorReportDownload => 'Download report (.txt)';

  @override
  String get errorReportNoThanks => 'No, thanks';
}
