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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Your Journey',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF202124),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF5F6368)),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3D5AFE)))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF3D5AFE),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
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
                            subtitle: '${_progress!.streakFreezes} Freezes',
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
                            iconColor: const Color(0xFF00C853),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 3. Weekly Recap Entry Banner
                    InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const WeeklyRecapScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF303F9F), Color(0xFF1A237E)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.auto_graph_rounded, color: Colors.amber, size: 28),
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
                                    'View wins, reclaimed time & algorithmic advice',
                                    style: TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 4. Badges & Trophies Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'BADGES & ACHIEVEMENTS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: Color(0xFF5F6368),
                          ),
                        ),
                        Text(
                          '${_badges.where((b) => b.isUnlocked).length} / ${_badges.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3D5AFE),
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
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _badges.length,
                      itemBuilder: (context, index) {
                        return _badgeCard(_badges[index]);
                      },
                    ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3D5AFE), Color(0xFF536DFE)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    '${_progress!.level}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
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
                      'Level ${_progress!.level}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3D5AFE),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _progress!.levelTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF202124),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${_progress!.xp} XP',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFF9100),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress!.levelProgress,
              minHeight: 10,
              backgroundColor: const Color(0xFFECEFF1),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3D5AFE)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(_progress!.levelProgress * 100).toInt()}% towards next level',
                style: const TextStyle(fontSize: 11, color: Color(0xFF70757A)),
              ),
              Text(
                '${_progress!.xpRemainingToNext} XP to Level ${_progress!.level + 1}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5F6368)),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EAED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF202124),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF70757A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgeCard(BadgeItem badge) {
    final isUnlocked = badge.isUnlocked;
    final primaryColor = isUnlocked ? const Color(0xFF3D5AFE) : const Color(0xFF9E9E9E);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUnlocked ? const Color(0xFF3D5AFE).withValues(alpha: 0.3) : const Color(0xFFEEEEEE),
          width: isUnlocked ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isUnlocked ? const Color(0xFF3D5AFE).withValues(alpha: 0.06) : Colors.transparent,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
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
                  color: isUnlocked ? const Color(0xFF3D5AFE).withValues(alpha: 0.12) : const Color(0xFFF1F3F4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isUnlocked ? Icons.verified_rounded : Icons.lock_outline_rounded,
                  size: 20,
                  color: primaryColor,
                ),
              ),
              if (isUnlocked)
                const Icon(Icons.check_circle_rounded, color: Color(0xFF00C853), size: 16),
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
              color: isUnlocked ? const Color(0xFF202124) : const Color(0xFF757575),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            badge.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF757575),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: badge.progressFraction,
              minHeight: 4,
              backgroundColor: const Color(0xFFEEEEEE),
              valueColor: AlwaysStoppedAnimation<Color>(
                isUnlocked ? const Color(0xFF00C853) : const Color(0xFFBDBDBD),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${badge.currentProgress}/${badge.maxProgress}',
            style: const TextStyle(fontSize: 9, color: Color(0xFF9E9E9E)),
          ),
        ],
      ),
    );
  }
}

