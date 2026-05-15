import 'package:flutter/material.dart';

class CameraIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? iconColor;
  final bool showFeedback;
  const CameraIconButton(
      {required this.icon,
      required this.tooltip,
      required this.onTap,
      this.iconColor,
      this.showFeedback = false,
      super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          splashColor: Theme.of(context).colorScheme.primary.withAlpha(45),
          onTap: () {
            onTap();
            if (showFeedback) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(tooltip),
                    duration: const Duration(milliseconds: 800)),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              icon,
              color: iconColor ??
                  Theme.of(context).iconTheme.color ??
                  Colors.white,
              size: 28,
              semanticLabel: tooltip,
            ),
          ),
        ),
      ),
    );
  }
}
