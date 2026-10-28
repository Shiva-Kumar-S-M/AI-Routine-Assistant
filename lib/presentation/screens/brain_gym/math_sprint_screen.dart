import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/models/brain_gym_models.dart';
import '../../../domain/services/brain_gym_generator.dart';
import '../../../data/repositories/brain_gym_repository.dart';
import '../../../data/repositories/progress_repository.dart';
import '../../../data/database/app_database.dart';
import '../../widgets/level_up_dialog.dart';

class MathSprintScreen extends StatefulWidget {
  final bool isDailyChallenge;
  final bool isFromOverlay;
  final String? overlayPackage;
  final VoidCallback? onComplete;

  const MathSprintScreen({
    super.key,
    this.isDailyChallenge = false,
    this.isFromOverlay = false,
    this.overlayPackage,
    this.onComplete,
  });

  @override
  State<MathSprintScreen> createState() => _MathSprintScreenState();
}

class _MathSprintScreenState extends State<MathSprintScreen>
    with SingleTickerProviderStateMixin {
  final BrainGymRepository _repository = BrainGymRepository();
  final ProgressRepository _progressRepo = ProgressRepository();

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
  bool _turnBackAwarded = false;
  String? _errorMessage;

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
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
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
      _flashFeedback(Colors.white.withValues(alpha: 0.08));
      _nextQuestion();
    } else {
      HapticFeedback.heavyImpact();
      _combo = 0;
      _flashFeedback(Colors.white.withValues(alpha: 0.16));
      setState(() => _currentInput = '');
    }
  }

  void _flashFeedback(Color color) {
    _feedbackTimer?.cancel();
    setState(() => _feedbackColor = color);
    _feedbackTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _feedbackColor = Colors.transparent);
    });
  }

  Future<void> _finishRound() async {
    _timer?.cancel();
    setState(() {
      _isGameOver = true;
      _errorMessage = null;
    });

    BrainGymResultSummary summary;
    try {
      summary = await _repository.recordGameResult(
        mode: BrainGymGameMode.mathSprint,
        score: _score,
        correctAnswers: _correctCount,
        totalQuestions: _totalAttempted,
        maxCombo: _maxCombo,
        isDailyChallenge: widget.isDailyChallenge,
      );

      // If launched from overlay and completed with a decent score:
      // Count as a turn-back (XP + daily goal)
      if (widget.isFromOverlay && (_score >= 20 || _correctCount >= 2)) {
        final pkg = widget.overlayPackage ?? 'distraction';
        await _progressRepo.recordTurnBack(
          packageName: pkg,
          usedMins: 0,
          limitMins: 0,
          hookType: 'brain_challenge',
        );

        final db = await AppDatabase.instance.database;
        await db.insert('notifications_log', {
          'package_name': pkg,
          'type': 'turn_back',
          'title': 'Brain Challenge Deflection',
          'body': 'Completed 60s Math Sprint impulse challenge',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'conditions': jsonEncode({
            'hook': 'brain_challenge',
            'score': _score,
          }),
          'rewarded': 1,
        });

        _turnBackAwarded = true;
      }
    } catch (e, st) {
      debugPrint('Error recording Math Sprint result: $e\n$st');
      if (mounted) {
        setState(() => _errorMessage = 'Failed to save score. Please try again.');
      }
      return;
    }

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
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.disabled,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (_turnBackAwarded) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, color: AppColors.primary, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'IMPULSE DEFLECTED · TURN-BACK COUNTED (+20 XP)',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Text(
            summary.isNewPersonalBest ? 'NEW PERSONAL BEST' : 'SPRINT FINISHED',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${summary.score} Points',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w300,
              letterSpacing: -0.5,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // 3-Metric Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _resultStat('Accuracy', '${summary.accuracyPercent.toInt()}%'),
              _resultStat('Max Combo', '${summary.maxCombo}x'),
              _resultStat('Rating Delta', summary.ratingDelta >= 0 ? '+${summary.ratingDelta}' : '${summary.ratingDelta}'),
            ],
          ),
          const SizedBox(height: 20),

          // XP reward badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_outline_rounded, color: AppColors.textPrimary, size: 16),
                const SizedBox(width: 6),
                Text(
                  '+${summary.xpAwarded} XP Gained',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
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
              if (widget.isFromOverlay)
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).popUntil((route) => route.isFirst);
                      widget.onComplete?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Back to Home', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                )
              else ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Back to Hub', style: TextStyle(fontWeight: FontWeight.w600)),
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
                        _errorMessage = null;
                      });
                      _nextQuestion();
                      _startTimer();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Play Again', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
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
            fontWeight: FontWeight.w600,
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
                // Header Bar (Exit button, Timer, Score, Combo)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
                        onPressed: () => Navigator.of(context).pop(),
                      ),

                      // Timer Dial
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceRaised,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer_outlined, color: AppColors.textPrimary, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '${_secondsRemaining}s',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
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
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
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
                                  letterSpacing: 0.8,
                                  color: AppColors.textSecondary,
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
                  backgroundColor: AppColors.surfaceRaised,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 2,
                ),

                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.disabled),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.textPrimary, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Equation Hero Card
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
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _currentQuestion.prompt,
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w300,
                                color: AppColors.textPrimary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // User Input Box
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceRaised,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _currentInput.isNotEmpty ? AppColors.primary : AppColors.border,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _currentInput.isEmpty ? '?' : _currentInput,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                color: _currentInput.isEmpty ? AppColors.disabled : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Big Custom Number Pad
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
                                color: AppColors.surfaceRaised,
                                iconColor: AppColors.textSecondary,
                                onTap: _onBackspace,
                                onLongPress: _onClear,
                              ),
                              _numpadKey('0'),
                              _actionKey(
                                icon: Icons.check_rounded,
                                color: AppColors.primary,
                                iconColor: AppColors.onPrimary,
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
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => _onDigitPress(digit),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Text(
                  digit,
                  style: const TextStyle(
                    fontSize: 24,
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
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Icon(icon, color: iconColor, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
