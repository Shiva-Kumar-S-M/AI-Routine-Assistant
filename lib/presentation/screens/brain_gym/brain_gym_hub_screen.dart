import 'package:flutter/material.dart';
import 'package:ai_routine_assistant/domain/models/brain_gym_models.dart';
import 'package:ai_routine_assistant/data/repositories/brain_gym_repository.dart';
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
        backgroundColor: Color(0xFF13131F),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF7C4DFF)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF13131F),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: const Color(0xFF7C4DFF),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildRatingCard(),
                const SizedBox(height: 20),
                _buildDailyChallengeCard(),
                const SizedBox(height: 24),
                const Text(
                  'TRAINING MODES',
                  style: TextStyle(
                    color: Color(0xFF8E8EA0),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                _buildGameCard(
                  title: 'Math Sprint',
                  subtitle: '60s mental arithmetic blitz. Adaptive difficulty.',
                  icon: Icons.bolt_rounded,
                  iconGradient: const [Color(0xFFFF9100), Color(0xFFFF3D00)],
                  mode: BrainGymGameMode.mathSprint,
                  onTap: () => _launchGame(const MathSprintScreen()),
                ),
                const SizedBox(height: 12),
                _buildGameCard(
                  title: 'Number Sequence',
                  subtitle: 'Spot the pattern and predict what follows.',
                  icon: Icons.tag_rounded,
                  iconGradient: const [Color(0xFF2979FF), Color(0xFF00E5FF)],
                  mode: BrainGymGameMode.numberSequence,
                  onTap: () => _launchGame(const SequenceGameScreen()),
                ),
                const SizedBox(height: 12),
                _buildGameCard(
                  title: 'Memory Flash',
                  subtitle: 'Remember and reproduce spatial light patterns.',
                  icon: Icons.grid_view_rounded,
                  iconGradient: const [Color(0xFF7C4DFF), Color(0xFFB388FF)],
                  mode: BrainGymGameMode.memoryFlash,
                  onTap: () => _launchGame(const MemoryFlashScreen()),
                ),
                const SizedBox(height: 12),
                _buildGameCard(
                  title: 'Logic Grid',
                  subtitle: 'Analogies, classifications & odd-one-out reasoning.',
                  icon: Icons.extension_rounded,
                  iconGradient: const [Color(0xFF00E676), Color(0xFF1DE9B6)],
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
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Cognitive training & impulse deflection',
              style: TextStyle(
                color: Color(0xFF8E8EA0),
                fontSize: 13,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F33),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF33334D)),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF5722), size: 18),
              const SizedBox(width: 4),
              Text(
                '${_profile.streakDays}d Streak',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A1B4E), Color(0xFF1E1E35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF4A3475)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0x337C4DFF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF7C4DFF)),
            ),
            child: const Icon(Icons.military_tech_rounded, color: Color(0xFFFFD700), size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _profile.skillTier.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• ${_profile.gamesPlayed} games played',
                      style: const TextStyle(color: Color(0xFF9E9EAF), fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_profile.skillRating} ELO',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Skill rating dynamically shifts based on speed & accuracy',
                  style: TextStyle(color: Color(0xFF8E8EA0), fontSize: 11),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F3E3A), Color(0xFF152A2D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x8000E676)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x2600E676),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.today_rounded, color: Color(0xFF00E676), size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DAILY CHALLENGE',
                  style: TextStyle(
                    color: Color(0xFF00E676),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Today\'s Mixed Workout',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '10 questions seeded for today • +40 XP reward',
                  style: TextStyle(color: Color(0xFF8E9FA0), fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _launchGame(const MathSprintScreen(isDailyChallenge: true)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: const Text('Play', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> iconGradient,
    required BrainGymGameMode mode,
    required VoidCallback onTap,
  }) {
    final bestScore = _personalBests[mode.id];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF313147)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: iconGradient),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
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
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (bestScore != null)
                        Text(
                          'Best: $bestScore',
                          style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8E8EA0),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF5A5A72)),
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
          'LOCAL LEADERBOARD & RECENT SESSIONS',
          style: TextStyle(
            color: Color(0xFF8E8EA0),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        if (_recentScores.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A28),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                'No games played yet. Jump into Math Sprint to calibrate your rating!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6E6E82), fontSize: 13),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2F),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF2C2C40)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentScores.take(5).length,
              separatorBuilder: (_, __) => const Divider(color: Color(0xFF2C2C40), height: 1),
              itemBuilder: (context, index) {
                final item = _recentScores[index];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFF2C2C42),
                    child: Text(
                      '#${index + 1}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    item.modeDisplayName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  subtitle: Text(
                    '${item.accuracy.toInt()}% accuracy • ${item.correctAnswers}/${item.totalQuestions}',
                    style: const TextStyle(color: Color(0xFF7E7E94), fontSize: 11),
                  ),
                  trailing: Text(
                    '${item.score} pts',
                    style: const TextStyle(
                      color: Color(0xFF00E676),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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

