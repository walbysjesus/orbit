# Sugerencia de estructura para internacionalización (i18n)

1. Agrega a pubspec.yaml:
#   flutter_localizations:
#     sdk: flutter
#   intl: ^0.19.0

2. Crea carpeta lib/l10n/ y agrega archivos como:
#   lib/l10n/intl_es.arb
#   lib/l10n/intl_en.arb

3. Ejemplo de intl_es.arb:
# {
#   "hello": "Hola",
#   "welcome": "Bienvenido a Orbit"
# }

4. En main.dart:
#   import 'package:flutter_localizations/flutter_localizations.dart';
#   ...
#   localizationsDelegates: [
#     GlobalMaterialLocalizations.delegate,
#     GlobalWidgetsLocalizations.delegate,
#     GlobalCupertinoLocalizations.delegate,
#   ],
#   supportedLocales: [
#     Locale('es'),
#     Locale('en'),
#   ],

Consulta la documentación oficial para detalles:
https://docs.flutter.dev/accessibility-and-localization/internationalization
