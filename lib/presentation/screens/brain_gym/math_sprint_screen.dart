import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/models/brain_gym_models.dart';
import '../../../domain/services/brain_gym_generator.dart';
import '../../../data/repositories/brain_gym_repository.dart';
import '../../widgets/level_up_dialog.dart';

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
    _comboScale = Tween<double>(begin: 1.0, end: 1.2).animate(
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
      _flashFeedback(AppColors.productive.withValues(alpha: 0.15));
      _nextQuestion();
    } else {
      HapticFeedback.heavyImpact();
      _combo = 0;
      _flashFeedback(AppColors.distracting.withValues(alpha: 0.15));
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
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1.0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            summary.isNewPersonalBest ? 'RECORD SET' : 'SESSION COMPLETED',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${summary.score} Points',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _resultStat('Accuracy', '${summary.accuracyPercent.toInt()}%'),
              _resultStat('Max Combo', '${summary.maxCombo}x'),
              _resultStat('Rating Delta', summary.ratingDelta >= 0 ? '+${summary.ratingDelta}' : '${summary.ratingDelta}'),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 16),
                const SizedBox(width: 6),
                Text(
                  '+${summary.xpAwarded} XP Gained',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
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
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Back to Hub', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
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
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Play Again', style: TextStyle(fontWeight: FontWeight.w600)),
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
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final timerPercent = (_secondsRemaining / totalRoundSeconds).clamp(0.0, 1.0);
    final timerColor = _secondsRemaining <= 10
        ? AppColors.distracting
        : (_secondsRemaining <= 25 ? AppColors.primary : AppColors.textPrimary);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            color: _feedbackColor,
          ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
                        onPressed: () => Navigator.of(context).pop(),
                      ),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.timer_outlined, color: timerColor, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '${_secondsRemaining}s',
                              style: TextStyle(
                                color: timerColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$_score PTS',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (_combo >= 2)
                            ScaleTransition(
                              scale: _comboScale,
                              child: Text(
                                '${_combo}x COMBO',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                LinearProgressIndicator(
                  value: timerPercent,
                  backgroundColor: AppColors.surfaceElevated,
                  valueColor: AlwaysStoppedAnimation<Color>(timerColor),
                  minHeight: 2,
                ),

                Expanded(
                  flex: 3,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentQuestion.prompt,
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),

                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _currentInput.isNotEmpty ? AppColors.primary : AppColors.border,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              _currentInput.isEmpty ? '—' : _currentInput,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: _currentInput.isEmpty ? AppColors.textDisabled : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

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
                                color: AppColors.surfaceElevated,
                                iconColor: AppColors.textSecondary,
                                onTap: _onBackspace,
                                onLongPress: _onClear,
                              ),
                              _numpadKey('0'),
                              _actionKey(
                                icon: Icons.check_rounded,
                                color: AppColors.productive,
                                iconColor: AppColors.background,
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
        padding: const EdgeInsets.all(4),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => _onDigitPress(digit),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Text(
                  digit,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
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
        padding: const EdgeInsets.all(4),
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color == AppColors.surfaceElevated ? AppColors.border : Colors.transparent),
              ),
              child: Center(
                child: Icon(icon, color: iconColor, size: 22),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
