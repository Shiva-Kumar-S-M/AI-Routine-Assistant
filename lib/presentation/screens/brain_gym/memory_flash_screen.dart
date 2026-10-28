import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/models/brain_gym_models.dart';
import '../../../domain/services/brain_gym_generator.dart';
import '../../../data/repositories/brain_gym_repository.dart';
import '../../widgets/level_up_dialog.dart';

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
              'MEMORY FLASH COMPLETED',
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
              'Reached Round $_round ($_sequenceLength tiles) · Rating Delta: ${summary.ratingDelta >= 0 ? "+${summary.ratingDelta}" : "${summary.ratingDelta}"}',
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
                    icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    'Round $_round · $_sequenceLength Tiles',
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
              const SizedBox(height: 24),

              Text(
                _isPlayingSequence ? 'WATCH SEQUENCE' : 'REPEAT PATTERN',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),

              // 3x3 Grid
              AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: 9,
                    itemBuilder: (context, index) {
                      final isFlashing = _activeFlashingTile == index;
                      final isTapped = _userSequence.contains(index);

                      Color tileColor = AppColors.surfaceRaised;
                      Border border = Border.all(color: AppColors.border);

                      if (isFlashing) {
                        tileColor = AppColors.primary;
                        border = Border.all(color: AppColors.primary, width: 2);
                      } else if (isTapped) {
                        tileColor = AppColors.surfaceRaised;
                        border = Border.all(color: AppColors.primary, width: 1.5);
                      }

                      return InkWell(
                        onTap: () => _onTileTap(index),
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            color: tileColor,
                            borderRadius: BorderRadius.circular(14),
                            border: border,
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
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
