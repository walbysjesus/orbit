// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'Orbit';

  @override
  String get welcome => 'Benvenuto su Orbit!';

  @override
  String get login => 'Accedi';

  @override
  String get register => 'Registrati';

  @override
  String get home => 'Home';

  @override
  String get language => 'Lingua';

  @override
  String get selectLanguage => 'Seleziona lingua';

  @override
  String selectedLanguage(Object lang) {
    return 'Lingua selezionata: $lang';
  }

  @override
  String get error => 'Errore';

  @override
  String get success => 'Successo';
}
