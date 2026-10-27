import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';

typedef DayTapCallback = void Function(DateTime day);

class TrendChart extends StatefulWidget {
  final Map<DateTime, int> dailyTotals;
  final DayTapCallback? onDayTapped;
  final DateTime? highlightedDay;

  const TrendChart({
    super.key,
    required this.dailyTotals,
    this.onDayTapped,
    this.highlightedDay,
  });

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.dailyTotals.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        child: const Text(
          'No 7-day trend data available',
          style: TextStyle(color: Color(0xFF5F6368), fontSize: 13),
        ),
      );
    }

    final entries = widget.dailyTotals.entries.toList()
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
                  const FlLine(color: Color(0xFFE8EAED), strokeWidth: 1),
              getDrawingVerticalLine: (_) =>
                  const FlLine(color: Color(0xFFE8EAED), strokeWidth: 1),
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
                      final isHighlighted = widget.highlightedDay != null &&
                          _sameDay(entries[index].key, widget.highlightedDay!);
                      return Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          DateFormat('E').format(entries[index].key),
                          style: TextStyle(
                            color: isHighlighted
                                ? AppColors.primary
                                : const Color(0xFF5F6368),
                            fontSize: 11,
                            fontWeight: isHighlighted
                                ? FontWeight.bold
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
                      color: Color(0xFF5F6368),
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
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
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
                color: AppColors.primary,
                barWidth: 3.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    final isHighlighted = _touchedIndex == index ||
                        (widget.highlightedDay != null &&
                            index < entries.length &&
                            _sameDay(entries[index].key,
                                widget.highlightedDay!));
                    return FlDotCirclePainter(
                      radius: isHighlighted ? 7 : 4,
                      color: isHighlighted
                          ? Colors.white
                          : AppColors.primary,
                      strokeWidth: isHighlighted ? 3 : 0,
                      strokeColor: AppColors.primary,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.primary.withValues(alpha: 0.12),
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
