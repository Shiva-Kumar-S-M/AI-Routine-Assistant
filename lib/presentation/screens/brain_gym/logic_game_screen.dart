import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/models/brain_gym_models.dart';
import '../../../domain/services/brain_gym_generator.dart';
import '../../../data/repositories/brain_gym_repository.dart';
import '../../widgets/level_up_dialog.dart';

class LogicGameScreen extends StatefulWidget {
  const LogicGameScreen({super.key});

  @override
  State<LogicGameScreen> createState() => _LogicGameScreenState();
}

class _LogicGameScreenState extends State<LogicGameScreen> {
  final BrainGymRepository _repository = BrainGymRepository();
  static const int totalQuestions = 10;

  int _currentIndex = 0;
  int _score = 0;
  int _correctCount = 0;
  int _combo = 0;
  int _maxCombo = 0;

  late BrainQuestion _currentQuestion;
  String? _selectedAnswer;
  bool _isAnswered = false;
  Color _feedbackColor = Colors.transparent;

  @override
  void initState() {
    super.initState();
    _loadQuestion();
  }

  void _loadQuestion() {
    setState(() {
      _currentQuestion = BrainGymGenerator.generateLogicQuestion(difficulty: (_currentIndex ~/ 3) + 1);
      _selectedAnswer = null;
      _isAnswered = false;
      _feedbackColor = Colors.transparent;
    });
  }

  void _onOptionSelected(String option) {
    if (_isAnswered) return;
    _isAnswered = true;
    _selectedAnswer = option;

    final isCorrect = option == _currentQuestion.answer;
    if (isCorrect) {
      HapticFeedback.lightImpact();
      _correctCount++;
      _combo++;
      if (_combo > _maxCombo) _maxCombo = _combo;
      _score += 15 * _combo;
      _feedbackColor = AppColors.productive.withValues(alpha: 0.15);
    } else {
      HapticFeedback.heavyImpact();
      _combo = 0;
      _feedbackColor = AppColors.distracting.withValues(alpha: 0.15);
    }

    Timer(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      if (_currentIndex + 1 < totalQuestions) {
        setState(() => _currentIndex++);
        _loadQuestion();
      } else {
        _finishGame();
      }
    });
  }

  Future<void> _finishGame() async {
    final summary = await _repository.recordGameResult(
      mode: BrainGymGameMode.logicGrid,
      score: _score,
      correctAnswers: _correctCount,
      totalQuestions: totalQuestions,
      maxCombo: _maxCombo,
    );

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
        border: Border(top: BorderSide(color: AppColors.border, width: 1.0)),
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
          const Text(
            'LOGIC MATRIX COMPLETE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_score Points',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Accuracy: ${summary.accuracyPercent.toInt()}% ($_correctCount/$totalQuestions) • Max Combo: ${_maxCombo}x',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _statBadge('XP EARNED', '+${summary.xpAwarded} XP', AppColors.primary),
              _statBadge(
                'SKILL RATING',
                '${summary.newRating} (${summary.ratingDelta >= 0 ? "+${summary.ratingDelta}" : summary.ratingDelta})',
                AppColors.productive,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Back to Gym', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _currentIndex = 0;
                      _score = 0;
                      _correctCount = 0;
                      _combo = 0;
                      _maxCombo = 0;
                    });
                    _loadQuestion();
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

  Widget _statBadge(String title, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.1)),
          const SizedBox(height: 2),
          Text(val, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentIndex + 1) / totalQuestions;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            color: _feedbackColor,
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 2,
                            backgroundColor: AppColors.surfaceElevated,
                            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_currentIndex + 1}/$totalQuestions',
                        style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SCORE: $_score',
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      if (_combo > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${_combo}x COMBO',
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _currentQuestion.prompt,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        if (_isAnswered && _currentQuestion.hint != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _currentQuestion.hint!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    children: _currentQuestion.options.map((option) {
                      final isSelected = _selectedAnswer == option;
                      final isCorrectOption = option == _currentQuestion.answer;

                      Color buttonBg = AppColors.surface;
                      Color borderColor = AppColors.border;
                      Color textColor = AppColors.textPrimary;

                      if (_isAnswered) {
                        if (isCorrectOption) {
                          buttonBg = AppColors.productive.withValues(alpha: 0.15);
                          borderColor = AppColors.productive;
                          textColor = AppColors.productive;
                        } else if (isSelected) {
                          buttonBg = AppColors.distracting.withValues(alpha: 0.15);
                          borderColor = AppColors.distracting;
                          textColor = AppColors.distracting;
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _onOptionSelected(option),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: buttonBg,
                            side: BorderSide(color: borderColor),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            option,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
