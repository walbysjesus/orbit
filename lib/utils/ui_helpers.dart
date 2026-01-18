import 'package:flutter/material.dart';

class FadeInWelcome extends StatefulWidget {
  final Widget child;
  const FadeInWelcome({required this.child, Key? key}) : super(key: key);

  @override
  State<FadeInWelcome> createState() => _FadeInWelcomeState();
}

class _FadeInWelcomeState extends State<FadeInWelcome> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: widget.child,
    );
  }
}

class LanguageFab extends StatefulWidget {
  const LanguageFab({Key? key}) : super(key: key);

  @override
  State<LanguageFab> createState() => _LanguageFabState();
}

class _LanguageFabState extends State<LanguageFab> {
  String _selected = 'es';

  final Map<String, String> _langs = const {
    'es': 'Español',
    'en': 'English',
    'fr': 'Français',
    'de': 'Deutsch',
  };

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: const Color(0xFF3389FF),
      tooltip: 'Seleccionar idioma',
      child: const Icon(Icons.language, color: Colors.white),
      onPressed: () async {
        if (!mounted) return;
        final bottomSheetContext = context;
        final result = await showModalBottomSheet<String>(
          context: bottomSheetContext,
          builder: (sheetContext) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: _langs.entries.map((entry) {
                return ListTile(
                  leading: _selected == entry.key
                      ? const Icon(Icons.check, color: Color(0xFF3389FF))
                      : null,
                  title: Text(entry.value),
                  onTap: () => Navigator.pop(sheetContext, entry.key),
                );
              }).toList(),
            );
          },
        );
        if (!mounted) return;
        if (result != null && result != _selected) {
          setState(() => _selected = result);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Idioma seleccionado: ${_langs[result]}',
                ),
              ),
            );
          }
        }
      },
    );
  }
}
