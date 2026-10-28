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

      await Future.delayed(const Duration(milliseconds: 150));
    }

    if (!mounted) return;
    setState(() => _isPlayingSequence = false);
  }

  void _onTileTap(int index) {
    if (_isPlayingSequence || _isGameOver) return;

    HapticFeedback.lightImpact();
    setState(() {
      _userSequence.add(index);
    });

    _totalAttemptedTiles++;
    final currentStep = _userSequence.length - 1;

    if (_currentSequence[currentStep] == index) {
      _totalCorrectTiles++;
      _score += 10 * _round;

      if (_userSequence.length == _currentSequence.length) {
        _currentCombo++;
        if (_currentCombo > _maxCombo) _maxCombo = _currentCombo;
        _score += 25 * _round;

        Timer(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          setState(() {
            _round++;
            if (_round % 2 == 1 && _sequenceLength < 8) {
              _sequenceLength++;
            }
          });
          _startNextRound();
        });
      }
    } else {
      HapticFeedback.heavyImpact();
      _endGame();
    }
  }

  Future<void> _endGame() async {
    setState(() => _isGameOver = true);

    final summary = await _repository.recordGameResult(
      mode: BrainGymGameMode.memoryFlash,
      score: _score,
      correctAnswers: _totalCorrectTiles,
      totalQuestions: _totalAttemptedTiles == 0 ? 1 : _totalAttemptedTiles,
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
            'MEMORY MATRIX PROTOCOL COMPLETE',
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
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Round $_round ($_sequenceLength tiles) · Delta: ${summary.ratingDelta >= 0 ? "+${summary.ratingDelta}" : "${summary.ratingDelta}"}',
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
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
                      'Round $_round · $_sequenceLength Tiles',
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
              const SizedBox(height: 20),

              Text(
                _isPlayingSequence ? 'MEMORIZE SPATIAL SEQUENCE' : 'REPRODUCE PATTERN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: _isPlayingSequence ? AppColors.primary : AppColors.productive,
                ),
              ),
              const Spacer(),

              AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: 9,
                    itemBuilder: (context, index) {
                      final isFlashing = _activeFlashingTile == index;
                      final isTapped = _userSequence.contains(index);

                      Color tileColor = AppColors.surfaceElevated;
                      Color borderColor = AppColors.border;

                      if (isFlashing) {
                        tileColor = AppColors.primary;
                        borderColor = AppColors.primary;
                      } else if (isTapped) {
                        tileColor = AppColors.primary.withValues(alpha: 0.25);
                        borderColor = AppColors.primary;
                      }

                      return InkWell(
                        onTap: () => _onTileTap(index),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            color: tileColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const Spacer(),

              Text(
                'Remember ${_currentSequence.length} highlighted positions in chronological order',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
