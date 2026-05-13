// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Orbit';

  @override
  String get welcome => 'Bem-vindo ao Orbit!';

  @override
  String get login => 'Entrar';

  @override
  String get register => 'Registrar';

  @override
  String get home => 'Início';

  @override
  String get language => 'Idioma';

  @override
  String get selectLanguage => 'Selecionar idioma';

  @override
  String selectedLanguage(Object lang) {
    return 'Idioma selecionado: $lang';
  }

  @override
  String get error => 'Erro';

  @override
  String get success => 'Sucesso';
}
