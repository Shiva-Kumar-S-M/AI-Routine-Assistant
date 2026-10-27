import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/repositories/focus_repository.dart';
import '../../data/repositories/preferences_repository.dart';
import '../../domain/models/focus_session.dart';
import '../../core/constants/app_colors.dart';

class FocusSessionScreen extends StatefulWidget {
  const FocusSessionScreen({super.key});

  @override
  State<FocusSessionScreen> createState() => _FocusSessionScreenState();
}

class _FocusSessionScreenState extends State<FocusSessionScreen> {
  final FocusRepository _repository = FocusRepository();
  final PreferencesRepository _prefs = PreferencesRepository();

  static const int defaultMinutes = 25;
  int _selectedMinutes = defaultMinutes;
  int _remainingSeconds = defaultMinutes * 60;
  Timer? _timer;
  bool _isRunning = false;
  DateTime? _sessionStartTime;

  final List<int> _presets = [15, 25, 45, 60];

  void _startTimer() async {
    _sessionStartTime ??= DateTime.now();
    await _prefs.setFocusActive(true);
    setState(() => _isRunning = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _completeSession();
      }
    });
  }

  void _pauseTimer() async {
    _timer?.cancel();
    await _prefs.setFocusActive(false);
    setState(() => _isRunning = false);
  }

  void _resetTimer() async {
    _timer?.cancel();
    await _prefs.setFocusActive(false);
    setState(() {
      _isRunning = false;
      _remainingSeconds = _selectedMinutes * 60;
      _sessionStartTime = null;
    });
  }

  void _setPreset(int minutes) {
    if (_isRunning) return;
    setState(() {
      _selectedMinutes = minutes;
      _remainingSeconds = minutes * 60;
      _sessionStartTime = null;
    });
  }

  Future<void> _completeSession() async {
    _timer?.cancel();
    await _prefs.setFocusActive(false);

    final endTime = DateTime.now();
    final startTime = _sessionStartTime ??
        endTime.subtract(Duration(minutes: _selectedMinutes));

    final session = FocusSession(
      startTime: startTime,
      endTime: endTime,
      durationMinutes: _selectedMinutes,
      isCompleted: true,
    );

    await _repository.insertFocusSession(session);

    if (mounted) {
      setState(() {
        _isRunning = false;
        _remainingSeconds = _selectedMinutes * 60;
        _sessionStartTime = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Focus Session ($_selectedMinutes min) Completed. Logged.'),
          backgroundColor: AppColors.productive,
        ),
      );
    }
  }

  String _formatTime(int totalSeconds) {
    final mins = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  double get _progress =>
      1.0 - (_remainingSeconds / (_selectedMinutes * 60));

  @override
  void dispose() {
    _timer?.cancel();
    _prefs.setFocusActive(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Focus Mode',
          style: TextStyle(
            color: Color(0xFF202124),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 24),

              // Preset Selector Pills
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _presets.map((min) {
                  final isSelected = min == _selectedMinutes;
                  return GestureDetector(
                    onTap: () => _setPreset(min),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryContainer
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        '${min}m',
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.primary
                              : const Color(0xFF5F6368),
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 36),

              // Circular Progress Ring (Google Style)
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 250,
                    height: 250,
                    child: CircularProgressIndicator(
                      value: _progress,
                      strokeWidth: 10,
                      backgroundColor: const Color(0xFFE8EAED),
                      color: _isRunning
                          ? AppColors.productive
                          : AppColors.primary,
                    ),
                  ),
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _formatTime(_remainingSeconds),
                          style: const TextStyle(
                            color: Color(0xFF202124),
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isRunning ? 'Focusing…' : 'Ready to Focus',
                          style: const TextStyle(
                            color: Color(0xFF5F6368),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Active Badge
              if (_isRunning)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.productiveContainer,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.productive.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_off_outlined,
                          color: AppColors.productive, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Distraction alerts suppressed',
                        style: TextStyle(
                          color: AppColors.productive,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isRunning ? _pauseTimer : _startTimer,
                    icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                    label: Text(_isRunning ? 'Pause' : 'Start Focus'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRunning
                          ? AppColors.distracting
                          : AppColors.productive,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: _resetTimer,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF5F6368),
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
