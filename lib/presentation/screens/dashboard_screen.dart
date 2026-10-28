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
import '../../services/app_label_helper.dart';

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
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border, width: 1.0),
            ),
            title: const Text(
              'DAILY FOCUS GOAL',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontSize: 13,
                letterSpacing: 1.2,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose your daily target:',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Radio<String>(
                    value: 'turn_backs',
                    // ignore: deprecated_member_use
                    groupValue: selectedType,
                    activeColor: AppColors.primary,
                    // ignore: deprecated_member_use
                    onChanged: (val) => setDialogState(() {
                      selectedType = val!;
                      target = 3;
                    }),
                  ),
                  title: const Text(
                    'Turn-backs from Distraction',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Resist full-screen overlays (Recommended)',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
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
                    activeColor: AppColors.primary,
                    // ignore: deprecated_member_use
                    onChanged: (val) => setDialogState(() {
                      selectedType = val!;
                      target = 60;
                    }),
                  ),
                  title: const Text(
                    'Max Distraction Screen Time',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Keep distracting apps under limit',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  onTap: () => setDialogState(() {
                    selectedType = 'distracting_minutes';
                    target = 60;
                  }),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      selectedType == 'turn_backs' ? 'Target Turn-backs:' : 'Target Minutes:',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    ),
                    DropdownButton<int>(
                      value: target,
                      dropdownColor: AppColors.surfaceRaised,
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
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
                child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _progressRepo.updateDailyGoal(selectedType, target);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  _loadDashboardData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Goal', style: TextStyle(fontWeight: FontWeight.w600)),
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
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: AppColors.border, width: 1.0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'PRODUCTIVITY SCORE',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  '$score / 100',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Your score is computed 100% on-device from 3 weighted signal metrics:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _signalRow('Distraction Ratio (45%)', '$distractionRatioPct pts'),
            _signalRow('Focus Time (35%)', '${_focusMinutesToday}m / 120m target'),
            _signalRow('Routine Adherence (20%)', '${_streakDays > 0 ? 85 : 50}% adherence'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _signalRow(String title, String detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Text(
            detail,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Stage 4 Components ─────────────────────────────────────────────────────

  Widget _buildGreetingHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getGreeting(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'AI ROUTINE ASSISTANT · ON-DEVICE',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'LEVEL ${p.level} · ${p.levelTitle.toUpperCase()}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  '${p.xp} TOTAL XP',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: levelProgress.clamp(0.0, 1.0),
                minHeight: 2,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(int score, int productiveSecs, int distractingSecs) {
    final reclaimedStr = _userProgress?.formattedTimeReclaimed ?? '0m';
    final turnBacks = _userProgress?.totalTurnBacks ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: _statColumn('RECLAIMED', reclaimedStr),
          ),
          Container(width: 1, height: 36, color: AppColors.border),
          Expanded(
            child: _statColumn('TURN-BACKS', '$turnBacks'),
          ),
          Container(width: 1, height: 36, color: AppColors.border),
          Expanded(
            child: _statColumn(
              'SCORE',
              '$score',
              onTap: () => _showScoreBreakdownSheet(score, productiveSecs, distractingSecs),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statColumn(String label, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w300,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrainGymEntryRow() {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MathSprintScreen()),
        ).then((_) => _loadDashboardData());
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.0),
        ),
        child: const Row(
          children: [
            Icon(Icons.extension_outlined, color: AppColors.textPrimary, size: 20),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(
                     'Brain Gym Sprint',
                     style: TextStyle(
                       color: AppColors.textPrimary,
                       fontSize: 14,
                       fontWeight: FontWeight.w600,
                     ),
                   ),
                   SizedBox(height: 2),
                   Text(
                     '60s mental math impulse deflection',
                     style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                   ),
                 ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildProductivityScoreCard(int score, String scoreDesc, int productiveSecs, int distractingSecs) {
    return GestureDetector(
      onTap: () => _showScoreBreakdownSheet(score, productiveSecs, distractingSecs),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PRODUCTIVITY SCORE',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$score',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 54,
                        fontWeight: FontWeight.w300,
                        letterSpacing: -2.0,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scoreDesc.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.info_outline, color: AppColors.textSecondary, size: 18),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _metricPill(
                    label: 'FOCUS',
                    value: _formatMinutes(_focusMinutesToday),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _metricPill(
                    label: 'DISTRACTION',
                    value: '${(distractingSecs / 60).round()}m',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _metricPill(
                    label: 'PRODUCTIVE',
                    value: '${(productiveSecs / 60).round()}m',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(int totalMins) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "TODAY'S SCREEN TIME",
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatMinutes(totalMins),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 44,
              fontWeight: FontWeight.w300,
              letterSpacing: -1.5,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_formatMinutes(_focusMinutesToday)} focused today',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                '${_categoryTotals['distracting'] != null ? (_categoryTotals['distracting']! ~/ 60) : 0}m distracting',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productiveSecs = _categoryTotals['productive'] ?? 0;
    final distractingSecs = _categoryTotals['distracting'] ?? 0;
    final totalSecs = productiveSecs + distractingSecs;
    final totalMins = totalSecs ~/ 60;
    final score = ProductivityScoreCalculator.calculateCompositeScore(
      productiveSeconds: productiveSecs,
      distractingSeconds: distractingSecs,
      focusMinutesToday: _focusMinutesToday,
    );
    final scoreDesc = ProductivityScoreCalculator.getScoreDescription(score);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.background,
        title: const Text(
          'FOCUS ASSISTANT',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined, color: AppColors.textSecondary, size: 20),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.timer_outlined, color: AppColors.textSecondary, size: 20),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FocusSessionScreen()),
            ),
            tooltip: 'Focus Mode',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.textPrimary))
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              color: AppColors.textPrimary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Minimal Greeting Header
                    _buildGreetingHeader(),
                    const SizedBox(height: 14),

                    // 2. Level & XP Progress Bar
                    _buildLevelAndXpBar(),
                    const SizedBox(height: 12),

                    // 3. Hero Stat (Today's screen-time in 44sp weight 300)
                    _buildHeroCard(totalMins),
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

                    // 5. Stat Row (Reclaimed | Turn-backs | Score separated by 1px dividers)
                    _buildStatRow(score, productiveSecs, distractingSecs),
                    const SizedBox(height: 12),

                    // 6. Quick Actions
                    Row(
                      children: [
                        Expanded(
                          child: ChunkyButton(
                            text: 'Start Focus',
                            icon: Icons.play_arrow_outlined,
                            height: 48,
                            borderRadius: 14,
                            isSecondary: false,
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
                            icon: Icons.tune_outlined,
                            height: 48,
                            borderRadius: 14,
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
                    const SizedBox(height: 12),

                    // 7. Brain Gym Entry Row
                    _buildBrainGymEntryRow(),
                    const SizedBox(height: 12),

                    // 8. Productivity Score Details Card
                    _buildProductivityScoreCard(score, scoreDesc, productiveSecs, distractingSecs),
                    const SizedBox(height: 24),

                    // 9. Top Apps Used Today
                    if (_topApps.isNotEmpty) ...[
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Top Apps Today',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'TAP TO SET LIMIT',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border, width: 1.0),
                        ),
                        child: Column(
                          children: _topApps.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final app = entry.value;
                            final durationSecs = app['durationSeconds'] as int;
                            final pkgName = app['packageName'] as String;
                            final rawAppName = app['appName'] as String? ?? '';
                            final appName = (rawAppName.isNotEmpty && rawAppName != pkgName)
                                ? rawAppName
                                : AppLabelHelper.cleanPackageName(pkgName);
                            final category = (app['category'] as String).toUpperCase();

                            return Column(
                              children: [
                                if (idx > 0)
                                  const Divider(color: AppColors.border, height: 16),
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
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceRaised,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppColors.border, width: 1.0),
                                          ),
                                          child: const Icon(Icons.apps_outlined, size: 18, color: AppColors.textSecondary),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                appName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 14,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              Text(
                                                category,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textSecondary,
                                                  letterSpacing: 0.8,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          _formatMinutes(durationSecs ~/ 60),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w400,
                                            fontSize: 13,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
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

                    // 10. Screen Time Donut Breakdown
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Today's Screen Time",
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_selectedCategory != null)
                          GestureDetector(
                            onTap: () => _onCategoryTapped(null),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceRaised,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border, width: 1.0),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.close, color: AppColors.textPrimary, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'CLEAR',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
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
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 1.0),
                      ),
                      child: CategoryChart(
                        categoryTotals: _categoryTotals,
                        onCategoryTapped: _onCategoryTapped,
                        highlightedCategory: _selectedCategory,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 11. 7-Day Trend Chart
                    const Text(
                      '7-Day Screen Time Trend',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 1.0),
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
                          color: AppColors.surfaceRaised,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border, width: 1.0),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _miniBreakdown('Productive', _selectedDayBreakdown!['productive'] ?? 0),
                            _miniBreakdown('Distracting', _selectedDayBreakdown!['distracting'] ?? 0),
                            _miniBreakdown('Neutral', _selectedDayBreakdown!['neutral'] ?? 0),
                          ],
                        ),
                      ),
                    ],

                    // 12. Intervention Alerts List
                    if (_filteredAlerts.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Recent Interventions',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
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
                                        child: CircularProgressIndicator(color: AppColors.textPrimary),
                                      ),
                                    )
                                  : OutlinedButton(
                                      onPressed: _loadMoreAlerts,
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(44),
                                        side: const BorderSide(color: AppColors.border),
                                        foregroundColor: AppColors.textPrimary,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: const Text('Load More Alerts'),
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

  Widget _miniBreakdown(String label, int seconds) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _formatMinutes(seconds ~/ 60),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _metricPill({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
