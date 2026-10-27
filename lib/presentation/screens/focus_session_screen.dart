import 'dart:async';
import 'package:flutter/material.dart';
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
        backgroundColor: const Color(0xFF181827),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF2B2B44)),
        ),
        title: const Text('🎉 Focus Completed!',
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        content: Text(
          'Great job! You maintained focus for $_selectedMinutes minutes and earned +30 XP.',
          style: const TextStyle(color: Color(0xFF8E8EA2), fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _resetTimer();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Awesome', style: TextStyle(fontWeight: FontWeight.bold)),
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
      backgroundColor: const Color(0xFF0E0E18),
      appBar: AppBar(
        title: const Text(
          'Focus Mode',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: const Color(0xFF0E0E18),
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
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF261D4E)
                            : const Color(0xFF181827),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF7C4DFF)
                              : const Color(0xFF2B2B44),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        '${min}m',
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFFB388FF)
                              : const Color(0xFF8E8EA2),
                          fontWeight: isSelected
                              ? FontWeight.w900
                              : FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 48),

              // Glowing Circular Timer Ring
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 260,
                    height: 260,
                    child: CircularProgressIndicator(
                      value: _progress,
                      strokeWidth: 10,
                      backgroundColor: const Color(0xFF1F1F35),
                      valueColor: AlwaysStoppedAnimation(
                        _isRunning ? const Color(0xFF00E676) : const Color(0xFF7C4DFF),
                      ),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Container(
                    width: 230,
                    height: 230,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF181827),
                      border: Border.all(color: const Color(0xFF2B2B44)),
                      boxShadow: [
                        BoxShadow(
                          color: (_isRunning ? const Color(0xFF00E676) : const Color(0xFF7C4DFF))
                              .withValues(alpha: 0.15),
                          blurRadius: 28,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _formatTime(_remainingSeconds),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isRunning ? 'Deep Work in Progress' : 'Ready to Focus',
                          style: TextStyle(
                            color: _isRunning ? const Color(0xFF00E676) : const Color(0xFF8E8EA2),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
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
                    color: const Color(0xFF0F3E2B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_off_outlined,
                          color: Color(0xFF00E676), size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Distraction alerts & triggers suppressed',
                        style: TextStyle(
                          color: Color(0xFF00E676),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
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
                        icon: _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        height: 54,
                        borderRadius: 18,
                        color: _isRunning
                            ? const Color(0xFFFF2A55)
                            : const Color(0xFF00E676),
                        textColor: _isRunning ? Colors.white : Colors.black,
                        onPressed: _isRunning ? _pauseTimer : _startTimer,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 1,
                      child: ChunkyButton(
                        text: 'Reset',
                        icon: Icons.refresh_rounded,
                        height: 54,
                        borderRadius: 18,
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
