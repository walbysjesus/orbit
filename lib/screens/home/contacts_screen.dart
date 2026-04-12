import '../../utils/camera_icon_button.dart';
import 'package:flutter/material.dart';
import '../../models/orbit_user.dart';
import '../../services/auth_service.dart';
import '../communication/chat_screen.dart';
import '../communication/video_call_screen.dart';

enum ContactActionType { chat, voiceCall, videoCall }

class ContactsScreen extends StatefulWidget {
  final ContactActionType initialAction;

  const ContactsScreen({
    super.key,
    this.initialAction = ContactActionType.chat,
  });

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final List<OrbitUser> _contacts = [];
  List<OrbitUser> _filtered = [];
  final TextEditingController _orbitIdController = TextEditingController();
  bool _loading = false;
  String _query = '';
  late ContactActionType _selectedAction;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String _newName = '';
  String _newEmail = '';

  @override
  void initState() {
    super.initState();
    _selectedAction = widget.initialAction;
    _filtered = List.from(_contacts);
  }

  @override
  void dispose() {
    _orbitIdController.dispose();
    super.dispose();
  }

  String _actionLabel(ContactActionType action) {
    switch (action) {
      case ContactActionType.chat:
        return 'Chat';
      case ContactActionType.voiceCall:
        return 'Llamada';
      case ContactActionType.videoCall:
        return 'Videollamada';
    }
  }

  void _openPreferredAction(OrbitUser contact) {
    switch (_selectedAction) {
      case ContactActionType.chat:
        _openChat(contact);
        break;
      case ContactActionType.voiceCall:
        _openVoiceCall(contact);
        break;
      case ContactActionType.videoCall:
        _openVideoCall(contact);
        break;
    }
  }

  Future<void> _openByOrbitIdentifier() async {
    final raw = _orbitIdController.text.trim();
    if (raw.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un numero Orbit o UID')),
      );
      return;
    }

    final remoteUid = await AuthService.resolveUserIdFromContactIdentifier(raw);
    if (!mounted) return;

    if (remoteUid == null || remoteUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No existe un usuario con ese numero Orbit')),
      );
      return;
    }

    final currentUid = AuthService.getCurrentUser()?.uid;
    if (currentUid != null && currentUid == remoteUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No puedes iniciar chat o llamada contigo mismo')),
      );
      return;
    }

    final tempContact = OrbitUser(uid: remoteUid, fullName: remoteUid);
    _openPreferredAction(tempContact);
  }

  // ================== ADD ==================
  Future<void> _addContact() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar contacto'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Ingrese nombre' : null,
                onChanged: (v) => _newName = v,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Ingrese email' : null,
                onChanged: (v) => _newEmail = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Agregar'),
            onPressed: () {
              if (_formKey.currentState?.validate() ?? false) {
                setState(() {
                  final contact = OrbitUser(
                    uid: DateTime.now().millisecondsSinceEpoch.toString(),
                    fullName: _newName,
                    email: _newEmail,
                  );
                  _contacts.add(contact);
                  _filtered = List.from(_contacts);
                });
                Navigator.of(ctx).pop();
              }
            },
          ),
        ],
      ),
    );

    _newName = '';
    _newEmail = '';
  }

  // ================== EDIT ==================
  Future<void> _editContact(int index) async {
    final contact = _filtered[index];
    _newName = contact.fullName ?? '';
    _newEmail = contact.email ?? '';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar contacto'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: _newName,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Ingrese nombre' : null,
                onChanged: (v) => _newName = v,
              ),
              TextFormField(
                initialValue: _newEmail,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Ingrese email' : null,
                onChanged: (v) => _newEmail = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Guardar'),
            onPressed: () {
              if (_formKey.currentState?.validate() ?? false) {
                setState(() {
                  final idx = _contacts.indexWhere((c) => c.uid == contact.uid);
                  if (idx != -1) {
                    _contacts[idx] = OrbitUser(
                      uid: contact.uid,
                      fullName: _newName,
                      email: _newEmail,
                    );
                    _filtered = List.from(_contacts);
                  }
                });
                Navigator.of(ctx).pop();
              }
            },
          ),
        ],
      ),
    );

    _newName = '';
    _newEmail = '';
  }

  // ================== DELETE ==================
  void _deleteContact(int index) {
    final contact = _filtered[index];
    setState(() {
      _contacts.removeWhere((c) => c.uid == contact.uid);
      _filtered = List.from(_contacts);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contacto eliminado'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ================== FILTER ==================
  void _filterContacts(String query) {
    _query = query.trim();
    setState(() {
      if (query.isEmpty) {
        _filtered = List.from(_contacts);
      } else {
        _filtered = _contacts.where((c) {
          return (c.fullName ?? '')
                  .toLowerCase()
                  .contains(query.toLowerCase()) ||
              (c.email ?? '').toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _openChat(OrbitUser contact) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(contactNameOrId: contact.uid),
      ),
    );
  }

  void _openVoiceCall(OrbitUser contact) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          remoteUserId: contact.uid,
          audioOnly: true,
          isCaller: true,
        ),
      ),
    );
  }

  void _openVideoCall(OrbitUser contact) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          remoteUserId: contact.uid,
          isCaller: true,
        ),
      ),
    );
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8FD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        foregroundColor: const Color(0xFF0A4D8F),
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        title: const Text('Contactos'),
        actions: [
          CameraIconButton(
            icon: Icons.add,
            tooltip: 'Agregar contacto',
            onTap: _addContact,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFC9DEEE)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre, correo o Orbit ID',
                      prefixIcon:
                          const Icon(Icons.search, color: Color(0xFF5F7890)),
                      hintStyle: const TextStyle(color: Color(0xFF7B8FA2)),
                      filled: true,
                      fillColor: const Color(0xFFF8FCFF),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFC9DEEE)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFC9DEEE)),
                      ),
                    ),
                    onChanged: _filterContacts,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.person_add, color: Colors.white),
                  label: const Text('Nuevo',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A4D8F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  onPressed: _addContact,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _orbitIdController,
                    decoration: InputDecoration(
                      hintText: 'Numero Orbit o UID para abrir directo',
                      prefixIcon: const Icon(Icons.alternate_email,
                          color: Color(0xFF5F7890)),
                      hintStyle: const TextStyle(color: Color(0xFF7B8FA2)),
                      filled: true,
                      fillColor: const Color(0xFFF8FCFF),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFC9DEEE)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFC9DEEE)),
                      ),
                    ),
                    onSubmitted: (_) => _openByOrbitIdentifier(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _openByOrbitIdentifier,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A4D8F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  child: const Text('Abrir'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Text(
                  'Accion:',
                  style: TextStyle(color: Color(0xFF4D6880)),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Chat'),
                  selected: _selectedAction == ContactActionType.chat,
                  selectedColor: const Color(0xFFD9EBFA),
                  backgroundColor: const Color(0xFFEFF6FC),
                  labelStyle: const TextStyle(color: Color(0xFF0A4D8F)),
                  onSelected: (_) =>
                      setState(() => _selectedAction = ContactActionType.chat),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Llamada'),
                  selected: _selectedAction == ContactActionType.voiceCall,
                  selectedColor: const Color(0xFFD9EBFA),
                  backgroundColor: const Color(0xFFEFF6FC),
                  labelStyle: const TextStyle(color: Color(0xFF0A4D8F)),
                  onSelected: (_) => setState(
                      () => _selectedAction = ContactActionType.voiceCall),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Video'),
                  selected: _selectedAction == ContactActionType.videoCall,
                  selectedColor: const Color(0xFFD9EBFA),
                  backgroundColor: const Color(0xFFEFF6FC),
                  labelStyle: const TextStyle(color: Color(0xFF0A4D8F)),
                  onSelected: (_) => setState(
                      () => _selectedAction = ContactActionType.videoCall),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _query.isEmpty
                    ? 'Todos los contactos (${_filtered.length})'
                    : 'Resultados para "$_query" (${_filtered.length})',
                style: const TextStyle(color: Color(0xFF4D6880), fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay contactos aún. Agrega el primero.',
                          style: TextStyle(color: Color(0xFF4D6880)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(10, 4, 10, 16),
                        itemCount: _filtered.length,
                        itemBuilder: (_, index) {
                          final contact = _filtered[index];
                          final displayName =
                              (contact.fullName ?? '').trim().isEmpty
                                  ? 'Sin nombre'
                                  : contact.fullName!.trim();
                          return InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _openPreferredAction(contact),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFFFFF),
                                      Color(0xFFE9F4FE)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: const Color(0xFFC3DAEC)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: [
                                                Color(0xFF58C2FF),
                                                Color(0xFF1F84E8)
                                              ],
                                            ),
                                          ),
                                          child: const Icon(Icons.person,
                                              color: Colors.white),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                displayName,
                                                style: const TextStyle(
                                                  color: Color(0xFF123A5B),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                contact.email ?? 'Sin correo',
                                                style: const TextStyle(
                                                  color: Color(0xFF617C90),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEAF5FE),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                                color: const Color(0xFFB8D5EA)),
                                          ),
                                          child: Text(
                                            '${_actionLabel(_selectedAction)} > ID ${contact.uid}',
                                            style: const TextStyle(
                                              color: Color(0xFF2D5D82),
                                              fontFamily: 'monospace',
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _QuickActionButton(
                                            icon: Icons.chat_bubble_rounded,
                                            label: 'Chat',
                                            color: const Color(0xFF2FA0FF),
                                            onTap: () => _openChat(contact),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _QuickActionButton(
                                            icon: Icons.call_rounded,
                                            label: 'Voz',
                                            color: const Color(0xFFFFA552),
                                            onTap: () =>
                                                _openVoiceCall(contact),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _QuickActionButton(
                                            icon: Icons.videocam_rounded,
                                            label: 'Video',
                                            color: const Color(0xFF46CFA2),
                                            onTap: () =>
                                                _openVideoCall(contact),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () => _editContact(index),
                                          icon:
                                              const Icon(Icons.edit, size: 16),
                                          label: const Text('Editar'),
                                        ),
                                        TextButton.icon(
                                          onPressed: () =>
                                              _deleteContact(index),
                                          icon: const Icon(Icons.delete,
                                              size: 16),
                                          label: const Text('Eliminar'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.redAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ));
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: color.withAlpha(35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(185)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
