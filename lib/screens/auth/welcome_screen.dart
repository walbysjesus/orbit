import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:orbit/services/subscription_service.dart';
import '../../utils/ui_helpers.dart';

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
    final size = MediaQuery.of(context).size;
    final sphereSize =
        math.min(size.width * 0.46, size.height * 0.28).clamp(160.0, 220.0);

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      floatingActionButton: const LanguageFab(),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: FadeInWelcome(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        const Text(
                          '¡Bienvenido a',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF3389FF),
                            fontSize: 20,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: sphereSize,
                          height: sphereSize,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox.expand(
                                child: AnimatedBuilder(
                                  animation: _controller,
                                  builder: (_, __) {
                                    return CustomPaint(
                                      painter: SpherePainter(
                                        angle: _controller.value * 2 * math.pi,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const Text(
                                'ORBIT',
                                style: TextStyle(
                                  color: Color(0xFF0A4D8F),
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Semantics(
                          label: 'Conectando el mundo, en todas partes',
                          child: Text(
                            'Conectando el mundo, en todas partes',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF3389FF),
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Plan actual: ${subscriptionService.level.name.toUpperCase()}',
                          style: const TextStyle(
                              color: Color(0xFF3389FF), fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Semantics(
                          button: true,
                          label: 'Iniciar sesión',
                          child: ElevatedButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/login'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0A4D8F),
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
                              'Iniciar sesión',
                              style:
                                  TextStyle(fontSize: 18, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Semantics(
                          button: true,
                          label: 'Registrarse',
                          child: TextButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/register'),
                            child: const Text(
                              '¿No tienes cuenta? Regístrate',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF0A4D8F),
                                fontSize: 18,
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFF0A4D8F),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
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
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
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
        colors: [Color(0xFF5BAEF7), Color(0xFF0A4D8F)],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius),
      );

    canvas.drawCircle(center, radius, paintSphere);

    final orbitPaint = Paint()
      ..color = const Color(0x663389FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final ringRadii = <double>[radius + 15, radius + 27, radius + 39];

    for (final ringRadius in ringRadii) {
      canvas.drawCircle(center, ringRadius, orbitPaint);
    }

    final satelliteR = ringRadii[1];
    final satellite = Offset(
      center.dx + satelliteR * math.cos(angle),
      center.dy + satelliteR * math.sin(angle),
    );

    canvas.drawCircle(satellite, 6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant SpherePainter oldDelegate) => true;
}
