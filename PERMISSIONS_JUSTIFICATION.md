# Justificación de Permisos - Orbit

Este documento sirve para justificar ante Google Play Console por qué Orbit solicita ciertos permisos sensibles.

## Resumen
- App: Orbit
- Package: com.orbit.app
- Uso: Telefonía satelital / VoIP, mensajería, multimedia

## Permisos solicitados

- `INTERNET`
  - Uso: Comunicaciones con APIs, señalización y servicios multimedia.

- `ACCESS_NETWORK_STATE`
  - Uso: Detectar conectividad para conmutar entre redes y optimizar uso de datos.

- `CAMERA` / `RECORD_AUDIO`
  - Uso: Videollamadas y llamadas VoIP.
  - Justificación: La funcionalidad principal incluye llamadas con video/audio; el permiso solo se usa tras consentimiento explícito del usuario.

- `MODIFY_AUDIO_SETTINGS`
  - Uso: Ajustar mezclador de audio durante llamadas (altavoz, manos libres, MIC mute).

- `POST_NOTIFICATIONS` / `VIBRATE`
  - Uso: Notificaciones de mensajes y llamadas entrantes.

- `RECEIVE_BOOT_COMPLETED`
  - Uso: Reagendar alarmas locales y notificaciones.

- `FOREGROUND_SERVICE` y `FOREGROUND_SERVICE_*` (phone_call, microphone, camera, connectedDevice)
  - Uso: Mantener servicios activos durante llamadas VoIP y actividades en segundo plano que requieren acceso continuo a micrófono/cámara.
  - Justificación: Necesario para evitar que el sistema mate el servicio durante una llamada; la app muestra siempre notificación persistente cuando está en foreground service.

- `WAKE_LOCK` / `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`
  - Uso: Mantener la app responsiva durante llamadas críticas y sincronizaciones en redes intermitentes.
  - Justificación: Se solicita a usuarios solo cuando las funcionalidades lo requieren y con explicación en UI.

- `BLUETOOTH`, `BLUETOOTH_ADMIN`, `BLUETOOTH_CONNECT`
  - Uso: Integración con dispositivos Bluetooth (headsets, micrófonos externos).
  - Justificación: Solo se utilizan cuando el usuario conecta un accesorio.

## Controles y mitigaciones
- Todas las operaciones de micrófono/cámara requieren consentimiento en tiempo de ejecución.
- Los servicios en foreground muestran notificación persistente claramente identificable.
- No se solicita permiso hasta que la funcionalidad que lo requiere es iniciada por el usuario.

## Texto sugerido para Play Store (Usage Explanation)
> Orbit solicita acceso a la cámara y al micrófono para permitir videollamadas y grabación de mensajes de voz. Estos permisos se solicitan cuando inicia la acción correspondiente y la app muestra un aviso que explica su uso.

---

Más detalles técnicos o ejemplos de UX para la solicitud de permisos están disponibles bajo petición.