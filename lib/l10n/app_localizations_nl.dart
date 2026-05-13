// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get appTitle => 'Orbit';

  @override
  String get welcome => 'Welkom bij Orbit!';

  @override
  String get login => 'Inloggen';

  @override
  String get register => 'Registreren';

  @override
  String get home => 'Thuis';

  @override
  String get language => 'Taal';

  @override
  String get selectLanguage => 'Taal kiezen';

  @override
  String selectedLanguage(Object lang) {
    return 'Geselecteerde taal: $lang';
  }

  @override
  String get error => 'Fout';

  @override
  String get success => 'Succes';
}
