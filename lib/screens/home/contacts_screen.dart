import '../../utils/camera_icon_button.dart';
import 'package:flutter/material.dart';
import '../../models/orbit_user.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final List<OrbitUser> _contacts = [];
  List<OrbitUser> _filtered = [];
  bool _loading = false;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String _newName = '';
  String _newEmail = '';

  @override
  void initState() {
    super.initState();
    _filtered = List.from(_contacts);
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
                    uid: DateTime.now()
                        .millisecondsSinceEpoch
                        .toString(),
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
                  final idx = _contacts.indexWhere(
                      (c) => c.uid == contact.uid);
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
    setState(() {
      if (query.isEmpty) {
        _filtered = List.from(_contacts);
      } else {
        _filtered = _contacts.where((c) {
          return (c.fullName ?? '')
                  .toLowerCase()
                  .contains(query.toLowerCase()) ||
              (c.email ?? '')
                  .toLowerCase()
                  .contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    // Contactos modo PRO: búsqueda avanzada y botón elegante
    return Scaffold(
      appBar: AppBar(
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
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Búsqueda avanzada (nombre, email, empresa...)',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: _filterContacts,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.person_add, color: Colors.white),
                  label: const Text('Agregar', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3389FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                  ),
                  onPressed: _addContact,
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(child: Text('No hay contactos', style: TextStyle(color: Colors.white70)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        itemCount: _filtered.length,
                        itemBuilder: (_, index) {
                          final contact = _filtered[index];
                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                            child: ListTile(
                              leading: const Icon(Icons.person, color: Color(0xFF3389FF)),
                              title: Text(contact.fullName ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(contact.email ?? '', style: const TextStyle(color: Colors.black54)),
                              trailing: Wrap(
                                spacing: 8,
                                children: [
                                  CameraIconButton(
                                    icon: Icons.edit,
                                    tooltip: 'Editar contacto',
                                    onTap: () => _editContact(index),
                                  ),
                                  CameraIconButton(
                                    icon: Icons.delete,
                                    tooltip: 'Eliminar contacto',
                                    onTap: () => _deleteContact(index),
                                  ),
                                ],
                              ),
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
