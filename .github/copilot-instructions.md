# Instrucciones Copilot para Orbit

## Descripción General del Proyecto
- Orbit es una aplicación Flutter con soporte multiplataforma (Android, iOS, Linux, macOS, Windows, Web).
- El punto de entrada principal es `lib/main.dart`.
- La lógica central está organizada en `lib/` con subcarpetas para configuración, firebase, modelos, pantallas, servicios y utilidades.

## Arquitectura y Patrones
- **Pantallas (Screens)**: La UI se divide en carpetas por funcionalidad dentro de `lib/screens/` (ej: `auth`, `communication`, `home`, `ia`).
- **Servicios**: La lógica de negocio y APIs está en `lib/services/` (ej: `auth_service.dart`, `chat_api_service.dart`).
- **Modelos**: Estructuras de datos en `lib/models/`.
- **Config**: Configuración global en `lib/config/config.dart`.
- **Firebase**: Archivos de integración en `lib/firebase/` (autenticación, inicialización).
- **Utils**: Helpers compartidos en `lib/utils/`.

## Flujos de Trabajo para Desarrolladores
- **Build**: Usa `flutter build <plataforma>` (ej: `flutter build apk`, `flutter build web`).
- **Run**: Usa `flutter run` para desarrollo local.
- **Test**: Ejecuta `flutter test` para tests unitarios/widget (ver `test/widget_test.dart`).
- **Android/iOS**: Configuración nativa en las carpetas `android/` e `ios/`. Archivos de Google/Firebase presentes para ambas plataformas.

## Convenciones y Prácticas
- Carpetas por funcionalidad para pantallas y servicios; evita archivos monolíticos.
- Usa modelos para todos los datos estructurados entre servicios y pantallas.
- Las llamadas a APIs externas están abstraídas en archivos de servicios (ver `lib/services/api_client.dart`).
- La autenticación e inicialización de Firebase se manejan en archivos dedicados (`lib/firebase/firebase_auth_service.dart`, `lib/firebase/firebase_init.dart`).
- Helpers de UI en `lib/utils/ui_helpers.dart`.

## Puntos de Integración
- **Firebase**: Archivos de autenticación y configuración para Android (`google-services.json`) e iOS (`GoogleService-Info.plist`).
- **API**: Toda comunicación con APIs externas pasa por archivos de servicios.
- **Assets**: Imágenes y archivos estáticos en `assets/images/`.

## Ejemplos
- Para agregar una nueva pantalla: crea una carpeta en `lib/screens/`, agrega tu archivo Dart y conéctalo vía navegación en `main.dart`.
- Para agregar un nuevo servicio: agrega un archivo Dart en `lib/services/`, define tu lógica y usa modelos de `lib/models/`.

## Archivos y Directorios Clave
- `lib/main.dart`: Punto de entrada y navegación de la app.
- `lib/services/`: Lógica de negocio y APIs.
- `lib/models/`: Estructuras de datos.
- `lib/screens/`: Componentes de UI.
- `lib/firebase/`: Integración con Firebase.
- `assets/images/`: Recursos estáticos.
- `test/`: Tests.

---

Ante dudas o convenciones poco claras, revisa la estructura de carpetas o consulta. Actualiza este archivo si surgen nuevos patrones.