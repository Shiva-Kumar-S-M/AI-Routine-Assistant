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
import 'focus_session_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final UsageRepository _repository = UsageRepository();
  final FocusRepository _focusRepository = FocusRepository();
  final UsageCollectorService _collector = UsageCollectorService();

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
      // Fix any stale rows where app_name == package_name using resolved names
      // already present in the DB from the sync above. Pure SQL — no MethodChannel.
      await _repository.backfillStaleAppNames();

      final totals = await _repository.getCategoryScreenTimeForToday();
      final trend = await _repository.get7DayScreenTimeTrend();
      final alerts =
          await _repository.getNotificationsPage(limit: _pageSize, offset: 0);
      final focusMin = await _focusRepository.getTodayCompletedMinutes();
      final topApps = await _repository.getTopAppsForToday();
      final streak = await _repository.getProductivityStreak();

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
          _selectedCategory = null;
          _selectedDay = null;
          _selectedDayBreakdown = null;
        });
      }
    } catch (e, stack) {
      debugPrint('Error loading dashboard data: $e\n$stack');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMoreAlerts() async {
    if (_loadingMoreAlerts || !_hasMoreAlerts) return;
    setState(() => _loadingMoreAlerts = true);

    final more = await _repository.getNotificationsPage(
        limit: _pageSize, offset: _alertsOffset);

    if (mounted) {
      setState(() {
        _recentAlerts.addAll(more);
        _alertsOffset += more.length;
        _hasMoreAlerts = more.length == _pageSize;
        _loadingMoreAlerts = false;
      });
    }
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
      if (_selectedCategory == 'productive') return !isDistraction;
      return true;
    }).toList();
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }

  Color _getCategoryColor(String cat) {
    switch (cat) {
      case 'productive':
        return AppColors.productive;
      case 'distracting':
        return AppColors.distracting;
      default:
        return AppColors.neutral;
    }
  }

  void _showScoreBreakdownSheet(int score, int productiveSecs, int distractingSecs) {
    final totalSecs = productiveSecs + distractingSecs;
    final distractionRatioPct = totalSecs > 0
        ? ((1.0 - (distractingSecs / totalSecs)) * 100).round()
        : 50;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
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
                    color: Color(0xFF202124),
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
            const SizedBox(height: 16),
            const Text(
              'Your score is calculated on-device from 3 weighted signal metrics:',
              style: TextStyle(color: Color(0xFF5F6368), fontSize: 13),
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
                      color: Color(0xFF202124),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          Text(detail,
              style: const TextStyle(
                  color: Color(0xFF5F6368),
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ],
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFF1A73E8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.psychology_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'AI Routine Assistant',
              style: TextStyle(
                color: Color(0xFF202124),
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF5F6368)),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.timer_outlined, color: Color(0xFF5F6368)),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FocusSessionScreen()),
            ),
            tooltip: 'Focus Mode',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Productivity Score Hero Card (Tappable Breakdown)
                    GestureDetector(
                      onTap: () => _showScoreBreakdownSheet(
                          score, productiveSecs, distractingSecs),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Productivity Score',
                                            style: TextStyle(
                                              color: Color(0xFF5F6368),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.info_outline,
                                              size: 14, color: Color(0xFF80868B)),
                                          if (_streakDays > 0) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF7E0),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.star_rounded,
                                                    size: 12,
                                                    color: Color(0xFFF9AB00),
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    '${_streakDays}d streak',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFFB06000),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        scoreDesc,
                                        style: const TextStyle(
                                          color: Color(0xFF202124),
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
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
                                      color:
                                          scoreColor.withValues(alpha: 0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$score',
                                      style: TextStyle(
                                        color: scoreColor,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),
                            const Divider(color: AppColors.border, height: 1),
                            const SizedBox(height: 14),

                            // Sub-metrics Pill Bar
                            Row(
                              children: [
                                Expanded(
                                  child: _metricPill(
                                    icon: Icons.timer_outlined,
                                    label: 'Focus',
                                    value: _formatMinutes(_focusMinutesToday),
                                    color: AppColors.productive,
                                    bg: AppColors.productiveContainer,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _metricPill(
                                    icon: Icons.warning_amber_rounded,
                                    label: 'Distraction',
                                    value:
                                        '${(distractingSecs / 60).round()}m',
                                    color: AppColors.distracting,
                                    bg: AppColors.distractingContainer,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _metricPill(
                                    icon: Icons.check_circle_outline,
                                    label: 'Productive',
                                    value:
                                        '${(productiveSecs / 60).round()}m',
                                    color: AppColors.primary,
                                    bg: AppColors.primaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Quick Actions Bar (Fully Functional)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const FocusSessionScreen()),
                              );
                            },
                            icon: const Icon(Icons.play_arrow_rounded,
                                size: 18),
                            label: const Text('Start Focus'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _loadDashboardData,
                            icon: const Icon(Icons.autorenew_rounded,
                                size: 18),
                            label: const Text('Sync Logs'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const SettingsScreen()),
                              );
                            },
                            icon: const Icon(Icons.tune_rounded, size: 18),
                            label: const Text('App Limits'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Top 3 Apps Used Today (Tappable for App Limits)
                    if (_topApps.isNotEmpty) ...[
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Top Apps Used Today',
                            style: TextStyle(
                              color: Color(0xFF202124),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Tap to set limit',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: _topApps.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final app = entry.value;
                            final catColor =
                                _getCategoryColor(app['category'] as String);
                            final durationSecs =
                                app['durationSeconds'] as int;
                            final pkgName = app['packageName'] as String;
                            final appName = app['appName'] as String;

                            return Column(
                              children: [
                                if (idx > 0)
                                  const Divider(
                                      color: AppColors.border, height: 16),
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
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor:
                                              catColor.withValues(alpha: 0.1),
                                          child: Icon(
                                            Icons.android_rounded,
                                            size: 20,
                                            color: catColor,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                appName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                  color: Color(0xFF202124),
                                                ),
                                              ),
                                              Text(
                                                (app['category'] as String)
                                                    .toUpperCase(),
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
                                            color: Color(0xFF202124),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.edit_outlined,
                                            size: 16, color: Color(0xFF80868B)),
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

                    // Donut Chart
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Today's Screen Time",
                          style: TextStyle(
                            color: Color(0xFF202124),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_selectedCategory != null)
                          GestureDetector(
                            onTap: () => _onCategoryTapped(null),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.close,
                                      color: AppColors.primary, size: 14),
                                  SizedBox(width: 4),
                                  Text('Clear filter',
                                      style: TextStyle(
                                          color: AppColors.primary,
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: CategoryChart(
                        categoryTotals: _categoryTotals,
                        onCategoryTapped: _onCategoryTapped,
                        highlightedCategory: _selectedCategory,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Trend Line Chart
                    const Text(
                      '7-Day Screen Time Trend',
                      style: TextStyle(
                        color: Color(0xFF202124),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TrendChart(
                        dailyTotals: _trendTotals,
                        onDayTapped: _onDayTapped,
                        highlightedDay: _selectedDay,
                      ),
                    ),

                    if (_selectedDay != null && _selectedDayBreakdown != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.primary),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today,
                                        color: AppColors.primary, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year} breakdown',
                                      style: const TextStyle(
                                        color: Color(0xFF202124),
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: () => setState(() {
                                        _selectedDay = null;
                                        _selectedDayBreakdown = null;
                                      }),
                                      child: const Icon(Icons.close,
                                          color: Color(0xFF5F6368), size: 18),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                CategoryChart(
                                    categoryTotals: _selectedDayBreakdown!),
                              ],
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 24),

                    // Recent AI Alerts
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent AI Alerts & Routines',
                          style: TextStyle(
                            color: Color(0xFF202124),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_selectedCategory != null)
                          Text(
                            'Filtered: $_selectedCategory',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_filteredAlerts.isEmpty)
                      _buildAlertsEmptyState()
                    else
                      Column(
                        children: [
                          ..._filteredAlerts
                              .map((alert) => AlertTile(alert: alert)),
                          if (_hasMoreAlerts && _selectedCategory == null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: _loadingMoreAlerts
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(12),
                                        child: CircularProgressIndicator(
                                            color: AppColors.primary),
                                      ),
                                    )
                                  : OutlinedButton.icon(
                                      onPressed: _loadMoreAlerts,
                                      icon: const Icon(Icons.expand_more,
                                          size: 18),
                                      label: const Text('Load More Alerts'),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize:
                                            const Size.fromHeight(42),
                                      ),
                                    ),
                            ),
                        ],
                      ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
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
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.notifications_none_outlined,
            color: Color(0xFF80868B),
            size: 44,
          ),
          const SizedBox(height: 12),
          Text(
            _selectedCategory != null
                ? 'No alerts for "$_selectedCategory" apps'
                : 'No alerts or routines detected yet',
            style: const TextStyle(color: Color(0xFF5F6368), fontSize: 13),
            textAlign: TextAlign.center,
          ),
          if (_selectedCategory != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _onCategoryTapped(null),
              child: const Text('Clear filter'),
            ),
          ],
        ],
      ),
    );
  }
}
