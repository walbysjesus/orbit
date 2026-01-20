import 'package:flutter/material.dart';

class CameraIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const CameraIconButton({required this.icon, required this.tooltip, required this.onTap, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        onTap();
        // Feedback visual PRO
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tooltip), duration: const Duration(milliseconds: 800)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
