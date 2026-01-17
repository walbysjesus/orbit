import 'dart:math' as math;
import 'package:flutter/material.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F), // Azul Orbit
      floatingActionButton: const _LanguageFab(),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // WELCOME TO
              const Text(
                "WELCOME TO",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 8),

              // ORBIT (principal)
              const Text(
                "ORBIT",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 46,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),

              const SizedBox(height: 40),

              // ESFERA + TEXTO CENTRADO
              SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (_, child) {
                        return CustomPaint(
                          painter: SpherePainter(
                            angle: _controller.value * 2 * math.pi,
                          ),
                        );
                      },
                    ),
                    const Text(
                      "ORBIT",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36, // Ajustado para que no sobresalga
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 60),

              // BOTÓN LOGIN
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, "/login");
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3389FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Login',
                  style: TextStyle(fontSize: 18, letterSpacing: 1.2),
                ),
              ),

              const SizedBox(height: 24),

              // SIGN UP
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, "/register");
                },
                child: const Text(
                  "Don't have an account?\nSign Up",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}


// ================= FAB IDIOMA =================
class _LanguageFab extends StatefulWidget {
  const _LanguageFab();

  @override
  State<_LanguageFab> createState() => _LanguageFabState();
}

class _LanguageFabState extends State<_LanguageFab> {
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
        final result = await showModalBottomSheet<String>(
          context: context,
          builder: (context) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: _langs.entries.map((entry) {
                return ListTile(
                  leading: _selected == entry.key
                      ? const Icon(Icons.check, color: Color(0xFF3389FF))
                      : null,
                  title: Text(entry.value),
                  onTap: () => Navigator.pop(context, entry.key),
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

// ================= PINTOR ORBIT =================

class SpherePainter extends CustomPainter {
  final double angle;
  SpherePainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.35;

    final paintSphere = Paint()
      ..shader = const RadialGradient(
        colors: [Colors.white, Color(0xFF3389FF)],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius),
      );

    canvas.drawCircle(center, radius, paintSphere);

    final orbitPaint = Paint()
      ..color = const Color.fromARGB(102, 255, 255, 255) // 102 = 0.4 * 255
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(center, radius + 15 + (i * 12), orbitPaint);
    }

    final satelliteR = radius + 28;
    final satelliteX = center.dx + satelliteR * math.cos(angle);
    final satelliteY = center.dy + satelliteR * math.sin(angle);

    canvas.drawCircle(
      Offset(satelliteX, satelliteY),
      6,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant SpherePainter oldDelegate) => true;
}
