import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/preferences_repository.dart';
import '../../domain/models/app_category.dart';
import '../../domain/services/retention_policy.dart';
import '../widgets/category_picker_dialog.dart';
import '../widgets/app_limit_dialog.dart';
import '../../services/security_service.dart';
import '../../services/usage_collector_service.dart';
import 'network_proof_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  final CategoryRepository _categoryRepository = CategoryRepository();
  final SecurityService _securityService = SecurityService();
  final PreferencesRepository _prefs = PreferencesRepository();
  final RetentionPolicy _retentionPolicy = RetentionPolicy();
  final UsageCollectorService _collector = UsageCollectorService();

  late TabController _tabController;

  List<AppCategory> _categories = [];
  List<AppCategory> _filteredCategories = [];
  bool _isLoadingApps = true;
  String _searchQuery = '';

  bool _isLoadingPrefs = true;
  int _quietStart = 22;
  int _quietEnd = 7;
  bool _muteDistraction = false;
  bool _muteRoutine = false;
  int _maxAlerts = 20;
  int _earlyWarningPct = 80;
  bool _weeklySummary = false;
  RetentionOption _retentionOption = RetentionOption.days90;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCategories();
    _loadPreferences();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingApps = true);
    final list = await _categoryRepository.getAllCategories();
    if (mounted) {
      setState(() {
        _categories = list;
        _filterList(_searchQuery);
        _isLoadingApps = false;
      });
    }
  }

  Future<void> _loadPreferences() async {
    setState(() => _isLoadingPrefs = true);
    final qs = await _prefs.getQuietHoursStart();
    final qe = await _prefs.getQuietHoursEnd();
    final md = await _prefs.isDistractionMuted();
    final mr = await _prefs.isRoutineMuted();
    final ma = await _prefs.getMaxAlertsPerDay();
    final ew = await _prefs.getEarlyWarningThresholdPct();
    final ws = await _prefs.isWeeklySummaryEnabled();
    final ro = await _retentionPolicy.getCurrentOption();
    if (mounted) {
      setState(() {
        _quietStart = qs;
        _quietEnd = qe;
        _muteDistraction = md;
        _muteRoutine = mr;
        _maxAlerts = ma;
        _earlyWarningPct = ew;
        _weeklySummary = ws;
        _retentionOption = ro;
        _isLoadingPrefs = false;
      });
    }
  }

  void _filterList(String query) {
    _searchQuery = query;
    final q = query.toLowerCase();
    _filteredCategories = query.isEmpty
        ? List.from(_categories)
        : _categories
            .where((cat) =>
                cat.appName.toLowerCase().contains(q) ||
                cat.packageName.toLowerCase().contains(q))
            .toList();
  }

  Future<void> _updateCategory(AppCategory category, String newCat) async {
    await _categoryRepository.updateCategory(category.packageName, newCat);
    await _loadCategories();
  }

  Future<void> _resetToDefault(AppCategory category) async {
    await _categoryRepository.resetToDefault(category.packageName);
    await _loadCategories();
  }

  Future<void> _exportData() async {
    final exportJson = await _securityService.exportAppDataAsJson();
    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border, width: 1.0),
              ),
          title: const Text('EXPORTED APP DATA (JSON)',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 1.2)),
          content: SingleChildScrollView(
            child: SelectableText(
              exportJson,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontFamily: 'monospace'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: AppColors.textPrimary)),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _pickHour(
      String label, int current, Future<void> Function(int) onSet) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (_) => _HourPickerDialog(label: label, current: current),
    );
    if (picked != null) {
      await onSet(picked);
      _loadPreferences();
    }
  }

  void _showAppActionSheet(AppCategory item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
            const SizedBox(height: 16),
            Text(
              item.appName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.category_outlined, color: AppColors.textPrimary, size: 20),
              title: const Text('Change Category',
                  style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary, fontSize: 14)),
              subtitle: Text('Current: ${item.category.toUpperCase()}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => CategoryPickerDialog(
                    currentCategory: item.category,
                    isCustom: item.isCustom,
                    onSelected: (newCat) => _updateCategory(item, newCat),
                    onReset: item.isCustom ? () => _resetToDefault(item) : null,
                  ),
                );
              },
            ),
            const Divider(color: AppColors.border),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.timer_outlined, color: AppColors.textPrimary, size: 20),
              title: const Text('Set Daily Screen-Time Limit',
                  style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary, fontSize: 14)),
              subtitle: const Text('Configure daily maximum usage duration',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => AppLimitDialog(
                    packageName: item.packageName,
                    appName: item.appName,
                    onLimitSaved: _loadCategories,
                  ),
                );
              },
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
      appBar: AppBar(
        title: const Text(
          'SETTINGS & LIMITS',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.textPrimary,
          indicatorWeight: 2,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 0.8),
          tabs: const [
            Tab(icon: Icon(Icons.apps_outlined, size: 18), text: 'APP CATEGORIES'),
            Tab(icon: Icon(Icons.tune_outlined, size: 18), text: 'PREFERENCES'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAppsTab(),
          _buildPreferencesTab(),
        ],
      ),
    );
  }

  Widget _buildAppsTab() {
    return _isLoadingApps
        ? const Center(
            child: CircularProgressIndicator(color: AppColors.textPrimary))
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  onChanged: (val) => setState(() => _filterList(val)),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search app or package name...',
                    hintStyle: const TextStyle(color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                    filled: true,
                    fillColor: AppColors.surface,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.textPrimary, width: 1.0),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: OutlinedButton.icon(
                  onPressed: _exportData,
                  icon: const Icon(Icons.download_outlined, color: AppColors.textPrimary, size: 18),
                  label: const Text('Export Local Data (JSON)', style: TextStyle(color: AppColors.textPrimary)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _filteredCategories.isEmpty
                    ? const Center(
                        child: Text('No matching packages found',
                            style: TextStyle(color: AppColors.textSecondary)),
                      )
                    : ListView.builder(
                        itemCount: _filteredCategories.length,
                        itemBuilder: (context, index) {
                          final item = _filteredCategories[index];
                          return Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              child: ListTile(
                                title: Text(
                                  item.appName,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  item.appName != item.packageName
                                      ? '${item.packageName} · ${item.isCustom ? "Custom" : "Default"}'
                                      : (item.isCustom ? 'Custom Override' : 'Default Preset'),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceRaised,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.border, width: 0.5),
                                  ),
                                  child: Text(
                                    item.category.toUpperCase(),
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                onTap: () => _showAppActionSheet(item),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
  }

  Widget _buildPreferencesTab() {
    if (_isLoadingPrefs) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.textPrimary));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('Notification Behavior', Icons.notifications_outlined),
        const SizedBox(height: 8),
        _prefCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Color(0xFF00E5FF), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Background Monitoring Indicator',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Android requires a continuous low-priority foreground notification for real-time screen-time tracking and overlay protection. It is silent and has no sound or vibration.',
                  style: TextStyle(color: Color(0xFF8E8EA2), fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _collector.openNotificationChannelSettings(),
                  icon: const Icon(Icons.tune_outlined, size: 16),
                  label: const Text('Configure or Hide from Status Bar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _prefCard(
          child: Column(
            children: [
              _toggleRow(
                icon: Icons.warning_amber_outlined,
                label: 'Mute Distraction Alerts',
                value: _muteDistraction,
                onChanged: (v) async {
                  await _prefs.setDistractionMuted(v);
                  setState(() => _muteDistraction = v);
                },
              ),
              const Divider(color: AppColors.border, height: 1),
              _toggleRow(
                icon: Icons.psychology_outlined,
                label: 'Mute Routine Reminders',
                value: _muteRoutine,
                onChanged: (v) async {
                  await _prefs.setRoutineMuted(v);
                  setState(() => _muteRoutine = v);
                },
              ),
              const Divider(color: AppColors.border, height: 1),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up,
                        color: AppColors.textSecondary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Max Alerts Per Day',
                              style: TextStyle(
                                  color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                          Text('$_maxAlerts alerts per day',
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      child: Slider(
                        value: _maxAlerts.toDouble(),
                        min: 1,
                        max: 50,
                        divisions: 49,
                        activeColor: AppColors.textPrimary,
                        inactiveColor: AppColors.border,
                        onChanged: (v) =>
                            setState(() => _maxAlerts = v.toInt()),
                        onChangeEnd: (v) async {
                          await _prefs.setMaxAlertsPerDay(v.toInt());
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.border, height: 1),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined,
                        color: AppColors.textPrimary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Early Warning Threshold',
                              style: TextStyle(
                                  color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                          Text('$_earlyWarningPct% of limit (nudge before overlay)',
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      child: Slider(
                        value: _earlyWarningPct.toDouble(),
                        min: 50,
                        max: 95,
                        divisions: 9,
                        activeColor: AppColors.textPrimary,
                        inactiveColor: AppColors.border,
                        onChanged: (v) =>
                            setState(() => _earlyWarningPct = v.toInt()),
                        onChangeEnd: (v) async {
                          await _prefs.setEarlyWarningThresholdPct(v.toInt());
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        _sectionHeader('Quiet Hours', Icons.bedtime_outlined),
        const SizedBox(height: 8),
        _prefCard(
          child: Column(
            children: [
              _tapRow(
                icon: Icons.nights_stay_outlined,
                label: 'Start Hour',
                value: '${_quietStart.toString().padLeft(2, '0')}:00',
                onTap: () => _pickHour(
                  'Quiet Hours Start',
                  _quietStart,
                  (h) => _prefs.setQuietHoursStart(h),
                ),
              ),
              const Divider(color: AppColors.border, height: 1),
              _tapRow(
                icon: Icons.wb_sunny_outlined,
                label: 'End Hour',
                value: '${_quietEnd.toString().padLeft(2, '0')}:00',
                onTap: () => _pickHour(
                  'Quiet Hours End',
                  _quietEnd,
                  (h) => _prefs.setQuietHoursEnd(h),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Text(
            'No notifications sent between '
            '${_quietStart.toString().padLeft(2, '0')}:00 and '
            '${_quietEnd.toString().padLeft(2, '0')}:00',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ),

        const SizedBox(height: 20),

        _sectionHeader('Weekly Digest', Icons.calendar_month_outlined),
        const SizedBox(height: 8),
        _prefCard(
          child: _toggleRow(
            icon: Icons.bar_chart_outlined,
            label: 'Weekly Productivity Digest',
            subtitle: 'Receive scheduled summary notification once per week',
            value: _weeklySummary,
            onChanged: (v) async {
              await _prefs.setWeeklySummaryEnabled(v);
              setState(() => _weeklySummary = v);
            },
          ),
        ),

        const SizedBox(height: 20),

        _sectionHeader('Privacy & Security', Icons.shield_outlined),
        const SizedBox(height: 8),
        _prefCard(
          child: ListTile(
            leading: const Icon(Icons.verified_user_outlined, color: AppColors.textPrimary),
            title: const Text('Network-Proof Privacy Verification',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
            subtitle: const Text('Live assertion: 0 network calls, internet permission not requested',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            trailing: const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NetworkProofScreen()),
              );
            },
          ),
        ),

        const SizedBox(height: 20),

        _sectionHeader('Data Retention', Icons.storage_outlined),
        const SizedBox(height: 8),
        _prefCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.delete_sweep_outlined,
                    color: AppColors.textSecondary, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Keep raw logs for',
                          style: TextStyle(
                              color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                      Text(
                        'Older entries are pruned automatically',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                DropdownButton<RetentionOption>(
                  value: _retentionOption,
                  dropdownColor: AppColors.surfaceRaised,
                  underline: const SizedBox(),
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                  items: RetentionOption.values
                      .map((o) => DropdownMenuItem(
                            value: o,
                            child: Text(o.label),
                          ))
                      .toList(),
                  onChanged: (o) async {
                    if (o == null) return;
                    await _retentionPolicy.setOption(o);
                    setState(() => _retentionOption = o);
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 18),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _prefCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.0),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }

  Widget _toggleRow({
    required IconData icon,
    required String label,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      activeThumbColor: Colors.black,
      activeTrackColor: Colors.white,
      inactiveThumbColor: AppColors.textSecondary,
      inactiveTrackColor: AppColors.surfaceRaised,
      secondary: Icon(icon, color: AppColors.textSecondary, size: 20),
      title: Text(label,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12))
          : null,
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _tapRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 20),
      title: Text(label,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right,
              color: AppColors.textSecondary, size: 18),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _HourPickerDialog extends StatefulWidget {
  final String label;
  final int current;

  const _HourPickerDialog({required this.label, required this.current});

  @override
  State<_HourPickerDialog> createState() => _HourPickerDialogState();
}

class _HourPickerDialogState extends State<_HourPickerDialog> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1.0),
      ),
      title: Text(
        widget.label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          letterSpacing: 1.2,
        ),
      ),
      content: SizedBox(
        height: 220,
        width: 100,
        child: ListWheelScrollView.useDelegate(
          itemExtent: 44,
          onSelectedItemChanged: (i) => setState(() => _selected = i),
          controller:
              FixedExtentScrollController(initialItem: widget.current),
          childDelegate: ListWheelChildBuilderDelegate(
            builder: (context, index) {
              if (index < 0 || index > 23) return null;
              final isSelected = index == _selected;
              return Center(
                child: Text(
                  '${index.toString().padLeft(2, '0')}:00',
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize: isSelected ? 22 : 16,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              );
            },
            childCount: 24,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selected),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Set',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
