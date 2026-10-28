import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import 'dashboard_screen.dart';
import 'journey_screen.dart';
import 'insights_screen.dart';
import 'settings_screen.dart';
import 'brain_gym/brain_gym_hub_screen.dart';
import 'brain_gym/math_sprint_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  static const MethodChannel _platformChannel =
      MethodChannel('com.example.ai_routine_assistant/usage');

  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _setupDeepLinkHandling();
  }

  void _setupDeepLinkHandling() {
    _platformChannel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLinkRoute') {
        final route = call.arguments as String?;
        _navigateRoute(route);
      }
    });

    // Check for pending launch route on cold start
    _platformChannel.invokeMethod<String>('getLaunchRoute').then((route) {
      if (route != null && mounted) {
        _navigateRoute(route);
      }
    }).catchError((_) {});
  }

  void _navigateRoute(String? route) {
    if (route == 'math_sprint') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MathSprintScreen()),
      );
    }
  }

  static const _pages = <Widget>[
    DashboardScreen(),
    BrainGymHubScreen(),
    JourneyScreen(),
    InsightsScreen(),
    SettingsScreen(),
  ];

  void _onNavSelected(int i) {
    if (i != _selectedIndex) {
      HapticFeedback.selectionClick();
      setState(() => _selectedIndex = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.border, width: 1.0),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onNavSelected,
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.surfaceRaised,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined, color: AppColors.textSecondary, size: 22),
              selectedIcon: Icon(Icons.grid_view_rounded, color: AppColors.textPrimary, size: 22),
              label: 'Overview',
            ),
            NavigationDestination(
              icon: Icon(Icons.extension_outlined, color: AppColors.textSecondary, size: 22),
              selectedIcon: Icon(Icons.extension_rounded, color: AppColors.textPrimary, size: 22),
              label: 'Brain Gym',
            ),
            NavigationDestination(
              icon: Icon(Icons.military_tech_outlined, color: AppColors.textSecondary, size: 22),
              selectedIcon: Icon(Icons.military_tech_rounded, color: AppColors.textPrimary, size: 22),
              label: 'Journey',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined, color: AppColors.textSecondary, size: 22),
              selectedIcon: Icon(Icons.insights_rounded, color: AppColors.textPrimary, size: 22),
              label: 'Insights',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_outlined, color: AppColors.textSecondary, size: 22),
              selectedIcon: Icon(Icons.tune_rounded, color: AppColors.textPrimary, size: 22),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
