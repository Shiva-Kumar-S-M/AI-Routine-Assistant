import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/repositories/preferences_repository.dart';

class AppLimitDialog extends StatefulWidget {
  final String packageName;
  final String appName;
  final VoidCallback? onLimitSaved;

  const AppLimitDialog({
    super.key,
    required this.packageName,
    required this.appName,
    this.onLimitSaved,
  });

  @override
  State<AppLimitDialog> createState() => _AppLimitDialogState();
}

class _AppLimitDialogState extends State<AppLimitDialog> {
  final PreferencesRepository _prefs = PreferencesRepository();
  int? _currentLimitMinutes;
  bool _isLoading = true;
  final List<int> _presetLimits = [15, 30, 45, 60, 90, 120];

  @override
  void initState() {
    super.initState();
    _loadCurrentLimit();
  }

  Future<void> _loadCurrentLimit() async {
    final limit = await _prefs.getAppLimitMinutes(widget.packageName);
    if (mounted) {
      setState(() {
        _currentLimitMinutes = limit;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveLimit(int? minutes) async {
    await _prefs.setAppLimitMinutes(widget.packageName, minutes);
    if (mounted) {
      widget.onLimitSaved?.call();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            minutes == null || minutes <= 0
                ? 'Removed limit for ${widget.appName}'
                : 'Set daily limit of $minutes minutes for ${widget.appName}',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF181827) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF202124);
    final subtextColor = isDark ? Colors.white60 : const Color(0xFF5F6368);
    final chipBorder = isDark ? const Color(0xFF2E2E48) : AppColors.border;

    return AlertDialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set Daily Limit',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.appName,
            style: TextStyle(
              color: subtextColor,
              fontSize: 13,
            ),
          ),
        ],
      ),
      content: _isLoading
          ? const SizedBox(
              height: 100,
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary)))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_currentLimitMinutes != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: isDark ? 0.25 : 1.0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Current limit: $_currentLimitMinutes mins/day',
                          style: TextStyle(
                            color: isDark ? AppColors.primaryLight : AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _saveLimit(null),
                          child: const Text(
                            'Remove',
                            style: TextStyle(
                              color: AppColors.distracting,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                Text(
                  'Select daily time limit:',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presetLimits.map((mins) {
                    final isSelected = _currentLimitMinutes == mins;
                    return ChoiceChip(
                      label: Text('${mins}m'),
                      selected: isSelected,
                      onSelected: (_) => _saveLimit(mins),
                      selectedColor: isDark
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : AppColors.primaryContainer,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? (isDark ? AppColors.primaryLight : AppColors.primary)
                            : subtextColor,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : chipBorder,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: subtextColor)),
        ),
      ],
    );
  }
}
