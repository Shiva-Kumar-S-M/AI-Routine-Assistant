import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/usage_collector_service.dart';
import '../../services/notification_service.dart';
import '../widgets/chunky_button.dart';
import 'main_navigation_screen.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with WidgetsBindingObserver {
  final UsageCollectorService _collectorService = UsageCollectorService();

  bool _hasUsage = false;
  bool _hasOverlay = false;
  bool _hasBatteryExemption = false;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    setState(() => _isChecking = true);
    final hasUsage = await _collectorService.checkPermission();
    final hasOverlay = await _collectorService.checkOverlayPermission();
    final hasBattery = await _collectorService.checkBatteryOptimizationIgnored();

    if (mounted) {
      setState(() {
        _hasUsage = hasUsage;
        _hasOverlay = hasOverlay;
        _hasBatteryExemption = hasBattery;
        _isChecking = false;
      });
    }
  }

  Future<void> _grantUsagePermission() async {
    await _collectorService.openUsageSettings();
    _checkPermissions();
  }

  Future<void> _grantOverlayPermission() async {
    await _collectorService.openOverlaySettings();
    _checkPermissions();
  }

  Future<void> _grantBatteryExemption() async {
    await _collectorService.requestBatteryOptimization();
    _checkPermissions();
  }

  Future<void> _grantNotificationPermission() async {
    await NotificationService.instance.requestNotificationsPermission();
    _checkPermissions();
  }

  Future<void> _proceedToApp() async {
    if (!_hasUsage || !_hasOverlay) return;
    await _collectorService.startUsageMonitorService();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final allRequiredGranted = _hasUsage && _hasOverlay;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border, width: 1.0),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    size: 32,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              const Text(
                'PERMISSION SETUP',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '100% on-device screen-time monitoring and focus intervention. '
                'No internet access, zero telemetry, total privacy.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              // Section 1: Required Permissions
              const Text(
                'REQUIRED PERMISSIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),

              // 1. Usage Stats Permission
              _permissionTile(
                title: 'Usage Access',
                subtitle: 'Detects active screen time across apps',
                isGranted: _hasUsage,
                icon: Icons.bar_chart_outlined,
                onTap: _grantUsagePermission,
              ),
              const SizedBox(height: 10),

              // 2. Overlay Permission (Mandatory)
              _permissionTile(
                title: 'Display Over Other Apps',
                subtitle: 'Shows the full-screen psychological nudge overlay',
                isGranted: _hasOverlay,
                icon: Icons.layers_outlined,
                onTap: _grantOverlayPermission,
              ),
              const SizedBox(height: 24),

              // Section 2: Reliability
              const Text(
                'BACKGROUND RELIABILITY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),

              // 3. Battery Optimization
              _permissionTile(
                title: 'Battery Whitelist',
                subtitle: 'Prevents Android from killing real-time monitor',
                isGranted: _hasBatteryExemption,
                icon: Icons.battery_charging_full_outlined,
                onTap: _grantBatteryExemption,
              ),
              const SizedBox(height: 10),

              // 4. Notifications
              _permissionTile(
                title: 'Notifications Access',
                subtitle: 'Required for routine service indicator & summaries',
                isGranted: true,
                icon: Icons.notifications_none_outlined,
                onTap: _grantNotificationPermission,
              ),
              const SizedBox(height: 32),

              // Continue Button
              ChunkyButton(
                text: allRequiredGranted ? 'Enter Assistant' : 'Grant Required Permissions',
                icon: allRequiredGranted ? Icons.arrow_forward : Icons.lock_outline,
                height: 52,
                borderRadius: 14,
                isSecondary: !allRequiredGranted,
                onPressed: allRequiredGranted ? _proceedToApp : null,
              ),

              if (_isChecking)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _permissionTile({
    required String title,
    required String subtitle,
    required bool isGranted,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isGranted ? AppColors.textPrimary : AppColors.border,
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isGranted ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isGranted ? AppColors.surfaceRaised : AppColors.primary,
                borderRadius: BorderRadius.circular(8),
                border: isGranted ? Border.all(color: AppColors.border, width: 0.5) : null,
              ),
              child: Text(
                isGranted ? 'Granted' : 'Grant',
                style: TextStyle(
                  color: isGranted ? AppColors.textSecondary : AppColors.onPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
