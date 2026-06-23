# Implementación Firebase P2P Calling - MVP 5 Usuarios

## 📱 ¿Cómo Funciona?

**Modelo Manual de Compartir Links:**
1. Usuario A (caller) inicia llamada → genera UUID único
2. UUID se guarda en Firestore: `/calls/{callId}/`
3. Usuario A comparte UUID por chat/email
4. Usuario B (receiver) entra con ese UUID
5. Firebase maneja intercambio de SDP/ICE (WebRTC signaling)
6. Conexión P2P directa (no pasa por servidor)

```
┌─────────────────┐
│   Usuario A     │
│   (Caller)      │
└────────┬────────┘
         │ 1. Genera UUID
         │ 2. Crea call en Firestore
         │
    ┌────▼─────┐
    │ Firestore │  SDP Offer → Answer
    │ /calls/   │  ICE Candidates
    └────┬─────┘
         │
         │ 3. Comparte UUID por chat
         │
┌────────▼────────┐
│   Usuario B     │
│   (Receiver)    │
└─────────────────┘
```

---

## 🔧 Pasos de Implementación

### 1️⃣ Crear Firestore Rules para Llamadas

**Archivo:** `firestore.rules`

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Chat collections
    match /chat_rooms/{roomId=**} {
      allow read, write: if isAuthenticated();
    }

    // ✅ NEW: Calls collection for P2P signaling
    match /calls/{callId} {
      allow create: if isAuthenticated();
      allow read: if isAuthenticated() && exists(/databases/$(database)/documents/calls/$(callId));
      allow update: if isAuthenticated() && resource.data.userId_caller == request.auth.uid || resource.data.userId_receiver == request.auth.uid;
      allow delete: if isAuthenticated() && (resource.data.userId_caller == request.auth.uid || resource.data.userId_receiver == request.auth.uid);

      // SDP offers
      match /sdp_offer/{userId} {
        allow read, write: if isAuthenticated();
      }

      // ICE candidates
      match /ice_candidates/{userId} {
        allow read, write: if isAuthenticated();
      }

      // Call status
      match /status/{document=**} {
        allow read, write: if isAuthenticated();
      }
    }
  }

  function isAuthenticated() {
    return request.auth != null;
  }
}
```

---

### 2️⃣ Crear CallService Completo

**Archivo:** `lib/services/call_service.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'webrtc_service.dart';
import 'firestore_signaling.dart';

enum CallStatus { pending, ringing, active, ended, rejected }

class CallService {
  static final CallService _instance = CallService._internal();
  
  factory CallService() {
    return _instance;
  }
  
  CallService._internal();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _webrtcService = WebRTCService();
  final _signaling = FirestoreSignaling();

  String? _currentCallId;
  String? _currentRemoteUserId;
  CallStatus _callStatus = CallStatus.ended;

  // Getters
  String? get currentCallId => _currentCallId;
  String? get currentRemoteUserId => _currentRemoteUserId;
  CallStatus get callStatus => _callStatus;

  /// Iniciar una nueva llamada (Caller)
  Future<String> initiateCall({
    required String remoteUserId,
    required bool isVideo,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No authenticated user');

      // 1. Generar UUID único para la llamada
      final callId = const Uuid().v4();
      _currentCallId = callId;
      _currentRemoteUserId = remoteUserId;

      // 2. Crear documento de llamada en Firestore
      await _firestore.collection('calls').doc(callId).set({
        'callId': callId,
        'userId_caller': currentUser.uid,
        'userId_receiver': remoteUserId,
        'isVideo': isVideo,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'startedAt': null,
        'endedAt': null,
      });

      // 3. Iniciar WebRTC connection
      await _webrtcService.initConnection(isAudio: true, isVideo: isVideo);

      // 4. Configurar signaling con Firestore
      await _signaling.initializeSignaling(
        callId: callId,
        userId: currentUser.uid,
        remoteUserId: remoteUserId,
        isInitiator: true,
      );

      // 5. Crear offer SDP
      final offer = await _webrtcService.createOffer();
      
      // 6. Guardar offer en Firestore
      await _firestore
          .collection('calls')
          .doc(callId)
          .collection('sdp_offer')
          .doc(currentUser.uid)
          .set({
        'sdp': offer.sdp,
        'type': offer.type,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 7. Actualizar estado
      _callStatus = CallStatus.pending;

      // 8. Escuchar respuesta del receiver
      _listenForAnswer(callId, currentUser.uid, remoteUserId);

      return callId;
    } catch (e) {
      print('Error initiating call: $e');
      rethrow;
    }
  }

  /// Aceptar una llamada (Receiver)
  Future<void> acceptCall({required String callId}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No authenticated user');

      _currentCallId = callId;

      // 1. Obtener documento de la llamada
      final callDoc = await _firestore.collection('calls').doc(callId).get();
      final callData = callDoc.data() as Map<String, dynamic>;

      _currentRemoteUserId = callData['userId_caller'] as String;
      final isVideo = callData['isVideo'] as bool;

      // 2. Iniciar WebRTC
      await _webrtcService.initConnection(isAudio: true, isVideo: isVideo);

      // 3. Configurar signaling
      await _signaling.initializeSignaling(
        callId: callId,
        userId: currentUser.uid,
        remoteUserId: _currentRemoteUserId!,
        isInitiator: false,
      );

      // 4. Obtener offer del caller
      final offerDoc = await _firestore
          .collection('calls')
          .doc(callId)
          .collection('sdp_offer')
          .doc(_currentRemoteUserId)
          .get();

      final offerData = offerDoc.data() as Map<String, dynamic>;
      final offer = RTCSessionDescription(
        offerData['sdp'] as String,
        offerData['type'] as String,
      );

      // 5. Setear remote description
      await _webrtcService.peerConnection?.setRemoteDescription(offer);

      // 6. Crear answer
      final answer = await _webrtcService.createAnswer();

      // 7. Guardar answer en Firestore
      await _firestore
          .collection('calls')
          .doc(callId)
          .collection('sdp_offer')
          .doc(currentUser.uid)
          .set({
        'sdp': answer.sdp,
        'type': answer.type,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 8. Actualizar estado
      await _firestore.collection('calls').doc(callId).update({
        'status': 'active',
        'startedAt': FieldValue.serverTimestamp(),
      });

      _callStatus = CallStatus.active;

      // 9. Escuchar ICE candidates
      _listenForIceCandidates(callId, currentUser.uid, _currentRemoteUserId!);

    } catch (e) {
      print('Error accepting call: $e');
      rethrow;
    }
  }

  /// Rechazar una llamada
  Future<void> rejectCall({required String callId}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      await _firestore.collection('calls').doc(callId).update({
        'status': 'rejected',
        'rejectedBy': currentUser.uid,
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      _callStatus = CallStatus.rejected;
    } catch (e) {
      print('Error rejecting call: $e');
    }
  }

  /// Terminar una llamada
  Future<void> endCall({required String callId}) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      });

      await _webrtcService.closeConnection();
      _callStatus = CallStatus.ended;
      _currentCallId = null;
      _currentRemoteUserId = null;
    } catch (e) {
      print('Error ending call: $e');
    }
  }

  /// Escuchar cambios en el offer/answer
  void _listenForAnswer(String callId, String localUserId, String remoteUserId) {
    _firestore
        .collection('calls')
        .doc(callId)
        .collection('sdp_offer')
        .doc(remoteUserId)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final answer = RTCSessionDescription(
          data['sdp'] as String,
          data['type'] as String,
        );

        try {
          await _webrtcService.peerConnection?.setRemoteDescription(answer);
          _callStatus = CallStatus.active;
          _listenForIceCandidates(callId, localUserId, remoteUserId);
        } catch (e) {
          print('Error setting remote description: $e');
        }
      }
    });
  }

  /// Escuchar ICE candidates
  void _listenForIceCandidates(String callId, String localUserId, String remoteUserId) {
    _firestore
        .collection('calls')
        .doc(callId)
        .collection('ice_candidates')
        .doc(remoteUserId)
        .collection('candidates')
        .snapshots()
        .listen((snapshot) async {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final candidate = RTCIceCandidate(
          data['candidate'] as String,
          data['sdpMid'] as String,
          data['sdpMLineIndex'] as int,
        );

        try {
          await _webrtcService.peerConnection?.addIceCandidate(candidate);
        } catch (e) {
          print('Error adding ICE candidate: $e');
        }
      }
    });
  }

  /// Agregar ICE candidate (llamado desde WebRTCService)
  Future<void> addIceCandidateToFirestore(
    String callId,
    RTCIceCandidate candidate,
  ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      await _firestore
          .collection('calls')
          .doc(callId)
          .collection('ice_candidates')
          .doc(currentUser.uid)
          .collection('candidates')
          .add({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding ICE candidate to Firestore: $e');
    }
  }
}
```

---

### 3️⃣ Actualizar WebRTCService para Capturar Audio

**Archivo:** `lib/services/webrtc_service.dart` (agregar al initConnection):

```dart
Future<void> initConnection({
  required bool isAudio,
  required bool isVideo,
}) async {
  try {
    // Configuración de medios
    final mediaConstraints = <String, dynamic>{
      'audio': isAudio,
      'video': isVideo
          ? {
              'mandatory': {
                'minWidth': 640,
                'minHeight': 480,
                'minFrameRate': 30,
              },
              'facingMode': 'user',
              'optional': [],
            }
          : false,
    };

    // Obtener stream local
    localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

    // Agregar tracks al peer connection
    for (var track in localStream!.getTracks()) {
      await peerConnection?.addTrack(track, localStream!);
    }

    print('✅ Media initialized: audio=$isAudio, video=$isVideo');
  } catch (e) {
    print('❌ Error initializing connection: $e');
    rethrow;
  }
}
```

---

### 4️⃣ Crear Pantalla de Llamada Mejorada

**Archivo:** `lib/screens/communication/call_initiate_screen.dart` (NUEVA)

```dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../services/call_service.dart';

class CallInitiateScreen extends StatefulWidget {
  @override
  _CallInitiateScreenState createState() => _CallInitiateScreenState();
}

class _CallInitiateScreenState extends State<CallInitiateScreen> {
  final _callService = CallService();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  
  List<Map<String, dynamic>> _onlineUsers = [];
  bool _isVideo = false;

  @override
  void initState() {
    super.initState();
    _loadOnlineUsers();
  }

  void _loadOnlineUsers() {
    final currentUser = _auth.currentUser;
    _firestore
        .collection('users')
        .where('uid', isNotEqualTo: currentUser?.uid)
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _onlineUsers = snapshot.docs
            .map((doc) => {'uid': doc.id, ...doc.data()})
            .toList();
      });
    });
  }

  void _startCall(String remoteUserId) async {
    try {
      final callId = await _callService.initiateCall(
        remoteUserId: remoteUserId,
        isVideo: _isVideo,
      );

      Navigator.of(context).pushNamed(
        '/video-call',
        arguments: {'callId': callId, 'isInitiator': true},
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Iniciar Llamada')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.videocam),
                SizedBox(width: 8),
                Text('Video'),
                Switch(
                  value: _isVideo,
                  onChanged: (v) => setState(() => _isVideo = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _onlineUsers.length,
              itemBuilder: (context, index) {
                final user = _onlineUsers[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user['photoUrl'] != null
                        ? NetworkImage(user['photoUrl'])
                        : null,
                    child: user['photoUrl'] == null
                        ? Icon(Icons.person)
                        : null,
                  ),
                  title: Text(user['displayName'] ?? 'User'),
                  trailing: ElevatedButton(
                    onPressed: () => _startCall(user['uid']),
                    child: Text(_isVideo ? '📹' : '📞'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

---

### 5️⃣ Actualizar Video Call Screen

**Archivo:** `lib/screens/communication/video_call_screen.dart` (actualizar build):

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: Text('Llamada en Curso')),
    body: Stack(
      children: [
        // Remote video
        _buildRemoteVideo(),
        
        // Local video (picture-in-picture)
        Positioned(
          bottom: 80,
          right: 16,
          child: Container(
            width: 100,
            height: 150,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildLocalVideo(),
          ),
        ),

        // Controls
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FloatingActionButton(
                onPressed: _toggleMute,
                child: Icon(_isMuted ? Icons.mic_off : Icons.mic),
              ),
              SizedBox(width: 16),
              FloatingActionButton(
                onPressed: _toggleCamera,
                child: Icon(_cameraDisabled ? Icons.videocam_off : Icons.videocam),
              ),
              SizedBox(width: 16),
              FloatingActionButton(
                onPressed: _endCall,
                backgroundColor: Colors.red,
                child: Icon(Icons.call_end),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildRemoteVideo() {
  if (remoteVideoTrack == null) {
    return Center(child: Text('Esperando video del otro usuario...'));
  }
  return RTCVideoView(
    RTCVideoRenderer()..srcObject = remoteVideoTrack,
    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
  );
}

Widget _buildLocalVideo() {
  if (localVideoTrack == null) {
    return Center(child: Icon(Icons.videocam_off));
  }
  return RTCVideoView(
    RTCVideoRenderer()..srcObject = localVideoTrack,
    mirror: true,
    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
  );
}
```

---

## 📋 Workflow para 5 Usuarios

### Paso 1: Configurar 5 Usuarios en Firebase Console
```
1. Ir a Firebase Console > Authentication
2. Crear 5 usuarios de prueba:
   - user1@test.com / password123
   - user2@test.com / password123
   - user3@test.com / password123
   - user4@test.com / password123
   - user5@test.com / password123
```

### Paso 2: Ejecutar la App en 5 Dispositivos/Emuladores
```bash
# Terminal 1
flutter run -d emulator-5554

# Terminal 2
flutter run -d emulator-5556

# Terminal 3, 4, 5 (en otros dispositivos)
flutter run -d device-uuid
```

### Paso 3: Login y Probar Llamadas
```
Device 1 (user1):
  1. Login con user1@test.com
  2. Ver lista de usuarios online (user2, user3, user4, user5)
  3. Click en user2 → Llamada iniciada

Device 2 (user2):
  1. Login con user2@test.com
  2. Recibir notificación de llamada de user1
  3. Click "Aceptar" → Se abre video call
  4. Ver video/audio de user1
  5. Click "End Call" para terminar

Device 1 (user1):
  1. Ver video/audio de user2
  2. Pruebas:
     - Mute/Unmute
     - Toggle camera
     - End call
```

---

## 🔍 Monitoreo en Firebase Console

### Verificar Documentos Creados:
```
Firestore > calls > {callId}
├── status: "active"
├── userId_caller: "uid..."
├── userId_receiver: "uid..."
├── sdp_offer
│   ├── uid_caller: {sdp, type}
│   └── uid_receiver: {sdp, type}
└── ice_candidates
    ├── uid_caller
    │   └── candidates: [{...}, {...}]
    └── uid_receiver
        └── candidates: [{...}, {...}]
```

### Firebase Rules Checker:
- **Firestore Security Rules**: Validar que permitan lectura/escritura solo a usuarios autenticados
- **Verificar con**: `console.log(request.auth.uid)` en reglas

---

## ⚠️ Limitaciones Conocidas (Firebase P2P)

| Característica | ¿Soportado? | Nota |
|---|---|---|
| 1:1 Llamadas | ✅ | Funciona perfecto |
| Conferencias | ❌ | Max 2 usuarios |
| Grabación | ❌ | No disponible en P2P |
| Mensajes Automáticos | ❌ | Requiere notificaciones FCM |
| Presencia Automática | ⚠️ | Manual con Firestore |
| Escalabilidad | ⚠️ | Funciona para <20 users |

---

## 🚀 Siguiente Fase (Después de MVP)

Si necesitas >5 usuarios, cambiar a **Twilio**:

```dart
// FUTURO: Twilio integration
import 'package:twilio_programmable_video/twilio_programmable_video.dart';

// Esto reemplazaría CallService + WebRTCService
// Tiempo de migración: 2-3 semanas
// Costo: $1,500-3,000/mes
```

---

## ✅ Checklist de Implementación

- [ ] Crear Firestore rules
- [ ] Implementar CallService completo
- [ ] Actualizar WebRTCService (initConnection)
- [ ] Crear CallInitiateScreen
- [ ] Actualizar VideoCallScreen
- [ ] Crear 5 usuarios de prueba
- [ ] Ejecutar app en 5 dispositivos
- [ ] Probar 1:1 calls
- [ ] Probar mute/camera toggle
- [ ] Documentar issues encontrados
