import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class CategoryPickerDialog extends StatelessWidget {
  final String? appName;
  final String currentCategory;
  final bool isCustom;
  final ValueChanged<String> onSelected;
  final VoidCallback? onReset;

  const CategoryPickerDialog({
    super.key,
    this.appName,
    required this.currentCategory,
    required this.onSelected,
    this.isCustom = false,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1.0),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SELECT APP CATEGORY',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          if (appName != null && appName!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              appName!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOption(context, 'productive', 'Productive',
              Icons.check_circle_outline),
          const SizedBox(height: 8),
          _buildOption(context, 'distracting', 'Distracting',
              Icons.warning_amber_outlined),
          const SizedBox(height: 8),
          _buildOption(context, 'neutral', 'Neutral / System',
              Icons.remove_circle_outline),
          if (isCustom && onReset != null) ...[
            const Divider(color: AppColors.border, height: 24),
            InkWell(
              onTap: () {
                onReset!();
                Navigator.of(context).pop();
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.restore_outlined, color: AppColors.textSecondary, size: 18),
                    SizedBox(width: 12),
                    Text(
                      'Reset to Default',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
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
  ) {
    final isSelected = currentCategory == value;
    return InkWell(
      onTap: () {
        onSelected(value);
        Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.surfaceRaised
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.textPrimary : AppColors.border,
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.textPrimary : AppColors.textSecondary, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, color: AppColors.textPrimary, size: 16),
          ],
        ),
      ),
    );
  }
}
