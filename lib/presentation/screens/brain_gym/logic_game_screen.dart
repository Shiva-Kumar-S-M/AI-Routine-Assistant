import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ai_routine_assistant/domain/models/brain_gym_models.dart';
import 'package:ai_routine_assistant/domain/services/brain_gym_generator.dart';
import 'package:ai_routine_assistant/data/repositories/brain_gym_repository.dart';
import 'package:ai_routine_assistant/presentation/widgets/level_up_dialog.dart';

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
        color: Color(0xFF1E1E2C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              summary.isNewPersonalBest ? '🏆 NEW PERSONAL BEST!' : '🧩 ROUND COMPLETE',
              style: TextStyle(
                color: summary.isNewPersonalBest ? const Color(0xFFFFD700) : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$_score',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Accuracy: ${summary.accuracyPercent.toInt()}% ($_correctCount/$totalQuestions) • Max Combo: ${_maxCombo}x',
              style: const TextStyle(color: Color(0xFF9E9EAF), fontSize: 13),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statBadge('XP EARNED', '+${summary.xpAwarded} XP', const Color(0xFF7C4DFF)),
                _statBadge(
                  'SKILL RATING',
                  '${summary.newRating} (${summary.ratingDelta >= 0 ? "+${summary.ratingDelta}" : summary.ratingDelta})',
                  const Color(0xFF00E676),
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
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF3F3F56)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Back to Gym'),
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
                      backgroundColor: const Color(0xFF7C4DFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Play Again'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBadge(String title, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF28283C),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF8E8EA0), fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(val, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentIndex + 1) / totalQuestions;

    return Scaffold(
      backgroundColor: const Color(0xFF13131F),
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
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: const Color(0xFF2A2A3E),
                            valueColor: const AlwaysStoppedAnimation(Color(0xFF7C4DFF)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_currentIndex + 1}/$totalQuestions',
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SCORE: $_score',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                      if (_combo > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFF9100), Color(0xFFFF3D00)]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_combo}x COMBO',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E2F),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF33334D)),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'LOGIC GRID & PATTERN',
                          style: TextStyle(
                            color: Color(0xFF7C4DFF),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _currentQuestion.prompt,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        if (_currentQuestion.hint != null && _isAnswered) ...[
                          const SizedBox(height: 12),
                          Text(
                            _currentQuestion.hint!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF9E9EAF),
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: (_currentQuestion.options).map((opt) {
                      Color btnColor = const Color(0xFF26263B);
                      BorderSide border = const BorderSide(color: Color(0xFF3D3D56));

                      if (_isAnswered) {
                        if (opt == _currentQuestion.answer) {
                          btnColor = const Color(0x4D00C853);
                          border = const BorderSide(color: Color(0xFF00C853), width: 2);
                        } else if (opt == _selectedAnswer) {
                          btnColor = const Color(0x4DFF1744);
                          border = const BorderSide(color: Color(0xFFFF1744), width: 2);
                        }
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => _onOptionSelected(opt),
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              color: btnColor,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.fromBorderSide(border),
                            ),
                            child: Center(
                              child: Text(
                                opt,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
