import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/models/brain_gym_models.dart';
import '../../../data/repositories/brain_gym_repository.dart';
import 'math_sprint_screen.dart';
import 'sequence_game_screen.dart';
import 'memory_flash_screen.dart';
import 'logic_game_screen.dart';

class BrainGymHubScreen extends StatefulWidget {
  const BrainGymHubScreen({super.key});

  @override
  State<BrainGymHubScreen> createState() => _BrainGymHubScreenState();
}

class _BrainGymHubScreenState extends State<BrainGymHubScreen> {
  final BrainGymRepository _repository = BrainGymRepository();
  bool _loading = true;
  BrainGymProfile _profile = BrainGymProfile.initial();
  Map<String, int> _personalBests = {};
  List<BrainGymScore> _recentScores = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final profile = await _repository.getProfile();
    final personalBests = await _repository.getPersonalBests();
    final recents = await _repository.getHighScores(limit: 10);

    if (mounted) {
      setState(() {
        _profile = profile;
        _personalBests = personalBests;
        _recentScores = recents;
        _loading = false;
      });
    }
  }

  void _launchGame(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 18),
                _buildRatingCard(),
                const SizedBox(height: 16),
                _buildDailyChallengeCard(),
                const SizedBox(height: 24),
                const Text(
                  'NEURO-TRAINING SUITE',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                _buildGameCard(
                  title: 'Math Sprint',
                  subtitle: '60s mental arithmetic blitz. Adaptive difficulty.',
                  icon: Icons.bolt_rounded,
                  mode: BrainGymGameMode.mathSprint,
                  onTap: () => _launchGame(const MathSprintScreen()),
                ),
                const SizedBox(height: 10),
                _buildGameCard(
                  title: 'Number Sequence',
                  subtitle: 'Spot the pattern and predict what follows.',
                  icon: Icons.tag_rounded,
                  mode: BrainGymGameMode.numberSequence,
                  onTap: () => _launchGame(const SequenceGameScreen()),
                ),
                const SizedBox(height: 10),
                _buildGameCard(
                  title: 'Memory Flash',
                  subtitle: 'Remember and reproduce spatial light patterns.',
                  icon: Icons.grid_view_rounded,
                  mode: BrainGymGameMode.memoryFlash,
                  onTap: () => _launchGame(const MemoryFlashScreen()),
                ),
                const SizedBox(height: 10),
                _buildGameCard(
                  title: 'Logic Grid',
                  subtitle: 'Analogies, classifications & deductive reasoning.',
                  icon: Icons.extension_rounded,
                  mode: BrainGymGameMode.logicGrid,
                  onTap: () => _launchGame(const LogicGameScreen()),
                ),
                const SizedBox(height: 24),
                _buildLeaderboardSection(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Brain Gym',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Cognitive training & impulse deflection',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 16),
              const SizedBox(width: 4),
              Text(
                '${_profile.streakDays}d Streak',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRatingCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.psychology_outlined, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _profile.skillTier.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• ${_profile.gamesPlayed} sessions',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_profile.skillRating} ELO',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Calibrated dynamically across speed and accuracy vectors',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyChallengeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.productive.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.event_available_outlined, color: AppColors.productive, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DAILY PROTOCOL',
                  style: TextStyle(
                    color: AppColors.productive,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                    letterSpacing: 1.1,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Mixed Cognition Workout',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '10 questions • +40 XP reward',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _launchGame(const MathSprintScreen(isDailyChallenge: true)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.productive,
              foregroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              elevation: 0,
            ),
            child: const Text('Start', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required BrainGymGameMode mode,
    required VoidCallback onTap,
  }) {
    final bestScore = _personalBests[mode.id];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(icon, color: AppColors.textPrimary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (bestScore != null)
                        Text(
                          'Best: $bestScore',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textDisabled, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RECENT SESSIONS & LOGS',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        if (_recentScores.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Text(
                'No sessions recorded yet. Launch Math Sprint to calibrate your cognitive rating.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentScores.take(5).length,
              separatorBuilder: (_, __) => const Divider(color: AppColors.border, height: 1),
              itemBuilder: (context, index) {
                final item = _recentScores[index];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.surfaceElevated,
                    child: Text(
                      '#${index + 1}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                  title: Text(
                    item.modeDisplayName,
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  subtitle: Text(
                    '${item.accuracy.toInt()}% accuracy • ${item.correctAnswers}/${item.totalQuestions}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                  trailing: Text(
                    '${item.score} pts',
                    style: const TextStyle(
                      color: AppColors.productive,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
