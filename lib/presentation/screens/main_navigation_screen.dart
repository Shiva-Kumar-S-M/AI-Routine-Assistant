import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      backgroundColor: const Color(0xFF0E0E18),
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141424),
          border: Border(
            top: BorderSide(color: Color(0xFF26263C), width: 1.0),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onNavSelected,
          backgroundColor: const Color(0xFF141424),
          indicatorColor: const Color(0x337C4DFF),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          height: 68,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: Color(0xFF8E8EA2)),
              selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF7C4DFF)),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.bolt_outlined, color: Color(0xFF8E8EA2)),
              selectedIcon: Icon(Icons.bolt_rounded, color: Color(0xFFFF9100)),
              label: 'Brain Gym',
            ),
            NavigationDestination(
              icon: Icon(Icons.military_tech_outlined, color: Color(0xFF8E8EA2)),
              selectedIcon: Icon(Icons.military_tech_rounded, color: Color(0xFFFFD700)),
              label: 'Journey',
            ),
            NavigationDestination(
              icon: Icon(Icons.psychology_outlined, color: Color(0xFF8E8EA2)),
              selectedIcon: Icon(Icons.psychology_rounded, color: Color(0xFF00E5FF)),
              label: 'Insights',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined, color: Color(0xFF8E8EA2)),
              selectedIcon: Icon(Icons.settings_rounded, color: Colors.white),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
