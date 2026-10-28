import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

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
    final primaryColor = isAchieved ? AppColors.productive : AppColors.primary;
    final borderColor = isAchieved
        ? AppColors.productive.withValues(alpha: 0.35)
        : AppColors.border;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: Row(
          children: [
            // Precision Radial Ring
            SizedBox(
              width: 50,
              height: 50,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progressPercent.clamp(0.0, 1.0),
                    strokeWidth: 4.0,
                    backgroundColor: AppColors.surfaceElevated,
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Icon(
                      isAchieved ? Icons.check_rounded : Icons.flag_outlined,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'DAILY FOCUS TARGET',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (isAchieved) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.productive.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ACHIEVED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppColors.productive,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${(progressPercent * 100).toInt()}% towards goal • Tap to adjust target',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textDisabled,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
