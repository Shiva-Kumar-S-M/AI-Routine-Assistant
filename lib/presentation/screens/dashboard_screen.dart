import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/repositories/usage_repository.dart';
import '../../data/repositories/focus_repository.dart';
import '../../domain/models/routine_alert.dart';
import '../../domain/services/productivity_score_calculator.dart';
import '../../services/usage_collector_service.dart';
import '../widgets/category_chart.dart';
import '../widgets/trend_chart.dart';
import '../widgets/alert_tile.dart';
import '../widgets/app_limit_dialog.dart';
import '../widgets/daily_goal_ring.dart';
import '../widgets/level_up_dialog.dart';
import '../widgets/chunky_button.dart';
import '../../data/repositories/progress_repository.dart';
import '../../domain/models/user_progress.dart';
import 'journey_screen.dart';
import 'focus_session_screen.dart';
import 'settings_screen.dart';
import 'brain_gym/math_sprint_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final UsageRepository _repository = UsageRepository();
  final FocusRepository _focusRepository = FocusRepository();
  final UsageCollectorService _collector = UsageCollectorService();
  final ProgressRepository _progressRepo = ProgressRepository();

  UserProgress? _userProgress;
  Map<String, dynamic>? _dailyGoalProgress;

  Map<String, int> _categoryTotals = {
    'productive': 0,
    'distracting': 0,
    'neutral': 0
  };
  Map<DateTime, int> _trendTotals = {};
  List<RoutineAlert> _recentAlerts = [];
  List<Map<String, dynamic>> _topApps = [];
  int _focusMinutesToday = 0;
  int _streakDays = 0;
  bool _isLoading = true;

  String? _selectedCategory;
  DateTime? _selectedDay;
  Map<String, int>? _selectedDayBreakdown;

  static const int _pageSize = 10;
  int _alertsOffset = 0;
  bool _hasMoreAlerts = true;
  bool _loadingMoreAlerts = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      await _collector.collectAndSaveLogs(window: const Duration(hours: 24));
      await _repository.backfillStaleAppNames();

      final totals = await _repository.getCategoryScreenTimeForToday();
      final trend = await _repository.get7DayScreenTimeTrend();
      final alerts =
          await _repository.getNotificationsPage(limit: _pageSize, offset: 0);
      final focusMin = await _focusRepository.getTodayCompletedMinutes();
      final topApps = await _repository.getTopAppsForToday();
      final streak = await _repository.getProductivityStreak();

      // Stage 2: Sync progress, interventions & daily goal
      final levelUp = await _progressRepo.syncFromUnrewardedInterventions();
      await _progressRepo.syncDailyStreak();
      final progress = await _progressRepo.getUserProgress();
      final goal = await _progressRepo.getDailyGoalProgress();

      if (levelUp != null && mounted) {
        LevelUpDialog.show(context, newLevel: levelUp.newLevel, title: levelUp.title);
      }

      if (mounted) {
        setState(() {
          _categoryTotals = totals;
          _trendTotals = trend;
          _recentAlerts = alerts;
          _alertsOffset = alerts.length;
          _hasMoreAlerts = alerts.length == _pageSize;
          _focusMinutesToday = focusMin;
          _topApps = topApps;
          _streakDays = streak;
          _userProgress = progress;
          _dailyGoalProgress = goal;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreAlerts() async {
    if (_loadingMoreAlerts || !_hasMoreAlerts) return;
    setState(() => _loadingMoreAlerts = true);

    try {
      final next = await _repository.getNotificationsPage(
          limit: _pageSize, offset: _alertsOffset);
      if (mounted) {
        setState(() {
          _recentAlerts.addAll(next);
          _alertsOffset += next.length;
          _hasMoreAlerts = next.length == _pageSize;
          _loadingMoreAlerts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMoreAlerts = false);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _showDailyGoalDialog() {
    String selectedType = _dailyGoalProgress?['goalType'] ?? 'turn_backs';
    int target = _dailyGoalProgress?['target'] ?? 3;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF181827),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Color(0xFF2D2D46)),
            ),
            title: const Text('Set Daily Focus Goal',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose your daily target:',
                    style: TextStyle(color: Color(0xFF8E8EA2), fontSize: 13)),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Radio<String>(
                    value: 'turn_backs',
                    // ignore: deprecated_member_use
                    groupValue: selectedType,
                    activeColor: const Color(0xFF7C4DFF),
                    // ignore: deprecated_member_use
                    onChanged: (val) => setDialogState(() {
                      selectedType = val!;
                      target = 3;
                    }),
                  ),
                  title: const Text('Turn-backs from Distraction',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Resist overlays (Recommended)',
                      style: TextStyle(color: Color(0xFF8E8EA2), fontSize: 12)),
                  onTap: () => setDialogState(() {
                    selectedType = 'turn_backs';
                    target = 3;
                  }),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Radio<String>(
                    value: 'distracting_minutes',
                    // ignore: deprecated_member_use
                    groupValue: selectedType,
                    activeColor: const Color(0xFF7C4DFF),
                    // ignore: deprecated_member_use
                    onChanged: (val) => setDialogState(() {
                      selectedType = val!;
                      target = 60;
                    }),
                  ),
                  title: const Text('Max Distraction Screen Time',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Keep distracting apps under limit',
                      style: TextStyle(color: Color(0xFF8E8EA2), fontSize: 12)),
                  onTap: () => setDialogState(() {
                    selectedType = 'distracting_minutes';
                    target = 60;
                  }),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      selectedType == 'turn_backs' ? 'Target Turn-backs:' : 'Target Minutes:',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    DropdownButton<int>(
                      value: target,
                      dropdownColor: const Color(0xFF222238),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      items: (selectedType == 'turn_backs' ? [1, 2, 3, 5, 8] : [30, 45, 60, 90, 120])
                          .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => target = val);
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8EA2))),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _progressRepo.updateDailyGoal(selectedType, target);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  _loadDashboardData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C4DFF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Save Goal', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _onCategoryTapped(String? category) {
    setState(() => _selectedCategory = category);
  }

  Future<void> _onDayTapped(DateTime day) async {
    if (_selectedDay != null &&
        _selectedDay!.year == day.year &&
        _selectedDay!.month == day.month &&
        _selectedDay!.day == day.day) {
      setState(() {
        _selectedDay = null;
        _selectedDayBreakdown = null;
      });
      return;
    }

    final breakdown = await _repository.getCategoryBreakdownForDay(day);
    if (mounted) {
      setState(() {
        _selectedDay = day;
        _selectedDayBreakdown = breakdown;
      });
    }
  }

  List<RoutineAlert> get _filteredAlerts {
    if (_selectedCategory == null) return _recentAlerts;
    return _recentAlerts.where((alert) {
      final isDistraction = alert.type == AlertType.distractionAlert;
      if (_selectedCategory == 'distracting') return isDistraction;
      return !isDistraction;
    }).toList();
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'productive':
        return AppColors.productive;
      case 'distracting':
        return AppColors.distracting;
      default:
        return AppColors.neutral;
    }
  }

  void _showScoreBreakdownSheet(
      int score, int productiveSecs, int distractingSecs) {
    final totalSecs = productiveSecs + distractingSecs;
    final distractionRatioPct =
        totalSecs > 0 ? ((1 - (distractingSecs / totalSecs)) * 100).round() : 100;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF181827),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0xFF2D2D46))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF383854),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Productivity Score Formula',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '$score / 100',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.scoreColor(score),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Your score is computed 100% on-device from 3 weighted signal metrics:',
              style: TextStyle(color: Color(0xFF8E8EA2), fontSize: 13),
            ),
            const SizedBox(height: 16),
            _signalRow('Distraction Ratio (45%)', '$distractionRatioPct pts', AppColors.primary),
            _signalRow('Focus Time (35%)', '${_focusMinutesToday}m / 120m target', AppColors.productive),
            _signalRow('Routine Adherence (20%)', '${_streakDays > 0 ? 85 : 50}% adherence', AppColors.warning),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _signalRow(String title, String detail, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          Text(detail,
              style: const TextStyle(
                  color: Color(0xFF9E9EAF),
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── Stage 4 Components ─────────────────────────────────────────────────────

  Widget _buildGreetingAndStreakHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getGreeting(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'AI Routine Assistant • 100% On-Device',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Color(0xFF8E8EA2), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildLevelAndXpBar() {
    if (_userProgress == null) return const SizedBox.shrink();

    final p = _userProgress!;
    final levelProgress = p.progressTowardsNextLevel;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const JourneyScreen()),
        ).then((_) => _loadDashboardData());
      },
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2B1D4E), Color(0xFF1E1738)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF563B8C)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF7C4DFF)),
                  ),
                  child: const Icon(Icons.military_tech_rounded, color: Color(0xFFFFD700), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Level ${p.level} • ${p.levelTitle}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              '${p.currentLevelXp} / ${p.xpNeededForNextLevel} XP to Level ${p.level + 1}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFF9E9EAF), fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${p.xp} Total XP',
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: levelProgress.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: const Color(0xFF332A55),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF7C4DFF)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeReclaimedHeroCard() {
    final reclaimedStr = _userProgress?.formattedTimeReclaimed ?? '0m';
    final turnBacks = _userProgress?.totalTurnBacks ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF181827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2B2B44)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.timer_rounded, color: Color(0xFF00E676), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$reclaimedStr Reclaimed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Saved across $turnBacks resisted distraction impulses this month',
                  style: const TextStyle(color: Color(0xFF8E8EA2), fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.auto_graph_rounded, color: Color(0xFF00E676), size: 20),
        ],
      ),
    );
  }

  Widget _buildBrainGymQuickStartCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF281C3F), Color(0xFF161E36)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF483568)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF9100), Color(0xFFFF3D00)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BRAIN GYM SPRINT',
                  style: TextStyle(
                    color: Color(0xFFFF9100),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '60s Mental Math Blitz',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Rapid impulse deflection • +20 XP',
                  style: TextStyle(color: Color(0xFF9E9EAF), fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MathSprintScreen()),
              ).then((_) => _loadDashboardData());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9100),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: const Text('Sprint', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildProductivityScoreCard(int score, String scoreDesc, Color scoreColor,
      Color scoreContainerColor, int productiveSecs, int distractingSecs) {
    return GestureDetector(
      onTap: () => _showScoreBreakdownSheet(score, productiveSecs, distractingSecs),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF181827),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF2B2B44)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text(
                            'Productivity Score',
                            style: TextStyle(
                              color: Color(0xFF8E8EA2),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.info_outline, size: 14, color: Color(0xFF6E6E84)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        scoreDesc,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: scoreContainerColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scoreColor.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$score',
                      style: TextStyle(
                        color: scoreColor,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF28283C), height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _metricPill(
                    icon: Icons.timer_outlined,
                    label: 'Focus',
                    value: _formatMinutes(_focusMinutesToday),
                    color: AppColors.productive,
                    bg: const Color(0xFF122C24),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _metricPill(
                    icon: Icons.warning_amber_rounded,
                    label: 'Distraction',
                    value: '${(distractingSecs / 60).round()}m',
                    color: AppColors.distracting,
                    bg: const Color(0xFF331620),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _metricPill(
                    icon: Icons.check_circle_outline,
                    label: 'Productive',
                    value: '${(productiveSecs / 60).round()}m',
                    color: AppColors.primary,
                    bg: const Color(0xFF221A3D),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productiveSecs = _categoryTotals['productive'] ?? 0;
    final distractingSecs = _categoryTotals['distracting'] ?? 0;
    final score = ProductivityScoreCalculator.calculateCompositeScore(
      productiveSeconds: productiveSecs,
      distractingSeconds: distractingSecs,
      focusMinutesToday: _focusMinutesToday,
    );
    final scoreDesc = ProductivityScoreCalculator.getScoreDescription(score);
    final scoreColor = AppColors.scoreColor(score);
    final scoreContainerColor = AppColors.scoreContainerColor(score);

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E18),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0E0E18),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFF651FFF)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Focus Assistant',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF8E8EA2)),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.timer_outlined, color: Color(0xFF8E8EA2)),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FocusSessionScreen()),
            ),
            tooltip: 'Focus Mode',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C4DFF)))
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              color: const Color(0xFF7C4DFF),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Greeting & Streak Flame Header
                    _buildGreetingAndStreakHeader(),
                    const SizedBox(height: 14),

                    // 2. Level & XP Progress Bar
                    _buildLevelAndXpBar(),
                    const SizedBox(height: 12),

                    // 3. Time Reclaimed Hero Stat
                    _buildTimeReclaimedHeroCard(),
                    const SizedBox(height: 12),

                    // 4. Daily Goal Ring
                    if (_dailyGoalProgress != null) ...[
                      DailyGoalRing(
                        label: _dailyGoalProgress!['label'] as String,
                        progressPercent: (_dailyGoalProgress!['percent'] as num).toDouble(),
                        isAchieved: _dailyGoalProgress!['isAchieved'] as bool,
                        onTap: _showDailyGoalDialog,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // 5. Quick-Start Brain Gym Blitz Card
                    _buildBrainGymQuickStartCard(),
                    const SizedBox(height: 14),

                    // 6. Productivity Score Hero Card
                    _buildProductivityScoreCard(score, scoreDesc, scoreColor, scoreContainerColor,
                        productiveSecs, distractingSecs),
                    const SizedBox(height: 16),

                    // Quick Actions
                    Row(
                      children: [
                        Expanded(
                          child: ChunkyButton(
                            text: 'Start Focus',
                            icon: Icons.play_arrow_rounded,
                            height: 48,
                            borderRadius: 16,
                            gradient: const [Color(0xFF7C4DFF), Color(0xFF651FFF)],
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const FocusSessionScreen()),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ChunkyButton(
                            text: 'App Limits',
                            icon: Icons.tune_rounded,
                            height: 48,
                            borderRadius: 16,
                            isSecondary: true,
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const SettingsScreen()),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Top Apps Used Today
                    if (_topApps.isNotEmpty) ...[
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Top Apps Today',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Tap to set limit',
                            style: TextStyle(
                              color: Color(0xFF7C4DFF),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF181827),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF2B2B44)),
                        ),
                        child: Column(
                          children: _topApps.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final app = entry.value;
                            final catColor = _getCategoryColor(app['category'] as String);
                            final durationSecs = app['durationSeconds'] as int;
                            final pkgName = app['packageName'] as String;
                            final appName = app['appName'] as String;

                            return Column(
                              children: [
                                if (idx > 0)
                                  const Divider(color: Color(0xFF28283C), height: 16),
                                InkWell(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => AppLimitDialog(
                                        packageName: pkgName,
                                        appName: appName,
                                        onLimitSaved: _loadDashboardData,
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: catColor.withValues(alpha: 0.15),
                                          child: Icon(Icons.android_rounded, size: 20, color: catColor),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                appName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              Text(
                                                (app['category'] as String).toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: catColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          _formatMinutes(durationSecs ~/ 60),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF6E6E84)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Screen Time Donut Breakdown
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Today's Screen Time",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_selectedCategory != null)
                          GestureDetector(
                            onTap: () => _onCategoryTapped(null),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF261D4E),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.close, color: Color(0xFF7C4DFF), size: 14),
                                  SizedBox(width: 4),
                                  Text('Clear filter',
                                      style: TextStyle(
                                          color: Color(0xFF7C4DFF),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181827),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF2B2B44)),
                      ),
                      child: CategoryChart(
                        categoryTotals: _categoryTotals,
                        onCategoryTapped: _onCategoryTapped,
                        highlightedCategory: _selectedCategory,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 7-Day Trend Chart
                    const Text(
                      '7-Day Screen Time Trend',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181827),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF2B2B44)),
                      ),
                      child: TrendChart(
                        trendTotals: _trendTotals,
                        onDayTapped: _onDayTapped,
                        selectedDay: _selectedDay,
                      ),
                    ),

                    if (_selectedDay != null && _selectedDayBreakdown != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF202035),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF33334E)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _miniBreakdown('Productive', _selectedDayBreakdown!['productive'] ?? 0, AppColors.productive),
                            _miniBreakdown('Distracting', _selectedDayBreakdown!['distracting'] ?? 0, AppColors.distracting),
                            _miniBreakdown('Neutral', _selectedDayBreakdown!['neutral'] ?? 0, AppColors.neutral),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Intervention Alerts List
                    if (_filteredAlerts.isNotEmpty) ...[
                      const Text(
                        'Recent Interventions & Routines',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Column(
                        children: [
                          ..._filteredAlerts.map((alert) => AlertTile(alert: alert)),
                          if (_hasMoreAlerts && _selectedCategory == null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: _loadingMoreAlerts
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(12),
                                        child: CircularProgressIndicator(color: Color(0xFF7C4DFF)),
                                      ),
                                    )
                                  : OutlinedButton.icon(
                                      onPressed: _loadMoreAlerts,
                                      icon: const Icon(Icons.expand_more, size: 18),
                                      label: const Text('Load More Alerts'),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(44),
                                        side: const BorderSide(color: Color(0xFF2B2B44)),
                                      ),
                                    ),
                            ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _miniBreakdown(String label, int seconds, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(_formatMinutes(seconds ~/ 60),
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _metricPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
