import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class CategoryPickerDialog extends StatelessWidget {
  final String currentCategory;
  final bool isCustom;
  final ValueChanged<String> onSelected;
  final VoidCallback? onReset;

  const CategoryPickerDialog({
    super.key,
    required this.currentCategory,
    required this.onSelected,
    this.isCustom = false,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF181827) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF202124);
    final subtextColor = isDark ? Colors.white60 : const Color(0xFF5F6368);
    final borderColor = isDark ? const Color(0xFF2E2E48) : AppColors.border;

    return AlertDialog(
      backgroundColor: bgColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        'Select App Category',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOption(context, 'productive', 'Productive',
              Icons.check_circle_outline, AppColors.productive, isDark),
          const SizedBox(height: 8),
          _buildOption(context, 'distracting', 'Distracting',
              Icons.warning_amber_rounded, AppColors.distracting, isDark),
          const SizedBox(height: 8),
          _buildOption(context, 'neutral', 'Neutral / System',
              Icons.remove_circle_outline, AppColors.neutral, isDark),
          if (isCustom && onReset != null) ...[
            Divider(color: borderColor, height: 24),
            InkWell(
              onTap: () {
                onReset!();
                Navigator.of(context).pop();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.restore, color: subtextColor),
                    const SizedBox(width: 12),
                    Text(
                      'Reset to Default',
                      style: TextStyle(
                        color: subtextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context,
    String value,
    String label,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    final isSelected = currentCategory == value;
    final textColor = isDark ? Colors.white : const Color(0xFF202124);
    return InkWell(
      onTap: () {
        onSelected(value);
        Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: isDark ? 0.22 : 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : textColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (isSelected) Icon(Icons.check_rounded, color: color),
          ],
        ),
      ),
    );
  }
}
