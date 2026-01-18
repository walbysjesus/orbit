import 'dart:math' as math;
import 'package:flutter/material.dart';

// ================= WELCOME SCREEN =================

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
      backgroundColor: const Color(0xFF001F3F),
      floatingActionButton: const LanguageFab(),
      body: SafeArea(
        child: Center(
          child: FadeInWelcome(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                SizedBox(
                  height: 80,
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),

                const SizedBox(height: 8),
                const Text(
                  "WELCOME TO",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 22,
                    letterSpacing: 2,
                  ),
                ),

                const Text(
                  "ORBIT",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 46,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),

                const SizedBox(height: 8),
                const Text(
                  "Connecting the world, everywhere",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (_, __) {
                          return CustomPaint(
                            painter: SpherePainter(
                              angle: _controller.value * 2 * math.pi,
                            ),
                          );
                        },
                      ),
                      const Text(
                        "ORBIT",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                ElevatedButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3389FF),
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
                    style: TextStyle(fontSize: 18),
                  ),
                ),

                const SizedBox(height: 24),

                GestureDetector(
                  onTap: () =>
                      Navigator.pushNamed(context, '/register'),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================= FADE IN =================

class FadeInWelcome extends StatefulWidget {
  final Widget child;
  const FadeInWelcome({required this.child, super.key});

  @override
  State<FadeInWelcome> createState() => _FadeInWelcomeState();
}

class _FadeInWelcomeState extends State<FadeInWelcome>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _fade, child: widget.child);
  }
}

// ================= LANGUAGE FAB =================

class LanguageFab extends StatefulWidget {
  const LanguageFab({super.key});

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
      child: const Icon(Icons.language),
      onPressed: () async {
        final result = await showModalBottomSheet<String>(
          context: context,
          builder: (_) => Column(
            mainAxisSize: MainAxisSize.min,
            children: _langs.entries.map((e) {
              return ListTile(
                leading: _selected == e.key
                    ? const Icon(Icons.check, color: Color(0xFF3389FF))
                    : null,
                title: Text(e.value),
                onTap: () => Navigator.pop(context, e.key),
              );
            }).toList(),
          ),
        );

        if (result != null) {
          setState(() => _selected = result);
        }
      },
    );
  }
}

// ================= SPHERE PAINTER =================

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
      ..color = Colors.white38
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(center, radius + 15 + (i * 12), orbitPaint);
    }

    final satelliteR = radius + 28;
    final satellite = Offset(
      center.dx + satelliteR * math.cos(angle),
      center.dy + satelliteR * math.sin(angle),
    );

    canvas.drawCircle(satellite, 6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant SpherePainter oldDelegate) => true;
}