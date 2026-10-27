import 'package:flutter/material.dart';
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
    final allRequiredGranted = _hasUsage && _hasOverlay;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E18),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C4DFF), Color(0xFF651FFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C4DFF).withValues(alpha: 0.35),
                        blurRadius: 28,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
              ),

              const Text(
                'Permission Setup',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '100% on-device screen-time monitoring and focus intervention. '
                'No internet access, zero telemetry, total privacy.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF8E8EA2),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              // Section 1: Required Permissions
              const Text(
                'REQUIRED PERMISSIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Color(0xFF7C4DFF),
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
              const SizedBox(height: 10),

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
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Color(0xFF8E8EA2),
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
              const SizedBox(height: 10),

              // 4. Notifications
              _permissionTile(
                title: 'Notifications Access',
                subtitle: 'Required for routine service indicator & summaries',
                isGranted: true,
                icon: Icons.notifications_active_rounded,
                onTap: _grantNotificationPermission,
              ),
              const SizedBox(height: 32),

              // Continue Button
              ChunkyButton(
                text: allRequiredGranted ? 'Enter Assistant' : 'Grant Required Permissions',
                icon: allRequiredGranted ? Icons.arrow_forward_rounded : Icons.lock_open_rounded,
                height: 56,
                borderRadius: 20,
                color: allRequiredGranted ? const Color(0xFF7C4DFF) : const Color(0xFF26263A),
                textColor: allRequiredGranted ? Colors.white : const Color(0xFF6E6E84),
                onPressed: allRequiredGranted ? _proceedToApp : null,
              ),

              if (_isChecking)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF7C4DFF),
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF181827),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isGranted ? const Color(0xFF00E676).withValues(alpha: 0.5) : const Color(0xFF2B2B44),
            width: isGranted ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isGranted ? const Color(0xFF00E676).withValues(alpha: 0.15) : const Color(0xFF222234),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 22,
                color: isGranted ? const Color(0xFF00E676) : const Color(0xFF8E8EA2),
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
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8E8EA2),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isGranted ? const Color(0xFF00E676).withValues(alpha: 0.15) : const Color(0xFF7C4DFF),
                borderRadius: BorderRadius.circular(16),
                border: isGranted ? Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.5)) : null,
              ),
              child: Text(
                isGranted ? 'Granted' : 'Grant',
                style: TextStyle(
                  color: isGranted ? const Color(0xFF00E676) : Colors.white,
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
