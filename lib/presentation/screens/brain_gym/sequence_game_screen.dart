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
      mode: BrainGymGameMode.numberSequence,
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
            'SEQUENCE PROTOCOL COMPLETE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$_score Points',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '$_correctCount / $totalQuestions Correct · Delta: ${summary.ratingDelta >= 0 ? "+${summary.ratingDelta}" : "${summary.ratingDelta}"}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Back to Hub', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
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
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          'Question ${_currentIndex + 1} / $totalQuestions',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        '$_score PTS',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  LinearProgressIndicator(
                    value: (_currentIndex + 1) / totalQuestions,
                    minHeight: 2,
                    backgroundColor: AppColors.surfaceElevated,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                  const Spacer(),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'FIND THE NEXT SEQUENCE TERM',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _currentQuestion.prompt,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: 1.0,
                          ),
                        ),
                        if (_isAnswered && _currentQuestion.hint != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _currentQuestion.hint!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Spacer(),

                  Column(
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
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            option,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
