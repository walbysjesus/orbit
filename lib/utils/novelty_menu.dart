import 'package:flutter/material.dart';

class NoveltyMenu extends StatelessWidget {
  final void Function(String) onSelected;
  const NoveltyMenu({required this.onSelected, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      onSelected: onSelected,
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'privacy',
          child: Text('Privacidad de novedades'),
        ),
        const PopupMenuItem(
          value: 'highlight',
          child: Text('Destacar novedades'),
        ),
        const PopupMenuItem(
          value: 'settings',
          child: Text('Ajustes de novedades'),
        ),
        const PopupMenuItem(
          value: 'general',
          child: Text('Ir a Ajustes generales'),
        ),
      ],
    );
  }
}
