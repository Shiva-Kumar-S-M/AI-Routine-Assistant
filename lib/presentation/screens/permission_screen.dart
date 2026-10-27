import 'package:flutter/material.dart';
import '../../services/usage_collector_service.dart';
import '../../services/notification_service.dart';
import 'main_navigation_screen.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with WidgetsBindingObserver {
  final UsageCollectorService _collectorService = UsageCollectorService();
  bool _isChecking = false;
  bool _hasUsage = false;
  bool _hasOverlay = false;
  bool _hasBatteryExemption = false;

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

    // Auto-advance only if both required permissions are active
    if (hasUsage && hasOverlay) {
      await _collectorService.startUsageMonitorService();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    }
  }

  Future<void> _grantUsagePermission() async {
    await _collectorService.openUsageSettings();
  }

  Future<void> _grantOverlayPermission() async {
    await _collectorService.openOverlaySettings();
  }

  Future<void> _grantBatteryExemption() async {
    await _collectorService.requestBatteryOptimization();
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
    final cs = Theme.of(context).colorScheme;
    final allRequiredGranted = _hasUsage && _hasOverlay;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.security_rounded,
                    size: 40,
                    color: cs.primary,
                  ),
                ),
              ),

              Text(
                'Permission Setup',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF202124),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '100% on-device screen-time monitoring and focus intervention. '
                'No internet access, zero tracking, total privacy.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5F6368),
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 28),

              // Section 1: Required Permissions
              Text(
                'REQUIRED PERMISSIONS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 10),

              // 1. Usage Stats Permission
              _permissionTile(
                title: 'Usage Access',
                subtitle: 'Detects active screen time across apps',
                isGranted: _hasUsage,
                icon: Icons.bar_chart_rounded,
                onTap: _grantUsagePermission,
              ),
              const SizedBox(height: 8),

              // 2. Overlay Permission (Mandatory)
              _permissionTile(
                title: 'Display Over Other Apps',
                subtitle: 'Shows the full-screen psychological nudge overlay',
                isGranted: _hasOverlay,
                icon: Icons.layers_rounded,
                onTap: _grantOverlayPermission,
              ),
              const SizedBox(height: 24),

              // Section 2: Reliability
              const Text(
                'BACKGROUND RELIABILITY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: Color(0xFF5F6368),
                ),
              ),
              const SizedBox(height: 10),

              // 3. Battery Optimization
              _permissionTile(
                title: 'Battery Whitelist',
                subtitle: 'Prevents Android from killing real-time monitor',
                isGranted: _hasBatteryExemption,
                icon: Icons.battery_charging_full_rounded,
                onTap: _grantBatteryExemption,
              ),
              const SizedBox(height: 8),

              // 4. Notifications
              _permissionTile(
                title: 'Notifications Access',
                subtitle: 'Required for routine service indicator & summaries',
                isGranted: true, // System dialog handled on demand
                icon: Icons.notifications_active_rounded,
                onTap: _grantNotificationPermission,
              ),
              const SizedBox(height: 32),

              // Continue Button
              ElevatedButton(
                onPressed: allRequiredGranted ? _proceedToApp : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  disabledBackgroundColor: const Color(0xFFDADCE0),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      allRequiredGranted ? 'Enter Assistant' : 'Grant Required Permissions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: allRequiredGranted ? Colors.white : const Color(0xFF70757A),
                      ),
                    ),
                    if (allRequiredGranted) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                    ]
                  ],
                ),
              ),

              if (_isChecking)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isGranted ? Colors.green.withValues(alpha: 0.5) : const Color(0xFFE0E0E0),
            width: isGranted ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isGranted ? Colors.green.withValues(alpha: 0.1) : const Color(0xFFF1F3F4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 22,
                color: isGranted ? Colors.green : const Color(0xFF5F6368),
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
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF202124),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF70757A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isGranted ? Colors.green : const Color(0xFF1A73E8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isGranted ? 'Granted' : 'Grant',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
