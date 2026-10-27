import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LevelUpDialog extends StatefulWidget {
  final int newLevel;
  final String title;

  const LevelUpDialog({
    super.key,
    required this.newLevel,
    required this.title,
  });

  static Future<void> show(BuildContext context, {required int newLevel, required String title}) async {
    HapticFeedback.heavyImpact();
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => LevelUpDialog(newLevel: newLevel, title: title),
    );
  }

  @override
  State<LevelUpDialog> createState() => _LevelUpDialogState();
}

class _LevelUpDialogState extends State<LevelUpDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Canvas Confetti Particles
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ConfettiPainter(progress: _controller.value),
                );
              },
            ),
          ),

          // Dialog Card
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3D5AFE).withValues(alpha: 0.25),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Crown Badge
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFF9100)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF9100).withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'Lv ${widget.newLevel}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'LEVEL UP!',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      color: Color(0xFF3D5AFE),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF202124),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your discipline is compounding. Every resisted distraction reclaims focus and energy for what matters.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF5F6368),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3D5AFE),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Claim & Keep Growing',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles = [];

  _ConfettiPainter({required this.progress}) {
    final random = Random(42);
    const colors = [
      Color(0xFF3D5AFE),
      Color(0xFFFF9100),
      Color(0xFF00C853),
      Color(0xFFFF4081),
      Color(0xFF00E5FF),
      Color(0xFFFFD700),
    ];
    for (int i = 0; i < 40; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final distance = random.nextDouble() * 160 + 60;
      particles.add(_Particle(
        color: colors[i % colors.length],
        dx: cos(angle) * distance,
        dy: sin(angle) * distance,
        size: random.nextDouble() * 6 + 4,
      ));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint();

    for (final p in particles) {
      paint.color = p.color.withValues(alpha: (1.0 - progress).clamp(0.0, 1.0));
      final offset = Offset(
        center.dx + p.dx * progress,
        center.dy + p.dy * progress,
      );
      canvas.drawCircle(offset, p.size * (1 - progress * 0.3), paint);
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => true;
}

class _Particle {
  final Color color;
  final double dx;
  final double dy;
  final double size;

  _Particle({
    required this.color,
    required this.dx,
    required this.dy,
    required this.size,
  });
}
