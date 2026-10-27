import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ai_routine_assistant/domain/models/brain_gym_models.dart';
import 'package:ai_routine_assistant/domain/services/brain_gym_generator.dart';
import 'package:ai_routine_assistant/data/repositories/brain_gym_repository.dart';
import 'package:ai_routine_assistant/presentation/widgets/level_up_dialog.dart';

class MathSprintScreen extends StatefulWidget {
  final bool isDailyChallenge;
  final VoidCallback? onComplete;

  const MathSprintScreen({
    super.key,
    this.isDailyChallenge = false,
    this.onComplete,
  });

  @override
  State<MathSprintScreen> createState() => _MathSprintScreenState();
}

class _MathSprintScreenState extends State<MathSprintScreen>
    with SingleTickerProviderStateMixin {
  final BrainGymRepository _repository = BrainGymRepository();

  static const int totalRoundSeconds = 60;
  int _secondsRemaining = totalRoundSeconds;
  Timer? _timer;

  late BrainQuestion _currentQuestion;
  String _currentInput = '';
  int _score = 0;
  int _combo = 0;
  int _maxCombo = 0;
  int _correctCount = 0;
  int _totalAttempted = 0;
  int _difficulty = 1;

  Color _feedbackColor = Colors.transparent;
  Timer? _feedbackTimer;
  bool _isGameOver = false;

  late AnimationController _comboAnimController;
  late Animation<double> _comboScale;

  @override
  void initState() {
    super.initState();
    _comboAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _comboScale = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _comboAnimController, curve: Curves.easeOutBack),
    );

    _nextQuestion();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _feedbackTimer?.cancel();
    _comboAnimController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() => _secondsRemaining--);
      } else {
        setState(() => _secondsRemaining = 0);
        _finishRound();
      }
    });
  }

  void _nextQuestion() {
    // Difficulty scales adaptively based on combo
    if (_combo >= 10) {
      _difficulty = 5;
    } else if (_combo >= 6) {
      _difficulty = 4;
    } else if (_combo >= 3) {
      _difficulty = 3;
    } else if (_score >= 50) {
      _difficulty = 2;
    } else {
      _difficulty = 1;
    }

    setState(() {
      _currentQuestion = BrainGymGenerator.generateMathQuestion(difficulty: _difficulty);
      _currentInput = '';
    });
  }

  void _onDigitPress(String digit) {
    if (_isGameOver) return;
    HapticFeedback.selectionClick();
    if (_currentInput.length < 6) {
      setState(() => _currentInput += digit);
    }
  }

  void _onBackspace() {
    if (_isGameOver) return;
    HapticFeedback.selectionClick();
    if (_currentInput.isNotEmpty) {
      setState(() => _currentInput = _currentInput.substring(0, _currentInput.length - 1));
    }
  }

  void _onClear() {
    if (_isGameOver) return;
    HapticFeedback.selectionClick();
    setState(() => _currentInput = '');
  }

  void _onSubmit() {
    if (_isGameOver || _currentInput.isEmpty) return;
    _totalAttempted++;

    final isCorrect = _currentInput.trim() == _currentQuestion.answer.trim();

    if (isCorrect) {
      HapticFeedback.lightImpact();
      _correctCount++;
      _combo++;
      if (_combo > _maxCombo) _maxCombo = _combo;

      // Combo multiplier: 1x, 2x (3+), 3x (6+), 4x (10+), 5x (15+)
      int multiplier = 1;
      if (_combo >= 15) {
        multiplier = 5;
      } else if (_combo >= 10) {
        multiplier = 4;
      } else if (_combo >= 6) {
        multiplier = 3;
      } else if (_combo >= 3) {
        multiplier = 2;
      }

      final points = (10 * _difficulty) * multiplier;
      _score += points;

      _comboAnimController.forward().then((_) => _comboAnimController.reverse());
      _flashFeedback(const Color(0x3300C853));
      _nextQuestion();
    } else {
      HapticFeedback.heavyImpact();
      _combo = 0;
      _flashFeedback(const Color(0x33FF1744));
      setState(() => _currentInput = '');
    }
  }

  void _flashFeedback(Color color) {
    _feedbackTimer?.cancel();
    setState(() => _feedbackColor = color);
    _feedbackTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _feedbackColor = Colors.transparent);
    });
  }

  Future<void> _finishRound() async {
    _timer?.cancel();
    setState(() => _isGameOver = true);

    final summary = await _repository.recordGameResult(
      mode: BrainGymGameMode.mathSprint,
      score: _score,
      correctAnswers: _correctCount,
      totalQuestions: _totalAttempted,
      maxCombo: _maxCombo,
      isDailyChallenge: widget.isDailyChallenge,
    );

    widget.onComplete?.call();

    if (!mounted) return;

    if (summary.levelUpResult != null) {
      await LevelUpDialog.show(
        context,
        newLevel: summary.levelUpResult!.newLevel,
        title: summary.levelUpResult!.title,
      );
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildResultSheet(ctx, summary),
    );
  }

  Widget _buildResultSheet(BuildContext ctx, BrainGymResultSummary summary) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 5,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Text(
            summary.isNewPersonalBest ? '🏆 NEW PERSONAL BEST!' : 'SPRINT FINISHED',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: Color(0xFF3D5AFE),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${summary.score} Points',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Color(0xFF202124),
            ),
          ),
          const SizedBox(height: 18),

          // 3-Metric Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _resultStat('Accuracy', '${summary.accuracyPercent.toInt()}%'),
              _resultStat('Max Combo', '${summary.maxCombo}x'),
              _resultStat('Rating Delta', summary.ratingDelta >= 0 ? '+${summary.ratingDelta}' : '${summary.ratingDelta}'),
            ],
          ),
          const SizedBox(height: 16),

          // XP reward badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9100).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFFFF9100), size: 18),
                const SizedBox(width: 6),
                Text(
                  '+${summary.xpAwarded} XP Gained',
                  style: const TextStyle(
                    color: Color(0xFFFF9100),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Back to Hub'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    setState(() {
                      _secondsRemaining = totalRoundSeconds;
                      _score = 0;
                      _combo = 0;
                      _maxCombo = 0;
                      _correctCount = 0;
                      _totalAttempted = 0;
                      _difficulty = 1;
                      _isGameOver = false;
                    });
                    _nextQuestion();
                    _startTimer();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3D5AFE),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Play Again', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF202124),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF70757A),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final timerPercent = (_secondsRemaining / totalRoundSeconds).clamp(0.0, 1.0);
    final timerColor = _secondsRemaining <= 10
        ? const Color(0xFFFF1744)
        : (_secondsRemaining <= 25 ? const Color(0xFFFF9100) : const Color(0xFF3D5AFE));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          // Background flash feedback
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            color: _feedbackColor,
          ),

          SafeArea(
            child: Column(
              children: [
                // Header Bar (Exit button, Timer, Score, Combo)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF202124)),
                        onPressed: () => Navigator.of(context).pop(),
                      ),

                      // Timer Dial
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: timerColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.timer_outlined, color: timerColor, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              '${_secondsRemaining}s',
                              style: TextStyle(
                                color: timerColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Score & Combo
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$_score PTS',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF202124),
                            ),
                          ),
                          if (_combo >= 2)
                            ScaleTransition(
                              scale: _comboScale,
                              child: Text(
                                '🔥 ${_combo}x COMBO',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF9100),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Linear Timer Bar
                LinearProgressIndicator(
                  value: timerPercent,
                  backgroundColor: const Color(0xFFEEEEEE),
                  valueColor: AlwaysStoppedAnimation<Color>(timerColor),
                  minHeight: 4,
                ),

                // Equation Hero Card
                Expanded(
                  flex: 3,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE8EAED)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentQuestion.prompt,
                            style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF202124),
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // User Input Box
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F3F4),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _currentInput.isNotEmpty ? const Color(0xFF3D5AFE) : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              _currentInput.isEmpty ? '?' : _currentInput,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: _currentInput.isEmpty ? const Color(0xFF9AA0A6) : const Color(0xFF3D5AFE),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Big Custom Number Pad (Optimized for rapid one-thumb typing)
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              _numpadKey('1'),
                              _numpadKey('2'),
                              _numpadKey('3'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              _numpadKey('4'),
                              _numpadKey('5'),
                              _numpadKey('6'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              _numpadKey('7'),
                              _numpadKey('8'),
                              _numpadKey('9'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              _actionKey(
                                icon: Icons.backspace_outlined,
                                color: const Color(0xFFF1F3F4),
                                iconColor: const Color(0xFF5F6368),
                                onTap: _onBackspace,
                                onLongPress: _onClear,
                              ),
                              _numpadKey('0'),
                              _actionKey(
                                icon: Icons.check_rounded,
                                color: const Color(0xFF3D5AFE),
                                iconColor: Colors.white,
                                onTap: _onSubmit,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _numpadKey(String digit) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          elevation: 1,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          child: InkWell(
            onTap: () => _onDigitPress(digit),
            borderRadius: BorderRadius.circular(18),
            child: Center(
              child: Text(
                digit,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF202124),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionKey({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(18),
          elevation: color == const Color(0xFF3D5AFE) ? 2 : 1,
          shadowColor: Colors.black.withValues(alpha: 0.12),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(18),
            child: Center(
              child: Icon(icon, color: iconColor, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}
