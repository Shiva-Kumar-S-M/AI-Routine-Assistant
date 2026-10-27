import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ai_routine_assistant/domain/models/brain_gym_models.dart';
import 'package:ai_routine_assistant/domain/services/brain_gym_generator.dart';
import 'package:ai_routine_assistant/data/repositories/brain_gym_repository.dart';
import 'package:ai_routine_assistant/presentation/widgets/level_up_dialog.dart';

class MemoryFlashScreen extends StatefulWidget {
  const MemoryFlashScreen({super.key});

  @override
  State<MemoryFlashScreen> createState() => _MemoryFlashScreenState();
}

class _MemoryFlashScreenState extends State<MemoryFlashScreen> {
  final BrainGymRepository _repository = BrainGymRepository();

  int _round = 1;
  int _sequenceLength = 3;
  int _score = 0;
  int _maxCombo = 0;
  int _currentCombo = 0;
  int _totalCorrectTiles = 0;
  int _totalAttemptedTiles = 0;

  List<int> _currentSequence = [];
  List<int> _userSequence = [];
  int? _activeFlashingTile;
  bool _isPlayingSequence = false;
  bool _isGameOver = false;

  @override
  void initState() {
    super.initState();
    _startNextRound();
  }

  void _startNextRound() {
    setState(() {
      _userSequence = [];
      _currentSequence = BrainGymGenerator.generateMemorySequence(length: _sequenceLength);
      _isPlayingSequence = true;
    });

    _playSequence();
  }

  Future<void> _playSequence() async {
    await Future.delayed(const Duration(milliseconds: 600));

    for (int i = 0; i < _currentSequence.length; i++) {
      if (!mounted) return;
      final tile = _currentSequence[i];
      HapticFeedback.selectionClick();
      setState(() => _activeFlashingTile = tile);

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() => _activeFlashingTile = null);

      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (mounted) {
      setState(() => _isPlayingSequence = false);
    }
  }

  void _onTileTap(int tileIndex) {
    if (_isPlayingSequence || _isGameOver) return;
    HapticFeedback.lightImpact();

    final expectedIndex = _currentSequence[_userSequence.length];
    _totalAttemptedTiles++;

    if (tileIndex == expectedIndex) {
      _userSequence.add(tileIndex);
      _totalCorrectTiles++;
      _currentCombo++;
      if (_currentCombo > _maxCombo) _maxCombo = _currentCombo;
      _score += 10 * _currentCombo;
      setState(() {});

      if (_userSequence.length == _currentSequence.length) {
        // Round completed successfully!
        HapticFeedback.mediumImpact();
        if (_round < 6) {
          _round++;
          _sequenceLength++;
          _startNextRound();
        } else {
          _finishGame();
        }
      }
    } else {
      // Mistake!
      HapticFeedback.heavyImpact();
      _finishGame();
    }
  }

  Future<void> _finishGame() async {
    setState(() => _isGameOver = true);
    final summary = await _repository.recordGameResult(
      mode: BrainGymGameMode.memoryFlash,
      score: _score,
      correctAnswers: _totalCorrectTiles,
      totalQuestions: _totalAttemptedTiles > 0 ? _totalAttemptedTiles : 1,
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
              'MEMORY FLASH COMPLETE',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Color(0xFF00B0FF),
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
            const SizedBox(height: 14),
            Text(
              'Reached Round $_round ($_sequenceLength tiles) · Rating Delta: ${summary.ratingDelta >= 0 ? "+${summary.ratingDelta}" : "${summary.ratingDelta}"}',
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
                  backgroundColor: const Color(0xFF00B0FF),
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF202124)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    'Round $_round · $_sequenceLength Tiles',
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
              const SizedBox(height: 20),

              Text(
                _isPlayingSequence ? 'WATCH THE SEQUENCE...' : 'REPEAT THE PATTERN',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: _isPlayingSequence ? const Color(0xFFFF9100) : const Color(0xFF00C853),
                ),
              ),
              const Spacer(),

              // 3x3 Grid
              AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: 9,
                    itemBuilder: (context, index) {
                      final isFlashing = _activeFlashingTile == index;
                      final isTapped = _userSequence.contains(index);

                      Color tileColor = const Color(0xFFF1F3F4);
                      if (isFlashing) {
                        tileColor = const Color(0xFF00B0FF);
                      } else if (isTapped) {
                        tileColor = const Color(0xFF80D8FF).withValues(alpha: 0.5);
                      }

                      return InkWell(
                        onTap: () => _onTileTap(index),
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            color: tileColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: isFlashing
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF00B0FF).withValues(alpha: 0.5),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const Spacer(),

              Text(
                'Remember ${_currentSequence.length} highlighted tiles in order',
                style: const TextStyle(fontSize: 12, color: Color(0xFF70757A)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
