import 'package:flutter/material.dart';
import '../../services/usage_collector_service.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermission();
  }

  Future<void> _checkPermission() async {
    setState(() => _isChecking = true);
    final hasUsage = await _collectorService.checkPermission();
    final hasOverlay = await _collectorService.checkOverlayPermission();
    
    if (mounted) {
      setState(() {
        _hasUsage = hasUsage;
        _hasOverlay = hasOverlay;
        _isChecking = false;
      });
    }

    if (hasUsage && mounted) {
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon
              Container(
                width: 96,
                height: 96,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shield_outlined,
                  size: 48,
                  color: cs.primary,
                ),
              ),

              Text(
                'Permissions Required',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF202124),
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'AI Routine Assistant processes your screen time '
                'entirely on-device to detect distraction habits and '
                'display behavioral nudges.\n\nWe never transmit your data anywhere.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5F6368),
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 36),

              // Grant Usage button
              ElevatedButton.icon(
                onPressed: _grantUsagePermission,
                icon: Icon(_hasUsage ? Icons.check_circle : Icons.settings_outlined),
                label: Text(_hasUsage ? 'Usage Permission Granted' : 'Grant Usage Stats Access'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasUsage ? Colors.green : cs.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                ),
              ),
              const SizedBox(height: 12),

              // Grant Overlay button
              OutlinedButton.icon(
                onPressed: _grantOverlayPermission,
                icon: Icon(_hasOverlay ? Icons.check_circle : Icons.layers_outlined),
                label: Text(_hasOverlay ? 'Nudge Overlay Granted' : 'Grant System Overlay Access'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                ),
              ),
              const SizedBox(height: 16),

              if (_isChecking)
                Center(
                  child: CircularProgressIndicator(
                    color: cs.primary,
                    strokeWidth: 2.5,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

