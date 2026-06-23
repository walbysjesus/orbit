# 📐 ARQUITECTURA ORBIT - Diagrama y Componentes

**Versión:** 1.0.0  
**Fecha:** 2026-06-19

---

## 🏗️ ARQUITECTURA GENERAL

```
┌─────────────────────────────────────────────────────────────────────┐
│                         USUARIOS (2-N)                              │
│                                                                     │
│  Android Phone      iOS Phone       Web (Futura)   Desktop (Future) │
└─────┬───────────────────┬──────────────────────────────────────────┘
      │                   │
      │  Flutter App      │ Flutter App
      │  (Orbit Client)   │ (Orbit Client)
      │                   │
      └───────────┬───────┘
                  │
      ┌───────────┴──────────────┐
      │                          │
      ▼                          ▼
┌──────────────────────┐  ┌──────────────────────┐
│   Firebase (Google)   │  │   WebSocket Server   │
├──────────────────────┤  │   (Signaling)        │
│ • Authentication     │  │   ❌ NOT BUILT YET   │
│ • Cloud Firestore    │  │                      │
│ • Cloud Storage      │  └──────────────────────┘
│ • Firebase Messaging │
│ • App Check          │
└──────────────────────┘
      │
      ▼
┌──────────────────────┐
│  Orbit Backend       │
│  ❌ NOT BUILT YET    │
├──────────────────────┤
│ • API Server         │
│ • Database (Postgres)│
│ • Media Server (SFU) │
│ • TURN Server        │
└──────────────────────┘
```

---

## 📱 ARQUITECTURA DEL CLIENTE FLUTTER

```
┌────────────────────────────────────────────────────────┐
│                   FLUTTER APP (Orbit)                  │
├────────────────────────────────────────────────────────┤
│                                                        │
│  ┌──────────────────────────────────────────────────┐ │
│  │         PRESENTATION LAYER (UI)                 │ │
│  ├──────────────────────────────────────────────────┤ │
│  │ • LoginScreen          [Auth Package]           │ │
│  │ • HomeScreen           [Navigation]             │ │
│  │ • ChatScreen           [Messages]               │ │
│  │ • ChatHubScreen        [Conversations List]     │ │
│  │ • VideoCallScreen      [Video Call UI]          │ │
│  │ • VideoHubScreen       [Available Calls]        │ │
│  │ • CallScreen           [Call History]           │ │
│  │ • OrbitIAScreen        [AI Assistant]           │ │
│  │ • SettingsScreen       [Configuration]          │ │
│  └──────────────────────────────────────────────────┘ │
│                        │                               │
│  ┌──────────────────────┴──────────────────────────┐  │
│  │         DOMAIN LAYER (Business Logic)           │  │
│  ├──────────────────────────────────────────────────┤  │
│  │ • Message Entity                                │  │
│  │ • Call Entity                                   │  │
│  │ • User Entity                                   │  │
│  │ • Chat Room Entity                              │  │
│  └──────────────────────────────────────────────────┘  │
│                        │                               │
│  ┌──────────────────────┴──────────────────────────┐  │
│  │         SERVICES LAYER (Integration)            │  │
│  ├──────────────────────────────────────────────────┤  │
│  │                                                 │  │
│  │  ┌─────────────────────────────────────────┐   │  │
│  │  │  AUTHENTICATION                         │   │  │
│  │  ├─────────────────────────────────────────┤   │  │
│  │  │ • AuthService (Firebase Auth)          │   │  │
│  │  │ • MFAService                            │   │  │
│  │  │ • SecurityService                       │   │  │
│  │  └─────────────────────────────────────────┘   │  │
│  │                                                 │  │
│  │  ┌─────────────────────────────────────────┐   │  │
│  │  │  COMMUNICATION - CHAT                   │   │  │
│  │  ├─────────────────────────────────────────┤   │  │
│  │  │ • ChatApiService                        │   │  │
│  │  │   - getOrCreateRoom()                   │   │  │
│  │  │   - messagesStream()                    │   │  │
│  │  │   - sendMessage()                       │   │  │
│  │  │   - uploadAttachment()                  │   │  │
│  │  │ • E2EChatCryptoService (AES encryption) │   │  │
│  │  │ • FCMService (Push notifications)       │   │  │
│  │  └─────────────────────────────────────────┘   │  │
│  │                                                 │  │
│  │  ┌─────────────────────────────────────────┐   │  │
│  │  │  COMMUNICATION - VOICE & VIDEO          │   │  │
│  │  ├─────────────────────────────────────────┤   │  │
│  │  │ • CallService ⚠️ (Stubs)               │   │  │
│  │  │ • CallSessionService                    │   │  │
│  │  │ • WebRTCService                         │   │  │
│  │  │   - initConnection()                    │   │  │
│  │  │   - createOffer()                       │   │  │
│  │  │   - addIceCandidate()                   │   │  │
│  │  │ • SignalingService (WebSocket)          │   │  │
│  │  │ • FirestoreSignaling (Fallback)         │   │  │
│  │  │ • TurnStunConfig                        │   │  │
│  │  │   - buildIceServers()                   │   │  │
│  │  │ • CallDiagnosticsService                │   │  │
│  │  └─────────────────────────────────────────┘   │  │
│  │                                                 │  │
│  │  ┌─────────────────────────────────────────┐   │  │
│  │  │  AI ASSISTANT                           │   │  │
│  │  ├─────────────────────────────────────────┤   │  │
│  │  │ • OrbitIAService                        │   │  │
│  │  │   - sendMessage()                       │   │  │
│  │  │   - sendMessageDetailed()               │   │  │
│  │  │ • OrbitBrain (Intent processing)        │   │  │
│  │  │ • DecisionEngine                        │   │  │
│  │  │ • ConversationState                     │   │  │
│  │  │ • Executors:                            │   │  │
│  │  │   - ChatExecutor                        │   │  │
│  │  │   - CallExecutor                        │   │  │
│  │  │   - StatusExecutor                      │   │  │
│  │  │   - DashboardExecutor                   │   │  │
│  │  │ • OrbitLLMService (OpenAI integration)  │   │  │
│  │  └─────────────────────────────────────────┘   │  │
│  │                                                 │  │
│  │  ┌─────────────────────────────────────────┐   │  │
│  │  │  CLOUD SERVICES                         │   │  │
│  │  ├─────────────────────────────────────────┤   │  │
│  │  │ • APIClient (Dio HTTP)                  │   │  │
│  │  │ • DioClient (Interceptors)              │   │  │
│  │  │ • StorageService                        │   │  │
│  │  │ • ContactAPIService                     │   │  │
│  │  │ • DashboardAPIService                   │   │  │
│  │  │ • HistoryAPIService                     │   │  │
│  │  │ • StatusAPIService                      │   │  │
│  │  │ • SubscriptionService                   │   │  │
│  │  │ • InAppPurchaseService                  │   │  │
│  │  │ • RemoteConfigService                   │   │  │
│  │  │ • RemoteNotificationService             │   │  │
│  │  └─────────────────────────────────────────┘   │  │
│  │                                                 │  │
│  │  ┌─────────────────────────────────────────┐   │  │
│  │  │  UTILITY SERVICES                       │   │  │
│  │  ├─────────────────────────────────────────┤   │  │
│  │  │ • NetworkService                        │   │  │
│  │  │ • LocaleService                         │   │  │
│  │  │ • ConfigService                         │   │  │
│  │  │ • WeatherService                        │   │  │
│  │  │ • OrganizationService                   │   │  │
│  │  │ • ResilientStreamHelper                 │   │  │
│  │  └─────────────────────────────────────────┘   │  │
│  │                                                 │  │
│  └──────────────────────────────────────────────────┘  │
│                        │                               │
│  ┌──────────────────────┴──────────────────────────┐  │
│  │      DATA LAYER (Storage & Connectivity)        │  │
│  ├──────────────────────────────────────────────────┤  │
│  │ • Firebase (Cloud Firestore)                    │  │
│  │   - Collection: chats                           │  │
│  │   - Collection: users                           │  │
│  │   - Collection: calls                           │  │
│  │   - Collection: organizations                   │  │
│  │ • Firebase Storage (Files & Media)              │  │
│  │ • SharedPreferences (Local config)              │  │
│  │ • FlutterSecureStorage (Credentials)            │  │
│  │ • WebSocket Connection (WebRTC Signaling)       │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
└────────────────────────────────────────────────────────┘
```

---

## 🗄️ ESTRUCTURA DE DATOS (Firestore)

```
firestore-root/
│
├── chats/                          ← Conversaciones
│   ├── {roomId}/
│   │   ├── participants: [uid1, uid2]
│   │   ├── createdBy: uid
│   │   ├── createdAt: timestamp
│   │   └── messages/
│   │       ├── {messageId}
│   │       │   ├── sender: uid
│   │       │   ├── text: string
│   │       │   ├── timestamp: timestamp
│   │       │   ├── encrypted: boolean
│   │       │   ├── attachments: [...]
│   │       │   └── read: boolean
│
├── users/                          ← Perfiles de usuario
│   ├── {uid}/
│   │   ├── email: string
│   │   ├── displayName: string
│   │   ├── photoUrl: string
│   │   ├── status: "online" | "offline"
│   │   ├── organization: string
│   │   ├── mfaEnabled: boolean
│   │   ├── createdAt: timestamp
│   │   └── lastSeen: timestamp
│
├── calls/                          ← Historial de llamadas
│   ├── {callId}/
│   │   ├── participants: [uid1, uid2]
│   │   ├── type: "audio" | "video"
│   │   ├── startedAt: timestamp
│   │   ├── endedAt: timestamp
│   │   ├── duration: number (segundos)
│   │   ├── status: "ringing" | "active" | "ended"
│   │   └── quality: {...}
│
├── call-sessions/                  ← Estado de sesiones activas
│   ├── {sessionId}/
│   │   ├── roomId: string
│   │   ├── initiator: uid
│   │   ├── participant: uid
│   │   ├── status: "ringing" | "accepted" | "rejected"
│   │   ├── createdAt: timestamp
│   │   └── signalingData: {...}
│
├── organizations/                  ← Organizaciones (futuro)
│   ├── {orgId}/
│   │   ├── name: string
│   │   ├── members: [uid1, uid2, ...]
│   │   └── settings: {...}
```

---

## 🔄 FLUJO DE CHAT

```
┌─────────────────────────────────────────────────────────┐
│             USUARIO A                USUARIO B          │
│         (remoteUserId A)          (remoteUserId B)      │
└───────────────────┬───────────────────┬─────────────────┘
                    │                   │
                    │ ChatScreen        │ ChatScreen
                    │ (abierto)         │ (abierto)
                    │                   │
      ┌─────────────┴─────────────┬─────┴──────────────┐
      │                           │                    │
   1. │ chatApiService            │                    │
      │ .getOrCreateRoom()        │                    │
      │ → roomId = "A_B"          │                    │
      │ (determinístico)          │                    │
      │                           │                    │
      │ Firestore: /chats/A_B     │                    │
      │ creada si no existe       │                    │
      │                           │                    │
      ├─ messagesStream()         │                    │
      │  (escucha cambios)        │                    │
      │                           │                    │
   2. │ Usuario A escribe y       │                    │
      │ presiona "Enviar"         │                    │
      │                           │                    │
      │ chatApiService            │                    │
      │ .sendMessage(roomId, msg) │                    │
      │                           │                    │
      │ E2EChatCryptoService      │                    │
      │ .encryptMessage(msg)      │                    │
      │ → encrypted_msg           │                    │
      │                           │                    │
      │ Firestore: /chats/A_B     │                    │
      │ /messages/{newId}         │                    │
      │ ← Guardado                │                    │
      │                           │                    │
      │                           │ Firestore notifica │
      │                           │ cambio en stream   │
      │                           │                    │
      │                           │ messagesStream()   │
      │                           │ recibe nuevo msg   │
      │                           │                    │
      │                           │ E2ECrypto          │
      │                           │ .decryptMessage()  │
      │                           │                    │
      │                           │ ChatScreen         │
      │                           │ refresca UI        │
      │                           │ muestra: "Usuario A: mensaje"
      │                           │                    │
   3. │ B responde                │                    │
      │ Mismo flujo (2-3)         │                    │
      │                           │                    │
      │ FCMService               │ FCMService         │
      │ envía notificación        │ enviará notif      │
      │                           │                    │
      │ Push Notification ────────→ Delivery ← ─────  │
      │ "Nuevo mensaje de B"      │                    │
      │                           │                    │
```

---

## 📞 FLUJO DE VIDEO LLAMADA (Actual)

```
┌──────────────────────────────────────────────────────────┐
│         USUARIO A (Iniciador)  │  USUARIO B (Recibidor)  │
└───────────────────┬────────────┼────────────┬────────────┘
                    │            │            │
                    │            │ 1. Recibe notif push
                    │            │    (FCMService)
                    │            │
        ┌───────────┴────────────┴────────────┬────────────┐
        │                                      │            │
        │ 2. A abre VideoCallScreen            │ B abre     │
        │                                      │ VideoCall  │
        │    roomId = generateUUID()           │            │
        │    (A es iniciador)                  │            │
        │                                      │            │
        │ 3. WebRTCService                     │            │
        │    .initConnection(isCaller=true)    │            │
        │                                      │            │
        │ 4. A envía SDP Offer                 │            │
        │    via SignalingService              │            │
        │    (WebSocket o Firestore)           │            │
        │                                      │            │
        │    ─────────SDP OFFER─────────────→  │            │
        │                                      │            │
        │                                      │ WebRTC     │
        │                                      │ .initConn( │
        │                                      │ isCaller=  │
        │                                      │ false)     │
        │                                      │            │
        │                                      │ createAnswer
        │                                      │            │
        │    ←─────SDP ANSWER─────────────────│            │
        │                                      │            │
        │ 5. ICE Candidate Exchange            │            │
        │                                      │            │
        │    A gathers candidates              │ B gathers  │
        │    (TURN/STUN servers)               │ candidates │
        │                                      │            │
        │    ─ice-candidate─────────────────→  │            │
        │    ←─ice-candidate─────────────────  │            │
        │    ─ice-candidate─────────────────→  │            │
        │    ← ice-candidate─────────────────  │            │
        │                                      │            │
        │ 6. P2P Connection Established        │            │
        │    RTCIceConnectionState =            │            │
        │    CONNECTED                         │            │
        │                                      │            │
        │ [Media streams ready]                │            │
        │                                      │            │
        │ ❌ AQUÍ FALTA:                       │            │
        │    • Local video stream              │            │
        │    • Remote video stream             │            │
        │    • Display en UI                   │            │
        │    • Audio routing                   │            │
        │                                      │            │
        │ 7. Llamada activa (estado)           │            │
        │    updateUI()                        │            │
        │    startConnectionHeartbeat()        │            │
        │                                      │            │
        │ [Durante llamada]                    │            │
        │                                      │            │
        │ Heartbeat verifica:                  │            │
        │   - RTCIceConnectionState            │            │
        │   - RTCConnectionState               │            │
        │   - Signal strength                  │            │
        │                                      │            │
        │ 8. Finalización (A cuelga)           │            │
        │                                      │            │
        │    closeCall()                       │            │
        │    _peerConnection?.close()          │            │
        │    SignalingService.disconnect()     │            │
        │                                      │            │
        │    ─────────CALL_ENDED──────────────→│            │
        │                                      │ Desconectar │
        │                                      │ UI update   │
        │                                      │            │
        │ CallSessionService.endCall()         │            │
        │ (guardar duración, estado)           │            │
        │                                      │            │
```

---

## 🌐 FLUJO DE SEÑALIZACIÓN (Signaling)

```
OPCIÓN 1: WebSocket (Preferida para P2P)
─────────────────────────────────────

Formato JSON:
{
  "type": "join",
  "roomId": "uuid",
  "userId": "uid123",
  "token": "jwt_token"
}

{
  "type": "offer",
  "sdp": "v=0\no=...",
  "to": "uid456"
}

{
  "type": "answer",
  "sdp": "v=0\no=...",
  "to": "uid123"
}

{
  "type": "ice-candidate",
  "candidate": {...},
  "to": "uid456"
}

{
  "type": "peer-joined",
  "from": "uid456"
}

{
  "type": "peer-left",
  "from": "uid456"
}


OPCIÓN 2: Firestore (Fallback, más lento)
──────────────────────────────────────────

call-sessions/{sessionId}/
  ├── initiator: uid123
  ├── participant: uid456
  ├── sdpOffer: "v=0\no=..."
  ├── sdpAnswer: "v=0\no=..."
  ├── iceCandidatesA: [...]
  ├── iceCandidatesB: [...]
  └── status: "active"

Firestore listeners notifican cambios
(más latencia pero sin servidor WebSocket)
```

---

## 📊 DEPENDENCIAS Y FLUJO

```
CHAT FLOW:
User → ChatScreen
  → ChatApiService.getOrCreateRoom()
      → Firestore
  → ChatApiService.messagesStream()
      → ResilientStreamHelper (reconnect logic)
          → Firestore listener
  → ChatApiService.sendMessage()
      → E2EChatCryptoService (encrypt)
          → Firestore
              → FCMService (push to other user)
                  → Firebase Cloud Messaging
                      → User B notified


VOICE CALL FLOW:
User → VideoCallScreen
  → WebRTCService.initConnection()
  → SignalingService.connect() (WebSocket)
      → Exchange SDP/ICE
      → TurnStunConfig.buildIceServers()
  → WebRTC P2P connection
  → ❌ Missing: audio stream integration
  → Heartbeat monitoring


VIDEO CALL FLOW:
User → VideoCallScreen
  → Same as voice call, but:
    → Camera/Mic permissions
    → Video stream (❌ missing integration)
    → Remote video display (❌ missing)


IA FLOW:
User → OrbitIAScreen
  → OrbitIAService.sendMessage()
      → OrbitBrain.process()
          → DecisionEngine.analyze()
              → Execute:
                  - ChatExecutor
                  - CallExecutor
                  - StatusExecutor
                  - DashboardExecutor
          → OrbitLLMService (OpenAI)
  → Response to user
```

---

## 🔒 SEGURIDAD EN ARQUITECTURA

```
┌────────────────────────────────────────────────┐
│              SEGURIDAD POR CAPAS               │
├────────────────────────────────────────────────┤
│                                                │
│ NIVEL 1: Transporte                          │
│ ✅ HTTPS/WSS only (Firebase enforced)        │
│ ✅ Certificate validation                     │
│ ⚠️  Certificate pinning (partial)             │
│ ❌ TURN server TLS (needs config)             │
│                                                │
│ NIVEL 2: Autenticación                        │
│ ✅ Firebase Auth (OAuth2 compatible)          │
│ ✅ MFA support                                │
│ ✅ Secure token storage                       │
│ ✅ Token refresh                              │
│                                                │
│ NIVEL 3: Autorización                         │
│ ✅ Firestore security rules                   │
│ ✅ Storage security rules                     │
│ ❌ Firebase App Check (needs setup)           │
│ ⚠️  Backend auth (no backend yet)             │
│                                                │
│ NIVEL 4: Datos                                │
│ ✅ E2E encryption para chat (AES)             │
│ ⚠️  RTC media (needs DTLS-SRTP)              │
│ ✅ Secure storage para credentials            │
│ ❌ Field-level encryption (Firestore)        │
│                                                │
│ NIVEL 5: Validación                           │
│ ⚠️  Input validation (client-side only)       │
│ ❌ Server-side validation (no server)         │
│ ⚠️  Rate limiting (Firebase only)             │
│ ❌ DDoS protection (needs CloudFlare/WAF)     │
│                                                │
│ NIVEL 6: Auditoría                            │
│ ✅ FCM logging (Firebase)                     │
│ ⚠️  Call diagnostics (basic)                  │
│ ❌ Centralized logging (Sentry/Datadog)       │
│ ❌ Compliance logging (PII handling)          │
│                                                │
└────────────────────────────────────────────────┘
```

---

## 🚀 COMPONENTES LISTOS VS FALTA IMPLEMENTAR

```
┌──────────────────────────┬──────────┬───────────────────┐
│ COMPONENTE               │ STATUS   │ PRIORIDAD PARA MVP│
├──────────────────────────┼──────────┼───────────────────┤
│ Frontend (Flutter UI)    │ ✅ 90%   │ ✅ HECHO         │
│ Firebase Setup           │ ✅ 95%   │ ✅ HECHO         │
│ Chat Service             │ ✅ 95%   │ ✅ HECHO         │
│ Auth Service             │ ✅ 95%   │ ✅ HECHO         │
│ WebRTC Service           │ ✅ 90%   │ ✅ HECHO         │
│ Signaling Service        │ ✅ 85%   │ ✅ HECHO         │
│ FCM Notifications        │ ✅ 90%   │ ✅ HECHO         │
│ E2E Chat Encryption      │ ✅ 95%   │ ✅ HECHO         │
│ IA Service (Orbit Brain) │ ✅ 80%   │ ⚠️ NICE-TO-HAVE │
│                          │          │                  │
│ Call Service (complete)  │ ⚠️ 30%   │ 🔴 CRÍTICO      │
│ Audio Stream Integration │ ❌ 0%    │ 🔴 CRÍTICO      │
│ Video Stream Integration │ ❌ 0%    │ 🔴 CRÍTICO      │
│ Backend Server           │ ❌ 0%    │ 🔴 CRÍTICO      │
│ Call Routing Logic       │ ❌ 0%    │ 🔴 CRÍTICO      │
│ Media Server (SFU/MCU)   │ ❌ 0%    │ 🟠 IMPORTANTE   │
│ Testing Suite            │ ❌ 5%    │ 🟠 IMPORTANTE   │
│ Monitoring/Logging       │ ⚠️ 50%   │ 🟠 IMPORTANTE   │
│ Compliance/Legal         │ ⚠️ 60%   │ 🟠 IMPORTANTE   │
│ Security Audit           │ ⚠️ 30%   │ 🟠 IMPORTANTE   │
│ Performance Testing      │ ❌ 0%    │ 🟡 SECUNDARIO   │
│ Call Recording           │ ❌ 0%    │ 🟡 SECUNDARIO   │
│ Conference Calls         │ ❌ 0%    │ 🟡 SECUNDARIO   │
└──────────────────────────┴──────────┴───────────────────┘
```

---

**Diagrama generado:** 2026-06-19  
**Versión:** 1.0.0 (Orbit Project)

