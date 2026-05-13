// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Orbit';

  @override
  String get welcome => 'Welcome to Orbit!';

  @override
  String get login => 'Login';

  @override
  String get register => 'Register';

  @override
  String get home => 'Home';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select language';

  @override
  String selectedLanguage(Object lang) {
    return 'Selected language: $lang';
  }

  @override
  String get error => 'Error';

  @override
  String get success => 'Success';
}
