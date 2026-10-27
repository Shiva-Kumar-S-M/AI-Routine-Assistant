import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ai_routine_assistant/domain/models/brain_gym_models.dart';
import 'package:ai_routine_assistant/domain/services/brain_gym_generator.dart';
import 'package:ai_routine_assistant/data/repositories/brain_gym_repository.dart';
import 'package:ai_routine_assistant/presentation/widgets/level_up_dialog.dart';

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
      _feedbackColor = const Color(0x3300C853);
    } else {
      HapticFeedback.heavyImpact();
      _combo = 0;
      _feedbackColor = const Color(0x33FF1744);
    }

    setState(() {});

    Timer(const Duration(milliseconds: 700), () {
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
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'SEQUENCE SPRINT COMPLETED',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Color(0xFF651FFF),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_score Points',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF202124),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$_correctCount / $totalQuestions Correct · Rating Delta: ${summary.ratingDelta >= 0 ? "+${summary.ratingDelta}" : "${summary.ratingDelta}"}',
              style: const TextStyle(fontSize: 14, color: Color(0xFF5F6368)),
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
                  backgroundColor: const Color(0xFF651FFF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Back to Hub', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          AnimatedContainer(duration: const Duration(milliseconds: 200), color: _feedbackColor),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF202124)),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Text(
                        'Question ${_currentIndex + 1} / $totalQuestions',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5F6368),
                        ),
                      ),
                      Text(
                        '$_score PTS',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF202124),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (_currentIndex + 1) / totalQuestions,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE0E0E0),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF651FFF)),
                    ),
                  ),
                  const Spacer(),

                  // Sequence Prompt Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE8EAED)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'FIND THE NEXT NUMBER',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Color(0xFF651FFF),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _currentQuestion.prompt,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF202124),
                            letterSpacing: 1.2,
                          ),
                        ),
                        if (_isAnswered && _currentQuestion.hint != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _currentQuestion.hint!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF70757A),
                              fontStyle: FontStyle.italic,
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
                    Color btnColor = Colors.white;
                    Color textColor = const Color(0xFF202124);
                    BorderSide border = const BorderSide(color: Color(0xFFE0E0E0));

                    if (_isAnswered) {
                      if (opt == _currentQuestion.answer) {
                        btnColor = const Color(0xFFE8F5E9);
                        textColor = const Color(0xFF00C853);
                        border = const BorderSide(color: Color(0xFF00C853), width: 1.5);
                      } else if (opt == _selectedAnswer) {
                        btnColor = const Color(0xFFFFEBEE);
                        textColor = const Color(0xFFFF1744);
                        border = const BorderSide(color: Color(0xFFFF1744), width: 1.5);
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: btnColor,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () => _onOptionSelected(opt),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.fromBorderSide(border),
                            ),
                            child: Center(
                              child: Text(
                                opt,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
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
        ],
      ),
    );
  }
}
