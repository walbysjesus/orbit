import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../../services/auth_service.dart';
import '../../utils/camera_icon_button.dart';
import '../../utils/novelty_menu.dart';
import 'novelty_search_delegate.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  static const String _cacheKey = 'orbit_local_statuses_v2';

  List<Map<String, dynamic>> _statuses = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _textController = TextEditingController();

  XFile? _selectedMedia;
  String? _selectedMediaType;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadStatuses() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_cacheKey) ?? const [];
      final parsed = raw
          .map((entry) => jsonDecode(entry) as Map<String, dynamic>)
          .where((item) {
        final mediaPath = item['mediaPath']?.toString();
        if (mediaPath == null || mediaPath.isEmpty) return true;
        return File(mediaPath).existsSync();
      }).toList()
        ..sort((a, b) => (b['createdAt'] ?? '')
            .toString()
            .compareTo((a['createdAt'] ?? '').toString()));

      if (!mounted) return;
      setState(() {
        _statuses = parsed;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los estados';
        _loading = false;
      });
    }
  }

  Future<void> _persistStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _cacheKey,
      _statuses.map((item) => jsonEncode(item)).toList(),
    );
  }

  Future<void> _pickMedia({
    required ImageSource source,
    required bool isVideo,
  }) async {
    try {
      final picked = isVideo
          ? await _picker.pickVideo(
              source: source,
              maxDuration: const Duration(seconds: 30),
              preferredCameraDevice: CameraDevice.rear,
            )
          : await _picker.pickImage(
              source: source,
              imageQuality: 88,
              maxWidth: 1920,
            );

      if (!mounted || picked == null) return;
      setState(() {
        _selectedMedia = picked;
        _selectedMediaType = isVideo ? 'video' : 'image';
      });
    } catch (e) {
      _showSnack('No se pudo abrir la camara o galeria');
    }
  }

  Future<void> _submitStatus() async {
    if (_submitting) return;
    final text = _textController.text.trim();
    if (text.isEmpty && _selectedMedia == null) {
      _showSnack('Agrega texto, foto o video para publicar');
      return;
    }

    setState(() => _submitting = true);

    final now = DateTime.now();
    final user = AuthService.getCurrentUser();
    final localStatus = {
      'id': now.microsecondsSinceEpoch.toString(),
      'userName': (user?.displayName?.trim().isNotEmpty ?? false)
          ? user!.displayName!.trim()
          : 'Tu',
      'text': text.isEmpty ? 'Actualización sin texto' : text,
      'mediaPath': _selectedMedia?.path,
      'mediaType': _selectedMediaType,
      'date': _formatDateTime(now),
      'createdAt': now.toIso8601String(),
      'isLocalFile': _selectedMedia != null,
    };

    setState(() {
      _statuses.insert(0, localStatus);
    });

    await _persistStatuses();

    _textController.clear();
    _selectedMedia = null;
    _selectedMediaType = null;

    if (!mounted) return;
    _showSnack('Estado publicado');
    setState(() => _submitting = false);
  }

  Future<void> _deleteStatus(Map<String, dynamic> status) async {
    setState(() {
      _statuses.removeWhere((item) => item['id'] == status['id']);
    });
    await _persistStatuses();
    if (!mounted) return;
    _showSnack('Estado eliminado');
  }

  String _formatDateTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$d/$mo · $h:$m';
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  List<Map<String, dynamic>> get _visibleStatuses {
    if (_searchQuery.trim().isEmpty) return _statuses;
    final q = _searchQuery.toLowerCase();
    return _statuses.where((s) {
      return (s['userName'] ?? '').toString().toLowerCase().contains(q) ||
          (s['text'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
  }

  void _showComposerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFFFFF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setModalState) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _textController,
                  maxLines: 3,
                  style: const TextStyle(
                      color: Color(0xFF123A5B),
                      fontSize: 16,
                      fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: '¿Qué quieres compartir?',
                    hintStyle:
                        const TextStyle(color: Color(0xFF7B8FA2), fontSize: 15),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: const Color(0xFFF8FCFF),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 16),
                  ),
                ),
                const SizedBox(height: 16),
                if (_selectedMedia != null)
                  _ComposerMediaPreview(
                    mediaPath: _selectedMedia!.path,
                    mediaType: _selectedMediaType ?? 'image',
                    onRemove: () {
                      setState(() {
                        _selectedMedia = null;
                        _selectedMediaType = null;
                      });
                      setModalState(() {});
                    },
                  ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _ComposerActionButton(
                      icon: Icons.photo_camera_rounded,
                      label: 'Camara',
                      onTap: () async {
                        await _pickMedia(
                          source: ImageSource.camera,
                          isVideo: false,
                        );
                        setModalState(() {});
                      },
                    ),
                    _ComposerActionButton(
                      icon: Icons.videocam_rounded,
                      label: 'Video',
                      onTap: () async {
                        await _pickMedia(
                          source: ImageSource.camera,
                          isVideo: true,
                        );
                        setModalState(() {});
                      },
                    ),
                    _ComposerActionButton(
                      icon: Icons.collections_rounded,
                      label: 'Galeria',
                      onTap: () async {
                        await _showGalleryPickerSheet();
                        setModalState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send),
                  label: const Text('Compartir novedad'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A4D8F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 24),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  onPressed: _submitting
                      ? null
                      : () async {
                          Navigator.of(context).pop();
                          await _submitStatus();
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showGalleryPickerSheet() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFFFFFFFF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    const Icon(Icons.image_rounded, color: Color(0xFF0A4D8F)),
                title: const Text('Elegir foto',
                    style: TextStyle(color: Color(0xFF123A5B))),
                onTap: () => Navigator.of(ctx).pop('image'),
              ),
              ListTile(
                leading: const Icon(Icons.movie_creation_rounded,
                    color: Color(0xFF0A4D8F)),
                title: const Text('Elegir video',
                    style: TextStyle(color: Color(0xFF123A5B))),
                onTap: () => Navigator.of(ctx).pop('video'),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected == null) return;
    await _pickMedia(
      source: ImageSource.gallery,
      isVideo: selected == 'video',
    );
  }

  void _openStatusViewer(Map<String, dynamic> item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _StatusViewerScreen(status: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8FD),
      appBar: AppBar(
        title: const Text('Novedades'),
        backgroundColor: const Color(0xFFFFFFFF),
        foregroundColor: const Color(0xFF0A4D8F),
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        leading: NoveltyMenu(
          onSelected: (value) {
            // Acciones del menú de tres puntos
            if (value == 'general') {
              Navigator.of(context).pushNamed('/settings');
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Opción: $value')),
              );
            }
          },
        ),
        actions: [
          CameraIconButton(
            icon: Icons.search,
            tooltip: 'Buscar novedades',
            onTap: () async {
              HapticFeedback.selectionClick();
              final query = await showSearch<String>(
                context: context,
                delegate: NoveltySearchDelegate(_statuses),
              );
              setState(() {
                _searchQuery = (query ?? '').trim();
              });
            },
          ),
          if (_searchQuery.isNotEmpty)
            CameraIconButton(
              icon: Icons.clear,
              tooltip: 'Limpiar búsqueda',
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _searchQuery = '';
                });
              },
            ),
          CameraIconButton(
            icon: Icons.add_a_photo,
            tooltip: 'Agregar novedad',
            onTap: () {
              HapticFeedback.selectionClick();
              _showComposerSheet();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0A4D8F)))
          : _error != null
              ? Center(
                  child: Text('Error: $_error',
                      style: const TextStyle(color: Colors.redAccent)))
              : _visibleStatuses.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.camera_enhance_rounded,
                              color: Color(0xFF7BD5FF),
                              size: 58,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No hay estados recientes'
                                  : 'Sin resultados para "$_searchQuery"',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Color(0xFF4D6880), fontSize: 18),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: _showComposerSheet,
                              icon:
                                  const Icon(Icons.add_photo_alternate_rounded),
                              label: const Text('Crear estado'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFFFF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFC9DEEE)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.dynamic_feed,
                                  color: Color(0xFF8BD4FF)),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Feed de novedades Orbit',
                                  style: TextStyle(
                                    color: Color(0xFF123A5B),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  _showComposerSheet();
                                },
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Publicar'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        ..._visibleStatuses.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          final mediaPath = item['mediaPath']?.toString();
                          final mediaType =
                              item['mediaType']?.toString() ?? 'image';

                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration:
                                Duration(milliseconds: 260 + (index * 35)),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, (1 - value) * 10),
                                  child: child,
                                ),
                              );
                            },
                            child: _StatusCard(
                              item: item,
                              mediaPath: mediaPath,
                              mediaType: mediaType,
                              onOpen: () => _openStatusViewer(item),
                              onDelete: () => _deleteStatus(item),
                            ),
                          );
                        }),
                      ],
                    ),
    );
  }
}

class _ComposerActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ComposerActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      icon: Icon(icon, color: const Color(0xFF0A4D8F)),
      label: Text(label, style: const TextStyle(color: Color(0xFF123A5B))),
      style: TextButton.styleFrom(
        backgroundColor: const Color(0xFFEAF5FE),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
      ),
      onPressed: onTap,
    );
  }
}

class _ComposerMediaPreview extends StatelessWidget {
  final String mediaPath;
  final String mediaType;
  final VoidCallback onRemove;

  const _ComposerMediaPreview({
    required this.mediaPath,
    required this.mediaType,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isVideo = mediaType == 'video';
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 160,
            width: double.infinity,
            color: const Color(0xFFEAF5FE),
            child: isVideo
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: const Color(0xFFDCEEFE)),
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          color: Color(0xFF0A4D8F),
                          size: 54,
                        ),
                      ),
                      const Positioned(
                        left: 12,
                        bottom: 12,
                        child: Text(
                          'Video listo para publicar',
                          style: TextStyle(color: Color(0xFF4D6880)),
                        ),
                      ),
                    ],
                  )
                : Image.file(
                    File(mediaPath),
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.redAccent),
            tooltip: 'Quitar archivo',
            onPressed: onRemove,
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String? mediaPath;
  final String mediaType;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _StatusCard({
    required this.item,
    required this.mediaPath,
    required this.mediaType,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasMedia = mediaPath != null && mediaPath!.isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: hasMedia ? onOpen : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFEAF5FE)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFC9DEEE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFDCEEFE),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                title: Text(
                  (item['userName'] ?? 'Sin nombre').toString(),
                  style: const TextStyle(
                    color: Color(0xFF123A5B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  (item['date'] ?? '').toString(),
                  style: const TextStyle(
                    color: Color(0xFF4D6880),
                    fontSize: 12,
                  ),
                ),
                trailing: PopupMenuButton<String>(
                  color: const Color(0xFFFFFFFF),
                  icon: const Icon(Icons.more_vert, color: Color(0xFF5A7388)),
                  onSelected: (value) {
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Eliminar'),
                    ),
                  ],
                ),
              ),
              if (hasMedia)
                ClipRRect(
                  child: SizedBox(
                    width: double.infinity,
                    height: 210,
                    child: mediaType == 'video'
                        ? Container(
                            color: const Color(0xFFDCEEFE),
                            child: const Center(
                              child: Icon(
                                Icons.play_circle_fill_rounded,
                                color: Color(0xFF0A4D8F),
                                size: 62,
                              ),
                            ),
                          )
                        : Image.file(
                            File(mediaPath!),
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              if ((item['text'] ?? '').toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  child: Text(
                    (item['text'] ?? '').toString(),
                    style: const TextStyle(
                      color: Color(0xFF123A5B),
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusViewerScreen extends StatelessWidget {
  final Map<String, dynamic> status;

  const _StatusViewerScreen({required this.status});

  @override
  Widget build(BuildContext context) {
    final mediaPath = status['mediaPath']?.toString();
    final mediaType = status['mediaType']?.toString() ?? 'image';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text((status['userName'] ?? 'Estado').toString()),
      ),
      body: mediaPath == null || mediaPath.isEmpty
          ? Center(
              child: Text(
                (status['text'] ?? 'Sin contenido').toString(),
                style: const TextStyle(color: Colors.white),
              ),
            )
          : Stack(
              children: [
                Positioned.fill(
                  child: mediaType == 'video'
                      ? _StatusVideoPlayer(path: mediaPath)
                      : InteractiveViewer(
                          child: Center(
                            child: Image.file(File(mediaPath)),
                          ),
                        ),
                ),
                if ((status['text'] ?? '').toString().isNotEmpty)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 24,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(140),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        (status['text'] ?? '').toString(),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _StatusVideoPlayer extends StatefulWidget {
  final String path;

  const _StatusVideoPlayer({required this.path});

  @override
  State<_StatusVideoPlayer> createState() => _StatusVideoPlayerState();
}

class _StatusVideoPlayerState extends State<_StatusVideoPlayer> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.path))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller?.setLooping(true);
        _controller?.play();
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: VideoPlayer(controller),
      ),
    );
  }
}
