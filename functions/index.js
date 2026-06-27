const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// ─────────────────────────────────────────────────────────────────────────────
// HELPER: obtener FCM token de un usuario
// ─────────────────────────────────────────────────────────────────────────────
async function getFcmToken(userId) {
  const doc = await db.collection('users').doc(userId).get();
  if (!doc.exists) return null;
  const token = doc.data().fcmToken;
  return token && token.trim().length > 0 ? token.trim() : null;
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER: enviar FCM a un token
// ─────────────────────────────────────────────────────────────────────────────
async function sendFcm(token, message) {
  try {
    await messaging.send({ token, ...message });
    functions.logger.info('[FCM] Enviado OK', { token: token.slice(0, 20) });
    return true;
  } catch (err) {
    functions.logger.warn('[FCM] Error enviando', { error: err.message });
    // Si el token es inválido lo limpiamos de Firestore
    if (
      err.code === 'messaging/registration-token-not-registered' ||
      err.code === 'messaging/invalid-registration-token'
    ) {
      await db
        .collection('users')
        .where('fcmToken', '==', token)
        .get()
        .then((snap) =>
          snap.docs.forEach((d) => d.ref.update({ fcmToken: admin.firestore.FieldValue.delete() }))
        )
        .catch(() => {});
    }
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FUNCIÓN 1: Notificación de nuevo mensaje de chat
// Se dispara cuando se crea un doc en /messages/{msgId}
// ─────────────────────────────────────────────────────────────────────────────
exports.onNewChatMessage = functions.firestore
  .document('messages/{msgId}')
  .onCreate(async (snap) => {
    const data = snap.data();
    const senderId = data.senderId || '';
    const roomId = data.roomId || '';
    const type = data.type || 'text';

    if (!senderId || !roomId) return null;

    // Obtener participantes de la sala
    const roomSnap = await db.collection('chatRooms').doc(roomId).get();
    if (!roomSnap.exists) return null;

    const participants = roomSnap.data().participants || [];
    const receiverId = participants.find((uid) => uid !== senderId);
    if (!receiverId) return null;

    // Obtener nombre del remitente
    const senderSnap = await db.collection('users_public').doc(senderId).get();
    const senderName =
      senderSnap.exists
        ? senderSnap.data().fullName || senderSnap.data().displayName || 'Usuario'
        : 'Usuario';

    // Construir preview del mensaje (sin revelar contenido cifrado)
    let preview = 'Nuevo mensaje';
    if (type === 'image') preview = '📷 Imagen';
    else if (type === 'audio') preview = '🎵 Nota de voz';
    else if (type === 'file') preview = '📎 Archivo';
    else if (type === 'text') preview = 'Nuevo mensaje de texto';

    const token = await getFcmToken(receiverId);
    if (!token) {
      functions.logger.warn('[Chat] Sin token para', { receiverId });
      return null;
    }

    return sendFcm(token, {
      notification: {
        title: senderName,
        body: preview,
      },
      data: {
        type: 'chat_message',
        roomId,
        senderId,
        senderName,
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'orbit_messages',
          priority: 'max',
          sound: 'default',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
    });
  });

// ─────────────────────────────────────────────────────────────────────────────
// FUNCIÓN 2: Notificación de llamada entrante
// Se dispara cuando se crea un doc en /calls/{callId}
// ─────────────────────────────────────────────────────────────────────────────
exports.onIncomingCall = functions.firestore
  .document('calls/{callId}')
  .onCreate(async (snap, context) => {
    const callId = context.params.callId;
    const data = snap.data();

    const callerId = data.callerId || '';
    const receiverId = data.receiverId || '';
    const isVideo = data.isVideo === true;
    const status = data.status || '';

    if (!callerId || !receiverId || status !== 'pending') return null;

    const callerName = data.callerName || 'Usuario';
    const callType = isVideo ? 'video' : 'voz';

    const token = await getFcmToken(receiverId);
    if (!token) {
      functions.logger.warn('[Call] Sin token para', { receiverId });
      return null;
    }

    const sent = await sendFcm(token, {
      // Sin notification block para que sea "data-only" y el handler de background
      // construya la pantalla de llamada con fullScreenIntent
      data: {
        type: 'incoming_call',
        callId,
        callSessionId: callId,
        callerId,
        callerName,
        callType,
        isVideo: String(isVideo),
        roomId: data.roomId || callId,
      },
      android: {
        priority: 'high',
        ttl: 30000, // 30 segundos — si no responde en ese tiempo se descarta
      },
    });

    if (sent) {
      await snap.ref.update({ fcmSent: true, fcmSentAt: admin.firestore.FieldValue.serverTimestamp() });
    }

    return null;
  });

// ─────────────────────────────────────────────────────────────────────────────
// FUNCIÓN 3: Notificación de llamada perdida
// Se dispara cuando el status de /calls/{callId} cambia a 'missed' o 'ended'
// sin haber sido aceptada
// ─────────────────────────────────────────────────────────────────────────────
exports.onCallStatusChanged = functions.firestore
  .document('calls/{callId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Solo procesar cuando cambia a 'missed'
    if (before.status === after.status) return null;
    if (after.status !== 'missed') return null;

    const receiverId = after.receiverId || '';
    const callerId = after.callerId || '';
    const callerName = after.callerName || 'Usuario';

    if (!receiverId) return null;

    const token = await getFcmToken(receiverId);
    if (!token) return null;

    return sendFcm(token, {
      notification: {
        title: 'Llamada perdida',
        body: `${callerName} intentó llamarte`,
      },
      data: {
        type: 'missed_call',
        callerId,
        callerName,
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'orbit_messages',
          priority: 'high',
          sound: 'default',
        },
      },
    });
  });
