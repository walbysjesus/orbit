import '../../utils/camera_icon_button.dart';
import 'package:flutter/material.dart';
// import '../../services/status_api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../utils/novelty_menu.dart';
import 'novelty_search_delegate.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  List<Map<String, dynamic>> _statuses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    // Sin backend, lista vacía/local
    setState(() {
      _statuses = [];
      _loading = false;
    });
  }

  XFile? _selectedImage;
  final TextEditingController _textController = TextEditingController();
  bool _submitting = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    setState(() => _selectedImage = picked);
  }

  Future<void> _submitStatus() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    // Sin backend, solo limpiar campos
    _textController.clear();
    _selectedImage = null;
    await _loadStatuses();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Estado publicado (solo local)')));
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        // Título visual cambiado a "Novedades"
        title: const Text('Novedades'),
        backgroundColor: const Color(0xFF001F3F),
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
              final query = await showSearch<String>(
                context: context,
                delegate: NoveltySearchDelegate(_statuses),
              );
              if (query != null && query.isNotEmpty) {
                setState(() {
                  _statuses = _statuses.where((s) =>
                    (s['userName'] ?? '').toLowerCase().contains(query.toLowerCase()) ||
                    (s['text'] ?? '').toLowerCase().contains(query.toLowerCase())
                  ).toList();
                });
              }
            },
          ),
          CameraIconButton(
            icon: Icons.add_a_photo,
            tooltip: 'Agregar novedad (foto)',
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: const Color(0xFF001F3F),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: StatefulBuilder(
                    builder: (ctx, setModalState) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: _textController,
                            maxLines: 3,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                            decoration: InputDecoration(
                              hintText: '¿Qué quieres compartir?',
                              hintStyle: const TextStyle(color: Colors.white54, fontSize: 15),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              filled: true,
                              fillColor: Colors.black26,
                              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_selectedImage != null)
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.file(
                                    File(_selectedImage!.path),
                                    height: 140,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    onPressed: () {
                                      setState(() => _selectedImage = null);
                                      setModalState(() {});
                                    },
                                  ),
                                ),
                              ],
                            ),
                          TextButton.icon(
                            icon: const Icon(Icons.image, color: Colors.white),
                            label: const Text('Seleccionar imagen', style: TextStyle(color: Colors.white)),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.blueGrey.shade900,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                            ),
                            onPressed: () async {
                              await _pickImage();
                              setModalState(() {});
                            },
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: _submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
                            label: const Text('Compartir novedad'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3389FF),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            onPressed: _submitting ? null : () async {
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
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.redAccent)))
              : _statuses.isEmpty
                  ? const Center(child: Text('No hay estados recientes', style: TextStyle(color: Colors.white70, fontSize: 18)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                      itemCount: _statuses.length,
                      itemBuilder: (_, i) {
                        final item = _statuses[i];
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha((0.25 * 255).toInt()),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blueAccent.withAlpha((0.08 * 255).toInt()),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                            leading: item['photoUrl'] != null
                                ? CircleAvatar(
                                    radius: 32,
                                    backgroundImage: NetworkImage(item['photoUrl']),
                                    backgroundColor: Colors.blueGrey.shade800,
                                  )
                                : CircleAvatar(
                                    radius: 32,
                                    backgroundColor: Colors.blueGrey.shade800,
                                    child: const Icon(Icons.person, color: Colors.white, size: 32),
                                  ),
                            title: Text(
                              item['userName'] ?? 'Sin nombre',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                item['text'] ?? '',
                                style: const TextStyle(color: Colors.white70, fontSize: 16),
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.circle, color: Colors.blueAccent, size: 12),
                                const SizedBox(height: 4),
                                Text(
                                  item['date'] ?? '',
                                  style: const TextStyle(color: Colors.blueAccent, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
