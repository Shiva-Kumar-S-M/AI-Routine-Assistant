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
            style: const TextStyle(color: AppColors.onPrimary, fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1.0),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily App Limit',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.appName,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
      content: _isLoading
          ? const SizedBox(
              height: 100,
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.textPrimary)))
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
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Current: $_currentLimitMinutes mins/day',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
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
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const Text(
                  'Select daily time threshold:',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presetLimits.map((mins) {
                    final isSelected = _currentLimitMinutes == mins;
                    return InkWell(
                      onTap: () => _saveLimit(mins),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.border,
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          '${mins}m',
                          style: TextStyle(
                            color: isSelected ? AppColors.onPrimary : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            fontSize: 12,
                          ),
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
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}
