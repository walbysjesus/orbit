import '../../utils/camera_icon_button.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import '../../services/auth_service.dart';
import '../../services/chat_api_service.dart';
import '../../services/e2e_chat_crypto_service.dart';
import '../../services/network_service.dart';
import '../../utils/audio_record_indicator.dart';
import 'video_call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String contactNameOrId;
  const ChatScreen({super.key, required this.contactNameOrId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  final E2EChatCryptoService _crypto = E2EChatCryptoService();

  // ── Firestore real-time ──
  String? _roomId;
  StreamSubscription<QuerySnapshot>? _msgSub;

  List<Map<String, dynamic>> _messages = [];
  bool _isRecording = false;
  bool _recorderBusy = false;
  bool _recorderReady = false;
  bool _playerReady = false;
  bool _sendingFile = false;
  bool _useFirestore = false;
  Duration _recordingElapsed = Duration.zero;
  Timer? _recordingTicker;
  String? _activeAudioPath;
  String _activeEmojiCategory = 'Caras';
  String _networkHint = 'Analizando enlace...';
  Color _networkHintColor = const Color(0xFF8FA9C2);
  Timer? _networkHintTimer;

  static const Map<String, List<String>> _emojiCategories = {
    'Caras': [
      '😀',
      '😃',
      '😄',
      '😁',
      '😆',
      '🥹',
      '😂',
      '🤣',
      '😊',
      '🙂',
      '😉',
      '😍',
      '😘',
      '😎',
      '🤔',
      '😴',
      '😤',
      '😭',
      '😡',
      '🤯',
      '🥳',
      '😇',
      '😱',
      '🥶',
    ],
    'Gestos': [
      '👍',
      '👎',
      '👏',
      '🙌',
      '🙏',
      '🤝',
      '💪',
      '🫶',
      '👀',
      '✅',
      '❌',
      '⚠️',
      '💯',
      '🔥',
      '✨',
      '🎉',
      '🚀',
      '📌',
      '💡',
      '🧠',
      '📣',
      '🫡',
      '👌',
      '🤞',
    ],
    'Objetos': [
      '📞',
      '📱',
      '💻',
      '⌚',
      '🎧',
      '🎤',
      '🎵',
      '📷',
      '🎥',
      '📁',
      '📎',
      '📝',
      '🛠️',
      '🔋',
      '📡',
      '🛰️',
      '🧭',
      '🔒',
      '🔔',
      '💳',
      '💾',
      '🧩',
      '🖥️',
      '🗂️',
    ],
    'Viajes': [
      '🌍',
      '🌎',
      '🌏',
      '🏙️',
      '🏠',
      '🛫',
      '🛬',
      '🚆',
      '🚗',
      '🚕',
      '🚌',
      '🚲',
      '🚀',
      '⛽',
      '🗺️',
      '🧳',
      '🏖️',
      '🏔️',
      '🌦️',
      '☀️',
      '🌙',
      '⭐',
      '⚡',
      '🌧️',
    ],
    'Corazones': [
      '❤️',
      '🩷',
      '🧡',
      '💛',
      '💚',
      '💙',
      '🩵',
      '💜',
      '🤍',
      '🖤',
      '🤎',
      '💔',
      '❣️',
      '💕',
      '💞',
      '💓',
      '💗',
      '💖',
      '💘',
      '💝',
      '💟',
      '❤️\u200d🔥',
      '❤️\u200d🩹',
      '🫀',
    ],
  };

  MaterialBanner? _banner;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeChatSecurity());
    unawaited(_refreshNetworkHint());
    _networkHintTimer = Timer.periodic(
      const Duration(seconds: 28),
      (_) => unawaited(_refreshNetworkHint()),
    );
  }

  Future<void> _initializeChatSecurity() async {
    try {
      await _crypto.initialize();
    } catch (_) {
      if (mounted) {
        _showBanner(
          'No se pudo inicializar cifrado local seguro',
          Colors.redAccent,
        );
      }
    }
    await _initChat();
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _recordingTicker?.cancel();
    _networkHintTimer?.cancel();
    unawaited(_cleanupPlayer());
    unawaited(_cleanupRecorder());
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refreshNetworkHint() async {
    final networkService = NetworkService();
    final quality = await networkService.getNetworkQuality();
    final latency = await networkService.measureLatencyMs();

    String label;
    Color color;

    if (quality == NetworkQuality.none) {
      label = 'Sin conexión';
      color = const Color(0xFFE46E6E);
    } else if (quality == NetworkQuality.low) {
      label = 'Señal inestable';
      color = const Color(0xFFFFB46A);
    } else if (quality == NetworkQuality.medium) {
      if (latency != null && latency > 240) {
        label = 'Media, latencia alta';
        color = const Color(0xFFF1C96B);
      } else {
        label = 'Señal media';
        color = const Color(0xFFE5CE72);
      }
    } else {
      label = 'Señal estable';
      color = const Color(0xFF6ED6B1);
    }

    if (!mounted) return;
    setState(() {
      _networkHint = latency == null ? label : '$label · ${latency} ms';
      _networkHintColor = color;
    });
  }

  Future<void> _cleanupRecorder() async {
    try {
      if (_isRecording) {
        await _recorder.stopRecorder();
      }
      if (_recorderReady) {
        await _recorder.closeRecorder();
      }
    } catch (_) {
      // Evita romper el dispose por cierres duplicados o tardíos.
    }
  }

  Future<void> _cleanupPlayer() async {
    try {
      if (_playerReady) {
        await _player.stopPlayer();
        await _player.closePlayer();
      }
    } catch (_) {
      // Evita romper el dispose por cierres duplicados o tardíos.
    }
  }

  // ================= CHAT INIT =================

  Future<void> _initChat() async {
    final currentUser = AuthService.getCurrentUser();
    if (currentUser == null) {
      // Sin sesión: usa almacenamiento local cifrado
      _useFirestore = false;
      _loadLocalMessages();
      return;
    }

    try {
      _roomId = await ChatApiService.getOrCreateRoom(widget.contactNameOrId);
      _useFirestore = true;
      _subscribeToMessages();
    } catch (_) {
      // Si falla Firestore, degradar a local sin interrumpir usuario
      _useFirestore = false;
      _loadLocalMessages();
    }
  }

  void _subscribeToMessages() {
    if (_roomId == null) return;
    _msgSub = ChatApiService.messagesStream(_roomId!).listen((snap) {
      if (!mounted) return;
      final currentUid = AuthService.getCurrentUser()?.uid ?? '';
      final remoteMessages = snap.docs.map((doc) {
        final d = doc.data();
        return {
          'text': d['text'] ?? d['fileUrl'] ?? '',
          'fromMe': d['senderId'] == currentUid,
          'timestamp':
              (d['timestamp'] as Timestamp?)?.toDate().toIso8601String() ??
                  DateTime.now().toIso8601String(),
          'audioUrl': d['type'] == 'audio' ? d['fileUrl'] : null,
          'audioPath': null,
          'mediaType': d['type'],
          'durationMs': d['metadata']?['durationMs'],
          'fileName': d['metadata']?['fileName'],
          'filePath': null,
        };
      }).toList();
      unawaited(_mergeRemoteMessages(remoteMessages));
    }, onError: (_) {
      _showBanner('Error de conexión en chat', Colors.redAccent);
    });
  }

  Future<void> _mergeRemoteMessages(
      List<Map<String, dynamic>> remoteMessages) async {
    final cachedMessages = await _loadCachedMessages();
    final localMediaMessages = cachedMessages
        .where((message) =>
            message['audioPath'] != null ||
            message['filePath'] != null ||
            message['mediaType'] != null)
        .toList();

    final merged = [...remoteMessages, ...localMediaMessages];
    merged.sort((left, right) => (left['timestamp'] ?? '')
        .toString()
        .compareTo((right['timestamp'] ?? '').toString()));

    if (!mounted) return;
    setState(() {
      _messages = merged;
    });
  }

  Future<List<Map<String, dynamic>>> _loadCachedMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('chat_${widget.contactNameOrId}');
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  Future<void> _addLocalMessage(Map<String, dynamic> message) async {
    if (!mounted) return;
    setState(() {
      _messages.add(message);
    });
    await _saveLocalMessages();
  }

  Future<void> _updateUploadingMessage(
      String uploadId, Map<String, dynamic> updates,
      {bool persist = false}) async {
    if (!mounted) return;

    setState(() {
      final index = _messages.indexWhere((m) => m['uploadId'] == uploadId);
      if (index != -1) {
        _messages[index] = {..._messages[index], ...updates};
      }
    });

    if (persist) {
      await _saveLocalMessages();
    }
  }

  Future<void> _removeUploadingMessage(String uploadId) async {
    if (!mounted) return;

    setState(() {
      _messages.removeWhere((m) => m['uploadId'] == uploadId);
    });

    await _saveLocalMessages();
  }

  Future<Directory> _downloadsDir() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final downloads = Directory(
      '${baseDir.path}${Platform.pathSeparator}chat_downloads',
    );
    if (!await downloads.exists()) {
      await downloads.create(recursive: true);
    }
    return downloads;
  }

  Future<String> _downloadRemoteFile({
    required String url,
    required String suggestedName,
  }) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Error HTTP ${response.statusCode}');
    }

    final safeName = suggestedName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final dir = await _downloadsDir();
    final path = '${dir.path}${Platform.pathSeparator}$safeName';
    final file = File(path);
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file.path;
  }

  Future<String?> _ensureLocalMediaSource(Map<String, dynamic> msg) async {
    final source = _resolveMediaSource(msg);
    if (source == null) return null;

    if (!_isRemoteSource(source)) return source;

    final fileName = (msg['fileName'] as String?)?.trim();
    final ext = msg['mediaType'] == 'audio'
        ? 'aac'
        : (msg['mediaType'] == 'image')
            ? 'jpg'
            : (msg['mediaType'] == 'video')
                ? 'mp4'
                : 'bin';

    final localPath = await _downloadRemoteFile(
      url: source,
      suggestedName:
          fileName != null && fileName.isNotEmpty ? fileName : 'adjunto.$ext',
    );

    return localPath;
  }

  Future<void> _openAttachment(Map<String, dynamic> msg) async {
    try {
      final localPath = await _ensureLocalMediaSource(msg);
      if (localPath == null) return;

      final result = await OpenFilex.open(localPath);
      if (result.type != ResultType.done) {
        _showBanner('No se pudo abrir el archivo', Colors.redAccent);
      }
    } catch (_) {
      _showBanner('No se pudo abrir el adjunto', Colors.redAccent);
    }
  }

  Future<void> _downloadAttachment(Map<String, dynamic> msg) async {
    try {
      final source = _resolveMediaSource(msg);
      if (source == null) return;

      String savedPath;
      if (_isRemoteSource(source)) {
        final fileName = (msg['fileName'] as String?)?.trim();
        savedPath = await _downloadRemoteFile(
          url: source,
          suggestedName: fileName != null && fileName.isNotEmpty
              ? fileName
              : 'adjunto_descargado.bin',
        );
      } else {
        final fileName = _fileNameFromPath(source);
        final dir = await _downloadsDir();
        final targetPath = '${dir.path}${Platform.pathSeparator}$fileName';
        savedPath = await File(source).copy(targetPath).then((f) => f.path);
      }

      _showBanner('Archivo guardado en: $savedPath', Colors.green);
    } catch (_) {
      _showBanner('No se pudo descargar el adjunto', Colors.redAccent);
    }
  }

  Future<void> _sendOrStoreMedia({
    required String localPath,
    required String type,
    String? fileName,
    int? durationMs,
  }) async {
    final timestamp = DateTime.now();
    final safeName = (fileName ?? _fileNameFromPath(localPath))
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final uploadId = '${timestamp.microsecondsSinceEpoch}_$safeName';

    final localMessage = {
      'text': fileName ?? type,
      'audioPath': type == 'audio' ? localPath : null,
      'audioUrl': null,
      'filePath': type == 'audio' ? null : localPath,
      'fileUrl': null,
      'mediaType': type,
      'durationMs': durationMs,
      'fileName': fileName ?? safeName,
      'fromMe': true,
      'timestamp': timestamp.toIso8601String(),
      'uploadId': uploadId,
      'isUploading': _useFirestore && _roomId != null,
      'uploadProgress': 0.0,
      'canRetryUpload': false,
    };

    if (!_useFirestore || _roomId == null) {
      await _addLocalMessage(localMessage);
      return;
    }

    await _addLocalMessage(localMessage);

    await _uploadMediaFromLocal(
      uploadId: uploadId,
      localPath: localPath,
      type: type,
      fileName: fileName,
      durationMs: durationMs,
    );
  }

  Future<void> _uploadMediaFromLocal({
    required String uploadId,
    required String localPath,
    required String type,
    String? fileName,
    int? durationMs,
  }) async {
    if (!_useFirestore || _roomId == null) return;

    try {
      final storage = FirebaseStorage.instance;
      final timestamp = DateTime.now();
      final safeName = (fileName ?? _fileNameFromPath(localPath))
          .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final ref = storage
          .ref()
          .child('chatRooms')
          .child(_roomId!)
          .child('${type}_${timestamp.millisecondsSinceEpoch}_$safeName');

      final task = ref.putFile(File(localPath));
      task.snapshotEvents.listen((snapshot) {
        final total = snapshot.totalBytes;
        final progress = total <= 0 ? 0.0 : snapshot.bytesTransferred / total;
        unawaited(_updateUploadingMessage(uploadId, {
          'uploadProgress': progress,
        }));
      });

      await task;
      final url = await ref.getDownloadURL();

      await ChatApiService.sendMediaMessage(
        roomId: _roomId!,
        fileUrl: url,
        type: type,
        fileName: fileName,
        metadata: {
          if (durationMs != null) 'durationMs': durationMs,
        },
      );

      await _removeUploadingMessage(uploadId);
    } catch (_) {
      await _updateUploadingMessage(
        uploadId,
        {
          'isUploading': false,
          'uploadProgress': 0.0,
          'canRetryUpload': true,
        },
        persist: true,
      );

      _showBanner(
        'Storage no disponible. Se guardó el archivo en este dispositivo.',
        Colors.orangeAccent,
      );
    }
  }

  Future<void> _retryUploadMessage(Map<String, dynamic> msg) async {
    if (!_useFirestore || _roomId == null) {
      _showBanner(
          'Inicia sesión para subir archivos al chat', Colors.orangeAccent);
      return;
    }

    final localPath = (msg['audioPath'] ?? msg['filePath']) as String?;
    final mediaType = (msg['mediaType'] as String?)?.trim();
    if (localPath == null || mediaType == null || mediaType.isEmpty) {
      _showBanner(
          'No se encontró el archivo local para reintentar', Colors.redAccent);
      return;
    }

    final uploadId = (msg['uploadId'] as String?) ??
        '${DateTime.now().microsecondsSinceEpoch}_${_fileNameFromPath(localPath)}';

    await _updateUploadingMessage(
      uploadId,
      {
        'uploadId': uploadId,
        'isUploading': true,
        'uploadProgress': 0.0,
        'canRetryUpload': false,
      },
      persist: true,
    );

    await _uploadMediaFromLocal(
      uploadId: uploadId,
      localPath: localPath,
      type: mediaType,
      fileName: msg['fileName'] as String?,
      durationMs: (msg['durationMs'] as num?)?.toInt(),
    );
  }

  String? _resolveMediaSource(Map<String, dynamic> message) {
    return (message['audioPath'] ??
            message['filePath'] ??
            message['audioUrl'] ??
            message['fileUrl'])
        ?.toString();
  }

  bool _isRemoteSource(String source) {
    return source.startsWith('http://') || source.startsWith('https://');
  }

  void _insertEmoji(String emoji) {
    final selection = _controller.selection;
    final text = _controller.text;

    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final newText = text.replaceRange(start, end, emoji);
    final newOffset = start + emoji.length;

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }

  void _openEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final categories = _emojiCategories.keys.toList();
          final emojis = _emojiCategories[_activeEmojiCategory] ?? const [];

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Teclado de emojis',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: categories.map((category) {
                        final selected = category == _activeEmojiCategory;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(category),
                            selected: selected,
                            onSelected: (_) {
                              HapticFeedback.selectionClick();
                              setState(() => _activeEmojiCategory = category);
                              setSheetState(() {});
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    itemCount: emojis.length,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemBuilder: (_, index) {
                      final emoji = emojis[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _insertEmoji(emoji);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child:
                              Text(emoji, style: const TextStyle(fontSize: 24)),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ================= MESSAGES (local fallback) =================

  Future<void> _loadLocalMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('chat_${widget.contactNameOrId}');
    if (raw != null && mounted) {
      setState(() {
        _messages = List<Map<String, dynamic>>.from(jsonDecode(raw));
      });
    }
  }

  Future<void> _saveLocalMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'chat_${widget.contactNameOrId}',
      jsonEncode(_messages),
    );
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();

    if (_useFirestore && _roomId != null) {
      try {
        final encrypted =
            _crypto.encryptForRoom(roomId: _roomId!, plainText: text);
        await ChatApiService.sendTextMessage(roomId: _roomId!, text: encrypted);
      } catch (_) {
        if (mounted) _showBanner('Error al enviar mensaje', Colors.redAccent);
      }
      return;
    }

    try {
      // Fallback local cifrado con clave de dispositivo segura e IV aleatorio.
      final encrypted = _crypto.encryptLocal(text);
      if (!mounted) return;
      await _addLocalMessage({
        'text': encrypted,
        'fromMe': true,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      if (mounted) {
        _showBanner('No se pudo cifrar el mensaje local', Colors.redAccent);
      }
    }
  }

  // ================= FILE =================

  Future<void> _sendFile() async {
    setState(() => _sendingFile = true);

    try {
      final result = await FilePicker.platform.pickFiles();
      if (result?.files.single.path != null) {
        final file = result!.files.single;
        await _sendOrStoreMedia(
          localPath: file.path!,
          type: 'file',
          fileName: file.name,
        );
      }
    } catch (e) {
      _showBanner('Error al seleccionar archivo', Colors.red);
    }

    if (mounted) {
      setState(() => _sendingFile = false);
    }
  }

  Future<String> _buildLocalMediaPath(String extension) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeContactId =
        widget.contactNameOrId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return '${Directory.systemTemp.path}${Platform.pathSeparator}orbit_${safeContactId}_$timestamp.$extension';
  }

  String _fileNameFromPath(String path) {
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.isEmpty ? path : parts.last;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatMessageTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  bool _shouldShowDateSeparator(int index) {
    if (index == 0) return true;
    final prev = _messages[index - 1]['timestamp'] as String?;
    final curr = _messages[index]['timestamp'] as String?;
    if (prev == null || curr == null) return false;
    try {
      final a = DateTime.parse(prev).toLocal();
      final b = DateTime.parse(curr).toLocal();
      return a.day != b.day || a.month != b.month || a.year != b.year;
    } catch (_) {
      return false;
    }
  }

  Widget _buildDateSeparator(String? iso) {
    String label = 'Hoy';
    if (iso != null) {
      try {
        final dt = DateTime.parse(iso).toLocal();
        final now = DateTime.now();
        final diff = DateTime(now.year, now.month, now.day)
            .difference(DateTime(dt.year, dt.month, dt.day))
            .inDays;
        if (diff == 1) {
          label = 'Ayer';
        } else if (diff > 1) {
          label =
              '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
        }
      } catch (_) {}
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(
              child: Divider(color: Color(0xFF2A4E72), thickness: 0.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF14324F),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF2A4E72)),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF8ABBD8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const Expanded(
              child: Divider(color: Color(0xFF2A4E72), thickness: 0.5)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0D2138),
              border: Border.all(color: const Color(0xFF1D3F5D), width: 2),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: Color(0xFF2A6D9E),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Ningún mensaje aún',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Escribe algo para iniciar la conversación',
            style: TextStyle(color: Color(0xFF4A7498), fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _startRecordingTicker() {
    _recordingTicker?.cancel();
    _recordingElapsed = Duration.zero;
    final startedAt = DateTime.now();
    _recordingTicker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted || !_isRecording) return;
      setState(() {
        _recordingElapsed = DateTime.now().difference(startedAt);
      });
    });
  }

  void _stopRecordingTicker() {
    _recordingTicker?.cancel();
    _recordingTicker = null;
  }

  Future<void> _ensurePlayerReady() async {
    if (_playerReady) return;
    await _player.openPlayer();
    _playerReady = true;
  }

  Future<void> _playAudioMessage(String path) async {
    try {
      await _ensurePlayerReady();

      if (_activeAudioPath == path) {
        await _player.stopPlayer();
        if (!mounted) return;
        setState(() => _activeAudioPath = null);
        return;
      }

      await _player.stopPlayer();
      await _player.startPlayer(
        fromURI: path,
        whenFinished: () {
          if (!mounted) return;
          setState(() => _activeAudioPath = null);
        },
      );

      if (!mounted) return;
      setState(() => _activeAudioPath = path);
    } catch (_) {
      if (mounted) {
        _showBanner('No se pudo reproducir la nota de voz', Colors.redAccent);
      }
    }
  }

  Future<void> _captureImage() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (picked == null) return;

      final targetPath = await _buildLocalMediaPath('jpg');
      final savedFile = await File(picked.path).copy(targetPath);
      await _sendOrStoreMedia(
        localPath: savedFile.path,
        type: 'image',
        fileName: _fileNameFromPath(savedFile.path),
      );
    } catch (_) {
      if (mounted) {
        _showBanner('No se pudo tomar la foto', Colors.redAccent);
      }
    }
  }

  Future<void> _captureVideo() async {
    try {
      final picked = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 30),
      );
      if (picked == null) return;

      final targetPath = await _buildLocalMediaPath('mp4');
      final savedFile = await File(picked.path).copy(targetPath);
      await _sendOrStoreMedia(
        localPath: savedFile.path,
        type: 'video',
        fileName: _fileNameFromPath(savedFile.path),
      );
    } catch (_) {
      if (mounted) {
        _showBanner('No se pudo grabar el video', Colors.redAccent);
      }
    }
  }

  // ================= AUDIO =================

  Future<bool> _ensureRecorderReady() async {
    if (_recorderReady) return true;

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        _showBanner('Permiso de micrófono denegado', Colors.redAccent);
      }
      return false;
    }

    try {
      await _recorder.openRecorder();
      _recorderReady = true;
      return true;
    } catch (_) {
      if (mounted) {
        _showBanner('No se pudo inicializar el micrófono', Colors.redAccent);
      }
      return false;
    }
  }

  Future<void> _toggleRecording() async {
    if (_recorderBusy) return;
    _recorderBusy = true;

    try {
      if (_isRecording) {
        try {
          final recordedDuration = _recordingElapsed;
          final path = await _recorder.stopRecorder();
          if (!mounted) return;
          _stopRecordingTicker();
          setState(() => _isRecording = false);

          if (path != null) {
            await _sendOrStoreMedia(
              localPath: path,
              type: 'audio',
              fileName: 'nota_de_voz.aac',
              durationMs: recordedDuration.inMilliseconds,
            );
          }
        } catch (_) {
          if (mounted) {
            _showBanner('No se pudo detener la grabación', Colors.redAccent);
            setState(() => _isRecording = false);
          }
          _stopRecordingTicker();
        }
      } else {
        try {
          final ready = await _ensureRecorderReady();
          if (!ready) return;
          final outputPath = await _buildLocalMediaPath('aac');
          await _recorder.startRecorder(toFile: outputPath);
          if (!mounted) return;
          setState(() {
            _isRecording = true;
            _recordingElapsed = Duration.zero;
          });
          _startRecordingTicker();
        } catch (_) {
          if (mounted) {
            _showBanner('No se pudo iniciar la grabación', Colors.redAccent);
            setState(() => _isRecording = false);
          }
          _stopRecordingTicker();
        }
      }
    } finally {
      _recorderBusy = false;
    }
  }

  // ================= UI =================

  void _showBanner(String text, Color color) {
    setState(() {
      _banner = MaterialBanner(
        content: Text(text, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _banner = null);
            },
            child: const Text('Cerrar', style: TextStyle(color: Colors.white)),
          )
        ],
      );
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _banner = null);
    });
  }

  Widget _buildUploadStatus(Map<String, dynamic> msg, {String? mediaSource}) {
    final isUploading = msg['isUploading'] == true;
    final canRetry = msg['canRetryUpload'] == true;
    final uploaded = !isUploading &&
        !canRetry &&
        msg['fromMe'] == true &&
        mediaSource != null &&
        _isRemoteSource(mediaSource);

    if (!isUploading && !canRetry && !uploaded) {
      return const SizedBox.shrink();
    }

    final progress = (msg['uploadProgress'] as num?)?.toDouble() ?? 0.0;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isUploading) ...[
            SizedBox(
              width: 170,
              child: LinearProgressIndicator(value: progress),
            ),
            const SizedBox(height: 4),
            Text(
              'Subiendo ${(progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
          if (!isUploading && canRetry)
            TextButton.icon(
              onPressed: () {
                unawaited(_retryUploadMessage(msg));
              },
              icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
              label: const Text(
                'Reintentar subida',
                style: TextStyle(color: Colors.white),
              ),
            ),
          if (uploaded)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
                SizedBox(width: 6),
                Text(
                  'Subido',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 380;

    return Scaffold(
      backgroundColor: const Color(0xFF091526),
      appBar: AppBar(
        backgroundColor: const Color(0xFF091526),
        elevation: 0,
        titleSpacing: 8,
        title: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('Perfil de ${widget.contactNameOrId}'),
                content: const Text(
                    'Aquí se mostraría la información del contacto.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ContactAvatar(name: widget.contactNameOrId, size: 36),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.contactNameOrId,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _networkHintColor.withAlpha(35),
                        borderRadius: BorderRadius.circular(999),
                        border:
                            Border.all(color: _networkHintColor.withAlpha(170)),
                      ),
                      child: Text(
                        _networkHint,
                        style: TextStyle(
                          color: _networkHintColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_rounded),
            tooltip: 'Llamada de voz',
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => VideoCallScreen(
                  remoteUserId: widget.contactNameOrId,
                  audioOnly: true,
                  isCaller: true,
                ),
              ));
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam_rounded),
            tooltip: 'Videollamada',
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => VideoCallScreen(
                  remoteUserId: widget.contactNameOrId,
                  isCaller: true,
                ),
              ));
            },
          ),
          IconButton(
            icon: const Icon(Icons.attach_file),
            tooltip: 'Adjuntar archivo',
            onPressed: _sendingFile
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    unawaited(_sendFile());
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_banner != null) _banner!,
          if (_isRecording ||
              (_messages.isNotEmpty && _messages.last['audioPath'] != null))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: AudioRecordIndicator(
                isRecording: _isRecording,
                elapsed: _recordingElapsed,
                audioPath:
                    _messages.isNotEmpty ? _messages.last['audioPath'] : null,
              ),
            ),
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final msg = _messages[i];
                      final isMe = msg['fromMe'] == true;
                      Widget Function(Widget) wrapSep =
                          (w) => _shouldShowDateSeparator(i)
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildDateSeparator(
                                        msg['timestamp'] as String?),
                                    w,
                                  ],
                                )
                              : w;

                      String text = msg['text'];
                      try {
                        if (_useFirestore && _roomId != null) {
                          text = _crypto.decryptForRoom(
                              roomId: _roomId!, cipherText: text);
                        } else {
                          text = _crypto.decryptLocal(text);
                        }
                      } catch (_) {}

                      final mediaSource = _resolveMediaSource(msg);

                      if (msg['mediaType'] == 'image' && mediaSource != null) {
                        return wrapSep(Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? const Color(0xFF2E88D8)
                                  : const Color(0xFF2B3850),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => Dialog(
                                        child: InteractiveViewer(
                                          child: _isRemoteSource(mediaSource)
                                              ? Image.network(mediaSource)
                                              : Image.file(File(mediaSource)),
                                        ),
                                      ),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: _isRemoteSource(mediaSource)
                                        ? Image.network(
                                            mediaSource,
                                            width: 180,
                                            height: 220,
                                            fit: BoxFit.cover,
                                          )
                                        : Image.file(
                                            File(mediaSource),
                                            width: 180,
                                            height: 220,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                ),
                                _buildUploadStatus(msg,
                                    mediaSource: mediaSource),
                              ],
                            ),
                          ),
                        ));
                      }

                      if (msg['mediaType'] == 'video' && mediaSource != null) {
                        return wrapSep(Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? const Color(0xFF2E88D8)
                                  : const Color(0xFF2B3850),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: _VideoPreview(
                                    source: mediaSource,
                                    isRemote: _isRemoteSource(mediaSource),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.videocam,
                                        color: Colors.white),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        msg['fileName'] ?? 'Video grabado',
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                _buildUploadStatus(msg,
                                    mediaSource: mediaSource),
                              ],
                            ),
                          ),
                        ));
                      }

                      if (msg['mediaType'] == 'file' && mediaSource != null) {
                        return wrapSep(Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? const Color(0xFF2E88D8)
                                  : const Color(0xFF2B3850),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.insert_drive_file,
                                        color: Colors.white),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        msg['fileName'] ?? text,
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.open_in_new,
                                          color: Colors.white),
                                      tooltip: 'Abrir archivo',
                                      onPressed: () {
                                        HapticFeedback.selectionClick();
                                        unawaited(_openAttachment(msg));
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.download,
                                          color: Colors.white),
                                      tooltip: 'Descargar archivo',
                                      onPressed: () {
                                        HapticFeedback.selectionClick();
                                        unawaited(_downloadAttachment(msg));
                                      },
                                    ),
                                  ],
                                ),
                                _buildUploadStatus(msg,
                                    mediaSource: mediaSource),
                              ],
                            ),
                          ),
                        ));
                      }

                      if (msg['mediaType'] == 'audio' && mediaSource != null) {
                        final audioDuration = Duration(
                          milliseconds:
                              (msg['durationMs'] as num?)?.toInt() ?? 0,
                        );
                        return wrapSep(Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? const Color(0xFF2E88D8)
                                  : const Color(0xFF2B3850),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    _activeAudioPath == mediaSource
                                        ? Icons.stop
                                        : Icons.play_arrow,
                                    color: Colors.white,
                                  ),
                                  tooltip: 'Reproducir nota de voz',
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    _playAudioMessage(mediaSource);
                                  },
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Nota de voz',
                                        style: TextStyle(color: Colors.white)),
                                    Text(
                                      _formatDuration(audioDuration),
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 12),
                                    ),
                                    _buildUploadStatus(msg,
                                        mediaSource: mediaSource),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ));
                      }

                      final _msgTime =
                          _formatMessageTime(msg['timestamp'] as String?);
                      return wrapSep(Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? const Color(0xFF1A6FC4)
                                  : const Color(0xFF1B2E43),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(isMe ? 18 : 4),
                                bottomRight: Radius.circular(isMe ? 4 : 18),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(40),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    text,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 15),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _msgTime,
                                      style: const TextStyle(
                                          color: Colors.white38, fontSize: 10),
                                    ),
                                    if (isMe) ...[
                                      const SizedBox(width: 3),
                                      const Icon(Icons.done_all,
                                          size: 12, color: Color(0xFF4FC3F7)),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ));
                    },
                  ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0D2138),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF264A6A)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(30),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CameraIconButton(
                      icon: _isRecording ? Icons.stop : Icons.mic,
                      tooltip: _isRecording
                          ? 'Detener grabación'
                          : 'Grabar nota de voz',
                      onTap: () {
                        HapticFeedback.selectionClick();
                        unawaited(_toggleRecording());
                      },
                    ),
                    CameraIconButton(
                      icon: Icons.camera_alt,
                      tooltip: 'Tomar foto',
                      onTap: () {
                        HapticFeedback.selectionClick();
                        unawaited(_captureImage());
                      },
                    ),
                    CameraIconButton(
                      icon: Icons.videocam,
                      tooltip: 'Grabar video',
                      onTap: () {
                        HapticFeedback.selectionClick();
                        unawaited(_captureVideo());
                      },
                    ),
                    if (!isCompact)
                      CameraIconButton(
                        icon: Icons.emoji_emotions,
                        tooltip: 'Emojis/Stickers',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _openEmojiPicker();
                        },
                      ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Escribe un mensaje...',
                          filled: true,
                          fillColor: const Color(0xFF122A43),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF2A4E72)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF2A4E72)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF36C0FF), Color(0xFF1E8DFF)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CameraIconButton(
                        icon: Icons.send,
                        tooltip: 'Enviar mensaje',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          unawaited(_sendMessage());
                        },
                      ),
                    ),
                  ],
                ),
                if (isCompact)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        _openEmojiPicker();
                      },
                      icon: const Icon(Icons.emoji_emotions, size: 18),
                      label: const Text('Emojis'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactAvatar extends StatelessWidget {
  final String name;
  final double size;

  const _ContactAvatar({required this.name, this.size = 38});

  @override
  Widget build(BuildContext context) {
    final words = name.trim().split(RegExp(r'\s+'));
    final initials = words.isEmpty
        ? '?'
        : words.take(2).map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join();
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF2FA0FF), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  final String source;
  final bool isRemote;

  const _VideoPreview({required this.source, required this.isRemote});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;

  @override
  void initState() {
    super.initState();
    _controller = widget.isRemote
        ? VideoPlayerController.networkUrl(Uri.parse(widget.source))
        : VideoPlayerController.file(File(widget.source));
    _initializeFuture = _controller!.initialize();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null) return;

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return _buildFallback();
    }

    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            width: 220,
            height: 140,
            color: Colors.black.withValues(alpha: 0.25),
            alignment: Alignment.center,
            child: const CircularProgressIndicator(strokeWidth: 2),
          );
        }

        if (snapshot.hasError) {
          return _buildFallback();
        }

        return GestureDetector(
          onTap: _togglePlayback,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 220,
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio == 0
                      ? 16 / 9
                      : controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFallback() {
    return Container(
      width: 220,
      height: 140,
      color: Colors.black.withValues(alpha: 0.25),
      alignment: Alignment.center,
      child: const Icon(Icons.videocam, color: Colors.white, size: 32),
    );
  }
}
