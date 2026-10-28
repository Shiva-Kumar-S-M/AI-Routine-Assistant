import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';

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
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
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
          // Background Canvas Sparkle Particles (Silver & White)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _MonochromeSparklePainter(progress: _controller.value),
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
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border, width: 1.0),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Level Badge
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border, width: 1.0),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.newLevel}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w300,
                          fontSize: 32,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  const Text(
                    'LEVEL UP',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.6,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your discipline is compounding. Every resisted distraction reclaims focus and energy for what matters.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
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

class _MonochromeSparklePainter extends CustomPainter {
  final double progress;
  final List<_SparkleParticle> particles = [];

  _MonochromeSparklePainter({required this.progress}) {
    final random = Random(42);
    const colors = [
      Color(0xFFFFFFFF),
      Color(0xFFE5E5EA),
      Color(0xFFD1D1D6),
      Color(0xFF8E8E93),
    ];
    for (int i = 0; i < 36; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final distance = random.nextDouble() * 150 + 50;
      particles.add(_SparkleParticle(
        color: colors[i % colors.length],
        dx: cos(angle) * distance,
        dy: sin(angle) * distance,
        size: random.nextDouble() * 4 + 2,
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
  bool shouldRepaint(_MonochromeSparklePainter oldDelegate) => true;
}

class _SparkleParticle {
  final Color color;
  final double dx;
  final double dy;
  final double size;

  _SparkleParticle({
    required this.color,
    required this.dx,
    required this.dy,
    required this.size,
  });
}
