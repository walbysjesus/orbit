import 'package:flutter/material.dart';
import '../services/locale_service.dart';

class FadeInWelcome extends StatefulWidget {
  final Widget child;
  const FadeInWelcome({required this.child, super.key});

  @override
  State<FadeInWelcome> createState() => _FadeInWelcomeState();
}

class _FadeInWelcomeState extends State<FadeInWelcome>
    with SingleTickerProviderStateMixin {
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
  const LanguageFab({super.key});

  @override
  State<LanguageFab> createState() => _LanguageFabState();
}

class _LanguageFabState extends State<LanguageFab> {
  final Map<String, String> _langs = const {
    'es': '🇪🇸 Español',
    'en': '🇺🇸 English',
    'pt': '🇧🇷 Português',
    'fr': '🇫🇷 Français',
    'nl': '🇸🇷 Nederlands',
    'de': '🇩🇪 Deutsch',
    'it': '🇮🇹 Italiano',
  };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) {
        final selected = locale.languageCode;
        return FloatingActionButton(
          backgroundColor: const Color(0xFF3389FF),
          tooltip: 'Seleccionar idioma',
          child: const Icon(Icons.language, color: Colors.white),
          onPressed: () async {
            if (!mounted) return;
            final result = await showModalBottomSheet<String>(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (sheetContext) {
                return ListView(
                  shrinkWrap: true,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Seleccionar idioma',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF0A4D8F),
                        ),
                      ),
                    ),
                    ..._langs.entries.map((entry) => ListTile(
                          leading: selected == entry.key
                              ? const Icon(Icons.check,
                                  color: Color(0xFF3389FF))
                              : const SizedBox(width: 24),
                          title: Text(entry.value),
                          onTap: () => Navigator.pop(sheetContext, entry.key),
                        )),
                    const SizedBox(height: 8),
                  ],
                );
              },
            );
            if (!mounted) return;
            if (result != null && result != selected) {
              localeNotifier.value = Locale(result);
            }
          },
        );
      },
    );
  }
}
