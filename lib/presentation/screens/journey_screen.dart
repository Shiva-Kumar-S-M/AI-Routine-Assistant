import 'package:flutter/material.dart';
import '../../data/repositories/progress_repository.dart';
import '../../domain/models/user_progress.dart';
import '../../domain/models/badge_item.dart';
import 'weekly_recap_screen.dart';

class JourneyScreen extends StatefulWidget {
  const JourneyScreen({super.key});

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  final ProgressRepository _repo = ProgressRepository();
  UserProgress? _progress;
  List<BadgeItem> _badges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _repo.syncFromUnrewardedInterventions();
    final progress = await _repo.getUserProgress();
    final badges = await _repo.getBadges();
    if (mounted) {
      setState(() {
        _progress = progress;
        _badges = badges;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E18),
      appBar: AppBar(
        title: const Text(
          'Your Journey',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontSize: 22,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: const Color(0xFF0E0E18),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF8E8EA2)),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C4DFF)))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF7C4DFF),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Level & XP Hero Card
                    _levelCard(),
                    const SizedBox(height: 16),

                    // 2. Streaks & Time Reclaimed Row
                    Row(
                      children: [
                        // Streak Flame
                        Expanded(
                          child: _statPill(
                            title: 'Active Streak',
                            value: '${_progress!.streakDays} Days',
                            subtitle: '${_progress!.streakFreezes} Freezes Available',
                            icon: Icons.local_fire_department_rounded,
                            iconColor: const Color(0xFFFF5722),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Time Reclaimed
                        Expanded(
                          child: _statPill(
                            title: 'Time Reclaimed',
                            value: _progress!.formattedTimeReclaimed,
                            subtitle: 'Saved from scrolling',
                            icon: Icons.hourglass_bottom_rounded,
                            iconColor: const Color(0xFF00E676),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 3. Weekly Recap Entry Banner
                    InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const WeeklyRecapScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF281E48), Color(0xFF1E1738)],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFF4C3672)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.auto_graph_rounded, color: Color(0xFFFFD700), size: 28),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Weekly Focus Recap',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Wins, reclaimed hours & algorithmic insights',
                                    style: TextStyle(color: Color(0xFF9E9EAF), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF7C4DFF), size: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),

                    // 4. Badges & Trophies Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'BADGES & ACHIEVEMENTS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: Color(0xFF8E8EA2),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F1F35),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF33334E)),
                          ),
                          child: Text(
                            '${_badges.where((b) => b.isUnlocked).length} / ${_badges.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFFD700),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Badges Grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.88,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _badges.length,
                      itemBuilder: (context, index) {
                        return _badgeCard(_badges[index]);
                      },
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _levelCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF261D4E), Color(0xFF1B1736)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF4C3876)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C4DFF), Color(0xFF651FFF)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    '${_progress!.level}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LEVEL ${_progress!.level}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF7C4DFF),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _progress!.levelTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF332515),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFB300)),
                ),
                child: Text(
                  '${_progress!.xp} XP',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFD700),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress!.levelProgress,
              minHeight: 10,
              backgroundColor: const Color(0xFF262040),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7C4DFF)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(_progress!.levelProgress * 100).toInt()}% towards next tier',
                style: const TextStyle(fontSize: 11, color: Color(0xFF8E8EA2)),
              ),
              Text(
                '${_progress!.xpRemainingToNext} XP to Level ${_progress!.level + 1}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF9E9EAF)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statPill({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2B2B44)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF8E8EA2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgeCard(BadgeItem badge) {
    final isUnlocked = badge.isUnlocked;
    final primaryColor = isUnlocked ? const Color(0xFF7C4DFF) : const Color(0xFF5A5A72);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF181827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnlocked ? const Color(0xFF7C4DFF).withValues(alpha: 0.5) : const Color(0xFF26263A),
          width: isUnlocked ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? const Color(0xFF7C4DFF).withValues(alpha: 0.2)
                      : const Color(0xFF202032),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isUnlocked ? Icons.verified_rounded : Icons.lock_outline_rounded,
                  size: 20,
                  color: primaryColor,
                ),
              ),
              if (isUnlocked)
                const Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 16),
            ],
          ),
          const Spacer(),
          Text(
            badge.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isUnlocked ? Colors.white : const Color(0xFF7A7A90),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            badge.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF8E8EA2),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: badge.progressFraction,
              minHeight: 4,
              backgroundColor: const Color(0xFF252538),
              valueColor: AlwaysStoppedAnimation<Color>(
                isUnlocked ? const Color(0xFF00E676) : const Color(0xFF4A4A62),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${badge.currentProgress}/${badge.maxProgress}',
            style: const TextStyle(fontSize: 9, color: Color(0xFF6E6E84)),
          ),
        ],
      ),
    );
  }
}
