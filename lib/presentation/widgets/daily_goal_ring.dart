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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isAchieved ? const Color(0xFF00E676) : const Color(0xFF7C4DFF);
    final cardBg = isDark ? const Color(0xFF181827) : Colors.white;
    final borderColor = isAchieved
        ? const Color(0xFF00E676).withValues(alpha: 0.4)
        : (isDark ? const Color(0xFF2B2B44) : const Color(0xFFE8EAED));
    final ringBg = isDark ? const Color(0xFF24243A) : const Color(0xFFEEEEF4);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: isAchieved
                  ? const Color(0xFF00E676).withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: borderColor,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Radial Ring
            SizedBox(
              width: 58,
              height: 58,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progressPercent.clamp(0.0, 1.0),
                    strokeWidth: 6.5,
                    backgroundColor: ringBg,
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Icon(
                      isAchieved ? Icons.check_circle_rounded : Icons.flag_rounded,
                      color: primaryColor,
                      size: 26,
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
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: isAchieved ? const Color(0xFF00E676) : const Color(0xFF8E8EA2),
                        ),
                      ),
                      if (isAchieved) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E676).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'ACHIEVED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF00E676),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF202124),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${(progressPercent * 100).toInt()}% towards target • Tap to configure',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF8E8EA2) : const Color(0xFF5F6368),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? const Color(0xFF5A5A74) : const Color(0xFF9AA0A6),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
