import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';



class ChatScreen extends StatefulWidget {
  final String contactNameOrId;
  const ChatScreen({super.key, required this.contactNameOrId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  final _key = encrypt.Key.fromUtf8('my32lengthsupersecretnooneknows1');
  final _iv = encrypt.IV.fromLength(16);
  late encrypt.Encrypter _encrypter;

  List<Map<String, dynamic>> _messages = [];
  bool _isRecording = false;
  bool _sendingFile = false;

  MaterialBanner? _banner;

  @override
  void initState() {
    super.initState();
    _encrypter = encrypt.Encrypter(encrypt.AES(_key));
    _initAudio();
    _loadMessages();
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    super.dispose();
  }

  Future<void> _initAudio() async {
    await Permission.microphone.request();
    await _recorder.openRecorder();
  }

  // ================= MESSAGES =================

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('chat_${widget.contactNameOrId}');
    if (raw != null) {
      setState(() {
        _messages = List<Map<String, dynamic>>.from(jsonDecode(raw));
      });
    }
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'chat_${widget.contactNameOrId}',
      jsonEncode(_messages),
    );
  }

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;

    final encrypted =
        _encrypter.encrypt(_controller.text.trim(), iv: _iv);

    setState(() {
      _messages.add({
        'text': encrypted.base64,
        'fromMe': true,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });

    _controller.clear();
    _saveMessages();
  }

  // ================= FILE =================

  Future<void> _sendFile() async {
    setState(() => _sendingFile = true);

    try {
      final result = await FilePicker.platform.pickFiles();
      if (result?.files.single.path != null) {
        final file = result!.files.single;

        setState(() {
          _messages.add({
            'text': file.name,
            'filePath': file.path,
            'fromMe': true,
            'timestamp': DateTime.now().toIso8601String(),
          });
        });

        _saveMessages();
      }
    } catch (e) {
      _showBanner('Error al seleccionar archivo', Colors.red);
    }

    setState(() => _sendingFile = false);
  }

  // ================= AUDIO =================

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stopRecorder();
      setState(() => _isRecording = false);

      if (path != null) {
        setState(() {
          _messages.add({
            'text': 'Audio',
            'audioPath': path,
            'fromMe': true,
            'timestamp': DateTime.now().toIso8601String(),
          });
        });
        _saveMessages();
      }
    } else {
      await _recorder.startRecorder(toFile: 'audio.aac');
      setState(() => _isRecording = true);
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
            onPressed: () => setState(() => _banner = null),
            child: const Text('Cerrar', style: TextStyle(color: Colors.white)),
          )
        ],
      );
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _banner = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contactNameOrId),
        actions: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: _sendingFile ? null : _sendFile,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_banner != null) _banner!,
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final msg = _messages[i];
                final isMe = msg['fromMe'] == true;

                String text = msg['text'];
                try {
                  text = _encrypter.decrypt64(text, iv: _iv);
                } catch (_) {}

                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue : Colors.grey[700],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(text,
                        style: const TextStyle(color: Colors.white)),
                  ),
                );
              },
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                onPressed: _toggleRecording,
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration:
                      const InputDecoration(hintText: 'Mensaje...'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
