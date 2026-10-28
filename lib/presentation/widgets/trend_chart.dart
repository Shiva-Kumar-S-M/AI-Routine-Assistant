import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';

typedef DayTapCallback = void Function(DateTime day);

class TrendChart extends StatefulWidget {
  final Map<DateTime, int>? dailyTotals;
  final Map<DateTime, int>? trendTotals;
  final DayTapCallback? onDayTapped;
  final DateTime? highlightedDay;
  final DateTime? selectedDay;

  const TrendChart({
    super.key,
    this.dailyTotals,
    this.trendTotals,
    this.onDayTapped,
    this.highlightedDay,
    this.selectedDay,
  });

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  int _touchedIndex = -1;

  Map<DateTime, int> get _data => widget.dailyTotals ?? widget.trendTotals ?? {};
  DateTime? get _activeDay => widget.highlightedDay ?? widget.selectedDay;

  @override
  Widget build(BuildContext context) {
    if (_data.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        child: const Text(
          'No 7-day trend data available yet',
          style: TextStyle(color: Color(0xFF8E8EA2), fontSize: 13),
        ),
      );
    }

    final entries = _data.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final spots = <FlSpot>[
      for (int i = 0; i < entries.length; i++)
        FlSpot(i.toDouble(), entries[i].value / 3600),
    ];

    return AspectRatio(
      aspectRatio: 1.8,
      child: Padding(
        padding: const EdgeInsets.only(right: 16.0, top: 12.0),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: AppColors.border, strokeWidth: 1),
              getDrawingVerticalLine: (_) =>
                  const FlLine(color: AppColors.border, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < entries.length) {
                      final isHighlighted = _activeDay != null &&
                          _sameDay(entries[index].key, _activeDay!);
                      return Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          DateFormat('E').format(entries[index].key),
                          style: TextStyle(
                            color: isHighlighted
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: isHighlighted
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (value, meta) => Text(
                    '${value.toInt()}h',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchCallback: (event, response) {
                if (event is FlTapUpEvent &&
                    response?.lineBarSpots != null &&
                    response!.lineBarSpots!.isNotEmpty) {
                  final idx = response.lineBarSpots!.first.x.toInt();
                  if (idx >= 0 && idx < entries.length) {
                    setState(() => _touchedIndex = idx);
                    widget.onDayTapped?.call(entries[idx].key);
                  }
                }
              },
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots.map((s) {
                  final idx = s.x.toInt();
                  if (idx < entries.length) {
                    final h = (entries[idx].value / 3600).toStringAsFixed(1);
                    return LineTooltipItem(
                      '${DateFormat('EEE').format(entries[idx].key)}\n${h}h',
                      const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }
                  return null;
                }).toList(),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppColors.textPrimary,
                barWidth: 2.0,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    final isHighlighted = _touchedIndex == index ||
                        (_activeDay != null &&
                            index < entries.length &&
                            _sameDay(entries[index].key, _activeDay!));
                    return FlDotCirclePainter(
                      radius: isHighlighted ? 5 : 3,
                      color: isHighlighted
                          ? AppColors.textPrimary
                          : AppColors.surfaceRaised,
                      strokeWidth: isHighlighted ? 2 : 1,
                      strokeColor: AppColors.textPrimary,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.textPrimary.withValues(alpha: 0.08),
                      AppColors.textPrimary.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
