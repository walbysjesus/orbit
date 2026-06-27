import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../domain/entities/message_entity.dart';
import '../../presentation/widgets/chat_bubble.dart';
import 'video_call_screen.dart';
import '../../services/e2e_chat_crypto_service.dart';
import '../../services/fcm_service.dart';
import '../../services/resilient_stream_helper.dart';
import '../../utils/error_presenter.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String remoteUserId;
  final String? initialContactName;

  const ChatScreen({
    super.key,
    required this.remoteUserId,
    this.initialContactName,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const int _pageSize = 20;
  static const int _maxInMemoryMessages = 600;
  static const int _maxAttachmentBytes = 10 * 1024 * 1024;
  static const Set<String> _allowedAttachmentExtensions = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'pdf',
    'txt',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'zip',
    'rar',
    'mp3',
    'm4a',
    'wav',
    'ogg',
    'mp4',
  };

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final E2EChatCryptoService _crypto = E2EChatCryptoService();
  Future<void>? _cryptoInitFuture;

  bool _showEmojiPicker = false;
  bool _uploading = false;
  bool _isRecordingAudio = false;
  bool _sendingAudio = false;
  int _recordingSeconds = 0;
  bool _initializing = true;
  bool _markingRoomAsRead = false;
  Timer? _readReceiptDebounceTimer;
  DateTime? _pendingReadReceiptAt;
  DateTime? _lastReadReceiptSentAt;

  MessageEntity? _replyTo;
  String? _roomId;
  String? _contactName;
  Map<String, dynamic>? _roomData;
  List<Map<String, dynamic>> _messages = [];
  final Set<String> _hiddenMessageIds = <String>{};
  bool _showScrollToBottomFab = false;

  // Mensajes pendientes (optimista): se muestran inmediatamente y se eliminan al confirmar.
  final List<Map<String, dynamic>> _pendingMessages = [];

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _messagesSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomSubscription;
  ResilientStreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _messagesResilient;
  ResilientStreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _roomResilient;
  Timer? _recordingTimer;

  bool _hasMore = true;
  bool _loadingMoreMessages = false;
  bool _legacyFallbackLoaded = false;
  bool _legacyMirrorEnabled = true;
  QueryDocumentSnapshot<Map<String, dynamic>>? _oldestMessageDoc;
  bool _isAtBottom = true;
  String? _selectedMessageId;
  String _connectionStateLabel = 'Conectando...';
  RealtimeUxState _connectionState = RealtimeUxState.reconnecting;
  ResilientStreamStatus _roomStreamStatus = ResilientStreamStatus.connecting;
  ResilientStreamStatus _messagesStreamStatus =
      ResilientStreamStatus.connecting;

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _remoteUserId => widget.remoteUserId.trim();

  bool get _fallbackLooksLikeUid {
    final v = widget.remoteUserId.trim();
    // Heurística simple para IDs tipo Firebase UID (alfa-numérico largo, sin espacios).
    return v.length >= 20 &&
        !v.contains(' ') &&
        RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(v);
  }

  String get _contactTitle {
    final resolved = (_contactName ?? '').trim();
    if (resolved.isNotEmpty) return resolved;
    if ((widget.initialContactName ?? '').trim().isNotEmpty) {
      return widget.initialContactName!.trim();
    }
    if (_fallbackLooksLikeUid) return 'Cargando contacto...';
    return widget.remoteUserId;
  }

  @override
  void initState() {
    super.initState();
    FCMService.setActiveChatPeer(widget.remoteUserId);
    final initialName = (widget.initialContactName ?? '').trim();
    if (initialName.isNotEmpty) {
      _contactName = initialName;
    }
    _cryptoInitFuture = _crypto.initialize();
    unawaited(_initRecorder());
    unawaited(_loadContactName());
    _bootstrapRoom();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _initRecorder() async {
    try {
      await _recorder.openRecorder();
    } catch (_) {
      // Ignorar: se manejará al intentar grabar.
    }
  }

  Future<void> _loadContactName() async {
    if (_remoteUserId.isEmpty) return;
    try {
      final snap =
          await _db.collection('users_public').doc(_remoteUserId).get();
      if (!mounted) return; // lifecycle safety fix
      final data = snap.data();
      final publicName =
          ((data?['fullName'] ?? data?['displayName'] ?? '') as Object)
              .toString()
              .trim();

      if (publicName.isNotEmpty) {
        if (mounted) {
          setState(() => _contactName = publicName);
        }
        return;
      }

      final currentUid = _currentUserId;
      if (currentUid.isEmpty) return;

      // Fallback: usa el nombre local guardado en contactos del usuario actual.
      final localContactSnap = await _db
          .collection('users')
          .doc(currentUid)
          .collection('contacts')
          .doc(_remoteUserId)
          .get();
      if (!mounted) return; // lifecycle safety fix
      final localData = localContactSnap.data();
      final localName =
          ((localData?['fullName'] ?? '') as Object).toString().trim();

      if (mounted && localName.isNotEmpty) {
        setState(() => _contactName = localName);
      }
    } catch (_) {
      // Fallback de error: intenta resolver nombre desde contactos locales.
      try {
        final currentUid = _currentUserId;
        if (currentUid.isEmpty || !mounted) return;
        final localContactSnap = await _db
            .collection('users')
            .doc(currentUid)
            .collection('contacts')
            .doc(_remoteUserId)
            .get();
        final localData = localContactSnap.data();
        final localName =
            ((localData?['fullName'] ?? '') as Object).toString().trim();
        if (mounted && localName.isNotEmpty) {
          setState(() => _contactName = localName);
        }
      } catch (_) {
        // Ignorar para no afectar apertura del chat.
      }
    }
  }

  Future<void> _bootstrapRoom() async {
    try {
      final currentUid = _currentUserId;
      if (currentUid.isEmpty || _remoteUserId.isEmpty) {
        if (!mounted) return;
        setState(() => _initializing = false);
        if (currentUid.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debes iniciar sesión para usar el chat'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final sortedIds = [currentUid, _remoteUserId]..sort();
      final deterministicRoomId = '${sortedIds[0]}_${sortedIds[1]}';
      final deterministicRef =
          _db.collection('chatRooms').doc(deterministicRoomId);
      final deterministicSnap = await deterministicRef.get();
      if (!mounted) return; // lifecycle safety fix

      String resolvedRoomId = deterministicRoomId;

      if (!deterministicSnap.exists) {
        final fallbackQuery = await _db
            .collection('chatRooms')
            .where('participants', arrayContains: currentUid)
            .limit(100)
            .get();
        if (!mounted) return; // lifecycle safety fix

        final existing = fallbackQuery.docs.where((doc) {
          final participants = List<String>.from(
              (doc.data()['participants'] as List?) ?? const []);
          return participants.contains(_remoteUserId);
        }).toList();

        if (existing.isNotEmpty) {
          resolvedRoomId = existing.first.id;
        } else {
          await deterministicRef.set({
            'participants': [currentUid, _remoteUserId],
            'createdBy': currentUid,
            'title': '',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          if (!mounted) return; // lifecycle safety fix
        }
      }

      if (!mounted) return;
      setState(() {
        _roomId = resolvedRoomId;
        _initializing = false;
      });

      unawaited(_resolveRoomWritePolicy(resolvedRoomId));

      _subscribeRoom();
      _subscribeMessages();
      unawaited(_markRoomAsRead(force: true));

      unawaited(_loadContactName());
    } catch (e) {
      if (!mounted) return;
      setState(() => _initializing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo inicializar el chat: $e')),
      );
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final atBottom = pos.pixels >= pos.maxScrollExtent - 50;

    if (atBottom != _isAtBottom) {
      setState(() {
        _isAtBottom = atBottom;
        _showScrollToBottomFab = !atBottom;
      });
    }

    if (pos.pixels <= 100 && _hasMore) {
      unawaited(_loadOlderMessages());
    }

    if (_isAtBottom) {
      unawaited(_scheduleReadReceiptFlush());
    }
  }

  Future<void> _resolveRoomWritePolicy(String roomId) async {
    try {
      final snap = await _db.collection('chatRooms').doc(roomId).get();
      if (!mounted || !snap.exists) return;
      final data = snap.data() ?? const <String, dynamic>{};
      final mirror = data['legacyMessageMirror'];
      if (mirror is bool) {
        if (mounted) setState(() => _legacyMirrorEnabled = mirror);
      } else if (mirror == null) {
        // Default to compat mode for existing rooms.
        await _db.collection('chatRooms').doc(roomId).set({
          'legacyMessageMirror': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {
      // Keep safe default: mirror legacy writes if the policy cannot be read.
    }
  }

  void _subscribeRoom() {
    final roomId = _roomId;
    if (roomId == null) return;

    unawaited(_roomResilient?.cancel());
    _roomSubscription?.cancel();
    _roomResilient =
        ResilientStreamSubscription<DocumentSnapshot<Map<String, dynamic>>>(
      streamFactory: () => _db.collection('chatRooms').doc(roomId).snapshots(),
      timeout: const Duration(seconds: 15),
      logTag: 'ChatRoomStream:$roomId',
      onStatus: (status) {
        _applyConnectionStatus(status, isRoomStream: true);
      },
      onError: (error, _) {
        debugPrint('[ChatRoomStream:$roomId] error=$error');
      },
      onData: (snap) {
        if (!mounted) return;
        setState(() {
          _roomData = snap.data();
        });
      },
    );
    _roomResilient!.start();
  }

  void _subscribeMessages() {
    final roomId = _roomId;
    if (roomId == null) return;

    unawaited(_messagesResilient?.cancel());
    _messagesSubscription?.cancel();
    _oldestMessageDoc = null;
    _hasMore = true;
    _legacyFallbackLoaded = false;

    _messagesResilient =
        ResilientStreamSubscription<QuerySnapshot<Map<String, dynamic>>>(
      streamFactory: () => _db
          .collection('messages')
          .where('roomId', isEqualTo: roomId)
          .orderBy('timestamp', descending: true)
          .limit(_pageSize)
          .snapshots(includeMetadataChanges: true),
      timeout: const Duration(seconds: 15),
      logTag: 'ChatMessagesStream:$roomId',
      onStatus: (status) {
        _applyConnectionStatus(status, isRoomStream: false);
      },
      onError: (error, _) {
        debugPrint('[ChatMessagesStream:$roomId] error=$error');
      },
      onData: (snap) {
        if (!mounted) return; // lifecycle safety fix
        final uid = _currentUserId;
        final latestBatch = snap.docs.reversed.map((doc) {
          return _messageFromDoc(doc, currentUserId: uid);
        }).where((msg) {
          final id = (msg['id'] ?? '').toString();
          return id.isNotEmpty && !_hiddenMessageIds.contains(id);
        }).toList();

        if (snap.docs.isNotEmpty) {
          _oldestMessageDoc = snap.docs.last;
        }

        if (snap.docs.isEmpty && _messages.isEmpty && !_legacyFallbackLoaded) {
          _legacyFallbackLoaded = true;
          unawaited(_loadLegacyMessagesOnce(roomId));
        }

        final latestIds = latestBatch
            .map((m) => (m['id'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toSet();

        final preservedOlder = _messages
            .where((m) => !latestIds.contains((m['id'] ?? '').toString()))
            .toList();

        final msgs = [...latestBatch, ...preservedOlder];
        msgs.sort((a, b) {
          final ta = _extractTimestamp(a)?.millisecondsSinceEpoch ?? 0;
          final tb = _extractTimestamp(b)?.millisecondsSinceEpoch ?? 0;
          return ta.compareTo(tb);
        });

        final trimmed = _trimForLargeChats(msgs);

        setState(() {
          _messages = trimmed;
          _hasMore = snap.docs.length == _pageSize;
        });

        if (_isAtBottom) _scrollToBottom();
        unawaited(_markRoomAsRead());
      },
    );
    _messagesResilient!.start();
  }

  void _applyConnectionStatus(
    ResilientStreamStatus status, {
    required bool isRoomStream,
  }) {
    if (!mounted) return;
    if (isRoomStream) {
      _roomStreamStatus = status;
    } else {
      _messagesStreamStatus = status;
    }

    String label;
    RealtimeUxState nextState;
    final hasOffline = _roomStreamStatus == ResilientStreamStatus.timeout ||
        _roomStreamStatus == ResilientStreamStatus.offline ||
        _messagesStreamStatus == ResilientStreamStatus.timeout ||
        _messagesStreamStatus == ResilientStreamStatus.offline;
    final hasReconnecting =
        _roomStreamStatus == ResilientStreamStatus.connecting ||
            _roomStreamStatus == ResilientStreamStatus.reconnecting ||
            _messagesStreamStatus == ResilientStreamStatus.connecting ||
            _messagesStreamStatus == ResilientStreamStatus.reconnecting;

    if (hasOffline) {
      label = status == ResilientStreamStatus.timeout
          ? 'Sin conexión (timeout). Reintentando...'
          : 'Sin conexión';
      nextState = status == ResilientStreamStatus.timeout
          ? RealtimeUxState.timeout
          : RealtimeUxState.offline;
      if (_initializing) {
        // lifecycle safety fix
        setState(() => _initializing = false);
      }
    } else if (hasReconnecting) {
      label = 'Reconectando...';
      nextState = RealtimeUxState.reconnecting;
    } else {
      label = 'En línea';
      nextState = RealtimeUxState.online;
    }

    if (_connectionStateLabel != label || _connectionState != nextState) {
      setState(() {
        _connectionStateLabel = label;
        _connectionState = nextState;
      });
    }
  }

  Future<void> _loadOlderMessages() async {
    final roomId = _roomId;
    if (roomId == null || _loadingMoreMessages || !_hasMore) return;
    final cursor = _oldestMessageDoc;
    if (cursor == null) return;

    _loadingMoreMessages = true;
    try {
      final snap = await _runWithFirestoreRetry(() {
        return _db
            .collection('messages')
            .where('roomId', isEqualTo: roomId)
            .orderBy('timestamp', descending: true)
            .startAfterDocument(cursor)
            .limit(_pageSize)
            .get();
      });

      if (snap.docs.isNotEmpty) {
        _oldestMessageDoc = snap.docs.last;
      }

      final uid = _currentUserId;
      final olderBatch = snap.docs.reversed.map((doc) {
        return _messageFromDoc(doc, currentUserId: uid);
      }).where((msg) {
        final id = (msg['id'] ?? '').toString();
        return id.isNotEmpty && !_hiddenMessageIds.contains(id);
      }).toList();

      if (!mounted) return;
      setState(() {
        final existingIds = _messages
            .map((m) => (m['id'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toSet();
        final toInsert = olderBatch
            .where((m) => !existingIds.contains((m['id'] ?? '').toString()))
            .toList();
        _messages = [...toInsert, ..._messages];
        _hasMore = snap.docs.length == _pageSize;
      });
    } catch (_) {
      // Retry helper already attempted; keep UX silent for intermittent links.
    } finally {
      _loadingMoreMessages = false;
    }
  }

  Future<void> _loadLegacyMessagesOnce(String roomId) async {
    try {
      final snap = await _runWithFirestoreRetry(() {
        return _db
            .collection('chatRooms')
            .doc(roomId)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(_pageSize)
            .get();
      });

      final uid = _currentUserId;
      final legacy = snap.docs.reversed.map((doc) {
        final data = doc.data();
        final senderId = (data['senderId'] ?? '').toString();
        final rawText = (data['text'] ?? '').toString();
        final normalizedType = (data['type'] ?? 'text').toString();
        final metadata = (data['metadata'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};

        return {
          ...data,
          'id': doc.id,
          'fromMe': senderId == uid,
          'userId': senderId,
          'userName': senderId == uid ? 'Tu' : 'Contacto',
          'text': _decodeStoredText(rawText),
          'type': normalizedType,
          'replyTo': metadata['replyTo'],
          'replyToText': metadata['replyToText'],
          'attachment': _decodeNullableCipher(data['fileUrl']) ??
              _decodeNullableCipher(data['audioUrl']),
          'status': _statusForMessage(
            fromMe: senderId == uid,
            timestamp: data['timestamp'] as Timestamp?,
            fallbackType: normalizedType,
          ),
        };
      }).where((msg) {
        final id = (msg['id'] ?? '').toString();
        return id.isNotEmpty && !_hiddenMessageIds.contains(id);
      }).toList();

      if (!mounted || legacy.isEmpty) return;
      setState(() {
        if (_messages.isEmpty) {
          _messages = legacy;
          _hasMore = snap.docs.length == _pageSize;
        }
      });
    } catch (_) {
      // Legacy fallback is best-effort only.
    }
  }

  Map<String, dynamic> _messageFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required String currentUserId,
  }) {
    final data = doc.data();
    final senderId = (data['senderId'] ?? '').toString();
    final rawText = (data['text'] ?? '').toString();
    final normalizedType = (data['type'] ?? 'text').toString();
    final metadata = (data['metadata'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final resolvedTimestamp = _messageTimestamp(data);
    final isFromMe = senderId == currentUserId;

    final replyToTextRaw = _nullableString(metadata['replyToText']);
    final replyToTextDecoded =
        replyToTextRaw == null ? null : _decodeStoredText(replyToTextRaw);

    return {
      ...data,
      'timestamp': resolvedTimestamp,
      'id': doc.id,
      'fromMe': isFromMe,
      'userId': senderId,
      'userName': isFromMe ? 'Tu' : 'Contacto',
      'text': _decodeStoredText(rawText),
      'type': normalizedType,
      'replyTo': metadata['replyTo'],
      'replyToText': replyToTextDecoded,
      'attachment': _decodeNullableCipher(data['fileUrl']) ??
          _decodeNullableCipher(data['audioUrl']),
      'status': _statusForMessage(
        fromMe: isFromMe,
        timestamp: resolvedTimestamp,
        fallbackType: normalizedType,
        hasPendingWrites: doc.metadata.hasPendingWrites,
      ),
    };
  }

  Timestamp? _messageTimestamp(Map<String, dynamic> data) {
    return data['timestamp'] as Timestamp? ?? data['createdAt'] as Timestamp?;
  }

  DateTime? _extractTimestamp(Map<String, dynamic> message) {
    final ts = message['timestamp'] as Timestamp?;
    return ts?.toDate();
  }

  String? _decodeNullableCipher(Object? value) {
    final raw = _nullableString(value);
    if (raw == null) return null;
    return _decodeStoredText(raw);
  }

  List<Map<String, dynamic>> _trimForLargeChats(
      List<Map<String, dynamic>> src) {
    if (src.length <= _maxInMemoryMessages) return src;
    return src.sublist(src.length - _maxInMemoryMessages);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _decodeStoredText(String rawText) {
    final value = rawText.trim();
    if (value.isEmpty) return '';

    // Formato actual en esta pantalla: e2er1:texto_plano
    const plainMarker = 'e2er1:';
    if (value.startsWith(plainMarker) && value.split(':').length == 2) {
      return value.substring(plainMarker.length);
    }

    final roomId = _roomId;
    if (roomId != null && roomId.isNotEmpty) {
      // Soporta payload moderno del servicio E2E: e2er1:iv:cipher
      final decryptedMarked =
          _crypto.decryptForRoom(roomId: roomId, cipherText: value);
      if (decryptedMarked != value) {
        return decryptedMarked;
      }

      // Soporta payload legacy sin marcador: iv:cipher
      if (_looksLikeLegacyIvCipher(value)) {
        final wrapped = 'e2er1:$value';
        final decryptedLegacy =
            _crypto.decryptForRoom(roomId: roomId, cipherText: wrapped);
        if (decryptedLegacy != wrapped && decryptedLegacy != value) {
          return decryptedLegacy;
        }
      }
    }

    // Soporta payload local del servicio: e2el1:iv:cipher
    try {
      final local = _crypto.decryptLocal(value);
      if (local != value) return local;
    } catch (_) {
      // Cifrado local no inicializado o payload inválido.
    }

    // Evitar mostrar crudo un payload cifrado no compatible.
    if (_looksLikeCipherPayload(value)) {
      return 'Mensaje cifrado';
    }

    return rawText;
  }

  bool _looksLikeLegacyIvCipher(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return false;
    return _isBase64(parts[0]) && _isBase64(parts[1]);
  }

  bool _looksLikeCipherPayload(String value) {
    if (_looksLikeLegacyIvCipher(value)) return true;
    if (value.startsWith('e2er2:') || value.startsWith('e2el2:')) {
      final parts = value.split(':');
      if (parts.length == 6) {
        return _isBase64(parts[3]) &&
            _isBase64(parts[4]) &&
            _isBase64(parts[5]);
      }
      return true;
    }
    if (value.startsWith('e2er1:') || value.startsWith('e2el1:')) {
      final parts = value.split(':');
      if (parts.length >= 3) {
        return _isBase64(parts[1]) && _isBase64(parts.sublist(2).join(':'));
      }
    }
    return false;
  }

  bool _isBase64(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    try {
      base64Decode(t);
      return true;
    } catch (_) {
      return false;
    }
  }

  String? _nullableString(Object? value) {
    final v = (value ?? '').toString().trim();
    return v.isEmpty ? null : v;
  }

  String _statusForMessage({
    required bool fromMe,
    required Timestamp? timestamp,
    required String fallbackType,
    bool hasPendingWrites = false,
  }) {
    if (!fromMe) return '';
    if (hasPendingWrites) return 'sending';
    if (timestamp == null) return 'sent';

    final seenKey = 'lastSeen_$_remoteUserId';
    final seenTs = _roomData?[seenKey] as Timestamp?;
    if (seenTs != null) {
      final msgTime = timestamp.toDate();
      final seenTime = seenTs.toDate();
      if (!msgTime.isAfter(seenTime)) {
        return 'seen';
      }
    }

    if (fallbackType == 'text' ||
        fallbackType == 'image' ||
        fallbackType == 'file') {
      return 'delivered';
    }
    return 'sent';
  }

  Future<void> _markRoomAsRead({bool force = false}) async {
    await _scheduleReadReceiptFlush(force: force);
  }

  Future<void> _scheduleReadReceiptFlush({bool force = false}) async {
    final roomId = _roomId;
    if (roomId == null || _currentUserId.isEmpty) return;

    final now = DateTime.now();
    _pendingReadReceiptAt = now;

    if (_readReceiptDebounceTimer != null) {
      _readReceiptDebounceTimer!.cancel();
    }

    final elapsedSinceLastSend = _lastReadReceiptSentAt == null
        ? null
        : now.difference(_lastReadReceiptSentAt!).inMilliseconds;
    final canSendNow =
        force || elapsedSinceLastSend == null || elapsedSinceLastSend >= 5000;

    if (!canSendNow) {
      _readReceiptDebounceTimer = Timer(const Duration(seconds: 2), () {
        unawaited(_flushReadReceipt());
      });
      return;
    }

    _readReceiptDebounceTimer = Timer(Duration.zero, () {
      unawaited(_flushReadReceipt());
    });
  }

  Future<void> _flushReadReceipt() async {
    final roomId = _roomId;
    final pendingAt = _pendingReadReceiptAt;
    if (roomId == null || _currentUserId.isEmpty || pendingAt == null) return;
    if (_markingRoomAsRead) return;

    _markingRoomAsRead = true;

    try {
      await _db.collection('chatRooms').doc(roomId).set({
        'unread_$_currentUserId': 0,
        'lastReadAt_$_currentUserId': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _lastReadReceiptSentAt = DateTime.now();
    } catch (_) {
      // Se reintentará en el próximo evento del stream/scroll.
    } finally {
      _markingRoomAsRead = false;
    }
  }

  Future<void> _sendMessage() async {
    final roomId = _roomId;
    final text = _controller.text.trim();
    if (roomId == null ||
        text.isEmpty ||
        _currentUserId.isEmpty ||
        _remoteUserId.isEmpty) {
      return;
    }

    try {
      await _ensureCryptoReady();
    } catch (e) {
      if (!mounted) return;
      ErrorPresenter.showSnack(
        context,
        ErrorPresenter.humanize(
          e,
          fallback: 'No se pudo inicializar el cifrado del chat.',
        ),
        state: RealtimeUxState.error,
      );
      return;
    }

    final replySnapshot = _replyTo;
    final pendingId = 'pending_${DateTime.now().microsecondsSinceEpoch}';

    _controller.clear();

    // Mostrar mensaje optimista inmediatamente.
    setState(() {
      _pendingMessages.add({
        'id': pendingId,
        'fromMe': true,
        'senderId': _currentUserId,
        'text': text,
        'type': 'text',
        'status': 'queued',
        'timestamp': null,
      });
      _replyTo = null;
    });
    _scrollToBottom();

    const maxAttempts = 3;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        _updatePendingMessageStatus(pendingId, 'sending');
        final batch = _db.batch();
        final msgRef = _db.collection('messages').doc();
        final safeText =
            _crypto.encryptForRoom(roomId: roomId, plainText: text);
        final encryptedReplyText = replySnapshot == null
            ? null
            : _crypto.encryptForRoom(
                roomId: roomId,
                plainText: replySnapshot.text,
              );

        batch.set(msgRef, {
          'roomId': roomId,
          'senderId': _currentUserId,
          'text': safeText,
          'type': 'text',
          'fileUrl': '',
          'audioUrl': '',
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'metadata': {
            'replyTo': replySnapshot?.id,
            'replyToText': encryptedReplyText,
          },
        });

        if (_legacyMirrorEnabled) {
          batch.set(
            _db
                .collection('chatRooms')
                .doc(roomId)
                .collection('messages')
                .doc(msgRef.id),
            {
              'senderId': _currentUserId,
              'text': safeText,
              'type': 'text',
              'fileUrl': '',
              'audioUrl': '',
              'timestamp': FieldValue.serverTimestamp(),
              'metadata': {
                'replyTo': replySnapshot?.id,
                'replyToText': encryptedReplyText,
              },
            },
          );
        }

        batch.update(_db.collection('chatRooms').doc(roomId), {
          'lastMessage': 'Nuevo mensaje',
          'lastMessageType': 'text',
          'updatedAt': FieldValue.serverTimestamp(),
          'unread_$_remoteUserId': FieldValue.increment(1),
        });

        await _runWithFirestoreRetry(() => batch.commit()).timeout(
          const Duration(seconds: 30),
        );

        if (!mounted) return; // lifecycle safety fix

        // Éxito: quitar el optimista (el stream lo trae con id real).
        setState(() {
          _pendingMessages.removeWhere((m) => m['id'] == pendingId);
        });
        unawaited(_markRoomAsRead(force: true));
        return;
      } on TimeoutException catch (e) {
        _updatePendingMessageStatus(pendingId, 'queued');
        if (mounted) {
          ErrorPresenter.showSnack(
            context,
            ErrorPresenter.humanize(e),
            state: RealtimeUxState.timeout,
            actionLabel: 'Reintentar',
            onAction: () {
              if (!mounted) return;
              setState(() {
                _pendingMessages.removeWhere((m) => m['id'] == pendingId);
                _controller.text = text;
              });
            },
          );
        }
      } catch (e) {
        if (attempt == maxAttempts) {
          if (mounted) {
            setState(() {
              final idx =
                  _pendingMessages.indexWhere((m) => m['id'] == pendingId);
              if (idx != -1) _pendingMessages[idx]['status'] = 'failed';
            });
            ErrorPresenter.showSnack(
              context,
              ErrorPresenter.humanize(
                e,
                fallback: 'No se pudo enviar el mensaje.',
              ),
              state: RealtimeUxState.error,
              actionLabel: 'Reintentar',
              onAction: () {
                if (!mounted) return;
                setState(() {
                  _pendingMessages.removeWhere((m) => m['id'] == pendingId);
                  _controller.text = text;
                });
              },
            );
          }
        } else {
          _updatePendingMessageStatus(pendingId, 'queued');
          await Future.delayed(
              Duration(milliseconds: 600 * attempt)); // backoff simple
          if (!mounted) return; // lifecycle safety fix
        }
      }
    }
  }

  void _updatePendingMessageStatus(String pendingId, String status) {
    if (!mounted) return;
    setState(() {
      final idx = _pendingMessages.indexWhere((m) => m['id'] == pendingId);
      if (idx != -1) {
        _pendingMessages[idx]['status'] = status;
      }
    });
  }

  Future<void> _pickAttachment() async {
    final roomId = _roomId;
    if (roomId == null || _currentUserId.isEmpty || _remoteUserId.isEmpty) {
      return;
    }

    try {
      await _ensureCryptoReady();
    } catch (e) {
      if (!mounted) return;
      ErrorPresenter.showSnack(
        context,
        ErrorPresenter.humanize(
          e,
          fallback: 'No se pudo inicializar el cifrado del chat.',
        ),
        state: RealtimeUxState.error,
      );
      return;
    }

    setState(() => _uploading = true);
    try {
      final result = await FilePicker.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      final extension = (file.extension ?? '').toLowerCase();
      if (!_allowedAttachmentExtensions.contains(extension)) {
        if (!mounted) return;
        ErrorPresenter.showSnack(
          context,
          'Tipo de archivo no permitido.',
          state: RealtimeUxState.error,
        );
        return;
      }

      if (file.size > _maxAttachmentBytes) {
        if (!mounted) return;
        ErrorPresenter.showSnack(
          context,
          'El archivo supera 10 MB.',
          state: RealtimeUxState.error,
        );
        return;
      }

      final storagePath =
          'chatRooms/$roomId/attachments/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final ref = _storage.ref().child(storagePath);
      final contentType = _contentTypeForExtension(extension);
      final metadata = contentType == null
          ? null
          : SettableMetadata(contentType: contentType);

      if (file.bytes != null) {
        await _runWithFirestoreRetry(() => ref.putData(file.bytes!, metadata));
      } else if (file.path != null) {
        await _runWithFirestoreRetry(
            () => ref.putFile(File(file.path!), metadata));
      } else {
        if (!mounted) return;
        ErrorPresenter.showSnack(
          context,
          'No se pudo leer el archivo seleccionado.',
          state: RealtimeUxState.error,
        );
        return;
      }

      final url = await _runWithFirestoreRetry(() => ref.getDownloadURL());
      final encryptedUrl =
          _crypto.encryptForRoom(roomId: roomId, plainText: url);
      final text = _controller.text.trim();
      final encryptedText = text.isEmpty
          ? ''
          : _crypto.encryptForRoom(roomId: roomId, plainText: text);
      final messageType =
          {'jpg', 'jpeg', 'png', 'gif', 'webp'}.contains(extension)
              ? 'image'
              : 'file';

      final batch = _db.batch();
      final msgRef = _db.collection('messages').doc();
      final encryptedReplyText = _replyTo == null
          ? null
          : _crypto.encryptForRoom(roomId: roomId, plainText: _replyTo!.text);

      batch.set(msgRef, {
        'roomId': roomId,
        'senderId': _currentUserId,
        'text': encryptedText,
        'type': messageType,
        'fileUrl': encryptedUrl,
        'audioUrl': '',
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'metadata': {
          'fileName': file.name,
          'fileSize': file.size,
          'replyTo': _replyTo?.id,
          'replyToText': encryptedReplyText,
        },
      });

      if (_legacyMirrorEnabled) {
        batch.set(
          _db
              .collection('chatRooms')
              .doc(roomId)
              .collection('messages')
              .doc(msgRef.id),
          {
            'senderId': _currentUserId,
            'text': encryptedText,
            'type': messageType,
            'fileUrl': encryptedUrl,
            'audioUrl': '',
            'timestamp': FieldValue.serverTimestamp(),
            'metadata': {
              'fileName': file.name,
              'fileSize': file.size,
              'replyTo': _replyTo?.id,
              'replyToText': encryptedReplyText,
            },
          },
        );
      }

      batch.update(_db.collection('chatRooms').doc(roomId), {
        'lastMessage': messageType == 'image' ? 'Imagen' : 'Archivo',
        'lastMessageType': messageType,
        'updatedAt': FieldValue.serverTimestamp(),
        'unread_$_remoteUserId': FieldValue.increment(1),
      });

      await _runWithFirestoreRetry(() => batch.commit());

      if (!mounted) return;
      ErrorPresenter.showSnack(
        context,
        'Archivo enviado: ${file.name}',
        state: RealtimeUxState.delivered,
      );
      _controller.clear();
      setState(() => _replyTo = null);
      unawaited(_markRoomAsRead(force: true));
    } catch (e) {
      if (!mounted) return;
      ErrorPresenter.showSnack(
        context,
        ErrorPresenter.humanize(e, fallback: 'Error al subir archivo.'),
        state: RealtimeUxState.error,
      );
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  Future<String> _newAudioTempPath() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
  }

  Future<void> _toggleRecordingAudio() async {
    if (_isRecordingAudio) {
      final path = await _recorder.stopRecorder();
      if (!mounted) return;
      _recordingTimer?.cancel();
      final durationMs = _recordingSeconds * 1000;
      setState(() => _isRecordingAudio = false);
      if (path != null && path.trim().isNotEmpty) {
        await _sendAudioMessage(path, durationMs: durationMs);
      }
      return;
    }

    final roomId = _roomId;
    if (roomId == null || _currentUserId.isEmpty || _remoteUserId.isEmpty) {
      ErrorPresenter.showSnack(
        context,
        'No se pudo iniciar la grabación.',
        state: RealtimeUxState.error,
      );
      return;
    }

    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      if (!mounted) return;
      ErrorPresenter.showSnack(
        context,
        'Permiso de micrófono denegado.',
        state: RealtimeUxState.error,
      );
      return;
    }

    try {
      final path = await _newAudioTempPath();
      await _recorder.startRecorder(
        toFile: path,
        codec: Codec.aacADTS,
      );
      if (!mounted) return;
      _recordingTimer?.cancel();
      setState(() {
        _isRecordingAudio = true;
        _recordingSeconds = 0;
      });
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recordingSeconds++);
      });
    } catch (e) {
      if (!mounted) return;
      ErrorPresenter.showSnack(
        context,
        ErrorPresenter.humanize(e, fallback: 'No se pudo grabar audio.'),
        state: RealtimeUxState.error,
      );
    }
  }

  Future<void> _sendAudioMessage(String localPath,
      {required int durationMs}) async {
    final roomId = _roomId;
    if (roomId == null || _currentUserId.isEmpty || _remoteUserId.isEmpty) {
      return;
    }

    try {
      await _ensureCryptoReady();
    } catch (e) {
      if (!mounted) return;
      ErrorPresenter.showSnack(
        context,
        ErrorPresenter.humanize(
          e,
          fallback: 'No se pudo inicializar el cifrado del chat.',
        ),
        state: RealtimeUxState.error,
      );
      return;
    }

    setState(() => _sendingAudio = true);
    try {
      final file = File(localPath);
      final objectPath =
          'chatRooms/$roomId/audio/${DateTime.now().millisecondsSinceEpoch}.aac';
      final ref = _storage.ref().child(objectPath);
      await _runWithFirestoreRetry(() => ref.putFile(
            file,
            SettableMetadata(contentType: 'audio/aac'),
          ));
      final audioUrl = await _runWithFirestoreRetry(() => ref.getDownloadURL());
      final encryptedAudioUrl =
          _crypto.encryptForRoom(roomId: roomId, plainText: audioUrl);

      final batch = _db.batch();
      final msgRef = _db.collection('messages').doc();
      final encryptedReplyText = _replyTo == null
          ? null
          : _crypto.encryptForRoom(roomId: roomId, plainText: _replyTo!.text);

      batch.set(msgRef, {
        'roomId': roomId,
        'senderId': _currentUserId,
        'text': '',
        'type': 'audio',
        'fileUrl': '',
        'audioUrl': encryptedAudioUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'metadata': {
          'durationMs': durationMs,
          'replyTo': _replyTo?.id,
          'replyToText': encryptedReplyText,
        },
      });

      if (_legacyMirrorEnabled) {
        batch.set(
          _db
              .collection('chatRooms')
              .doc(roomId)
              .collection('messages')
              .doc(msgRef.id),
          {
            'senderId': _currentUserId,
            'text': '',
            'type': 'audio',
            'fileUrl': '',
            'audioUrl': encryptedAudioUrl,
            'timestamp': FieldValue.serverTimestamp(),
            'metadata': {
              'durationMs': durationMs,
              'replyTo': _replyTo?.id,
              'replyToText': encryptedReplyText,
            },
          },
        );
      }

      batch.update(_db.collection('chatRooms').doc(roomId), {
        'lastMessage': 'Nota de voz',
        'lastMessageType': 'audio',
        'updatedAt': FieldValue.serverTimestamp(),
        'unread_$_remoteUserId': FieldValue.increment(1),
      });

      await _runWithFirestoreRetry(() => batch.commit());
      if (!mounted) return;
      setState(() => _replyTo = null);
      unawaited(_markRoomAsRead(force: true));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar audio: $e')),
      );
    } finally {
      if (mounted) setState(() => _sendingAudio = false);
    }
  }

  Future<void> _showContactInfo() async {
    if (_remoteUserId.isEmpty) return;

    try {
      final snap =
          await _db.collection('users_public').doc(_remoteUserId).get();
      final data = snap.data() ?? const <String, dynamic>{};
      final fullName =
          ((data['fullName'] ?? data['displayName'] ?? 'Sin nombre') as Object)
              .toString()
              .trim();
      final orbitNumber =
          ((data['orbitNumber'] ?? '') as Object).toString().trim();
      final accountType =
          ((data['accountType'] ?? '') as Object).toString().trim();

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Informacion del contacto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('Nombre', fullName.isEmpty ? 'Sin nombre' : fullName),
              if (orbitNumber.isNotEmpty) _infoRow('Code Orbit', orbitNumber),
              if (accountType.isNotEmpty) _infoRow('Tipo', accountType),
              _infoRow('UID', _remoteUserId),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar el contacto: $e')),
      );
    }
  }

  String? _contentTypeForExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
        return 'audio/mp4';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'mp4':
        return 'video/mp4';
      default:
        return null;
    }
  }

  String _formatRecordingDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _startVoiceCall() {
    if (_remoteUserId.isEmpty) return;
    final knownName = (_contactName ?? widget.initialContactName ?? '').trim();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          remoteUserId: _remoteUserId,
          initialRemoteDisplayName: knownName.isEmpty ? null : knownName,
          isCaller: true,
          audioOnly: true,
        ),
      ),
    );
  }

  void _showMessageMenu(Map<String, dynamic> msg) {
    setState(() => _selectedMessageId = msg['id']);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Divider(height: 1),
              if ((msg['text'] ?? '').toString().isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.message_outlined,
                          size: 15, color: Colors.grey[400]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (msg['text'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 1),
              if (msg['fromMe'] == true)
                ..._sentActions(ctx, msg)
              else
                ..._receivedActions(ctx, msg),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _selectedMessageId = null);
    });
  }

  List<Widget> _sentActions(BuildContext ctx, Map<String, dynamic> msg) {
    return [
      _menuItem(ctx, Icons.copy_outlined, 'Copiar', () {
        Navigator.pop(ctx);
        _copyMessage((msg['text'] ?? '').toString());
      }),
      _menuItem(ctx, Icons.delete_outline, 'Eliminar para mi', () {
        Navigator.pop(ctx);
        _deleteForMe((msg['id'] ?? '').toString());
      }, color: Colors.red),
      _menuItem(ctx, Icons.info_outline, 'Info del mensaje', () {
        Navigator.pop(ctx);
        _showMessageInfo(msg);
      }),
    ];
  }

  List<Widget> _receivedActions(BuildContext ctx, Map<String, dynamic> msg) {
    return [
      _menuItem(ctx, Icons.copy_outlined, 'Copiar', () {
        Navigator.pop(ctx);
        _copyMessage((msg['text'] ?? '').toString());
      }),
      _menuItem(
          ctx, Icons.reply_outlined, 'Responder', () => _startReply(msg, ctx)),
      _menuItem(ctx, Icons.delete_outline, 'Eliminar para mi', () {
        Navigator.pop(ctx);
        _deleteForMe((msg['id'] ?? '').toString());
      }, color: Colors.red),
    ];
  }

  Widget _menuItem(
    BuildContext ctx,
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color ?? Colors.grey[700]),
            const SizedBox(width: 16),
            Text(label,
                style: TextStyle(fontSize: 15, color: color ?? Colors.black87)),
          ],
        ),
      ),
    );
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Mensaje copiado'), duration: Duration(seconds: 1)));
  }

  void _deleteForMe(String id) {
    if (id.isEmpty) return;
    setState(() {
      _hiddenMessageIds.add(id);
      _messages = _messages.where((msg) => msg['id'] != id).toList();
    });
  }

  void _startReply(Map<String, dynamic> msg, BuildContext ctx) {
    Navigator.pop(ctx);
    setState(() {
      _replyTo = MessageEntity(
        id: (msg['id'] ?? '').toString(),
        text: (msg['text'] ?? '').toString(),
        userId: (msg['userId'] ?? '').toString(),
        userName: (msg['userName'] ?? '').toString(),
        userAvatar: '',
        createdAt: DateTime.now(),
        status: (msg['status'] ?? 'delivered').toString(),
      );
      _selectedMessageId = null;
    });
  }

  void _showMessageInfo(Map<String, dynamic> msg) {
    final timestamp = msg['timestamp'] as Timestamp?;
    final sentAt = timestamp?.toDate();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Info del mensaje'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Estado', (msg['status'] ?? 'sent').toString()),
            _infoRow('Tipo', (msg['type'] ?? 'text').toString()),
            _infoRow(
              'Enviado',
              sentAt == null
                  ? 'Pendiente'
                  : '${sentAt.day.toString().padLeft(2, '0')}/${sentAt.month.toString().padLeft(2, '0')} ${sentAt.hour.toString().padLeft(2, '0')}:${sentAt.minute.toString().padLeft(2, '0')}',
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Flexible(child: Text(value)),
      ]),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final day = DateTime(date.year, date.month, date.day);

    final String label;
    if (day == today) {
      label = 'Hoy';
    } else if (day == yesterday) {
      label = 'Ayer';
    } else {
      label =
          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_messages.isEmpty) {
      return _buildEmptyState();
    }

    final List<Widget> items = [];
    DateTime? lastDay;

    for (final msg in _messages) {
      final timestamp = msg['timestamp'] as Timestamp?;
      final date = timestamp?.toDate();

      if (date != null) {
        final day = DateTime(date.year, date.month, date.day);
        if (lastDay == null || day != lastDay) {
          items.add(_buildDateSeparator(date));
          lastDay = day;
        }
      }

      final timeLabel = date != null
          ? '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
          : null;

      items.add(ChatBubble(
        text: ((msg['text'] ?? '').toString().trim().isEmpty &&
                (msg['type'] ?? '').toString() == 'audio')
            ? 'Nota de voz'
            : (msg['text'] ?? '').toString(),
        fromMe: msg['fromMe'] == true,
        userName: (msg['fromMe'] == true) ? null : (_contactName ?? 'Contacto'),
        userAvatar: '',
        status: (msg['status'] ?? '').toString(),
        attachmentUrl: msg['attachment']?.toString(),
        messageType: (msg['type'] ?? 'text').toString(),
        timeLabel: timeLabel,
        reaction: null,
        isHighlighted: _selectedMessageId == msg['id'],
        onLongPress: () => _showMessageMenu(msg),
      ));
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      children: [
        ...items,
        // Mensajes optimistas (pending/failed) aún no llegados por el stream.
        ..._pendingMessages.map((msg) {
          final status = msg['status'] as String? ?? 'queued';
          return ChatBubble(
            text: (msg['text'] ?? '').toString(),
            fromMe: true,
            status: status,
            messageType: (msg['type'] ?? 'text').toString(),
            timeLabel: status == 'failed' ? '!' : '...',
            reaction: null,
            isHighlighted: false,
          );
        }),
      ],
    );
  }

  Widget _buildEmptyState() {
    if (_roomId == null) {
      return Center(
        child: Text(
          'No fue posible abrir esta conversacion',
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      );
    }

    return Center(
      child: Text(
        'No hay mensajes',
        style: TextStyle(color: Colors.grey[600], fontSize: 16),
      ),
    );
  }

  Widget _buildEmojiPicker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Barra de cierre del teclado emoji
        Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Emojis',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              Row(
                children: [
                  // Botón de borrar último emoji
                  IconButton(
                    icon: const Icon(Icons.backspace_outlined, size: 20),
                    tooltip: 'Borrar',
                    onPressed: () {
                      final text = _controller.text;
                      if (text.isEmpty) return;
                      setState(() {
                        // Borra el último carácter (o emoji multi-byte)
                        final chars = text.characters;
                        _controller.text = chars
                            .take(chars.length - 1)
                            .toString();
                        _controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: _controller.text.length),
                        );
                      });
                    },
                  ),
                  // Botón de cerrar picker
                  IconButton(
                    icon: const Icon(Icons.keyboard_hide_outlined, size: 22),
                    tooltip: 'Cerrar emojis',
                    onPressed: () => setState(() => _showEmojiPicker = false),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: 270,
          child: EmojiPicker(
            onEmojiSelected: (category, emoji) {
              setState(() {
                _controller.text += emoji.emoji;
                _controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: _controller.text.length),
                );
              });
            },
            config: const Config(),
          ),
        ),
      ],
    );
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyTo != null)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Respondiendo a: ${_replyTo?.text ?? ''}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                          fontStyle: FontStyle.italic),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _replyTo = null),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _showEmojiPicker
                      ? Icons.keyboard_outlined
                      : Icons.emoji_emotions,
                ),
                onPressed: () {
                  setState(() => _showEmojiPicker = !_showEmojiPicker);
                },
              ),
              if (_isRecordingAudio)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedScale(
                        scale: _recordingSeconds.isEven ? 1.0 : 1.22,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                        child: AnimatedOpacity(
                          opacity: _recordingSeconds.isEven ? 1.0 : 0.55,
                          duration: const Duration(milliseconds: 500),
                          child: const Icon(
                            Icons.fiber_manual_record,
                            size: 12,
                            color: Colors.red,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatRecordingDuration(_recordingSeconds),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  minLines: 1,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Escribe un mensaje...',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _sendMessage,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.attach_file),
                onPressed: _pickAttachment,
              ),
              IconButton(
                icon: const Icon(Icons.mic),
                tooltip: _isRecordingAudio
                    ? 'Detener y enviar audio'
                    : 'Grabar audio',
                color: _isRecordingAudio ? Colors.red : null,
                onPressed: _sendingAudio ? null : _toggleRecordingAudio,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    FCMService.setActiveChatPeer(null);
    unawaited(_messagesResilient?.cancel());
    unawaited(_roomResilient?.cancel());
    _messagesSubscription?.cancel();
    _roomSubscription?.cancel();
    _recordingTimer?.cancel();
    _readReceiptDebounceTimer?.cancel();
    _scrollController.removeListener(_onScroll); // lifecycle safety fix
    if (_isRecordingAudio) {
      unawaited(_recorder.stopRecorder()); // lifecycle safety fix
    }
    unawaited(_recorder.closeRecorder()); // lifecycle safety fix
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<T> _runWithFirestoreRetry<T>(
    Future<T> Function() action, {
    int maxAttempts = 3,
    Duration baseDelay = const Duration(milliseconds: 400),
  }) async {
    Object? lastError;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await action();
      } on FirebaseException catch (e) {
        lastError = e;
        if (attempt == maxAttempts) break;
      } on TimeoutException catch (e) {
        lastError = e;
        if (attempt == maxAttempts) break;
      }

      await Future.delayed(Duration(
        milliseconds: baseDelay.inMilliseconds * attempt,
      ));
    }

    throw lastError ?? StateError('Firestore operation failed');
  }

  Future<void> _ensureCryptoReady() async {
    try {
      _cryptoInitFuture ??= _crypto.initialize();
      await _cryptoInitFuture;
    } catch (e) {
      throw StateError('Fallo la inicializacion del cifrado del chat: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _showContactInfo,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(_contactTitle)),
                const SizedBox(width: 6),
                const Icon(Icons.info_outline, size: 18),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            tooltip: 'Llamar',
            onPressed: _startVoiceCall,
          ),
        ],
      ),
      floatingActionButton: _showScrollToBottomFab
          ? FloatingActionButton.small(
              onPressed: () {
                setState(() {
                  _isAtBottom = true;
                  _showScrollToBottomFab = false;
                });
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
              child: const Icon(Icons.keyboard_arrow_down),
            )
          : null,
      body: Stack(
        children: [
          SafeArea(
            top: false,
            child: AbsorbPointer(
              absorbing: _uploading,
              child: Column(
                children: [
                  if (_connectionStateLabel.isNotEmpty &&
                      _connectionState != RealtimeUxState.online)
                    ErrorPresenter.buildStatusStrip(
                      state: _connectionState,
                      message: _connectionStateLabel,
                      onRetry: () {
                        _subscribeRoom();
                        _subscribeMessages();
                      },
                    ),
                  Expanded(child: _buildMessagesList()),
                  if (_showEmojiPicker) _buildEmojiPicker(),
                  _buildInputArea(),
                ],
              ),
            ),
          ),
          if (_uploading)
            Container(
              color: Colors.black.withAlpha((0.6 * 255).toInt()),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 24),
                    Text('Subiendo archivo, espera...',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
