import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../data/repositories/usage_repository.dart';
import '../../data/repositories/focus_repository.dart';
import '../../domain/models/usage_log.dart';
import '../../domain/models/focus_session.dart';
import '../widgets/category_chart.dart';
import '../widgets/trend_chart.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  final UsageRepository _usageRepository = UsageRepository();
  final FocusRepository _focusRepository = FocusRepository();

  late TabController _tabController;
  bool _isLoading = true;

  Map<DateTime, int> _trendTotals = {};
  List<UsageLog> _todayLogs = [];
  List<UsageLog> _filteredLogs = [];
  List<FocusSession> _focusSessions = [];
  Map<String, int> _todayCategoryTotals = {};
  int _streakDays = 0;

  String _searchQuery = '';
  String _selectedCategoryFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHistoryData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistoryData() async {
    setState(() => _isLoading = true);

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final trend = await _usageRepository.get7DayScreenTimeTrend();
    final logs = await _usageRepository.getLogsInWindow(startOfDay, endOfDay);
    final sessions = await _focusRepository.getSessionsInWindow(
      now.subtract(const Duration(days: 7)),
      endOfDay,
    );
    final categoryTotals =
        await _usageRepository.getCategoryScreenTimeForToday();
    final streak = await _usageRepository.getProductivityStreak();

    if (mounted) {
      setState(() {
        _trendTotals = trend;
        _todayLogs = logs;
        _focusSessions = sessions;
        _todayCategoryTotals = categoryTotals;
        _streakDays = streak;
        _applyFilters();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    _filteredLogs = _todayLogs.where((log) {
      final matchesSearch = _searchQuery.isEmpty ||
          log.appName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          log.packageName.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesCategory = _selectedCategoryFilter == 'all' ||
          log.category == _selectedCategoryFilter;

      return matchesSearch && matchesCategory;
    }).toList();
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds < 60) return '${totalSeconds}s';
    final mins = totalSeconds ~/ 60;
    if (mins < 60) return '${mins}m';
    final hours = mins ~/ 60;
    final remMins = mins % 60;
    return '${hours}h ${remMins}m';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Analytics & History',
          style: TextStyle(
            color: Color(0xFF202124),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF5F6368)),
            onPressed: _loadHistoryData,
            tooltip: 'Refresh Data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.show_chart_rounded), text: 'Screen Time'),
            Tab(icon: Icon(Icons.timer_outlined), text: 'Focus History'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildScreenTimeTab(),
                _buildFocusHistoryTab(),
              ],
            ),
    );
  }

  Widget _buildScreenTimeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Focus Streak Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF7E0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFF9AB00),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_streakDays-Day Focus Streak',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF202124),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _streakDays > 0
                            ? 'Great job! Keep maintaining your productive routines.'
                            : 'Achieve a high productivity score today to start a new streak.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5F6368),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 7-Day Usage Trend
          const Text(
            '7-Day Usage Trend',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF202124),
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
            child: TrendChart(dailyTotals: _trendTotals),
          ),
          const SizedBox(height: 20),

          // Category Share Breakdown
          const Text(
            "Today's Category Share",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF202124),
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
            child: CategoryChart(categoryTotals: _todayCategoryTotals),
          ),
          const SizedBox(height: 24),

          // Search & Filters Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Today App Activity Logs',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF202124),
                ),
              ),
              Text(
                '${_filteredLogs.length} sessions',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF5F6368),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search Bar
          TextField(
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
                _applyFilters();
              });
            },
            style: const TextStyle(color: Color(0xFF202124), fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search app logs by name...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('all', 'All Categories'),
                const SizedBox(width: 8),
                _filterChip('productive', 'Productive'),
                const SizedBox(width: 8),
                _filterChip('distracting', 'Distracting'),
                const SizedBox(width: 8),
                _filterChip('neutral', 'Neutral'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_filteredLogs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                children: [
                  Icon(Icons.search_off_outlined,
                      size: 40, color: Color(0xFF80868B)),
                  SizedBox(height: 12),
                  Text(
                    'No matching activity logs found',
                    style: TextStyle(color: Color(0xFF5F6368), fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredLogs.length > 30 ? 30 : _filteredLogs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final log = _filteredLogs[index];
                final catColor = _getCategoryColor(log.category);

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.android_rounded,
                          color: catColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.appName.isNotEmpty
                                  ? log.appName
                                  : log.packageName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Color(0xFF202124),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${DateFormat('h:mm a').format(log.startTime)} - ${DateFormat('h:mm a').format(log.endTime)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF5F6368),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatDuration(log.durationSeconds),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF202124),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              log.category.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: catColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _filterChip(String categoryKey, String label) {
    final isSelected = _selectedCategoryFilter == categoryKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedCategoryFilter = categoryKey;
            _applyFilters();
          });
        }
      },
      selectedColor: AppColors.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : const Color(0xFF5F6368),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
        ),
      ),
    );
  }

  Widget _buildFocusHistoryTab() {
    if (_focusSessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timer_off_outlined,
                size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No completed focus sessions recorded',
              style: TextStyle(fontSize: 15, color: Color(0xFF5F6368)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Start a focus session from the Focus tab to build your log',
              style: TextStyle(fontSize: 12, color: Color(0xFF80868B)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _focusSessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final session = _focusSessions[index];
        final dateStr = DateFormat('EEE, MMM d, yyyy').format(session.startTime);
        final timeStr =
            '${DateFormat('h:mm a').format(session.startTime)} - ${DateFormat('h:mm a').format(session.endTime)}';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFE6F4EA),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Color(0xFF1E8E3E),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${session.durationMinutes}-Minute Focus Session',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF202124),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$dateStr • $timeStr',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5F6368),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'COMPLETED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
