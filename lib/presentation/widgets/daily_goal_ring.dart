import 'package:flutter/material.dart';

class DailyGoalRing extends StatelessWidget {
  final String label;
  final double progressPercent; // 0.0 to 1.0
  final bool isAchieved;
  final VoidCallback? onTap;

  const DailyGoalRing({
    super.key,
    required this.label,
    required this.progressPercent,
    required this.isAchieved,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = isAchieved ? const Color(0xFF00C853) : const Color(0xFF3D5AFE);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isAchieved
                ? const Color(0xFF00C853).withValues(alpha: 0.3)
                : const Color(0xFFE8EAED),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Animated Radial Ring
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progressPercent,
                    strokeWidth: 6,
                    backgroundColor: const Color(0xFFEEEEF4),
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Icon(
                      isAchieved ? Icons.check_circle_rounded : Icons.flag_rounded,
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'DAILY GOAL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: isAchieved ? const Color(0xFF00C853) : const Color(0xFF5F6368),
                        ),
                      ),
                      if (isAchieved) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00C853).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'COMPLETED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00C853),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF202124),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${(progressPercent * 100).toInt()}% achieved · Tap to adjust',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF70757A),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9AA0A6),
            ),
          ],
        ),
      ),
    );
  }
}
