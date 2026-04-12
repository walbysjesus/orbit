# Orbit - Bateria E2E Movil (10 pruebas rapidas)

Objetivo:
Validar en movil real los flujos clave de registro, sesion, chat, llamada, videollamada e IA.

Tiempo estimado:
25 a 40 minutos.

Precondiciones:
- 2 moviles (A y B) con Orbit instalada.
- Ambos con internet.
- Firebase activo (Auth + Firestore + reglas desplegadas).
- Permisos de microfono/camara concedidos en ambos equipos.

## Resultado esperado global
- No crasheos.
- Navegacion estable con boton atras del sistema.
- Comunicacion entre usuarios funcional.
- IA responde en tiempo razonable y da fallback en error.

## Casos E2E (10)

### 1) Registro genera numero Orbit de 8 digitos
Pasos:
1. En A, ir a Registro.
2. Crear cuenta nueva valida.
3. Abrir menu lateral/home y ver Numero Orbit.
Esperado:
- Se muestra numero de contacto de exactamente 8 digitos.
- El numero se puede copiar.
Estado: [ ] PASS  [ ] FAIL

### 2) Login con cuenta valida
Pasos:
1. Cerrar sesion en A.
2. Iniciar sesion con credenciales correctas.
Esperado:
- Entra a Home sin error.
- No vuelve a login/register al presionar atras (debe salir app o quedar en root segun OS).
Estado: [ ] PASS  [ ] FAIL

### 3) Sesion invalida por perfil eliminado
Pasos:
1. Con usuario A creado, borrar users/{uid} en Firestore (consola).
2. Reabrir app A o relogin.
Esperado:
- No debe entrar a Home como si nada.
- Debe forzar salida de sesion o pedir login/registro.
Estado: [ ] PASS  [ ] FAIL

### 4) Boton atras desde Home
Pasos:
1. Con sesion activa en A, estar en Home principal.
2. Presionar boton atras del sistema una vez.
Esperado:
- No navega primero a Register/Login.
- Sale de app (o minimiza, segun comportamiento nativo del dispositivo).
Estado: [ ] PASS  [ ] FAIL

### 5) Chat A -> B por Numero Orbit
Pasos:
1. En A, abrir Chat directo.
2. Ingresar numero Orbit de B.
3. Enviar mensaje "hola desde A".
Esperado:
- B recibe mensaje en tiempo razonable.
- Mensaje queda persistido en historial.
Estado: [ ] PASS  [ ] FAIL

### 6) Chat B -> A (bidireccional)
Pasos:
1. Desde B responder "hola A".
2. Revisar en A.
Esperado:
- A recibe respuesta.
- No hay duplicados ni orden roto evidente.
Estado: [ ] PASS  [ ] FAIL

### 7) Llamada de voz A -> B
Pasos:
1. En A, iniciar llamada de voz a B.
2. En B, aceptar.
Esperado:
- Ringing visible.
- Conexion de audio estable al menos 30 segundos.
- Colgado limpia sesion de llamada.
Estado: [ ] PASS  [ ] FAIL

### 8) Videollamada A -> B
Pasos:
1. En A, iniciar videollamada a B.
2. En B, aceptar.
Esperado:
- Se ve video en ambos lados.
- Audio funcional.
- Al cortar, no quedan pantallas colgadas.
Estado: [ ] PASS  [ ] FAIL

### 9) IA responde consulta util
Pasos:
1. En A, abrir Orbit IA.
2. Preguntar: "Como mejorar señal en red inestable?".
Esperado:
- IA responde con recomendaciones utiles.
- Si hay error de backend, se muestra respuesta fallback amigable.
Estado: [ ] PASS  [ ] FAIL

### 10) IA en conversacion corta (contexto)
Pasos:
1. En IA, enviar 3 mensajes seguidos con contexto.
2. Ejemplo: "Estoy en zona rural", "Tengo latencia alta", "Que modo recomiendas?".
Esperado:
- Respuestas coherentes con el contexto reciente.
- UI no se congela.
Estado: [ ] PASS  [ ] FAIL

## Registro de incidencias
Para cada FAIL, anotar:
- Caso: (1..10)
- Dispositivo: A o B
- Hora:
- Evidencia: captura o video
- Error observado:
- Resultado esperado:

## Criterio de salida
Release candidata si:
- 10/10 PASS, o
- 9/10 PASS sin fallos en seguridad/sesion/comunicacion base.
