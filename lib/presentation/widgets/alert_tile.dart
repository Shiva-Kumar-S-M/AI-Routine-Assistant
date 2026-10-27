import 'package:flutter/material.dart';
import '../../domain/models/routine_alert.dart';
import '../../core/constants/app_colors.dart';

class AlertTile extends StatelessWidget {
  final RoutineAlert alert;
  final VoidCallback? onTap;

  const AlertTile({super.key, required this.alert, this.onTap});

  String _relativeTime(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final isDistraction = alert.type == AlertType.distractionAlert;
    final color = isDistraction ? AppColors.distracting : AppColors.primary;
    final bg = isDistraction
        ? AppColors.distractingContainer
        : AppColors.primaryContainer;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap ?? () => _showDetailSheet(context, alert),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF181827) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? const Color(0xFF2B2B44) : AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDistraction
                    ? Icons.warning_amber_rounded
                    : Icons.psychology_outlined,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.message,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF202124),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isDistraction ? 'Distraction' : 'Routine',
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _relativeTime(alert.timestamp),
                        style: const TextStyle(
                          color: Color(0xFF5F6368),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF80868B), size: 18),
          ],
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context, RoutineAlert alert) {
    final isDistraction = alert.type == AlertType.distractionAlert;
    final color = isDistraction ? AppColors.distracting : AppColors.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF181827) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF33334A) : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(
                  isDistraction
                      ? Icons.warning_amber_rounded
                      : Icons.psychology_outlined,
                  color: color,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isDistraction ? 'Distraction Alert' : 'Routine Detected',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF202124),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              alert.message,
              style: TextStyle(
                color: isDark ? const Color(0xFFE0E0EC) : const Color(0xFF202124),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            _detailRow(Icons.apps, 'Package', alert.packageName),
            _detailRow(
              Icons.access_time,
              'Triggered at',
              '${alert.timestamp.hour.toString().padLeft(2, '0')}:'
                  '${alert.timestamp.minute.toString().padLeft(2, '0')} · '
                  '${alert.timestamp.day}/${alert.timestamp.month}/${alert.timestamp.year}',
            ),
            const SizedBox(height: 16),
            if (alert.triggerConditions != null && alert.triggerConditions!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.account_tree_outlined, size: 18, color: Color(0xFF1B4F8A)),
                        SizedBox(width: 8),
                        Text(
                          'Why Flagged (Decision Tree Transparency)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B4F8A),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    ...alert.triggerConditions!.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.key,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF5F6368)),
                            ),
                            Text(
                              '${entry.value}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF202124),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF5F6368), size: 18),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: const TextStyle(color: Color(0xFF5F6368), fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF202124),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
