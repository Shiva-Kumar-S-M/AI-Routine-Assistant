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
        height: 64,
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(
            top: BorderSide(color: AppColors.border, width: 1.0),
          ),
        ),
        child: Row(
          children: [
            _navItem(0, Icons.home_outlined, 'Home'),
            _navItem(1, Icons.extension_outlined, 'Brain Gym'),
            _navItem(2, Icons.emoji_events_outlined, 'Journey'),
            _navItem(3, Icons.insights_outlined, 'Insights'),
            _navItem(4, Icons.settings_outlined, 'Settings'),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => _onNavSelected(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          children: [
            // Thin top indicator line
            Container(
              height: 2,
              width: 32,
              color: isSelected ? AppColors.textPrimary : Colors.transparent,
            ),
            const Spacer(),
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
