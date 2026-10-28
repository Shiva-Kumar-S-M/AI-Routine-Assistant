import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/models/brain_gym_models.dart';
import '../../../domain/services/brain_gym_generator.dart';
import '../../../data/repositories/brain_gym_repository.dart';
import '../../widgets/level_up_dialog.dart';

class SequenceGameScreen extends StatefulWidget {
  const SequenceGameScreen({super.key});

  @override
  State<SequenceGameScreen> createState() => _SequenceGameScreenState();
}

class _SequenceGameScreenState extends State<SequenceGameScreen> {
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

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadQuestion();
  }

  void _loadQuestion() {
    setState(() {
      _currentQuestion = BrainGymGenerator.generateSequenceQuestion(difficulty: (_currentIndex ~/ 3) + 1);
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
      _feedbackColor = Colors.white.withValues(alpha: 0.08);
    } else {
      HapticFeedback.heavyImpact();
      _combo = 0;
      _feedbackColor = Colors.white.withValues(alpha: 0.16);
    }

    setState(() {});

    Timer(const Duration(milliseconds: 650), () {
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
    BrainGymResultSummary summary;
    try {
      summary = await _repository.recordGameResult(
        mode: BrainGymGameMode.numberSequence,
        score: _score,
        correctAnswers: _correctCount,
        totalQuestions: totalQuestions,
        maxCombo: _maxCombo,
      );
    } catch (e, st) {
      debugPrint('Error recording sequence score: $e\n$st');
      if (mounted) {
        setState(() => _errorMessage = 'Failed to save score. Please try again.');
      }
      return;
    }

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
      builder: (ctx) => Container(
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
            const Text(
              'SEQUENCE SPRINT COMPLETED',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_score Points',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w300,
                letterSpacing: -0.5,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$_correctCount / $totalQuestions Correct · Rating Delta: ${summary.ratingDelta >= 0 ? "+${summary.ratingDelta}" : "${summary.ratingDelta}"}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back to Hub', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          AnimatedContainer(duration: const Duration(milliseconds: 200), color: _feedbackColor),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Top Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              Text(
                                'Question ${_currentIndex + 1} / $totalQuestions',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                '$_score PTS',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Progress Bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: (_currentIndex + 1) / totalQuestions,
                              minHeight: 2,
                              backgroundColor: AppColors.surfaceRaised,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                            ),
                          const Spacer(),

                          // Sequence Prompt Card
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'FIND THE NEXT NUMBER',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.1,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _currentQuestion.prompt,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w300,
                                      color: AppColors.textPrimary,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                                if (_isAnswered && _currentQuestion.hint != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    _currentQuestion.hint!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ),
                          const Spacer(),

                          // 4 Multiple Choice Buttons
                          ...List.generate(_currentQuestion.options.length, (idx) {
                            final opt = _currentQuestion.options[idx];
                            Color btnColor = AppColors.surface;
                            Color textColor = AppColors.textPrimary;
                            BorderSide border = const BorderSide(color: AppColors.border);

                            if (_isAnswered) {
                              if (opt == _currentQuestion.answer) {
                                btnColor = AppColors.primary;
                                textColor = AppColors.onPrimary;
                                border = const BorderSide(color: AppColors.primary);
                              } else if (opt == _selectedAnswer) {
                                btnColor = AppColors.surfaceRaised;
                                textColor = AppColors.textSecondary;
                                border = const BorderSide(color: AppColors.disabled);
                              } else {
                                textColor = AppColors.disabled;
                              }
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Material(
                                color: btnColor,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  onTap: () => _onOptionSelected(opt),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.fromBorderSide(border),
                                    ),
                                    child: Center(
                                      child: Text(
                                        opt,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
