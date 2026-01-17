import 'package:flutter/material.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        title: const Text('Contacts'),
        backgroundColor: const Color(0xFF001F3F),
        elevation: 0,
      ),
      body: ListView.builder(
        itemCount: 5,
        itemBuilder: (_, index) {
          return ListTile(
            leading: const Icon(Icons.person, color: Colors.white),
            title: Text(
              'Contact ${index + 1}',
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Orbit Network',
              style: TextStyle(color: Colors.white70),
            ),
          );
        },
      ),
    );
  }
}
