// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Orbit';

  @override
  String get welcome => 'Bienvenue sur Orbit !';

  @override
  String get login => 'Connexion';

  @override
  String get register => "S'inscrire";

  @override
  String get home => 'Accueil';

  @override
  String get language => 'Langue';

  @override
  String get selectLanguage => 'Choisir la langue';

  @override
  String selectedLanguage(Object lang) {
    return 'Langue sélectionnée : $lang';
  }

  @override
  String get error => 'Erreur';

  @override
  String get success => 'Succès';
}
