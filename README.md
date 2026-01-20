samples, guidance on mobile development, and a full API reference.

# Orbit

Aplicación Flutter multiplataforma con arquitectura profesional y motor de IA contextual.

## Arquitectura IA y Contexto Dinámico

Orbit permite inyectar contexto externo (como clima y calidad de red) en la toma de decisiones de la IA, sin acoplar la lógica ni romper el flujo original.

### Inyección de contexto en la IA

El objeto `OrbitContext` acepta parámetros opcionales para clima y red:

```dart
final context = OrbitContext(
	conversationId: conversationId,
	userId: userId,
	shortTermMemory: conversationState.shortTermMemory.snapshot(),
	longTermMemory: conversationState.longTermMemory.export(),
	lastIntent: conversationState.activeIntent,
	weatherCondition: WeatherCondition.rain, // Ejemplo: lluvia
	networkQuality: "good", // Ejemplo: buena red
);
```

Si no se proveen, la IA usará valores por defecto y el sistema seguirá funcionando normalmente.

### Flujo profesional para integración de contexto

1. **Obtener datos reales**: Integra servicios de clima/red (API, sensores, etc).
2. **Inyectar en OrbitContext**: Pasa los valores al crear el contexto en el servicio IA.
3. **Decisión adaptativa**: El motor de decisión usará estos datos para personalizar respuestas y recomendaciones.

### Ejemplo de extensión

Para agregar más contexto (ubicación, batería, etc), solo añade nuevos parámetros opcionales en OrbitContext y consúmelos en el motor de decisión.

---

Para más detalles de arquitectura y patrones, revisa `.github/copilot-instructions.md`.
