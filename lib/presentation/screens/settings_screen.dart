import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/preferences_repository.dart';
import '../../domain/models/app_category.dart';
import '../../domain/services/retention_policy.dart';
import '../widgets/category_picker_dialog.dart';
import '../widgets/app_limit_dialog.dart';
import '../../services/security_service.dart';
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
    final ws = await _prefs.isWeeklySummaryEnabled();
    final ro = await _retentionPolicy.getCurrentOption();
    if (mounted) {
      setState(() {
        _quietStart = qs;
        _quietEnd = qe;
        _muteDistraction = md;
        _muteRoutine = mr;
        _maxAlerts = ma;
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
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Exported App Data (JSON)',
              style: TextStyle(color: Color(0xFF202124))),
          content: SingleChildScrollView(
            child: SelectableText(
              exportJson,
              style: const TextStyle(
                  color: Color(0xFF5F6368),
                  fontSize: 12,
                  fontFamily: 'monospace'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
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
            const SizedBox(height: 16),
            Text(
              item.appName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF202124),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.category_outlined, color: AppColors.primary),
              title: const Text('Change Category',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Current: ${item.category.toUpperCase()}'),
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
              leading: const Icon(Icons.timer_outlined, color: AppColors.productive),
              title: const Text('Set Daily Screen-Time Limit',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Configure daily maximum usage duration'),
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Settings & Categories',
          style: TextStyle(
            color: Color(0xFF202124),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.apps_rounded), text: 'App Categories'),
            Tab(icon: Icon(Icons.tune_rounded), text: 'Preferences'),
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
            child: CircularProgressIndicator(color: AppColors.primary))
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  onChanged: (val) => setState(() => _filterList(val)),
                  style: const TextStyle(color: Color(0xFF202124)),
                  decoration: InputDecoration(
                    hintText: 'Search app package name...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: OutlinedButton.icon(
                  onPressed: _exportData,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Export Local Data (JSON)'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _filteredCategories.isEmpty
                    ? const Center(
                        child: Text('No matching packages found',
                            style: TextStyle(color: Color(0xFF5F6368))),
                      )
                    : ListView.builder(
                        itemCount: _filteredCategories.length,
                        itemBuilder: (context, index) {
                          final item = _filteredCategories[index];
                          final color = _getCategoryColor(item.category);
                          return Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
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
                                    color: Color(0xFF202124),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  item.appName != item.packageName
                                      ? '${item.packageName} · ${item.isCustom ? "Custom Override" : "Default Preset"}'
                                      : (item.isCustom ? 'Custom Override' : 'Default Preset'),
                                  style: const TextStyle(
                                    color: Color(0xFF5F6368),
                                    fontSize: 11,
                                  ),
                                ),
                                trailing: Chip(
                                  backgroundColor:
                                      color.withValues(alpha: 0.12),
                                  side: BorderSide(color: color),
                                  label: Text(
                                    item.category.toUpperCase(),
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
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
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('Notification Behavior', Icons.notifications_outlined),
        const SizedBox(height: 8),
        _prefCard(
          child: Column(
            children: [
              _toggleRow(
                icon: Icons.warning_amber_rounded,
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
                        color: Color(0xFF5F6368), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Max Alerts Per Day',
                              style: TextStyle(
                                  color: Color(0xFF202124), fontSize: 14)),
                          Text('$_maxAlerts alerts per day',
                              style: const TextStyle(
                                  color: Color(0xFF5F6368), fontSize: 12)),
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
                        activeColor: AppColors.primary,
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
            style: const TextStyle(color: Color(0xFF5F6368), fontSize: 12),
          ),
        ),

        const SizedBox(height: 20),

        _sectionHeader('Weekly Digest', Icons.calendar_month_outlined),
        const SizedBox(height: 8),
        _prefCard(
          child: _toggleRow(
            icon: Icons.bar_chart,
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
            leading: const Icon(Icons.verified_user_outlined, color: Color(0xFF1B4F8A)),
            title: const Text('Network-Proof Privacy Verification', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: const Text('Live assertion: 0 network calls, internet permission not requested', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, size: 20),
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
                    color: Color(0xFF5F6368), size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Keep raw logs for',
                          style: TextStyle(
                              color: Color(0xFF202124), fontSize: 14)),
                      Text(
                        'Older entries are pruned automatically',
                        style: TextStyle(
                            color: Color(0xFF5F6368), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                DropdownButton<RetentionOption>(
                  value: _retentionOption,
                  dropdownColor: Colors.white,
                  underline: const SizedBox(),
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
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
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF202124),
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _prefCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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
      activeThumbColor: Colors.white,
      activeTrackColor: AppColors.primary,
      secondary: Icon(icon, color: const Color(0xFF5F6368), size: 20),
      title: Text(label,
          style: const TextStyle(color: Color(0xFF202124), fontSize: 14)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: const TextStyle(
                  color: Color(0xFF5F6368), fontSize: 12))
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
      leading: Icon(icon, color: const Color(0xFF5F6368), size: 20),
      title: Text(label,
          style: const TextStyle(color: Color(0xFF202124), fontSize: 14)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right,
              color: Color(0xFF80868B), size: 18),
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
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        widget.label,
        style: const TextStyle(
          color: Color(0xFF202124),
          fontWeight: FontWeight.bold,
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
                        ? AppColors.primary
                        : const Color(0xFF5F6368),
                    fontSize: isSelected ? 20 : 16,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
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
              style: TextStyle(color: Color(0xFF5F6368))),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Set',
              style: TextStyle(color: AppColors.primary)),
        ),
      ],
    );
  }
}
