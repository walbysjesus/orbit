// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Orbit';

  @override
  String get welcome => 'Willkommen bei Orbit!';

  @override
  String get login => 'Anmelden';

  @override
  String get register => 'Registrieren';

  @override
  String get home => 'Startseite';

  @override
  String get language => 'Sprache';

  @override
  String get selectLanguage => 'Sprache wählen';

  @override
  String selectedLanguage(Object lang) {
    return 'Ausgewählte Sprache: $lang';
  }

  @override
  String get error => 'Fehler';

  @override
  String get success => 'Erfolg';
}
