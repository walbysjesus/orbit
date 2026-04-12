# Sugerencia de integración Crashlytics/Analytics
# 1. Agrega a pubspec.yaml:
#   firebase_crashlytics: ^4.0.0
#   firebase_analytics: ^11.0.0
# 2. Inicializa en main.dart:
#   import 'package:firebase_crashlytics/firebase_crashlytics.dart';
#   import 'package:firebase_analytics/firebase_analytics.dart';
#   await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
#   FirebaseAnalytics analytics = FirebaseAnalytics.instance;
# 3. Configura en consola Firebase y sigue la documentación oficial:
#   https://firebase.google.com/docs/crashlytics/get-started?platform=flutter
#   https://firebase.google.com/docs/analytics/get-started?platform=flutter
