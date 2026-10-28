import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/repositories/focus_repository.dart';
import '../../data/repositories/preferences_repository.dart';
import '../../domain/models/focus_session.dart';
import '../../data/repositories/progress_repository.dart';
import '../widgets/level_up_dialog.dart';
import '../widgets/chunky_button.dart';

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
    });
  }

  void _completeSession() async {
    _timer?.cancel();
    await _prefs.setFocusActive(false);
    setState(() => _isRunning = false);

    final session = FocusSession(
      startTime: _sessionStartTime ??
          DateTime.now().subtract(Duration(minutes: _selectedMinutes)),
      endTime: DateTime.now(),
      durationMinutes: _selectedMinutes,
      isCompleted: true,
    );

    await _repository.insertFocusSession(session);

    // Award +30 XP for Stage 2 Journey System
    final progressRepo = ProgressRepository();
    final levelUp = await progressRepo.recordFocusCompletion(_selectedMinutes);

    if (mounted) {
      if (levelUp != null) {
        await LevelUpDialog.show(context, newLevel: levelUp.newLevel, title: levelUp.title);
      }
      if (!mounted) return;
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1.0),
        ),
        title: const Text(
          'FOCUS SESSION COMPLETE',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            fontSize: 13,
            letterSpacing: 1.2,
          ),
        ),
        content: Text(
          'Maintained focus for $_selectedMinutes minutes and earned +30 XP.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _resetTimer();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  double get _progress {
    final total = _selectedMinutes * 60;
    if (total == 0) return 0.0;
    return (total - _remainingSeconds) / total;
  }

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _prefs.setFocusActive(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'FOCUS MODE',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: AppColors.background,
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
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        '${min}m',
                        style: TextStyle(
                          color: isSelected ? AppColors.onPrimary : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 48),

              // Minimal Circular Timer Ring
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 250,
                    height: 250,
                    child: CircularProgressIndicator(
                      value: _progress,
                      strokeWidth: 3,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation(AppColors.textPrimary),
                    ),
                  ),
                  Container(
                    width: 230,
                    height: 230,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border, width: 1.0),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _formatTime(_remainingSeconds),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 52,
                            fontWeight: FontWeight.w300,
                            letterSpacing: -1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isRunning ? 'DEEP WORK' : 'READY',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 36),

              // Active Badge
              if (_isRunning)
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 1.0),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_off_outlined,
                          color: AppColors.textSecondary, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Distraction alerts & triggers suppressed',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              // Action Controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ChunkyButton(
                        text: _isRunning ? 'Pause' : 'Start Focus',
                        icon: _isRunning ? Icons.pause_outlined : Icons.play_arrow_outlined,
                        height: 48,
                        borderRadius: 14,
                        isSecondary: false,
                        onPressed: _isRunning ? _pauseTimer : _startTimer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: ChunkyButton(
                        text: 'Reset',
                        icon: Icons.refresh_outlined,
                        height: 48,
                        borderRadius: 14,
                        isSecondary: true,
                        onPressed: _resetTimer,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
