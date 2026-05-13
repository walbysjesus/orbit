// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Orbit';

  @override
  String get welcome => '¡Bienvenido a Orbit!';

  @override
  String get login => 'Iniciar sesión';

  @override
  String get register => 'Registrarse';

  @override
  String get home => 'Inicio';

  @override
  String get language => 'Idioma';

  @override
  String get selectLanguage => 'Seleccionar idioma';

  @override
  String selectedLanguage(Object lang) {
    return 'Idioma seleccionado: $lang';
  }

  @override
  String get error => 'Error';

  @override
  String get success => 'Éxito';
}
