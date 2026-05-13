import '../../utils/camera_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/orbit_user.dart';
import '../../services/auth_service.dart';
import '../communication/chat_screen.dart' as chat_screen;
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
  final Set<String> _favoriteContactUids = <String>{};
  final Set<String> _blockedContactUids = <String>{};

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String _newName = '';
  String _newEmail = '';
  String _newOrbitNumber = '';

  @override
  void initState() {
    super.initState();
    _selectedAction = widget.initialAction;
    _filtered = List.from(_contacts);
    _loadContacts();
    _loadContactPreferences();
  }

  @override
  void dispose() {
    _orbitIdController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final currentUid = AuthService.getCurrentUser()?.uid;
    if (currentUid == null) return;
    if (!mounted) return; // lifecycle safety fix
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('contacts')
          .orderBy('fullName')
          .get();
      final loaded = snap.docs.map((d) {
        final data = d.data();
        return OrbitUser(
          uid: data['uid'] as String? ?? d.id,
          orbitNumber: data['orbitNumber'] as String?,
          fullName: data['fullName'] as String?,
          email: data['email'] as String?,
        );
      }).toList();
      if (mounted) {
        setState(() {
          _contacts
            ..clear()
            ..addAll(loaded);
          _filtered = List.from(_contacts);
        });
      }
    } catch (_) {
      // ignore load errors silently
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadContactPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList('contactsFavorites') ?? [];
    final blocked = prefs.getStringList('contactsBlocked') ?? [];
    if (!mounted) return;
    setState(() {
      _favoriteContactUids
        ..clear()
        ..addAll(favorites);
      _blockedContactUids
        ..clear()
        ..addAll(blocked);
    });
  }

  Future<void> _saveContactPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'contactsFavorites', _favoriteContactUids.toList());
    await prefs.setStringList('contactsBlocked', _blockedContactUids.toList());
  }

  bool _isFavorite(OrbitUser contact) =>
      _favoriteContactUids.contains(contact.uid);

  bool _isBlocked(OrbitUser contact) =>
      _blockedContactUids.contains(contact.uid);

  Future<void> _toggleFavoriteContact(OrbitUser contact) async {
    final nowFavorite = !_isFavorite(contact);
    setState(() {
      if (nowFavorite) {
        _favoriteContactUids.add(contact.uid);
      } else {
        _favoriteContactUids.remove(contact.uid);
      }
    });
    await _saveContactPreferences();
    if (!mounted) return;
    if (!context.mounted) return; // lifecycle safety fix
    final name = (contact.fullName ?? contact.uid).trim();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(nowFavorite
            ? '$name agregado a favoritos'
            : '$name eliminado de favoritos'),
      ),
    );
  }

  Future<void> _toggleBlockedContact(OrbitUser contact) async {
    final nowBlocked = !_isBlocked(contact);
    setState(() {
      if (nowBlocked) {
        _blockedContactUids.add(contact.uid);
      } else {
        _blockedContactUids.remove(contact.uid);
      }
    });
    await _saveContactPreferences();
    if (!mounted) return;
    if (!context.mounted) return; // lifecycle safety fix
    final name = (contact.fullName ?? contact.uid).trim();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(nowBlocked ? '$name bloqueado' : '$name desbloqueado'),
      ),
    );
  }

  void _copyTextValue(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    if (!context.mounted) return; // lifecycle safety fix
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copiado')),
    );
  }

  Future<void> _showContactDetails(OrbitUser contact) async {
    final name = (contact.fullName ?? '').trim().isEmpty
        ? 'Sin nombre'
        : contact.fullName!.trim();
    final email = (contact.email ?? '').trim().isEmpty
        ? 'Sin correo'
        : contact.email!.trim();
    final orbit = (contact.orbitNumber ?? '').trim().isEmpty
        ? 'Sin Code Orbit'
        : contact.orbitNumber!.trim();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Detalles del contacto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nombre: $name'),
            const SizedBox(height: 6),
            Text('Correo: $email'),
            const SizedBox(height: 6),
            Text('Orbit: $orbit'),
            const SizedBox(height: 6),
            Text('UID: ${contact.uid}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareContact(OrbitUser contact) async {
    final name = (contact.fullName ?? '').trim().isEmpty
        ? 'Sin nombre'
        : contact.fullName!.trim();
    final email = (contact.email ?? '').trim().isEmpty
        ? 'Sin correo'
        : contact.email!.trim();
    final orbit = (contact.orbitNumber ?? '').trim().isEmpty
        ? 'Sin Code Orbit'
        : contact.orbitNumber!.trim();

    final shareText =
        'Contacto Orbit\nNombre: $name\nCorreo: $email\nCode Orbit: $orbit\nUID: ${contact.uid}';

    await SharePlus.instance.share(
      ShareParams(
        text: shareText,
        subject: 'Contacto Orbit',
      ),
    );
  }

  Future<void> _confirmDeleteContact(int index) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar contacto'),
        content:
            const Text('Esta accion no se puede deshacer. Deseas continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (accepted == true) {
      await _deleteContact(index);
    }
  }

  Future<void> _showContactLongPressMenu(OrbitUser contact, int index) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final favorite = _isFavorite(contact);
        final blocked = _isBlocked(contact);
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.chat_bubble_rounded),
                  title: const Text('Enviar mensaje'),
                  onTap: () => Navigator.of(ctx).pop('chat'),
                ),
                ListTile(
                  leading: const Icon(Icons.call_rounded),
                  title: const Text('Llamada de voz'),
                  onTap: () => Navigator.of(ctx).pop('voice'),
                ),
                ListTile(
                  leading: const Icon(Icons.videocam_rounded),
                  title: const Text('Videollamada'),
                  onTap: () => Navigator.of(ctx).pop('video'),
                ),
                ListTile(
                  leading: Icon(favorite ? Icons.star : Icons.star_border),
                  title: Text(
                      favorite ? 'Quitar de favoritos' : 'Agregar a favoritos'),
                  onTap: () => Navigator.of(ctx).pop('favorite'),
                ),
                ListTile(
                  leading: const Icon(Icons.content_copy_rounded),
                  title: const Text('Copiar Code Orbit'),
                  onTap: () => Navigator.of(ctx).pop('copyOrbit'),
                ),
                ListTile(
                  leading: const Icon(Icons.copy_all_rounded),
                  title: const Text('Copiar UID'),
                  onTap: () => Navigator.of(ctx).pop('copyUid'),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Ver detalles'),
                  onTap: () => Navigator.of(ctx).pop('details'),
                ),
                ListTile(
                  leading: const Icon(Icons.share_rounded),
                  title: const Text('Compartir contacto'),
                  onTap: () => Navigator.of(ctx).pop('share'),
                ),
                ListTile(
                  leading: Icon(blocked ? Icons.lock_open : Icons.block),
                  title: Text(
                      blocked ? 'Desbloquear contacto' : 'Bloquear contacto'),
                  onTap: () => Navigator.of(ctx).pop('block'),
                ),
                ListTile(
                  leading: const Icon(Icons.edit_rounded),
                  title: const Text('Editar contacto'),
                  onTap: () => Navigator.of(ctx).pop('edit'),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: Colors.red),
                  title: const Text('Eliminar contacto',
                      style: TextStyle(color: Colors.red)),
                  onTap: () => Navigator.of(ctx).pop('delete'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    switch (action) {
      case 'chat':
        await _openChat(contact);
        break;
      case 'voice':
        await _openVoiceCall(contact);
        break;
      case 'video':
        await _openVideoCall(contact);
        break;
      case 'favorite':
        await _toggleFavoriteContact(contact);
        break;
      case 'copyOrbit':
        final orbit = (contact.orbitNumber ?? '').trim();
        if (orbit.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Este contacto no tiene Code Orbit')),
          );
          return;
        }
        _copyTextValue('Code Orbit', orbit);
        break;
      case 'copyUid':
        _copyTextValue('UID', contact.uid);
        break;
      case 'details':
        await _showContactDetails(contact);
        break;
      case 'share':
        await _shareContact(contact);
        break;
      case 'block':
        await _toggleBlockedContact(contact);
        break;
      case 'edit':
        await _editContact(index);
        break;
      case 'delete':
        await _confirmDeleteContact(index);
        break;
      default:
        break;
    }
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

  Future<String?> _resolveContactUid(OrbitUser contact) async {
    final primary = contact.uid.trim();
    final fallback = (contact.orbitNumber ?? '').trim();
    final identifier = primary.isNotEmpty ? primary : fallback;
    if (identifier.isEmpty) return null;

    return AuthService.resolveUserIdFromContactIdentifier(identifier);
  }

  Future<void> _openByOrbitIdentifier() async {
    final raw = _orbitIdController.text.trim();
    if (raw.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un Code Orbit o UID')),
      );
      return;
    }

    final remoteUid = await AuthService.resolveUserIdFromContactIdentifier(raw);
    if (!mounted) return;

    if (remoteUid == null || remoteUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No existe un usuario con ese Code Orbit')),
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
              TextFormField(
                decoration: const InputDecoration(labelText: 'Code Orbit'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Ingrese Code Orbit' : null,
                onChanged: (v) => _newOrbitNumber = v,
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
            onPressed: () async {
              if (_formKey.currentState?.validate() ?? false) {
                final orbitNumber = _newOrbitNumber.trim();
                final resolvedUid =
                    await AuthService.resolveUserIdFromContactIdentifier(
                        orbitNumber);
                if (resolvedUid == null || resolvedUid.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code Orbit no encontrado')),
                  );
                  return;
                }

                final currentUid = AuthService.getCurrentUser()?.uid;
                if (currentUid != null && currentUid == resolvedUid) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('No puedes agregarte a ti mismo')),
                  );
                  return;
                }

                final contact = OrbitUser(
                  uid: resolvedUid,
                  orbitNumber: orbitNumber,
                  fullName: _newName,
                  email: _newEmail,
                );
                setState(() {
                  _contacts.removeWhere((c) => c.uid == contact.uid);
                  _contacts.add(contact);
                  _filtered = List.from(_contacts);
                });
                if (currentUid != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUid)
                      .collection('contacts')
                      .doc(resolvedUid)
                      .set({
                    'uid': resolvedUid,
                    'orbitNumber': orbitNumber,
                    'fullName': contact.fullName,
                    'email': contact.email,
                    'createdAt': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
          ),
        ],
      ),
    );

    _newName = '';
    _newEmail = '';
    _newOrbitNumber = '';
  }

  // ================== EDIT ==================
  Future<void> _editContact(int index) async {
    final contact = _filtered[index];
    _newName = contact.fullName ?? '';
    _newEmail = contact.email ?? '';
    _newOrbitNumber = contact.orbitNumber ?? '';

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
              TextFormField(
                initialValue: _newOrbitNumber,
                decoration: const InputDecoration(labelText: 'Code Orbit'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Ingrese Code Orbit' : null,
                onChanged: (v) => _newOrbitNumber = v,
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
            onPressed: () async {
              if (_formKey.currentState?.validate() ?? false) {
                final orbitNumber = _newOrbitNumber.trim();
                final resolvedUid =
                    await AuthService.resolveUserIdFromContactIdentifier(
                        orbitNumber);
                if (resolvedUid == null || resolvedUid.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code Orbit no encontrado')),
                  );
                  return;
                }

                final updated = OrbitUser(
                  uid: resolvedUid,
                  orbitNumber: orbitNumber,
                  fullName: _newName,
                  email: _newEmail,
                );
                setState(() {
                  final idx = _contacts.indexWhere((c) => c.uid == contact.uid);
                  if (idx != -1) {
                    _contacts[idx] = updated;
                    _filtered = List.from(_contacts);
                  }
                });
                final currentUid = AuthService.getCurrentUser()?.uid;
                if (currentUid != null) {
                  final contactsRef = FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUid)
                      .collection('contacts');

                  if (contact.uid != resolvedUid) {
                    await contactsRef.doc(contact.uid).delete();
                    await contactsRef.doc(resolvedUid).set({
                      'uid': resolvedUid,
                      'orbitNumber': orbitNumber,
                      'fullName': updated.fullName,
                      'email': updated.email,
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));
                  } else {
                    await contactsRef.doc(resolvedUid).set({
                      'uid': resolvedUid,
                      'orbitNumber': orbitNumber,
                      'fullName': updated.fullName,
                      'email': updated.email,
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));
                  }
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
          ),
        ],
      ),
    );

    _newName = '';
    _newEmail = '';
    _newOrbitNumber = '';
  }

  // ================== DELETE ==================
  Future<void> _deleteContact(int index) async {
    final contact = _filtered[index];
    setState(() {
      _contacts.removeWhere((c) => c.uid == contact.uid);
      _filtered = List.from(_contacts);
    });
    final currentUid = AuthService.getCurrentUser()?.uid;
    if (currentUid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('contacts')
          .doc(contact.uid)
          .delete();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contacto eliminado'),
          backgroundColor: Colors.green,
        ),
      );
    }
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
              (c.email ?? '').toLowerCase().contains(query.toLowerCase()) ||
              (c.orbitNumber ?? '').toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _openChat(OrbitUser contact) async {
    if (_isBlocked(contact)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este contacto esta bloqueado')),
      );
      return;
    }
    final remoteUid = await _resolveContactUid(contact);
    if (!mounted) return;
    if (remoteUid == null || remoteUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este contacto no tiene Orbit ID válido')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => chat_screen.ChatScreen(
          remoteUserId: remoteUid,
          initialContactName: (contact.fullName ?? '').trim().isEmpty
              ? null
              : contact.fullName!.trim(),
        ),
      ),
    );
  }

  Future<void> _openVoiceCall(OrbitUser contact) async {
    if (_isBlocked(contact)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este contacto esta bloqueado')),
      );
      return;
    }
    final remoteUid = await _resolveContactUid(contact);
    if (!mounted) return;
    if (remoteUid == null || remoteUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este contacto no tiene Orbit ID válido')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          remoteUserId: remoteUid,
          initialRemoteDisplayName: (contact.fullName ?? '').trim().isEmpty
              ? null
              : contact.fullName!.trim(),
          audioOnly: true,
          isCaller: true,
        ),
      ),
    );
  }

  Future<void> _openVideoCall(OrbitUser contact) async {
    if (_isBlocked(contact)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este contacto esta bloqueado')),
      );
      return;
    }
    final remoteUid = await _resolveContactUid(contact);
    if (!mounted) return;
    if (remoteUid == null || remoteUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este contacto no tiene Orbit ID válido')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          remoteUserId: remoteUid,
          initialRemoteDisplayName: (contact.fullName ?? '').trim().isEmpty
              ? null
              : contact.fullName!.trim(),
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
                      hintText: 'Code Orbit o UID para abrir directo',
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
                              onLongPress: () =>
                                  _showContactLongPressMenu(contact, index),
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
                                              Text(
                                                (contact.orbitNumber ?? '')
                                                        .trim()
                                                        .isEmpty
                                                    ? 'Sin Code Orbit'
                                                    : 'Code: ${contact.orbitNumber}',
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
                                            '${_actionLabel(_selectedAction)} > OR ${contact.orbitNumber ?? '-'}',
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
